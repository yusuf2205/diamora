import type { Metadata } from 'next';
import type { ReactNode } from 'react';

export const metadata: Metadata = {
  title: 'Diamoraa — магазин',
  description: 'Каталог Diamoraa: выберите изделие и цвет, оставьте телефон — мы перезвоним.',
};

export default function ShopLayout({ children }: { children: ReactNode }) {
  return children;
}
