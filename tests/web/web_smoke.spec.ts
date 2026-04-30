import { expect, test, type Page } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';
import { PNG } from 'pngjs';

const repoRoot = path.resolve(__dirname, '../..');
const buildDir = process.env.WEB_BUILD_DIR
  ? path.resolve(process.env.WEB_BUILD_DIR)
  : path.join(repoRoot, 'build/web');
const expectSentry = process.env.WEB_SMOKE_EXPECT_SENTRY === '1';

type BrowserEvent = {
  kind: string;
  text: string;
};

const fatalPatterns: RegExp[] = [
  /^ERROR:/i,
  /SCRIPT ERROR/i,
  /Parse Error/i,
  /Failed to load script/i,
  /No loader found/i,
  /does not exist/i,
  /memory access out of bounds/i,
  /Uncaught RuntimeError/i,
  /loadDylibs/i,
  /\.side\.wasm/i,
  /libsentry\.web/i
];

function readExportFile(fileName: string): string {
  return fs.readFileSync(path.join(buildDir, fileName), 'utf8');
}

function expectFile(fileName: string): void {
  expect(fs.existsSync(path.join(buildDir, fileName)), `${fileName} exists`).toBe(true);
}

function watchBrowserEvents(page: Page): BrowserEvent[] {
  const events: BrowserEvent[] = [];
  page.on('console', (message) => {
    const text = message.text();
    if (message.type() === 'error' || message.type() === 'warning') {
      events.push({ kind: `console.${message.type()}`, text });
    }
  });
  page.on('pageerror', (error) => {
    events.push({ kind: 'pageerror', text: error.stack || error.message });
  });
  return events;
}

function expectNoFatalBrowserEvents(events: BrowserEvent[]): void {
  const fatal = events.filter((event) =>
    fatalPatterns.some((pattern) => pattern.test(event.text))
  );
  expect(
    fatal.map((event) => `${event.kind}: ${event.text}`).join('\n'),
    'no fatal browser or Godot errors'
  ).toBe('');
}

async function waitForGodotCanvas(page: Page): Promise<void> {
  await page.waitForSelector('canvas', { timeout: 45_000 });
  await page.waitForFunction(() => {
    const canvas = document.querySelector('canvas');
    if (!canvas) {
      return false;
    }
    const rect = canvas.getBoundingClientRect();
    return canvas.width > 0 && canvas.height > 0 && rect.width >= 700 && rect.height >= 1000;
  }, null, { timeout: 45_000 });
  await page.waitForTimeout(1_000);
}

function imageStats(buffer: Buffer): { uniqueColors: number; variance: number } {
  const png = PNG.sync.read(buffer);
  const unique = new Set<string>();
  let samples = 0;
  let sum = 0;
  let sumSq = 0;

  for (let y = 0; y < png.height; y += 8) {
    for (let x = 0; x < png.width; x += 8) {
      const index = (png.width * y + x) << 2;
      const r = png.data[index];
      const g = png.data[index + 1];
      const b = png.data[index + 2];
      const a = png.data[index + 3];
      if (a === 0) {
        continue;
      }
      unique.add(`${r >> 3},${g >> 3},${b >> 3}`);
      const luma = 0.299 * r + 0.587 * g + 0.114 * b;
      sum += luma;
      sumSq += luma * luma;
      samples += 1;
    }
  }

  const mean = samples > 0 ? sum / samples : 0;
  const variance = samples > 0 ? sumSq / samples - mean * mean : 0;
  return { uniqueColors: unique.size, variance };
}

function diffRatio(a: Buffer, b: Buffer): number {
  const first = PNG.sync.read(a);
  const second = PNG.sync.read(b);
  const width = Math.min(first.width, second.width);
  const height = Math.min(first.height, second.height);
  let changed = 0;
  let samples = 0;

  for (let y = 0; y < height; y += 8) {
    for (let x = 0; x < width; x += 8) {
      const ai = (first.width * y + x) << 2;
      const bi = (second.width * y + x) << 2;
      const delta =
        Math.abs(first.data[ai] - second.data[bi]) +
        Math.abs(first.data[ai + 1] - second.data[bi + 1]) +
        Math.abs(first.data[ai + 2] - second.data[bi + 2]);
      if (delta > 32) {
        changed += 1;
      }
      samples += 1;
    }
  }

  return samples > 0 ? changed / samples : 0;
}

async function expectNonBlankPage(page: Page, label: string): Promise<Buffer> {
  const screenshot = await page.screenshot({ fullPage: false });
  const stats = imageStats(screenshot);
  expect(stats.uniqueColors, `${label} has varied pixels`).toBeGreaterThan(24);
  expect(stats.variance, `${label} has visible contrast`).toBeGreaterThan(20);
  return screenshot;
}

async function clickStartButton(page: Page, menuScreenshot: Buffer): Promise<{ screenshot: Buffer; ratio: number }> {
  const candidates: Array<[number, number]> = [
    [360, 716],
    [360, 870],
    [360, 920]
  ];
  let bestScreenshot = menuScreenshot;
  let bestRatio = 0;

  for (const [x, y] of candidates) {
    await page.mouse.click(x, y);
    await page.waitForTimeout(1_500);
    const nextScreenshot = await page.screenshot({ fullPage: false });
    const ratio = diffRatio(menuScreenshot, nextScreenshot);
    if (ratio > bestRatio) {
      bestRatio = ratio;
      bestScreenshot = nextScreenshot;
    }
    if (ratio > 0.04) {
      return { screenshot: nextScreenshot, ratio };
    }
  }

  return { screenshot: bestScreenshot, ratio: bestRatio };
}

test('exported Web files are self-contained for Pages', async () => {
  for (const fileName of ['index.html', 'index.js', 'index.wasm', 'index.pck']) {
    expectFile(fileName);
  }

  const exportEntries = fs.readdirSync(buildDir);
  expect(exportEntries.filter((name) => name.endsWith('.side.wasm'))).toEqual([]);
  expect(exportEntries.filter((name) => /^libsentry\.web.*\.wasm$/.test(name))).toEqual([]);

  const html = readExportFile('index.html');
  const js = readExportFile('index.js');
  expect(html).not.toMatch(/"gdextensionLibs"\s*:\s*\[[^\]\s][^\]]*\]/);
  expect(html).not.toContain('sentry-bundle.js');
  expect(js).not.toContain('loadDylibs');

  if (expectSentry) {
    expect(html).toContain('WWL_SENTRY_CONFIG');
    expect(html).toContain('WWL_REPORT_GODOT_ERROR');
  }
});

test('main menu boots and Start enters gameplay without fatal errors', async ({ page }) => {
  const events = watchBrowserEvents(page);
  await page.goto(`/?v=web-smoke-${Date.now()}`, { waitUntil: 'domcontentloaded' });
  await waitForGodotCanvas(page);

  const menuScreenshot = await expectNonBlankPage(page, 'main menu');

  if (expectSentry) {
    const sentryState = await page.evaluate(() => {
      const browserWindow = window as typeof window & {
        Sentry?: unknown;
        WWL_SENTRY_CONFIG?: { dsn?: string; environment?: string; release?: string };
        WWL_SHOULD_CAPTURE_GODOT_ERROR?: (message: string) => boolean;
        WWL_REPORT_GODOT_ERROR?: unknown;
        WWL_REPORT_GODOT_LOG?: unknown;
      };
      return {
        hasSentry: typeof browserWindow.Sentry !== 'undefined',
        hasDsn: Boolean(browserWindow.WWL_SENTRY_CONFIG?.dsn),
        environment: browserWindow.WWL_SENTRY_CONFIG?.environment || '',
        filtersShutdownNoise:
          browserWindow.WWL_SHOULD_CAPTURE_GODOT_ERROR?.(
            'ERROR: 1 resources still in use at exit (run with --verbose for details).'
          ) === false &&
          browserWindow.WWL_SHOULD_CAPTURE_GODOT_ERROR?.(
            "ERROR: Pages in use exist at exit in PagedAllocator: N16WorkerThreadPool5GroupE"
          ) === false &&
          browserWindow.WWL_SHOULD_CAPTURE_GODOT_ERROR?.(
            "ERROR: Texture with GL ID of 78366: leaked 131072 bytes."
          ) === false,
        capturesRuntimeErrors:
          browserWindow.WWL_SHOULD_CAPTURE_GODOT_ERROR?.(
            'ERROR: Condition "!is_inside_tree()" is true. Returning: false'
          ) === true,
        hasErrorBridge: typeof browserWindow.WWL_REPORT_GODOT_ERROR === 'function',
        hasLogBridge: typeof browserWindow.WWL_REPORT_GODOT_LOG === 'function'
      };
    });
    expect(sentryState.hasSentry, 'Sentry Browser SDK exists').toBe(true);
    expect(sentryState.hasDsn, 'Sentry DSN exists').toBe(true);
    expect(sentryState.environment, 'Sentry environment').toBe('production');
    expect(sentryState.filtersShutdownNoise, 'Sentry filters Godot shutdown noise').toBe(true);
    expect(sentryState.capturesRuntimeErrors, 'Sentry keeps runtime Godot errors').toBe(true);
    expect(sentryState.hasErrorBridge, 'Godot error bridge exists').toBe(true);
    expect(sentryState.hasLogBridge, 'Godot log bridge exists').toBe(true);
  }

  expectNoFatalBrowserEvents(events);

  const startResult = await clickStartButton(page, menuScreenshot);
  const gameplayStats = imageStats(startResult.screenshot);
  expect(gameplayStats.uniqueColors, 'gameplay has varied pixels').toBeGreaterThan(24);
  expect(gameplayStats.variance, 'gameplay has visible contrast').toBeGreaterThan(20);
  expect(startResult.ratio, 'Start button changes scene').toBeGreaterThan(0.04);
  expectNoFatalBrowserEvents(events);
});
