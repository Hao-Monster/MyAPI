import { createFileRoute } from '@tanstack/react-router'

import { PublicLayout } from '@/components/layout'
import { Markdown } from '@/components/ui/markdown'
import guide from '@/features/tutorials/billing-support.md?raw'

export const Route = createFileRoute('/billing-support')({
  component: BillingSupport,
})

function BillingSupport() {
  return (
    <PublicLayout>
      <article
        lang='zh-CN'
        className='mx-auto w-full max-w-3xl px-4 py-8 md:py-12'
      >
        <Markdown>{guide}</Markdown>
      </article>
    </PublicLayout>
  )
}
