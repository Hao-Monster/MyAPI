import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, it } from 'vitest'

import { AntClaudeStory } from '../components/ant-claude-story'

it.each([
  ['View the Google Play receipt', 'subscription'],
  ['View the suspension email', 'suspension'],
])(
  'opens the corresponding full screenshot from "%s" and returns focus on Escape',
  async (name, file) => {
    const user = userEvent.setup()
    render(<AntClaudeStory />)
    const trigger = screen.getByRole('button', { name })
    await user.click(trigger)
    const dialog = await screen.findByRole('dialog', { name })
    expect(within(dialog).getByRole('img')).toHaveAttribute(
      'src',
      `/ant-claude-story/${file}.png`
    )
    await user.keyboard('{Escape}')
    await waitFor(() => expect(trigger).toHaveFocus())
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  }
)
