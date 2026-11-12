import { createFileRoute } from '@tanstack/react-router'

import { PublicLayout } from '@/components/layout'
import { Markdown } from '@/components/ui/markdown'
import tutorial from '@/features/tutorials/claude-desktop-windows.md?raw'

export const Route = createFileRoute('/tutorials/claude-desktop-windows')({
  component: ClaudeDesktopTutorial,
})

function ClaudeDesktopTutorial() {
  return (
    <PublicLayout>
      <article
        lang='zh-CN'
        className='mx-auto w-full max-w-3xl px-4 py-8 md:py-12'
      >
        <Markdown>{tutorial}</Markdown>
      </article>
    </PublicLayout>
  )
}
