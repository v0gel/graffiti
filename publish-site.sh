#!/usr/bin/env bash
# Puts the download page and its counter online. ./publish-site.sh
set -euo pipefail
cd "$(dirname "$0")"
B="$HOME/Library/Caches/graffiti-build"; SITE="$B/site"; mkdir -p "$SITE"
rsync -a --exclude='.*' site/ "$SITE/"
rsync -a --delete --exclude='.*' functions/ "$B/functions/"
[ -f "$SITE/Graffiti.dmg" ] || cp dist/Graffiti.dmg "$SITE/Graffiti.dmg"
printf '/latest.json\n  Cache-Control: no-cache\n' > "$SITE/_headers"
printf '{ "version": 1, "include": ["/api/*"], "exclude": [] }\n' > "$SITE/_routes.json"
cat > "$B/wrangler.toml" <<TOML
name = "graffiti-updates"
pages_build_output_dir = "site"
compatibility_date = "2026-10-01"

[[d1_databases]]
binding = "STATS"
database_name = "graffiti-stats"
database_id = "5b3ef42d-9a29-48f9-b62d-3d0113602445"
TOML
cd "$B" && wrangler pages deploy site --project-name graffiti-updates --branch main --commit-dirty=true
