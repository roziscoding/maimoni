import { readFileSync } from 'node:fs'

// iOS 27's Add to Home Screen sheet doesn't fetch touch icons over the network and falls back to
// a letter, so the icon is inlined into the HTML. /apple-touch-icon.png stays for other browsers.
const appleTouchIcon = `data:image/png;base64,${readFileSync(new URL('./app/assets/apple-touch-icon.png', import.meta.url)).toString('base64')}`

export default defineNuxtConfig({
  modules: ['@nuxt/ui'],
  ssr: false,
  css: ['~/assets/css/main.css'],
  devtools: { enabled: false },
  app: {
    head: {
      htmlAttrs: { lang: 'pt-BR' },
      title: 'maimoni',
      meta: [
        { name: 'robots', content: 'noindex, nofollow' },
        { name: 'theme-color', content: '#000000' },
        { name: 'apple-mobile-web-app-title', content: 'maimoni' },
        { name: 'apple-mobile-web-app-capable', content: 'yes' },
        { name: 'mobile-web-app-capable', content: 'yes' },
      ],
      link: [
        { rel: 'manifest', href: '/manifest.webmanifest' },
        { rel: 'icon', href: '/favicon.ico', sizes: '48x48' },
        { rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' },
        { rel: 'apple-touch-icon', href: appleTouchIcon },
        { rel: 'apple-touch-icon-precomposed', href: '/apple-touch-icon.png' },
      ],
    },
  },
  // Icon file names aren't hashed, so a changed icon reaches browsers within a week.
  routeRules: Object.fromEntries([
    '/favicon.ico',
    '/favicon.svg',
    '/apple-touch-icon.png',
    '/pwa-192x192.png',
    '/pwa-512x512.png',
    '/maskable-icon-512x512.png',
    '/manifest.webmanifest',
  ].map(path => [path, { headers: { 'cache-control': 'public, max-age=604800' } }])),
  runtimeConfig: {
    apiBase: 'http://localhost:3001',
  },
  compatibilityDate: '2026-10-01',
})
