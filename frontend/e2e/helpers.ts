import type { Page } from '@playwright/test'

export const TEST_USER_EMAIL = process.env.TEST_USER_EMAIL ?? 'test@example.com'
export const TEST_USER_PASSWORD = process.env.TEST_USER_PASSWORD ?? 'testpassword123'

export async function login(page: Page) {
  await page.goto('/login')
  await page.getByLabel(/email/i).fill(TEST_USER_EMAIL)
  await page.getByLabel(/password/i).fill(TEST_USER_PASSWORD)
  await page.getByRole('button', { name: /sign in|log in/i }).click()
  await page.waitForURL(/\/(dashboard|onboarding)/, { timeout: 10_000 })
}
