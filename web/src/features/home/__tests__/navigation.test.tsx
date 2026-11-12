import {
  createMemoryHistory,
  createRootRoute,
  createRoute,
  createRouter,
  RouterProvider,
} from '@tanstack/react-router'
import { render, screen, within } from '@testing-library/react'
import { expect, it } from 'vitest'

import { AntClaudeHome } from '../components/ant-claude-home'

function renderHome(signedIn: boolean) {
  const root = createRootRoute()
  const home = createRoute({
    getParentRoute: () => root,
    path: '/',
    component: () => <AntClaudeHome isAuthenticated={signedIn} />,
  })
  const router = createRouter({
    routeTree: root.addChildren([home]),
    history: createMemoryHistory({ initialEntries: ['/'] }),
  })
  render(<RouterProvider router={router} />)
}

it.each([
  { signedIn: false, label: 'Sign In', path: '/sign-in' },
  { signedIn: true, label: 'Go to Dashboard', path: '/dashboard' },
])(
  'offers $label when signedIn is $signedIn',
  async ({ signedIn, label, path }) => {
    renderHome(signedIn)
    expect(await screen.findByRole('link', { name: label })).toHaveAttribute(
      'href',
      path
    )
  }
)

it('lets a visitor inspect the site source from the public pledge', async () => {
  renderHome(false)
  const pledge = await screen.findByRole('region', { name: 'Our pledge' })
  expect(
    within(pledge).getByRole('link', { name: 'Inspect the source code' })
  ).toHaveAttribute('href', 'https://github.com/Hao-Monster/MyAPI')
})
