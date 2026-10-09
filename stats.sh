#!/usr/bin/env bash
# How many downloads and installs. ./stats.sh
set -euo pipefail
q() { wrangler d1 execute graffiti-stats --remote --json --command "$1" 2>/dev/null | python3 -c "import json,sys; [print(*r.values(), sep='  ') for r in json.load(sys.stdin)[0]['results']]"; }
echo "Totals (downloads, installs):"; q "SELECT kind, SUM(n) FROM hits WHERE kind IN ('download','install') GROUP BY kind"
echo "Active installs, last 7 days (update checks per day):"; q "SELECT day, SUM(n) FROM hits WHERE kind = 'check' GROUP BY day ORDER BY day DESC LIMIT 7"
echo "By version, today:"; q "SELECT version, SUM(n) FROM hits WHERE kind = 'check' AND day = date('now') GROUP BY version"
