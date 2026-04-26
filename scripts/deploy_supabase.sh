#!/usr/bin/env bash
#
# Push DB migrations + deploy all Edge Functions to a linked Supabase project.
#
# Prerequisites (one-time):
#   1. Create a project at https://supabase.com/dashboard (region: Northeast Asia)
#   2. supabase link --project-ref <prod-ref>
#   3. Set secrets:
#        supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
#      (DO NOT set MOCK_ANTHROPIC=true or MOCK_PURCHASES=true in production.)
#
# This script is safe to re-run; `db push` is idempotent against migration history,
# and `functions deploy` overwrites the deployed version.

set -euo pipefail

cd "$(dirname "$0")/.."

if ! supabase projects list --linked >/dev/null 2>&1; then
  echo "ERROR: no linked Supabase project found." >&2
  echo "  Run: supabase link --project-ref <your-project-ref>" >&2
  exit 1
fi

LINKED_REF=$(supabase projects list --output json 2>/dev/null \
  | python3 -c "import sys,json; [print(p['id']) for p in json.load(sys.stdin) if p.get('linked')]" \
  || echo "<unknown>")
echo "==> Deploying to project: $LINKED_REF"
read -r -p "    Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

echo
echo "==> Pushing migrations..."
supabase db push

echo
echo "==> Deploying Edge Functions..."
for fn in compute-saju chat verify-purchase; do
  echo "  - $fn"
  supabase functions deploy "$fn"
done

echo
echo "==> Verifying ANTHROPIC_API_KEY is set (chat function will fail without it)..."
if ! supabase secrets list 2>/dev/null | grep -q "ANTHROPIC_API_KEY"; then
  echo "  WARNING: ANTHROPIC_API_KEY not found in secrets. Set it with:" >&2
  echo "    supabase secrets set ANTHROPIC_API_KEY=sk-ant-..." >&2
fi

echo
echo "✅ Deploy complete."
echo
echo "Smoke test from your machine:"
echo "  curl -X POST https://${LINKED_REF}.supabase.co/functions/v1/chat \\"
echo "    -H 'Authorization: Bearer <user-jwt>' \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"content\":\"안녕하세요\"}'"
