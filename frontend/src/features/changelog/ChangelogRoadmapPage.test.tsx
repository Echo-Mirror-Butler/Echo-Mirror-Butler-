import { render, screen, fireEvent } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { describe, expect, test, vi } from 'vitest'
import { ChangelogRoadmapPage } from './ChangelogRoadmapPage'

// Mock the useTheme hook
vi.mock('../../lib/use-theme', () => ({
  useTheme: () => ({
    theme: 'dark',
    resolvedTheme: 'dark',
    setTheme: vi.fn(),
  }),
}))

describe('ChangelogRoadmapPage', () => {
  const renderPage = () => {
    return render(
      <MemoryRouter>
        <ChangelogRoadmapPage />
      </MemoryRouter>,
    )
  }

  test('renders the page header and default tab', () => {
    renderPage()

    // Verify main page title
    expect(screen.getByRole('heading', { name: 'Changelog & Roadmap', level: 1 })).toBeInTheDocument()

    // Verify Tab buttons
    expect(screen.getByRole('button', { name: 'Shipped Features' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Future Roadmap' })).toBeInTheDocument()
  })

  test('renders parsed changelog data correctly', () => {
    renderPage()

    // Check for some version numbers defined in our CHANGELOG.md
    expect(screen.getByText('v1.2.0')).toBeInTheDocument()
    expect(screen.getByText('v1.1.0')).toBeInTheDocument()
    expect(screen.getByText('v1.0.0')).toBeInTheDocument()

    // Check for section headers
    const addedSections = screen.getAllByRole('heading', { name: 'Added', level: 3 })
    expect(addedSections.length).toBeGreaterThan(0)
  })

  test('can switch to roadmap tab and view milestones', () => {
    renderPage()

    const roadmapTab = screen.getByRole('button', { name: 'Future Roadmap' })
    fireEvent.click(roadmapTab)

    // Verify milestones are displayed
    expect(screen.getByText('Milestone 1: Web Client Polish & Credentials Audit')).toBeInTheDocument()
    expect(screen.getByText('Milestone 2: Non-Custodial Stellar Wallet Integration')).toBeInTheDocument()

    // Verify GitHub links
    const gitHubLinks = screen.getAllByRole('link', { name: /GitHub Repository|View Milestone|Related Issues/i })
    expect(gitHubLinks.length).toBeGreaterThan(0)
  })
})
