import '@testing-library/jest-dom/vitest';
import { afterEach, beforeEach, vi } from 'vitest';

// Next.js App Router hooks: real navigation needs a running Next server, so route changes are observed
// through these mocks instead of asserting on actual URL changes.
export const push = vi.fn();
export const replace = vi.fn();
let currentPath = '/';
export function setPathname(path: string) {
  currentPath = path;
}

vi.mock('next/navigation', () => ({
  useRouter: () => ({ push, replace, refresh: vi.fn(), back: vi.fn() }),
  usePathname: () => currentPath,
  useParams: () => ({ id: 'item-1' }),
}));

beforeEach(() => {
  currentPath = '/';
  window.localStorage.clear();
});

afterEach(() => {
  push.mockClear();
  replace.mockClear();
});
