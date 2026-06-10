import type { Metadata } from 'next'
import React from 'react'
import './globals.css'

export const metadata: Metadata = {
  title: process.env.NEXT_PUBLIC_APP_TITLE || 'Collection Analytics',
  description: 'Real-time collection pipeline analytics',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>
        <div className="app-container">
          <header className="app-header">
            <h1>{process.env.NEXT_PUBLIC_APP_TITLE || 'Collection Analytics'}</h1>
            <nav className="nav-links">
              <a href="/">Overview</a>
              <a href="/funnel">Funnel</a>
              <a href="/distribution">Distribution</a>
              <a href="/agents">Agents</a>
              <a href="/time-travel">Time Travel</a>
            </nav>
          </header>
          <main className="app-main">{children}</main>
        </div>
      </body>
    </html>
  )
}
