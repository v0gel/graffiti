// Adds one to a count. Downloads, first installs and daily checks. Nothing about who.
const KINDS = ['download', 'install', 'check'];
const DAILY_CAP = 90000;

export async function onRequest({ request, env }) {
  const url = new URL(request.url);
  const kind = url.searchParams.get('k');
  const done = new Response(null, { status: 204, headers: { 'Cache-Control': 'no-store' } });
  if (!KINDS.includes(kind) || !env.STATS) return done;
  const version = (url.searchParams.get('v') || '').replace(/[^0-9.]/g, '').slice(0, 12);
  const day = new Date().toISOString().slice(0, 10);
  try {
    const row = await env.STATS.prepare('SELECT COALESCE(SUM(n), 0) AS t FROM hits WHERE day = ?').bind(day).first();
    if (row.t < DAILY_CAP) {
      await env.STATS.prepare('INSERT INTO hits (day, kind, version, n) VALUES (?, ?, ?, 1) ON CONFLICT (day, kind, version) DO UPDATE SET n = n + 1')
        .bind(day, kind, version).run();
    }
  } catch {}
  return done;
}
