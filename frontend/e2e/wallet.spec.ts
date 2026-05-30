import { test, expect } from '@playwright/test'
import { login } from './helpers'

test.describe('Wallet flow', () => {
  test('should display wallet page with balance card', async ({ page }) => {
    await login(page)

    await page.goto('/wallet')
    await page.waitForLoadState('networkidle')

    const walletContent = page.locator('.balance-card, [class*="wallet"], h2')
    await expect(walletContent.first()).toBeVisible({ timeout: 10_000 })
  })
})
