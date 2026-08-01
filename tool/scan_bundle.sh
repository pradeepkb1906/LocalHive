#!/bin/bash
# Scans a built web bundle for anything that must never ship to a browser.
#
# Run before every public deploy. Exits non-zero if it finds something, so it
# can gate a deploy rather than merely print a warning.
#
# Patterns are anchored deliberately. An early version looked for "sk_test"
# and matched Skia's WebAssembly symbol tables three times — sk_ is Skia's
# own prefix. A scanner that cries wolf gets ignored, which is worse than no
# scanner at all. Stripe keys always carry the trailing underscore.
set -uo pipefail
DIR="${1:-build/web}"
FOUND=0

# Live credentials. Any hit here is a stop-everything event.
declare -a FATAL=(
  'gsk_[A-Za-z0-9]\{20,\}'          # Groq
  'sk_live_[A-Za-z0-9]\{20,\}'      # Stripe secret, live
  'sk_test_[A-Za-z0-9]\{20,\}'      # Stripe secret, test
  'rk_live_[A-Za-z0-9]\{20,\}'      # Stripe restricted
  'whsec_[A-Za-z0-9]\{20,\}'        # Stripe webhook signing secret
  'sb_secret_[A-Za-z0-9]\{10,\}'    # Supabase service key
  'service_role'                     # Supabase service role JWT claim
  'BEGIN PRIVATE KEY'                # any PEM
  'BEGIN RSA PRIVATE KEY'
  'AKIA[0-9A-Z]\{16\}'              # AWS access key id
)

# Shared demo passwords. Not credentials to a system, but they should not be
# in a public build once the app is past demos.
declare -a WARN=(
  'admin@123'
  'sfstore@123'
  'delivery@123'
)

echo "scanning $DIR"
for p in "${FATAL[@]}"; do
  n=$(grep -rlE "$p" "$DIR" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$n" != "0" ]; then
    echo "  FATAL  $p  in $n file(s):"
    grep -rlE "$p" "$DIR" 2>/dev/null | sed 's/^/           /'
    FOUND=1
  fi
done
for p in "${WARN[@]}"; do
  n=$(grep -rl "$p" "$DIR" 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" != "0" ] && echo "  WARN   $p present (demo credentials in a public build)"
done

if [ "$FOUND" = "0" ]; then
  echo "  clean — no live credentials in the bundle"
else
  echo "  DO NOT DEPLOY"
fi
exit $FOUND
