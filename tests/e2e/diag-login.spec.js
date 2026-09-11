import { test, expect } from '@playwright/test';

const BASE = process.env.TEST_BASE_URL || 'http://localhost:5173';

async function acceptConsent(page) {
  // L-4: dialog renders async — poll instead of instant count() check
  const consent = page.locator('div[role="dialog"] button:has-text("Saya Setuju")');
  try {
    await consent.first().waitFor({ state: 'visible', timeout: 8000 });
    await consent.first().click();
    await page.waitForTimeout(500);
  } catch { /* no consent dialog — continue */ }
}

// L-4: poll for login completion instead of fixed wait (edge fallback can take >5s)
async function waitForLogin(page, pathPrefix, timeoutMs = 30000) {
  await page.waitForFunction(
    (prefix) => {
      try {
        const hasToken = !!JSON.parse(sessionStorage.getItem('wos_user'));
        const onPath = window.location.pathname.startsWith(prefix);
        return hasToken && onPath;
      } catch { return false; }
    },
    pathPrefix,
    { timeout: timeoutMs, polling: 500 }
  ).catch(() => {});
  await page.waitForTimeout(300); // settle
}

async function loginWorker(page, nrp, nik, pass) {
  const logs = [];
  const responses = [];
  page.on('console', (m) => logs.push('[' + m.type() + '] ' + m.text()));
  page.on('response', (r) => {
    if (r.url().includes('rpc') || r.url().includes('auth')) {
      responses.push(r.status() + ' ' + r.url().slice(0, 100));
    }
  });
  await page.goto(BASE + '/', { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForTimeout(1000);
  await acceptConsent(page);
  await page.locator('button', { hasText: 'Pekerja' }).click();
  await page.fill('input[placeholder*="NRP"]', nrp);
  await page.fill('input[placeholder*="NIK"]', nik);
  await page.fill('input[placeholder*="password"]', pass);
  await page.click('button[type="submit"]');
  await waitForLogin(page, '/worker');
  const url = page.url();
  const hasToken = await page.evaluate(() => {
    try { return !!JSON.parse(sessionStorage.getItem('wos_user')); } catch { return false; }
  });
  return { url, hasToken, logs, responses };
}

async function loginAdmin(page, email, pass) {
  await page.goto(BASE + '/', { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForTimeout(1000);
  await acceptConsent(page);
  await page.locator('button', { hasText: 'Admin' }).click();
  await page.waitForTimeout(500);
  const emailSel = await page.locator('input[type="email"]').count()
    ? 'input[type="email"]' : 'input[placeholder*="email" i]';
  await page.fill(emailSel, email);
  await page.fill('input[placeholder*="password"]', pass);
  await page.click('button[type="submit"]');
  await waitForLogin(page, '/admin');
  const url = page.url();
  const hasToken = await page.evaluate(() => {
    try { return !!JSON.parse(sessionStorage.getItem('wos_user')); } catch { return false; }
  });
  return { url, hasToken };
}

test('Worker: NRP002 + NIK 3204000000000002 + password 3204000000000002', async ({ page }) => {
  const r = await loginWorker(page, 'NRP002', '3204000000000002', '3204000000000002');
  console.log('NRP002/3204 → url=' + r.url + ' token=' + r.hasToken);
  if (r.responses && r.responses.length) { r.responses.forEach(r2 => console.log('  RESP: ' + r2)); }
});

test('Worker: NRP003 + NIK 3204000000000003 + password d5wcHVOp-GbnONVK', async ({ page }) => {
  const r = await loginWorker(page, 'NRP003', '3204000000000003', 'd5wcHVOp-GbnONVK');
  console.log('NRP003/d5wc → url=' + r.url + ' token=' + r.hasToken);
  if (r.responses && r.responses.length) { r.responses.forEach(r2 => console.log('  RESP: ' + r2)); }
});

test('Worker: NRP007 + NIK 3204000000000007 + password 3204000000000007', async ({ page }) => {
  const r = await loginWorker(page, 'NRP007', '3204000000000007', '3204000000000007');
  console.log('NRP007/3204 → url=' + r.url + ' token=' + r.hasToken);
});

test('Admin: pusat@insightwos.com + Admin123!', async ({ page }) => {
  const r = await loginAdmin(page, 'pusat@insightwos.com', 'Admin123!');
  console.log('Admin/pusat → url=' + r.url + ' token=' + r.hasToken);
});

test('Admin: ceo@insightwos.com + CEO123!', async ({ page }) => {
  const r = await loginAdmin(page, 'ceo@insightwos.com', 'CEO123!');
  console.log('Admin/ceo → url=' + r.url + ' token=' + r.hasToken);
});

test('Admin: hrd@insightwos.com + Hrd123!', async ({ page }) => {
  await page.goto(BASE + '/', { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForTimeout(1000);
  await acceptConsent(page);
  await page.locator('button', { hasText: 'Admin' }).click();
  await page.waitForTimeout(500);
  await page.fill('input[type="email"]', 'hrd@insightwos.com');
  await page.fill('input[placeholder*="password"]', 'Hrd123!');
  await page.click('button[type="submit"]');
  await waitForLogin(page, '/admin');
  const url = page.url();
  const hasToken = await page.evaluate(() => {
    try { return !!JSON.parse(sessionStorage.getItem('wos_user')); } catch { return false; }
  });
  console.log('Admin/hrd → url=' + url + ' token=' + hasToken);
});

test('Admin: operasional@insightwos.com + Ops123!', async ({ page }) => {
  const r = await loginAdmin(page, 'operasional@insightwos.com', 'Ops123!');
  console.log('Admin/ops → url=' + r.url + ' token=' + r.hasToken);
});
