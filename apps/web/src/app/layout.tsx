import type { Metadata } from 'next';
import { Manrope } from 'next/font/google';
import type { ReactNode } from 'react';
import { Providers } from '@/components/providers';
import './globals.css';

// Manrope: soft, modern, full Cyrillic — self-hosted by Next at build time (no request to Google from the phone)
const manrope = Manrope({ subsets: ['latin', 'cyrillic'], weight: ['400', '500', '600', '700', '800'], display: 'swap', variable: '--font-sans' });

export const metadata: Metadata = {
  title: 'Diamoraa',
  description: 'Diamoraa — работа для мастериц: заказы, прогресс и оплата в одном приложении.',
  robots: { index: false, follow: false },
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="ru" className={manrope.variable}>
      <body className="min-h-screen antialiased">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
