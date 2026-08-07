import { defineConfig, devices } from '@playwright/test';

// Three engine projects run the same passkey spec. localhost is a secure context,
// so no HTTPS is needed for WebAuthn. The webServer boots the static harness page.
export default defineConfig({
  testDir: './tests',
  timeout: 15_000,
  fullyParallel: false,
  reporter: [['list']],
  use: { baseURL: 'http://localhost:4599' },
  webServer: {
    command: 'node server.mjs',
    url: 'http://localhost:4599',
    reuseExistingServer: !process.env.CI,
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
  ],
});
