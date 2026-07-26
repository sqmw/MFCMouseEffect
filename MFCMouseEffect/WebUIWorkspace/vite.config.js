import path from 'node:path';
import fs from 'node:fs';
import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import { WEBUI_BUILD_TARGETS } from './scripts/webui-bundle-manifest.mjs';

const ENTRY_ROOT = 'src/entries';
const DEV_RUNTIME_ROUTE = '/__mfx/dev-runtime';
const DEFAULT_DEV_PROBE_FILE = '/tmp/mfx-core-websettings.probe';

const TARGETS = WEBUI_BUILD_TARGETS;

function pickBuildTarget(mode) {
  const target = TARGETS[mode] || TARGETS.workspace;
  return {
    entry: path.resolve(__dirname, ENTRY_ROOT, target.entry),
    name: target.name,
    fileName: target.fileName,
  };
}

function trimText(value) {
  return `${value || ''}`.trim();
}

function safeOrigin(rawUrl) {
  try {
    return trimText(new URL(rawUrl).origin);
  } catch (_error) {
    return '';
  }
}

function safeTokenFromUrl(rawUrl) {
  try {
    return trimText(new URL(rawUrl).searchParams.get('token') || '');
  } catch (_error) {
    return '';
  }
}

function readProbeRuntime(probeFile) {
  const runtime = {
    probeFile,
    url: '',
    baseUrl: '',
    token: '',
  };
  if (!probeFile || !fs.existsSync(probeFile)) {
    return runtime;
  }

  const lines = fs.readFileSync(probeFile, 'utf8').split(/\r?\n/);
  for (const line of lines) {
    const index = line.indexOf('=');
    if (index <= 0) {
      continue;
    }
    const key = trimText(line.slice(0, index));
    const value = trimText(line.slice(index + 1));
    if (!key || !value) {
      continue;
    }
    if (key === 'url') {
      runtime.url = value;
      continue;
    }
    if (key === 'token') {
      runtime.token = value;
      continue;
    }
    if (key === 'base_url' || key === 'baseUrl') {
      runtime.baseUrl = value;
    }
  }

  if (!runtime.baseUrl && runtime.url) {
    runtime.baseUrl = safeOrigin(runtime.url);
  }
  if (!runtime.token && runtime.url) {
    runtime.token = safeTokenFromUrl(runtime.url);
  }
  return runtime;
}

function resolveDevRuntime() {
  const probeFile = trimText(process.env.MFX_WEBUI_DEV_PROBE_FILE || DEFAULT_DEV_PROBE_FILE);
  const probeRuntime = readProbeRuntime(probeFile);
  const baseUrl = trimText(process.env.MFX_WEBUI_DEV_BASE_URL || probeRuntime.baseUrl);
  const token = trimText(process.env.MFX_WEBUI_DEV_TOKEN || probeRuntime.token);
  const settingsUrl = trimText(probeRuntime.url || (baseUrl ? `${baseUrl}/` : ''));

  return {
    available: !!baseUrl,
    baseUrl,
    token,
    settingsUrl,
    probeFile,
    reason: baseUrl ? '' : 'backend runtime not discovered',
  };
}

async function checkDevRuntimeBackend(runtime) {
  if (!runtime?.baseUrl) {
    return runtime;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 800);
  try {
    const target = new URL('/api/state', runtime.baseUrl);
    const headers = new Headers();
    if (runtime.token) {
      headers.set('x-mfcmouseeffect-token', runtime.token);
    }
    const response = await fetch(target, {
      method: 'GET',
      headers,
      signal: controller.signal,
    });
    if (response.ok) {
      return {
        ...runtime,
        available: true,
        reason: '',
      };
    }
    return {
      ...runtime,
      available: false,
      reason: `backend state probe failed: HTTP ${response.status}`,
    };
  } catch (error) {
    return {
      ...runtime,
      available: false,
      reason: error instanceof Error ? error.message : String(error),
    };
  } finally {
    clearTimeout(timeout);
  }
}

function readRequestBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (chunk) => {
      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    });
    req.on('end', () => {
      resolve(chunks.length > 0 ? Buffer.concat(chunks) : Buffer.alloc(0));
    });
    req.on('error', reject);
  });
}

function createDevRuntimePlugin() {
  return {
    name: 'mfx-dev-runtime',
    configureServer(server) {
      server.middlewares.use(async (req, res, next) => {
        const requestUrl = trimText(req.originalUrl || req.url || '');
        if (!requestUrl) {
          next();
          return;
        }

        if (requestUrl === DEV_RUNTIME_ROUTE) {
          const runtime = await checkDevRuntimeBackend(resolveDevRuntime());
          res.statusCode = 200;
          res.setHeader('Content-Type', 'application/json; charset=utf-8');
          res.end(JSON.stringify(runtime));
          return;
        }

        if (!requestUrl.startsWith('/api/')) {
          next();
          return;
        }

        const runtime = resolveDevRuntime();
        if (!runtime.available) {
          res.statusCode = 502;
          res.setHeader('Content-Type', 'application/json; charset=utf-8');
          res.end(JSON.stringify({
            ok: false,
            error: 'mfx-dev-runtime unavailable',
            probeFile: runtime.probeFile,
          }));
          return;
        }

        try {
          const target = new URL(requestUrl, runtime.baseUrl);
          const headers = new Headers();
          for (const [key, value] of Object.entries(req.headers)) {
            if (value == null) {
              continue;
            }
            if (key === 'host' || key === 'connection' || key === 'content-length') {
              continue;
            }
            if (Array.isArray(value)) {
              for (const item of value) {
                headers.append(key, item);
              }
              continue;
            }
            headers.set(key, value);
          }
          // In dev mode, prefer the probe token if the client didn't supply one.
          // Some helper scripts still rely on query-string token, while the backend
          // authorization expects the header.
          if (runtime.token && !headers.has('x-mfcmouseeffect-token')) {
            headers.set('x-mfcmouseeffect-token', runtime.token);
          }

          const method = req.method || 'GET';
          const requestBody = method === 'GET' || method === 'HEAD'
            ? undefined
            : await readRequestBody(req);
          const response = await fetch(target, {
            method,
            headers,
            body: requestBody,
          });

          res.statusCode = response.status;
          for (const [key, value] of response.headers.entries()) {
            if (key === 'content-length' || key === 'transfer-encoding' || key === 'connection') {
              continue;
            }
            res.setHeader(key, value);
          }
          const responseBody = Buffer.from(await response.arrayBuffer());
          res.end(responseBody);
        } catch (error) {
          res.statusCode = 502;
          res.setHeader('Content-Type', 'application/json; charset=utf-8');
          res.end(JSON.stringify({
            ok: false,
            error: error instanceof Error ? error.message : String(error),
            baseUrl: runtime.baseUrl,
          }));
        }
      });
    },
  };
}

export default defineConfig(({ mode, command }) => {
  const target = pickBuildTarget(mode);
  const inlineComponentCssForStaticRuntime = command === 'build';
  return {
    server: {
      fs: {
        allow: [
          path.resolve(__dirname),
          path.resolve(__dirname, '../WebUI'),
        ],
      },
    },
    esbuild: {
      legalComments: 'none',
    },
    plugins: [
      svelte({
        // The compiled desktop runtime serves one static WebUI shell that only
        // links `WebUI/styles.css`. Keep component-scoped CSS inside each
        // bundle during `vite build`, otherwise static runtime builds miss the
        // extracted `dist/*.svelte.css` files while Vite dev still looks correct.
        emitCss: !inlineComponentCssForStaticRuntime,
      }),
      createDevRuntimePlugin(),
    ],
    build: {
      emptyOutDir: false,
      outDir: path.resolve(__dirname, 'dist'),
      sourcemap: false,
      minify: 'esbuild',
      lib: {
        entry: target.entry,
        name: target.name,
        formats: ['iife'],
        fileName: () => target.fileName,
      },
      rollupOptions: {
        output: {
          extend: true,
        },
      },
    },
  };
});
