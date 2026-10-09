// The download number on the page.
export async function onRequest({ env }) {
  let total = null;
  try {
    const row = await env.STATS.prepare("SELECT COALESCE(SUM(n), 0) AS t FROM hits WHERE kind = 'download'").first();
    total = row.t;
  } catch {}
  return Response.json({ downloads: total }, { headers: { 'Cache-Control': 'public, max-age=30' } });
}
