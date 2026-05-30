import { test, expect } from '@playwright/test'
import { login } from './helpers'

test.describe('Mood log flow', () => {
  test('should create a mood log and see it in the logs list', async ({ page }) => {
    await login(page)

    await page.goto('/logs/new')
    await page.waitForLoadState('networkidle')

    const moodButtons = page.locator('.chip-row .chip')
    const moodCount = await moodButtons.count()
    if (moodCount > 0) {
      await moodButtons.nth(2).click()
    }

    const notesField = page.getByPlaceholder(/notes/i)
    if (await notesField.isVisible()) {
      await notesField.fill('Playwright e2e test log entry')
    }

    await page.getByRole('button', { name: /save/i }).click()

    await expect(page).toHaveURL('/logs', { timeout: 10_000 })

    await expect(page.locator('body')).toContainText(/playwright e2e test/i)
  })
})
