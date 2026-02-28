ARG BUILD_FROM
FROM ${BUILD_FROM}

# Install Node.js, build dependencies, and jq for config parsing
RUN apk add --no-cache nodejs npm git python3 make g++ curl jq bash

# Setup app
WORKDIR /app

# Install dependencies first (cached layer)
COPY package.json ./
RUN npm install --production --no-optional && npm cache clean --force

# Copy bridge code
COPY baileys_bridge.js ./

# Copy run script (init: false means no s6-overlay, just run CMD directly)
COPY run.sh /run.sh
RUN chmod a+x /run.sh

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD wget -q -O /dev/null http://127.0.0.1:${MORDOMO_BRIDGE_PORT:-3781}/health || exit 1

CMD [ "/run.sh" ]
