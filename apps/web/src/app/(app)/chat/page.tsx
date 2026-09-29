'use client';

import { Suspense } from 'react';
import { ChatApp } from '@/components/chat';
import { Spinner } from '@/components/ui';

/** «Чат» of the staff panel: the same chats as the app (everyone with everyone). */
export default function ChatPage() {
  return <Suspense fallback={<Spinner />}><ChatApp /></Suspense>;
}
