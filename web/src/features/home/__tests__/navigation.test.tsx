import {
  createMemoryHistory,
  createRootRoute,
  createRoute,
  createRouter,
  RouterProvider,
} from '@tanstack/react-router'
import { render, screen } from '@testing-library/react'
import { expect, it } from 'vitest'

import { AntClaudeHome } from '../components/ant-claude-home'

it.each([
  { signedIn: false, label: 'Sign In', path: '/sign-in' },
  { signedIn: true, label: 'Go to Dashboard', path: '/dashboard' },
])(
  'offers $label when signedIn is $signedIn',
  async ({ signedIn, label, path }) => {
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
    expect(await screen.findByRole('link', { name: label })).toHaveAttribute(
      'href',
      path
    )
  }
)
