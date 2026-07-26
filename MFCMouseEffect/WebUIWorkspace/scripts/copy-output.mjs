import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  generatedWebUiFiles,
  managedWebUiFiles,
  staticWebUiFiles,
} from './webui-bundle-manifest.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const workspaceDir = path.resolve(__dirname, '..');
const projectDir = path.resolve(workspaceDir, '..');
const repoRoot = path.resolve(projectDir, '..');
const webUiDir = path.join(projectDir, 'WebUI');

function copyOrThrow(source, target) {
  if (!fs.existsSync(source)) {
    throw new Error(`Build output not found: ${source}`);
  }
  fs.copyFileSync(source, target);
}

function wrapBundleScope(content) {
  const marker = '/* mfx-scope-wrapped */';
  if (content.includes(marker)) return content;
  return [
    '/* mfx-scope-wrapped */',
    '(() => {',
    content,
    '})();',
    '',
  ].join('\n');
}

function copyGeneratedBundleOrThrow(source, target) {
  if (!fs.existsSync(source)) {
    throw new Error(`Build output not found: ${source}`);
  }
  const original = fs.readFileSync(source, 'utf8');
  const wrapped = wrapBundleScope(original);
  fs.writeFileSync(target, wrapped, 'utf8');
}

// Deterministic staging: any web artifact in a managed directory that is
// not listed in the bundle manifest is a retired leftover and is removed,
// so stale bundles cannot keep old code paths alive across builds.
function purgeUnmanagedWebArtifacts(dir) {
  if (!fs.existsSync(dir)) {
    return;
  }
  const managed = new Set(managedWebUiFiles);
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (!entry.isFile()) {
      continue;
    }
    if (!/\.(js|css|html)$/.test(entry.name)) {
      continue;
    }
    if (managed.has(entry.name)) {
      continue;
    }
    fs.rmSync(path.join(dir, entry.name));
    console.log(`[copy-output] removed retired WebUI artifact: ${path.join(dir, entry.name)}`);
  }
}

for (const fileName of generatedWebUiFiles) {
  const source = path.join(workspaceDir, 'dist', fileName);
  const target = path.join(webUiDir, fileName);
  copyGeneratedBundleOrThrow(source, target);
}

purgeUnmanagedWebArtifacts(webUiDir);

const runtimeWebUiDirs = [
  path.join(repoRoot, 'x64', 'Debug', 'webui'),
  path.join(repoRoot, 'x64', 'Release', 'webui'),
];

for (const runtimeDir of runtimeWebUiDirs) {
  if (!fs.existsSync(runtimeDir)) {
    continue;
  }

  for (const fileName of generatedWebUiFiles) {
    const source = path.join(webUiDir, fileName);
    const target = path.join(runtimeDir, fileName);
    copyOrThrow(source, target);
  }

  for (const fileName of staticWebUiFiles) {
    const source = path.join(webUiDir, fileName);
    const target = path.join(runtimeDir, fileName);
    copyOrThrow(source, target);
  }

  purgeUnmanagedWebArtifacts(runtimeDir);
}
