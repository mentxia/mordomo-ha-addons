#!/usr/bin/with-contenv bashio

# ── Read addon config ──
BRIDGE_PORT=$(bashio::config 'bridge_port')

# ── Auth dir - persisted across restarts ──
AUTH_DIR="/config/mordomo_bridge/auth"
mkdir -p "$AUTH_DIR"

# ── Auto-discover Mordomo HA webhook ──
# The component registers a webhook with prefix "mordomo_ha_"
# We'll try to find it via the HA API, fallback to default
WEBHOOK_URL=""

if bashio::var.has_value "$(bashio::config 'webhook_url' 2>/dev/null)"; then
    WEBHOOK_URL=$(bashio::config 'webhook_url')
fi

# If no webhook configured, try auto-discovery via HA API
if [ -z "$WEBHOOK_URL" ]; then
    HA_TOKEN="${SUPERVISOR_TOKEN}"
    if [ -n "$HA_TOKEN" ]; then
        bashio::log.info "Auto-discovering Mordomo HA webhook..."
        # The component creates webhooks, we'll use the internal URL
        WEBHOOK_URL="http://supervisor/core/api/webhook/mordomo_ha_default"
    fi
fi

# Fallback
if [ -z "$WEBHOOK_URL" ]; then
    WEBHOOK_URL="http://homeassistant.local:8123/api/webhook/mordomo_ha_default"
fi

# ── Export env vars for the bridge ──
export MORDOMO_WEBHOOK_URL="$WEBHOOK_URL"
export MORDOMO_BRIDGE_PORT="$BRIDGE_PORT"
export MORDOMO_AUTH_DIR="$AUTH_DIR"
export MORDOMO_LOG_LEVEL="info"

# ── Log startup ──
bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bashio::log.info "  🏠 Mordomo HA - WhatsApp Bridge"
bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bashio::log.info "  Bridge Port: $BRIDGE_PORT"
bashio::log.info "  Webhook:     $WEBHOOK_URL"
bashio::log.info "  Auth Dir:    $AUTH_DIR"
bashio::log.info ""
bashio::log.info "  Open the Mordomo HA dashboard to"
bashio::log.info "  scan the QR code with WhatsApp."
bashio::log.info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Run bridge ──
exec node /app/baileys_bridge.js
