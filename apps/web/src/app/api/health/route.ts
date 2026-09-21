// Container health check target: no auth, no dependencies.
export const dynamic = 'force-dynamic';
export function GET() {
  return Response.json({ status: 'ok' });
}
