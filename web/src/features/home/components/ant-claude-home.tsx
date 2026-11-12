import { Link } from '@tanstack/react-router'
import { ArrowRight, ArrowUpRight } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { buttonVariants } from '@/components/ui/button'

import { AntClaudeStory } from './ant-claude-story'

import '@/styles/ant-claude.css'

export function AntClaudeHome({
  isAuthenticated,
}: {
  isAuthenticated: boolean
}) {
  const { t } = useTranslation()

  return (
    <main className='ant-home'>
      <div className='ant-wrap'>
        <section className='ant-hero'>
          <div>
            <p className='ant-wordmark'>Ant-Claude</p>
            <h1>{t('Everyone should have the right to use AI.')}</h1>
            <p className='ant-intro'>
              {t('An independent Claude service with transparent pricing.')}
            </p>
            <div className='ant-actions'>
              <Link
                className={buttonVariants({ className: 'ant-button' })}
                to={isAuthenticated ? '/dashboard' : '/sign-in'}
              >
                {isAuthenticated ? t('Go to Dashboard') : t('Sign In')}{' '}
                <ArrowRight aria-hidden />
              </Link>
              <a className='ant-text-link' href='#pricing-policy'>
                {t('Our pricing policy')} ↓
              </a>
            </div>
          </div>
          <img
            className='ant-hero-art'
            src='/ant-claude-swords.jpg'
            alt='Ant-Claude'
            width='960'
            height='960'
          />
        </section>

        <section className='ant-pledge' aria-labelledby='ant-pledge-title'>
          <h2 id='ant-pledge-title'>{t('Our pledge')}</h2>
          <p className='ant-pledge-lead'>
            {t(
              'We pledge to serve Claude exclusively through Amazon Bedrock or Google Cloud Vertex AI. We will never pass off another model or provider as the one you chose.'
            )}
          </p>
          <p>{t("We never collect, store or sell any user's usage data.")}</p>
          <p>
            {t(
              'We welcome every form of scrutiny of our model sources and how we handle user data.'
            )}{' '}
            <a
              className='ant-text-link'
              href='https://github.com/Hao-Monster/MyAPI'
            >
              {t('Inspect the source code')}{' '}
              <ArrowUpRight aria-hidden size={15} />
            </a>
          </p>
        </section>

        <section id='pricing-policy' className='ant-policy'>
          <h2>{t('Our pricing policy')}</h2>
          <div className='ant-rates'>
            <div>
              <h3>{t('Token markup')}</h3>
              <strong>
                0<span>%</span>
              </strong>
              <p>
                {t(
                  'Claude tokens will cost exactly what Anthropic charges for the same model and usage.'
                )}
              </p>
              <a
                className='ant-text-link'
                href='https://platform.claude.com/docs/en/about-claude/pricing'
                target='_blank'
                rel='noreferrer'
              >
                {t('Anthropic API pricing')}{' '}
                <ArrowUpRight aria-hidden size={15} />
              </a>
            </div>
            <div>
              <h3>{t('Fee per top-up')}</h3>
              <strong>
                6<span>%</span>–10<span>%</span>
              </strong>
              <p>
                {t(
                  'Our only service fee will be collected at top-up. It covers servers, network bandwidth and maintenance.'
                )}
              </p>
            </div>
          </div>
        </section>

        <AntClaudeStory />
        <section className='ant-notes'>
          <h2>{t('Claude model providers')}</h2>
          <ul>
            <li>Amazon Bedrock</li>
            <li>Google Cloud Vertex AI</li>
          </ul>
          <Link className='ant-text-link' to='/pricing'>
            {t('View model catalog')} <ArrowRight aria-hidden size={15} />
          </Link>
        </section>
      </div>
    </main>
  )
}
