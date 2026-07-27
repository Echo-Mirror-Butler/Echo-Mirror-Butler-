import { test, expect } from '@playwright/test'

// #605: the service worker precaches /offline.html and falls back to it on
// navigation when the network is unavailable. This test registers the real
// service worker, waits for it to activate, then simulates the browser going
// offline and confirms the dedicated offline page is served — not a generic
// browser error page (and not silently the cached app shell either).
test.describe('Offline fallback', () => {
  test('serves offline.html when navigating while offline', async ({ page, context }) => {
    await page.goto('/')

    await page.evaluate(async () => {
      const registration = await navigator.serviceWorker.register('/sw.js', { scope: '/' })
      await navigator.serviceWorker.ready
      return registration
    })

    // Give the install/activate handlers (which precache offline.html) a
    // moment to finish before we cut the network.
    await page.waitForTimeout(500)

    await context.setOffline(true)

    await page.goto('/some-uncached-route-for-offline-test', { waitUntil: 'domcontentloaded' })

    await expect(page.getByText(/you're offline/i)).toBeVisible()

    await context.setOffline(false)
  })
})
