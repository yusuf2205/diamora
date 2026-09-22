'use client';

import { useRouter } from 'next/navigation';
import { useEffect } from 'react';
import { isSignedIn } from '@/lib/api';

export default function Home() {
  const router = useRouter();
  useEffect(() => {
    router.replace(isSignedIn() ? '/dashboard' : '/login');
  }, [router]);
  return null;
}
