import Link from 'next/link';
import type { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode, SelectHTMLAttributes } from 'react';
import { errorMessage } from '@/lib/format';

export function Card({ children, className = '' }: { children: ReactNode; className?: string }) {
  return <div className={`rounded-lg border border-border bg-card p-5 ${className}`}>{children}</div>;
}

/** `href` makes the card a link to the exact filtered list it summarises — a card with no `href` is a plain stat
 * (e.g. an aggregate with no single matching filter), never a button that does nothing. */
export function StatCard({ label, value, hint, href }: { label: string; value: ReactNode; hint?: string; href?: string }) {
  const body = (
    <>
      <p className="text-sm text-muted">{label}</p>
      <p className="mt-1 text-2xl font-semibold">{value}</p>
      {hint && <p className="mt-1 text-xs text-muted">{hint}</p>}
    </>
  );
  if (href) return <Link href={href} className="block rounded-lg border border-border bg-card p-5 transition hover:border-primary/50 hover:bg-border/20">{body}</Link>;
  return <Card>{body}</Card>;
}

export function StatCardSkeleton() {
  return (
    <div className="rounded-lg border border-border bg-card p-5">
      <div className="h-3.5 w-20 animate-pulse rounded bg-border" />
      <div className="mt-2 h-7 w-12 animate-pulse rounded bg-border" />
    </div>
  );
}

export function Badge({ children, tone = 'default' }: { children: ReactNode; tone?: 'default' | 'ok' | 'danger' | 'warn' }) {
  const cls = { default: 'bg-border text-foreground', ok: 'bg-ok/15 text-ok', danger: 'bg-danger/15 text-danger', warn: 'bg-primary/15 text-primary' }[tone];
  return <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${cls}`}>{children}</span>;
}

export function Button({ children, variant = 'primary', className = '', ...props }: { children: ReactNode; variant?: 'primary' | 'outline' | 'ghost' } & ButtonHTMLAttributes<HTMLButtonElement>) {
  const base = 'inline-flex items-center justify-center gap-2 rounded-lg px-4 py-2 text-sm font-medium transition disabled:opacity-50 disabled:pointer-events-none';
  const variants = {
    primary: 'bg-primary text-white hover:opacity-90',
    outline: 'border border-border hover:bg-border/40',
    ghost: 'hover:bg-border/40',
  };
  return (
    <button className={`${base} ${variants[variant]} ${className}`} {...props}>
      {children}
    </button>
  );
}

export function Input(props: InputHTMLAttributes<HTMLInputElement>) {
  return <input {...props} className={`w-full rounded-lg border border-border bg-background px-3 py-2 text-sm outline-none focus:border-primary ${props.className ?? ''}`} />;
}

export function Select({ children, ...props }: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select {...props} className={`w-full rounded-lg border border-border bg-background px-3 py-2 text-sm outline-none focus:border-primary ${props.className ?? ''}`}>
      {children}
    </select>
  );
}

export function Table({ children }: { children: ReactNode }) {
  return (
    <div className="overflow-x-auto rounded-lg border border-border">
      <table className="w-full text-left text-sm">{children}</table>
    </div>
  );
}
export const Th = ({ children }: { children?: ReactNode }) => <th className="border-b border-border bg-border/30 px-3 py-2 font-medium text-muted">{children}</th>;
export const Td = ({ children, className = '' }: { children?: ReactNode; className?: string }) => <td className={`border-b border-border px-3 py-2 ${className}`}>{children}</td>;

export function EmptyState({ title, hint }: { title: string; hint?: string }) {
  return (
    <div className="rounded-lg border border-dashed border-border p-10 text-center text-muted">
      <p>{title}</p>
      {hint && <p className="mt-1 text-xs">{hint}</p>}
    </div>
  );
}

export function ErrorState({ error, onRetry }: { error: unknown; onRetry?: () => void }) {
  return (
    <div className="flex items-center justify-between gap-3 rounded-lg border border-danger/30 bg-danger/5 p-4 text-sm text-danger">
      <span>{errorMessage(error)}</span>
      {onRetry && (
        <button onClick={onRetry} className="shrink-0 rounded-lg border border-danger/30 px-3 py-1 font-medium hover:bg-danger/10">
          Повторить
        </button>
      )}
    </div>
  );
}

export function Spinner() {
  return <div className="h-5 w-5 animate-spin rounded-full border-2 border-border border-t-primary" />;
}

export function Modal({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <div className="w-full max-w-md rounded-lg border border-border bg-card p-5 shadow-xl" onClick={(e) => e.stopPropagation()}>
        <h3 className="mb-4 text-lg font-semibold">{title}</h3>
        {children}
      </div>
    </div>
  );
}
