#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# Reset the sync2.centaurion.me Traefik basic-auth password (hermes/VPS2)
# ═══════════════════════════════════════════════════════════════════════
# Run ON hermes, as root:   bash Cortex/deploy/syncthing/reset-sync2-password.sh
# The old password is bcrypt-hashed and unrecoverable; this sets a new one,
# prints it once, and verifies the login is live. Backs up the config first.
# ═══════════════════════════════════════════════════════════════════════
set -euo pipefail
FILE=/docker/traefik/dynamic/syncthing.yml
[ -f "$FILE" ] || { echo "✗ $FILE not found"; exit 1; }

HEX=$(openssl rand -hex 3)
NEWPW="Hermes-${HEX}-Sync2"                 # phone-typable, still strong
HASH=$(htpasswd -nbB admin "$NEWPW" | cut -d: -f2)

cp "$FILE" "$FILE.bak.$(date +%Y%m%d-%H%M%S)"
python3 - "$FILE" "$HASH" <<'PY'
import sys, re
f, h = sys.argv[1], sys.argv[2]
s = open(f).read()
s = re.sub(r'- "admin:\$2y\$[^"]*"', '- "admin:%s"' % h, s)
open(f, "w").write(s)
PY

echo "waiting for Traefik file-watch reload..."
sleep 3
code=$(curl -s -u "admin:$NEWPW" -o /dev/null -w '%{http_code}' --max-time 8 https://sync2.centaurion.me/)

echo "════════════════════════════════════════"
echo "  sync2.centaurion.me login RESET"
echo "    username: admin"
echo "    password: $NEWPW"
echo "    live test: HTTP $code   (200 or 302 = working)"
echo "════════════════════════════════════════"
echo "Change it later anytime by re-running this script."
