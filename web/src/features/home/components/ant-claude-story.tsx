import { ZoomIn } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import {
  Dialog,
  DialogContent,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'

export function AntClaudeStory() {
  const { t } = useTranslation()
  const events = [
    {
      document: 'subscription',
      time: '11:12',
      title: t('A year of Claude Pro'),
      caption: t(
        'I subscribed to Claude Pro through Google Play. The receipt lists the annual price as $216.00.'
      ),
      action: t('View the Google Play receipt'),
    },
    {
      document: 'suspension',
      time: '11:52',
      title: t('The suspension email arrived'),
      caption: t(
        'Forty minutes later, Anthropic emailed me. It cited its Usage Policy and said my access to Claude had been revoked.'
      ),
      action: t('View the suspension email'),
    },
  ]

  return (
    <section className='ant-story' aria-labelledby='ant-story-title'>
      <h2 id='ant-story-title'>{t('Why I started Ant-Claude')}</h2>
      <time className='ant-story-date' dateTime='2026-11-09'>
        2026.11.09
      </time>
      <ol className='ant-timeline'>
        {events.map((event) => (
          <li key={event.document}>
            <time dateTime={`2026-11-09T${event.time}`}>{event.time}</time>
            <h3>{event.title}</h3>
            <p>{event.caption}</p>
            <Dialog>
              <DialogTrigger className='ant-story-document'>
                <span className='ant-story-excerpt'>
                  <img
                    src={`/ant-claude-story/${event.document}-excerpt.png`}
                    alt=''
                    loading='lazy'
                  />
                </span>
                <span className='ant-story-open'>
                  <ZoomIn size={16} aria-hidden />
                  {event.action}
                </span>
              </DialogTrigger>
              <DialogContent className='max-h-[90dvh] grid-rows-[auto_minmax(0,1fr)] sm:max-w-2xl'>
                <DialogTitle className='pr-8'>{event.action}</DialogTitle>
                <div className='overflow-y-auto' tabIndex={0}>
                  <img
                    src={`/ant-claude-story/${event.document}.png`}
                    alt={event.title}
                    className='mx-auto h-auto w-full'
                  />
                </div>
              </DialogContent>
            </Dialog>
          </li>
        ))}
      </ol>
      <blockquote>
        {t(
          'As a Chinese user, I felt singled out when my Claude account was suspended. The 1,400 yuan I paid was never refunded. I started Ant-Claude so that anyone who wants to use Claude has a place to do so.'
        )}
      </blockquote>
    </section>
  )
}
