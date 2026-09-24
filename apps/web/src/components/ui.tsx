'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useState, type ButtonHTMLAttributes, type InputHTMLAttributes, type ReactNode, type SelectHTMLAttributes } from 'react';
import { errorMessage } from '@/lib/format';

/* Mobile-first building blocks. Rules every screen gets for free:
 *  - touch targets >= 40px, inputs 16px on phones (no iOS zoom-on-focus), 14px from `sm` up;
 *  - lists are CARDS on a phone and a TABLE from `lg` up (`DataList`) - never a table cut off at the screen edge;
 *  - filter chips scroll sideways on a phone instead of stacking into three rows (`Chips`);
 *  - dialogs are bottom sheets on a phone, centred cards on a desktop (`Modal`). */

/** Diamoraa mark — the same outlined diamond the mobile app shows on its sign-in screen. */
export function Logo({ size = 28, className = '' }: { size?: number; className?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden className={`text-primary ${className}`}>
      <path d="M19 3H5L2 9l10 12L22 9l-3-6zM9.62 8l1.5-3h1.76l1.5 3H9.62zM11 10v6.68L5.44 10H11zm2 0h5.56L13 16.68V10zm6.26-2h-2.65l-1.5-3h2.65l1.5 3zM6.24 5h2.65l-1.5 3H4.74l1.5-3z" />
    </svg>
  );
}

export function Card({ children, className = '' }: { children: ReactNode; className?: string }) {
  return <div className={`rounded-xl border border-border bg-card p-4 sm:p-5 ${className}`}>{children}</div>;
}

export function PageHeader({ title, subtitle, actions, back }: { title: ReactNode; subtitle?: ReactNode; actions?: ReactNode; back?: { href: string; label: string } }) {
  return (
    <div className="space-y-2">
      {back && <Link href={back.href} className="inline-flex items-center gap-1 text-sm text-muted hover:text-foreground">← {back.label}</Link>}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="min-w-0">
          <h1 className="text-xl font-semibold leading-tight sm:text-2xl">{title}</h1>
          {subtitle && <div className="mt-1 text-sm text-muted">{subtitle}</div>}
        </div>
        {actions && <div className="flex flex-wrap gap-2 [&>*]:flex-1 sm:[&>*]:flex-none">{actions}</div>}
      </div>
    </div>
  );
}

/** `href` makes the card a link to the exact filtered list it summarises — a card with no `href` is a plain stat
 * (e.g. an aggregate with no single matching filter), never a button that does nothing. */
export function StatCard({ label, value, hint, href, tone }: { label: string; value: ReactNode; hint?: string; href?: string; tone?: 'danger' | 'ok' | 'primary' }) {
  const color = tone === 'danger' ? 'text-danger' : tone === 'ok' ? 'text-ok' : tone === 'primary' ? 'text-primary' : '';
  const body = (
    <>
      <p className="text-xs text-muted sm:text-sm">{label}</p>
      <p className={`mt-1 text-xl font-semibold tabular-nums sm:text-2xl ${color}`}>{value}</p>
      {hint && <p className="mt-1 text-xs text-muted">{hint}</p>}
    </>
  );
  if (href) {
    return (
      <Link href={href} className="block rounded-xl border border-border bg-card p-4 transition hover:border-primary/50 hover:bg-border/20 active:scale-[0.99] sm:p-5">
        {body}
      </Link>
    );
  }
  return <Card>{body}</Card>;
}

export function StatCardSkeleton() {
  return (
    <div className="rounded-xl border border-border bg-card p-4 sm:p-5">
      <div className="h-3.5 w-20 animate-pulse rounded bg-border" />
      <div className="mt-2 h-7 w-12 animate-pulse rounded bg-border" />
    </div>
  );
}

export function ListSkeleton({ rows = 5 }: { rows?: number }) {
  return (
    <div className="space-y-2" aria-label="Загрузка">
      {Array.from({ length: rows }, (_, i) => <div key={i} className="h-16 animate-pulse rounded-xl border border-border bg-card" />)}
    </div>
  );
}

export function Badge({ children, tone = 'default' }: { children: ReactNode; tone?: 'default' | 'ok' | 'danger' | 'warn' }) {
  const cls = { default: 'bg-border text-foreground', ok: 'bg-ok/15 text-ok', danger: 'bg-danger/15 text-danger', warn: 'bg-primary/15 text-primary' }[tone];
  return <span className={`inline-flex shrink-0 items-center whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-medium ${cls}`}>{children}</span>;
}

export function Button({ children, variant = 'primary', className = '', ...props }: { children: ReactNode; variant?: 'primary' | 'outline' | 'ghost' | 'danger' } & ButtonHTMLAttributes<HTMLButtonElement>) {
  const base = 'inline-flex min-h-10 items-center justify-center gap-2 rounded-lg px-4 py-2 text-sm font-medium transition active:scale-[0.98] disabled:pointer-events-none disabled:opacity-50';
  const variants = {
    primary: 'bg-primary text-white hover:opacity-90',
    outline: 'border border-border bg-card hover:bg-border/40',
    ghost: 'hover:bg-border/40',
    danger: 'bg-danger text-white hover:opacity-90',
  };
  return (
    <button className={`${base} ${variants[variant]} ${className}`} {...props}>
      {children}
    </button>
  );
}

const field = 'w-full min-h-10 rounded-lg border border-border bg-card px-3 py-2 text-base outline-none transition focus:border-primary focus:ring-2 focus:ring-primary/15 sm:text-sm';

export function Input(props: InputHTMLAttributes<HTMLInputElement>) {
  return <input {...props} className={`${field} ${props.className ?? ''}`} />;
}

export function Select({ children, ...props }: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select {...props} className={`${field} ${props.className ?? ''}`}>
      {children}
    </select>
  );
}

export function Field({ label, htmlFor, children, hint }: { label: string; htmlFor?: string; children: ReactNode; hint?: string }) {
  return (
    <div className="space-y-1">
      <label htmlFor={htmlFor} className="block text-xs font-medium text-muted">{label}</label>
      {children}
      {hint && <p className="text-xs text-muted">{hint}</p>}
    </div>
  );
}

/** One-of-many filter. Scrolls sideways on a phone (never three stacked rows), wraps on a desktop. */
export function Chips<T extends string>({ options, value, onChange, label }: { options: readonly { value: T; label: string; count?: number }[]; value: T; onChange: (v: T) => void; label?: string }) {
  return (
    <div role="group" aria-label={label} className="-mx-4 flex gap-2 overflow-x-auto px-4 pb-1 [scrollbar-width:none] lg:mx-0 lg:flex-wrap lg:overflow-visible lg:px-0">
      {options.map((o) => (
        <button
          key={o.value}
          onClick={() => onChange(o.value)}
          aria-pressed={value === o.value}
          className={`min-h-9 shrink-0 whitespace-nowrap rounded-full border px-3.5 py-1.5 text-sm font-medium transition ${value === o.value ? 'border-primary bg-primary text-white' : 'border-border bg-card hover:bg-border/40'}`}
        >
          {o.label}{o.count != null ? <span className="ml-1.5 opacity-70">{o.count}</span> : null}
        </button>
      ))}
    </div>
  );
}

export function Table({ children }: { children: ReactNode }) {
  return (
    <div className="overflow-x-auto rounded-xl border border-border bg-card">
      <table className="w-full text-left text-sm">{children}</table>
    </div>
  );
}
export const Th = ({ children, className = '' }: { children?: ReactNode; className?: string }) => (
  <th className={`whitespace-nowrap border-b border-border bg-border/30 px-3 py-2.5 text-xs font-medium uppercase tracking-wide text-muted ${className}`}>{children}</th>
);
export const Td = ({ children, className = '' }: { children?: ReactNode; className?: string }) => <td className={`border-b border-border px-3 py-2.5 ${className}`}>{children}</td>;

/** true below Tailwind's `lg` (1024px): phones and portrait tablets. Read synchronously on first render (every page here is client-rendered after
 * sign-in), then kept in sync on resize/rotation. No matchMedia (tests, old browsers) = desktop. */
export function useIsPhone() {
  const query = '(max-width: 1023px)';
  const get = () => typeof window !== 'undefined' && typeof window.matchMedia === 'function' && window.matchMedia(query).matches;
  const [phone, setPhone] = useState(get);
  useEffect(() => {
    if (typeof window.matchMedia !== 'function') return;
    const mq = window.matchMedia(query);
    const on = () => setPhone(mq.matches);
    mq.addEventListener('change', on);
    return () => mq.removeEventListener('change', on);
  }, []);
  return phone;
}

export interface Column<T> { header: string; cell: (row: T) => ReactNode; className?: string }

/** A list that is a stack of tappable CARDS on a phone and a TABLE from `lg` up. Same rows, same link. */
export function DataList<T>({ rows, rowKey, columns, card, href, onRowClick }: {
  rows: T[];
  rowKey: (row: T) => string;
  columns: Column<T>[];
  card: (row: T) => ReactNode;
  href?: (row: T) => string | null;
  onRowClick?: (row: T) => void;
}) {
  const router = useRouter();
  const phone = useIsPhone();
  const wrap = (row: T, inner: ReactNode, className: string) => {
    const to = href?.(row);
    if (to) return <Link key={rowKey(row)} href={to} className={className}>{inner}</Link>;
    if (onRowClick) return <button key={rowKey(row)} onClick={() => onRowClick(row)} className={`${className} w-full text-left`}>{inner}</button>;
    return <div key={rowKey(row)} className={className}>{inner}</div>;
  };
  if (phone) {
    return <div className="space-y-2">{rows.map((row) => wrap(row, card(row), 'block rounded-xl border border-border bg-card p-3.5 transition active:bg-border/30'))}</div>;
  }
  return (
    <Table>
      <thead>
        <tr>{columns.map((c) => <Th key={c.header} className={c.className}>{c.header}</Th>)}</tr>
      </thead>
      <tbody>
        {rows.map((row) => {
          const to = href?.(row);
          const clickable = !!to || !!onRowClick;
          return (
            <tr
              key={rowKey(row)}
              className={clickable ? 'cursor-pointer hover:bg-border/20' : ''}
              onClick={() => (to ? router.push(to) : onRowClick?.(row))}
            >
              {columns.map((c, i) => (
                <Td key={c.header} className={c.className}>
                  {i === 0 && to ? <Link href={to} onClick={(e) => e.stopPropagation()} className="hover:underline">{c.cell(row)}</Link> : c.cell(row)}
                </Td>
              ))}
            </tr>
          );
        })}
      </tbody>
    </Table>
  );
}

export function EmptyState({ title, hint, action }: { title: string; hint?: string; action?: ReactNode }) {
  return (
    <div className="rounded-xl border border-dashed border-border px-6 py-10 text-center text-muted">
      <p className="font-medium text-foreground/80">{title}</p>
      {hint && <p className="mt-1 text-sm">{hint}</p>}
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
}

export function ErrorState({ error, onRetry }: { error: unknown; onRetry?: () => void }) {
  return (
    <div className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-danger/30 bg-danger/5 p-4 text-sm text-danger" role="alert">
      <span>{errorMessage(error)}</span>
      {onRetry && (
        <button onClick={onRetry} className="min-h-9 shrink-0 rounded-lg border border-danger/30 px-3 py-1 font-medium hover:bg-danger/10">
          Повторить
        </button>
      )}
    </div>
  );
}

export function Spinner() {
  return <div className="h-5 w-5 animate-spin rounded-full border-2 border-border border-t-primary" />;
}

/** Bottom sheet on a phone, centred dialog from `sm` up. Esc and a tap outside close it; the page behind never scrolls. */
export function Modal({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => { document.removeEventListener('keydown', onKey); document.body.style.overflow = prev; };
  }, [onClose]);
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 sm:items-center sm:p-4" onClick={onClose}>
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className="max-h-[92vh] w-full overflow-y-auto rounded-t-2xl border border-border bg-card p-5 pb-[max(1.25rem,env(safe-area-inset-bottom))] shadow-xl sm:max-w-md sm:rounded-xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mx-auto mb-3 h-1 w-10 rounded-full bg-border sm:hidden" />
        <h3 className="mb-4 text-lg font-semibold">{title}</h3>
        {children}
      </div>
    </div>
  );
}
