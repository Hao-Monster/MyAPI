import { useEffect, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { toIntlLocale } from '@/i18n/languages'
import '@/styles/ant-claude-support.css'

const baseUrl = 'https://chat.clawpan.online'
// Public website inbox identifier used by the FreedomPost web widget.
const websiteToken = 'WM32VohJAYcy69Rx6qr1P2Lt'
const standaloneUrl = `${baseUrl}/widget?website_token=${websiteToken}`
const positionKey = 'ant-claude-support-position'

declare global {
  interface Window {
    chatwootSDK?: { run(config: { websiteToken: string; baseUrl: string }): void }
    chatwootSettings?: {
      hideMessageBubble: boolean
      directConversation: boolean
      locale: string
    }
    $chatwoot?: { hasLoaded: boolean; toggle(state: 'open' | 'close'): void }
  }
}

export function AntClaudeSupport() {
  const { t, i18n } = useTranslation()
  const [state, setState] = useState<'idle' | 'loading' | 'open' | 'fallback'>('idle')
  const launcher = useRef<HTMLAnchorElement>(null)
  const drag = useRef<{ id: number; x: number; y: number; left: number; top: number } | null>(null)
  const dragged = useRef(false)
  const locale = toIntlLocale(i18n.language)?.replace('-', '_') || 'en'

  useEffect(() => {
    try {
      const saved = localStorage.getItem(positionKey)
      if (saved) {
        const { x, y } = JSON.parse(saved)
        if (Number.isFinite(x) && Number.isFinite(y)) {
          launcher.current?.style.setProperty('--support-x', `${x}px`)
          launcher.current?.style.setProperty('--support-y', `${y}px`)
        }
      }
    } catch { /* The launcher also works without browser storage. */ }
    function onClose() {
      setState('idle')
      launcher.current?.focus({ preventScroll: true })
    }
    window.addEventListener('chatwoot:closed', onClose)
    return () => window.removeEventListener('chatwoot:closed', onClose)
  }, [])

  useEffect(() => {
    if (state !== 'loading') return
    function open() {
      window.$chatwoot?.toggle('open')
      setState('open')
    }
    if (window.$chatwoot?.hasLoaded) {
      open()
      return
    }
    const fallback = () => setState('fallback')
    window.addEventListener('chatwoot:ready', open)
    const timeout = window.setTimeout(fallback, 25000)
    const listeners = new AbortController()
    let script: HTMLScriptElement | undefined
    if (!window.$chatwoot) {
      window.chatwootSettings = { hideMessageBubble: true, directConversation: true, locale }
      script = document.createElement('script')
      script.src = `${baseUrl}/packs/js/sdk.js`
      script.async = true
      script.addEventListener('load', () => {
        if (!window.chatwootSDK) return fallback()
        window.chatwootSDK.run({ websiteToken, baseUrl })
      }, { signal: listeners.signal })
      script.addEventListener('error', fallback, { signal: listeners.signal })
      document.head.appendChild(script)
    }
    return () => {
      window.removeEventListener('chatwoot:ready', open)
      window.clearTimeout(timeout)
      listeners.abort()
      script?.remove()
    }
  }, [state, locale])

  return (
    <a
      ref={launcher}
      href={standaloneUrl}
      target='_blank'
      rel='noopener noreferrer'
      className='ant-support-launcher'
      hidden={state === 'open'}
      aria-busy={state === 'loading'}
      draggable={false}
      onPointerDown={(event) => {
        if (!event.isPrimary || event.button !== 0) return
        const { left, top } = event.currentTarget.getBoundingClientRect()
        drag.current = { id: event.pointerId, x: event.clientX, y: event.clientY, left, top }
        dragged.current = false
        event.currentTarget.setPointerCapture(event.pointerId)
      }}
      onPointerMove={(event) => {
        const start = drag.current
        if (!start || start.id !== event.pointerId) return
        const dx = event.clientX - start.x
        const dy = event.clientY - start.y
        if (!dragged.current && Math.hypot(dx, dy) < 6) return
        dragged.current = true
        event.currentTarget.style.setProperty('--support-x', `${start.left + dx}px`)
        event.currentTarget.style.setProperty('--support-y', `${start.top + dy}px`)
      }}
      onPointerUp={(event) => {
        if (drag.current?.id !== event.pointerId || !dragged.current) return
        const { left: x, top: y } = event.currentTarget.getBoundingClientRect()
        try { localStorage.setItem(positionKey, JSON.stringify({ x, y })) } catch { /* Optional. */ }
      }}
      onLostPointerCapture={(event) => {
        if (drag.current?.id === event.pointerId) drag.current = null
      }}
      onClick={(event) => {
        if (dragged.current && event.detail > 0) {
          event.preventDefault()
          return
        }
        if (state === 'fallback' || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return
        event.preventDefault()
        setState('loading')
      }}
    >
      <img src='/ant-claude-swords-icon.png' alt='' width='42' height='42' draggable={false} fetchPriority='low' />
      <span>{t('Contact the site owner to top up')}</span>
      {state === 'loading' && <span role='status'>{t('Loading')}…</span>}
      {state === 'fallback' && <span>{t('Open in new tab')} ↗</span>}
    </a>
  )
}
