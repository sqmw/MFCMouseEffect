import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  WEBUI_BUILD_TARGETS,
  generatedWebUiFiles,
  managedWebUiFiles,
  staticWebUiFiles,
} from './webui-bundle-manifest.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const workspaceDir = path.resolve(__dirname, '..');
const projectDir = path.resolve(workspaceDir, '..');
const webUiIndexHtml = path.join(projectDir, 'WebUI', 'index.html');
const entriesDir = path.join(workspaceDir, 'src', 'entries');

let failed = 0;

function runTest(name, fn) {
  try {
    fn();
    console.log(`[pass] ${name}`);
  } catch (error) {
    failed += 1;
    console.error(`[fail] ${name}`);
    console.error(error instanceof Error ? error.stack || error.message : error);
  }
}

runTest('manifest lists are non-empty and disjoint', () => {
  assert.ok(generatedWebUiFiles.length > 0);
  assert.ok(staticWebUiFiles.length > 0);
  const generated = new Set(generatedWebUiFiles);
  for (const fileName of staticWebUiFiles) {
    assert.ok(!generated.has(fileName), `file listed twice: ${fileName}`);
  }
  assert.equal(
    managedWebUiFiles.length,
    generatedWebUiFiles.length + staticWebUiFiles.length,
  );
});

runTest('every build target entry exists under src/entries', () => {
  for (const [mode, target] of Object.entries(WEBUI_BUILD_TARGETS)) {
    const entryPath = path.join(entriesDir, target.entry);
    assert.ok(fs.existsSync(entryPath), `missing entry for mode "${mode}": ${target.entry}`);
  }
});

runTest('package.json has a build script per target mode', () => {
  const packageJson = JSON.parse(
    fs.readFileSync(path.join(workspaceDir, 'package.json'), 'utf8'),
  );
  const scripts = packageJson.scripts || {};
  for (const mode of Object.keys(WEBUI_BUILD_TARGETS)) {
    assert.ok(
      typeof scripts[`build:${mode}`] === 'string',
      `missing build:${mode} script`,
    );
    assert.ok(
      scripts[`build:${mode}`].includes(`--mode ${mode}`),
      `build:${mode} does not pass --mode ${mode}`,
    );
  }
});

runTest('index.html references only managed files, and all generated bundles', () => {
  const html = fs.readFileSync(webUiIndexHtml, 'utf8');
  const referenced = [...html.matchAll(/src="\/([^"]+)"/g)].map((m) => m[1]);
  assert.ok(referenced.length > 0, 'no script references found in index.html');

  const managed = new Set(managedWebUiFiles);
  for (const fileName of referenced) {
    assert.ok(
      managed.has(fileName),
      `index.html references unmanaged file: ${fileName}`,
    );
  }

  const referencedSet = new Set(referenced);
  for (const fileName of generatedWebUiFiles) {
    assert.ok(
      referencedSet.has(fileName),
      `generated bundle not referenced by index.html: ${fileName}`,
    );
  }
});

if (failed > 0) {
  console.error(`${failed} test(s) failed`);
  process.exit(1);
}
console.log('webui bundle manifest contract tests passed');
