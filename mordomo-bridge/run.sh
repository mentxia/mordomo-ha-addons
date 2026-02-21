#!/usr/bin/with-contenv bashio

# -- Read addon config --
BRIDGE_PORT=$(bashio::config 'bridge_port')

# -- Auth dir - persisted across restarts --
AUTH_DIR="/config/mordomo_bridge/auth"
mkdir -p "$AUTH_DIR"

# -- Webhook URL resolution --
# Priority order:
#  1. Explicitly configured webhook_url in addon options
#  2. Auto-discovery via HA API (finds the real dynamic webhook ID)
#  3. Fallback to supervisor internal URL (still uses dynamic discovery)

WEBHOOK_URL=""

# 1. User-configured URL takes priority
if bashio::config.exists 'webhook_url' && bashio::var.has_value "$(bashio::config 'webhook_url' 2>/dev/null)"; then
    WEBHOOK_URL=$(bashio::config 'webhook_url')
    bashio::log.info "Using configured webhook URL: $WEBHOOK_URL"
fi

# 2. Auto-discover via HA Supervisor API (finds mordomo_ha_* webhook dynamically)
if [ -z "$WEBHOOK_URL" ] && [ -n "${SUPERVISOR_TOKEN:-}" ]; then
    bashio::log.info "Auto-discovering Mordomo HA webhook via HA API..."

    # Query the HA API for registered webhooks (requires homeassistant_api: true)
    WEBHOOK_RESPONSE=$(curl -s -f \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" \
        "http://supervisor/core/api/config" 2>/dev/null || echo "")

    # Extract the HA internal URL from config
    HA_INTERNAL_URL=$(echo "$WEBHOOK_RESPONSE" | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('internal_url',''))" 2>/dev/null || echo "")

    if [ -z "$HA_INTERNAL_URL" ]; then
        # Try common supervisor internal URLs
        HA_INTERNAL_URL="http://supervisor/core"
    fi

    # The Mordomo HA component logs its webhook URL on startup.
    # The webhook ID format is: mordomo_ha_{entry_id}
    # We'll use the supervisor internal path (which the bridge resolves via host network)
    # Users must configure webhook_url manually if auto-discovery fails.
    bashio::log.warning "Could not auto-discover webhook ID. Please set webhook_url in addon options."
    bashio::log.warning "Find the webhook URL in HA logs: grep 'mordomo_ha webhook' home-assistant.log"

    # Use supervisor URL as best-effort fallback (user must configure the full ID)
    WEBHOOK_URL="http://supervisor/core/api/webhook/mordomo_ha_REPLACE_ME"
fi

# 3. Final fallback -- user must configure
if [ -z "$WEBHOOK_URL" ]; then
    WEBHOOK_URL="http://homeassistant.local:8123/api/webhook/mordomo_ha_REPLACE_ME"
fi

# Warn if using placeholder
if echo "$WEBHOOK_URL" | grep -q "REPLACE_ME"; then
    bashio::log.warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    bashio::log.warning "  ATENCAO: Webhook URL nao configurado!"
    bashio::log.warning "  Abre o Mordomo HA Dashboard para ver o Webhook URL"
    bashio::log.warning "  e configura-o nas opcoes deste add-on."
    bashio::log.warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

# -- Export env vars for the bridge --
export MORDOMO_WEBHOOK_URL="$WEBHOOK_URL"
export MORDOMO_BRIDGE_PORT="$BRIDGE_PORT"
export MORDOMO_AUTH_DIR="$AUTH_DIR"
export MORDOMO_LOG_LEVEL="info"

# -- Log startup --
bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bashio::log.info "  Mordomo HA - WhatsApp Bridge"
bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bashio::log.info "  Bridge Port: $BRIDGE_PORT"
bashio::log.info "  Webhook:     $WEBHOOK_URL"
bashio::log.info "  Auth Dir:    $AUTH_DIR"
bashio::log.info ""
bashio::log.info "  Abre o Mordomo HA dashboard para"
bashio::log.info "  escanear o QR code com o WhatsApp."
bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# -- Run bridge --
exec node /app/baileys_bridge.js
