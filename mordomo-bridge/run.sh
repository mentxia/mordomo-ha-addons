#!/usr/bin/with-contenv bashio

# -- Read addon config --
BRIDGE_PORT=$(bashio::config 'bridge_port')

# -- Auth dir - persisted across restarts --
AUTH_DIR="/config/mordomo_bridge/auth"
mkdir -p "$AUTH_DIR"

# -- Webhook URL resolution --
# Priority order:
#  1. Explicitly configured webhook_url in addon options
#  2. Auto-discovery via HA Supervisor API (finds the real dynamic webhook ID)
#  3. Fallback with warning

WEBHOOK_URL=""

# 1. User-configured URL takes priority
if bashio::config.exists 'webhook_url' && bashio::var.has_value "$(bashio::config 'webhook_url' 2>/dev/null)"; then
    WEBHOOK_URL=$(bashio::config 'webhook_url')
    bashio::log.info "Using configured webhook URL: $WEBHOOK_URL"
fi

# 2. Auto-discover via HA Supervisor API
if [ -z "$WEBHOOK_URL" ] && [ -n "${SUPERVISOR_TOKEN:-}" ]; then
    bashio::log.info "Auto-discovering Mordomo HA webhook via HA API..."

    # Try to find the config entry ID for mordomo_ha
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
        bashio::log.info "Auto-discovered webhook from config entry: $WEBHOOK_URL"
    else
        bashio::log.info "Mordomo HA integration not found yet - it may not be configured."
        bashio::log.info "The bridge will start but won't forward messages until webhook is set."
    fi
fi

# 3. Final fallback
if [ -z "$WEBHOOK_URL" ]; then
    bashio::log.warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    bashio::log.warning "  Webhook URL nao descoberto automaticamente."
    bashio::log.warning "  A bridge vai iniciar mas nao consegue reencaminhar"
    bashio::log.warning "  mensagens para o HA ate o webhook ser configurado."
    bashio::log.warning ""
    bashio::log.warning "  Para configurar:"
    bashio::log.warning "  1. Abre o HA -> Mordomo HA -> Dashboard"
    bashio::log.warning "  2. Copia o webhook URL"
    bashio::log.warning "  3. Cola nas opcoes deste add-on"
    bashio::log.warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    # Use a fallback that at least allows the bridge to start
    WEBHOOK_URL="http://supervisor/core/api/webhook/mordomo_ha_placeholder"
fi

# -- Export env vars for the bridge --
export MORDOMO_WEBHOOK_URL="$WEBHOOK_URL"
export MORDOMO_BRIDGE_PORT="$BRIDGE_PORT"
export MORDOMO_AUTH_DIR="$AUTH_DIR"
export MORDOMO_LOG_LEVEL="info"

# If SUPERVISOR_TOKEN is available, pass it so the bridge can authenticate
if [ -n "${SUPERVISOR_TOKEN:-}" ]; then
    export MORDOMO_HA_TOKEN="${SUPERVISOR_TOKEN}"
fi

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
