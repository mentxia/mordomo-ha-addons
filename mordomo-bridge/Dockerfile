ARG BUILD_FROM
FROM ${BUILD_FROM}

# Install Node.js and build dependencies
RUN apk add --no-cache nodejs npm git python3 make g++ curl

# Setup app
WORKDIR /app

# Install dependencies first (cached layer)
COPY package.json ./
RUN npm install --production --no-optional && npm cache clean --force

# Copy bridge code
COPY baileys_bridge.js ./

# Install run.sh as an s6-overlay service (required for HA base images)
COPY run.sh /etc/services.d/mordomo-bridge/run
RUN chmod a+x /etc/services.d/mordomo-bridge/run

# Add finish script for graceful shutdown
RUN printf '#!/usr/bin/execlineb -S1\n/bin/true\n' > /etc/services.d/mordomo-bridge/finish \
    && chmod a+x /etc/services.d/mordomo-bridge/finish

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD wget -q -O /dev/null http://127.0.0.1:${MORDOMO_BRIDGE_PORT:-3781}/health || exit 1
