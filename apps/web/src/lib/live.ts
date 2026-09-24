'use client';

import { useQueryClient } from '@tanstack/react-query';
import { useEffect, useRef } from 'react';
import { io, type Socket } from 'socket.io-client';
import { accessToken, api, apiOrigin } from './api';

/**
 * While a staff member has the panel open:
 *  1) a Socket.IO connection — the server counts them «в сети» (presence) and pushes events; every event refreshes the
 *     data on screen (no manual reload), throttled so a burst of events is one refetch;
 *  2) their browser position (only if the browser allows it) — so people who work from the web show up on the map too.
 * Nothing here is required: a denied geolocation or a dropped socket just means no dot / a slightly older screen.
 */
export function useLivePanel(enabled: boolean) {
  const qc = useQueryClient();
  const socketRef = useRef<Socket | null>(null);

  useEffect(() => {
    if (!enabled) return;
    let refreshTimer: ReturnType<typeof setTimeout> | null = null;
    const socket = io(apiOrigin(), {
      path: '/socket.io',
      transports: ['websocket'],
      auth: (cb) => cb({ token: accessToken() ?? '' }), // re-read on every reconnect: the access token rotates
      reconnectionDelay: 2_000,
      reconnectionDelayMax: 30_000,
    });
    socket.on('event', () => {
      if (refreshTimer) return;
      refreshTimer = setTimeout(() => { refreshTimer = null; qc.invalidateQueries(); }, 800);
    });
    // a rejected handshake (expired token): a cheap authenticated call refreshes the token, then try again
    socket.on('unauthorized', () => { api.get('/auth/me').catch(() => undefined).finally(() => setTimeout(() => socket.connect(), 1_000)); });
    socketRef.current = socket;
    return () => { if (refreshTimer) clearTimeout(refreshTimer); socket.close(); socketRef.current = null; };
  }, [enabled, qc]);

  useEffect(() => {
    if (!enabled || typeof navigator === 'undefined' || !navigator.geolocation) return;
    let last = 0;
    let lastPos: GeolocationCoordinates | null = null;
    const send = (c: GeolocationCoordinates) => {
      const now = Date.now();
      const moved = lastPos ? Math.hypot(c.latitude - lastPos.latitude, c.longitude - lastPos.longitude) > 0.0005 : true; // ~50 m
      if (now - last < 60_000 && !moved) return; // at most once a minute unless they really moved
      last = now;
      lastPos = c;
      api.post('/location', {
        latitude: c.latitude, longitude: c.longitude,
        accuracy: Number.isFinite(c.accuracy) ? Math.min(c.accuracy, 100_000) : undefined,
        recordedAt: new Date().toISOString(), isBackground: false,
      }).catch(() => undefined);
    };
    const id = navigator.geolocation.watchPosition((p) => send(p.coords), () => undefined, { enableHighAccuracy: false, maximumAge: 60_000, timeout: 30_000 });
    return () => navigator.geolocation.clearWatch(id);
  }, [enabled]);
}
