import { defineConfig } from '@playwright/test';
import path from 'node:path';

const repoRoot = path.resolve(__dirname, '../..');
const buildDir = process.env.WEB_BUILD_DIR
  ? path.resolve(process.env.WEB_BUILD_DIR)
  : path.join(repoRoot, 'build/web');
const port = Number(process.env.WEB_SMOKE_PORT || '8091');

export default defineConfig({
  testDir: './',
  timeout: 60_000,
  expect: {
    timeout: 10_000
  },
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL: `http://127.0.0.1:${port}`,
    browserName: 'chromium',
    viewport: { width: 720, height: 1280 },
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure'
  },
  webServer: {
    command: `python3 -m http.server ${port} --bind 127.0.0.1 --directory "${buildDir}"`,
    url: `http://127.0.0.1:${port}/`,
    reuseExistingServer: !process.env.CI,
    timeout: 15_000
  }
});
