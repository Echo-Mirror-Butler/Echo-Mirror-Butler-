import { test, expect } from '@playwright/test'

test.describe('Sign up flow', () => {
  test('should create account and redirect to dashboard or onboarding', async ({ page }) => {
    await page.goto('/signup')

    const uniqueEmail = `test+${Date.now()}@example.com`

    const nameField = page.getByLabel(/name/i)
    if (await nameField.isVisible()) {
      await nameField.fill('Test User')
    }

    await page.getByLabel(/email/i).fill(uniqueEmail)
    await page.getByLabel(/password/i).first().fill('TestPassword123!')

    const confirmField = page.getByLabel(/confirm/i)
    if (await confirmField.isVisible()) {
      await confirmField.fill('TestPassword123!')
    }

    await page.getByRole('button', { name: /sign up|create|register/i }).click()

    await expect(page).toHaveURL(/\/(dashboard|onboarding)/, { timeout: 15_000 })
  })
})
