#!/bin/bash
set -e

# ============================================================
#  Mordomo HA - WhatsApp Bridge (init: false - no s6-overlay)
#  Reads config from /data/options.json (HA add-on standard)
# ============================================================

# -- Read addon config from options.json --
OPTIONS_FILE="/data/options.json"
if [ ! -f "$OPTIONS_FILE" ]; then
    echo "[ERROR] Options file not found: $OPTIONS_FILE"
    exit 1
fi

BRIDGE_PORT=$(jq -r '.bridge_port // 3781' "$OPTIONS_FILE")
CONFIG_WEBHOOK=$(jq -r '.webhook_url // ""' "$OPTIONS_FILE")

# -- Auth dir - persisted across restarts --
AUTH_DIR="/config/mordomo_bridge/auth"
mkdir -p "$AUTH_DIR" 2>/dev/null || {
    # Fallback if /config is not writable
    AUTH_DIR="/data/auth"
    mkdir -p "$AUTH_DIR"
    echo "[WARN] Could not create /config/mordomo_bridge/auth, using /data/auth"
}

# -- Webhook URL resolution --
WEBHOOK_URL=""

# 1. User-configured URL takes priority
if [ -n "$CONFIG_WEBHOOK" ]; then
    WEBHOOK_URL="$CONFIG_WEBHOOK"
    echo "[INFO] Using configured webhook URL: $WEBHOOK_URL"
fi

# 2. Auto-discover via HA Supervisor API
if [ -z "$WEBHOOK_URL" ] && [ -n "${SUPERVISOR_TOKEN:-}" ]; then
    echo "[INFO] Auto-discovering Mordomo HA webhook via HA API..."

    ENTRY_ID=$(curl -s -f \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" \
        "http://supervisor/core/api/config/config_entries/entry" 2>/dev/null | \
        python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for entry in data:
        if entry.get('domain') == 'mordomo_ha':
            print(entry.get('entry_id', ''))
            break
except:
    pass
" 2>/dev/null || echo "")

    if [ -n "$ENTRY_ID" ]; then
        WEBHOOK_URL="http://supervisor/core/api/webhook/mordomo_ha_${ENTRY_ID}"
        echo "[INFO] Auto-discovered webhook: $WEBHOOK_URL"
    else
        echo "[INFO] Mordomo HA integration not found yet - will start without webhook"
    fi
fi

# 3. Final fallback
if [ -z "$WEBHOOK_URL" ]; then
    echo "[WARN] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[WARN]   Webhook URL nao descoberto automaticamente."
    echo "[WARN]   A bridge vai iniciar mas nao reencaminha mensagens."
    echo "[WARN]   Configura o webhook nas opcoes do add-on."
    echo "[WARN] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    WEBHOOK_URL="http://supervisor/core/api/webhook/mordomo_ha_placeholder"
fi

# -- Export env vars for the bridge --
export MORDOMO_WEBHOOK_URL="$WEBHOOK_URL"
export MORDOMO_BRIDGE_PORT="$BRIDGE_PORT"
export MORDOMO_AUTH_DIR="$AUTH_DIR"
export MORDOMO_LOG_LEVEL="info"

# If SUPERVISOR_TOKEN is available, pass it for webhook auth
if [ -n "${SUPERVISOR_TOKEN:-}" ]; then
    export MORDOMO_HA_TOKEN="${SUPERVISOR_TOKEN}"
fi

# -- Log startup --
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Mordomo HA - WhatsApp Bridge v1.0.5"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Bridge Port: $BRIDGE_PORT"
echo "  Webhook:     $WEBHOOK_URL"
echo "  Auth Dir:    $AUTH_DIR"
echo ""
echo "  Abre o Mordomo HA dashboard para"
echo "  escanear o QR code com o WhatsApp."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# -- Run bridge (exec replaces shell with node process) --
exec node /app/baileys_bridge.js
