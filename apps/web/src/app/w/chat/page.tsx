'use client';

import { Suspense } from 'react';
import { ChatApp } from '@/components/chat';
import { Spinner } from '@/components/ui';

/** «Чат» of the worker web version: the same chats as the app. */
export default function WorkerChatPage() {
  return <Suspense fallback={<Spinner />}><ChatApp single /></Suspense>;
}
