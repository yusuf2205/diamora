export const dynamic = 'force-dynamic';

type Check = { status: 'up' | 'down' | 'disabled'; latencyMs?: number };
interface Readiness { status: string; checks: Record<'database' | 'storage' | 'redis', Check> }

async function readiness(): Promise<Readiness | null> {
  try {
    // internal Docker network: the API's readiness endpoint is not reachable from the internet
    const res = await fetch(`${process.env.API_INTERNAL_URL ?? 'http://localhost:3000'}/health/ready`, { cache: 'no-store' });
    return (await res.json()) as Readiness;
  } catch {
    return null;
  }
}

const dot = (s: Check['status']) => (s === 'up' ? 'bg-ok' : s === 'down' ? 'bg-danger' : 'bg-muted');

export default async function Home() {
  const r = await readiness();
  return (
    <main className="mx-auto max-w-3xl space-y-6 px-4 py-10">
      <header>
        <h1 className="text-2xl font-semibold">Yusmus</h1>
        <p className="text-sm text-muted">Пульт управления домашним производством. Все данные — на нашем NAS.</p>
      </header>
      <section className="rounded-lg border border-border bg-card p-5">
        <h2 className="mb-3 font-medium">Состояние системы</h2>
        {r ? (
          <ul className="grid gap-2 text-sm sm:grid-cols-3">
            {(['database', 'storage', 'redis'] as const).map((k) => (
              <li key={k} className="flex items-center gap-2">
                <span className={`inline-block h-2.5 w-2.5 rounded-full ${dot(r.checks[k].status)}`} />
                <span className="capitalize">{k}</span>
                <span className="text-muted">{r.checks[k].latencyMs !== undefined ? `${r.checks[k].latencyMs} ms` : r.checks[k].status}</span>
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-sm text-danger">API недоступен</p>
        )}
      </section>
      <p className="text-xs text-muted">Таблицы, отчёты и настройки появятся по мере готовности этапов M2–M6. Повседневная работа — в мобильном приложении.</p>
    </main>
  );
}
