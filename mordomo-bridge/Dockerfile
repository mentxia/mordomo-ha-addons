ARG BUILD_FROM
FROM ${BUILD_FROM}

# Install Node.js
RUN apk add --no-cache nodejs npm

# Setup app
WORKDIR /app

# Install dependencies first (cached layer)
COPY package.json ./
RUN npm install --production --no-optional && npm cache clean --force

# Copy bridge code
COPY baileys_bridge.js ./
COPY run.sh /run.sh
RUN chmod +x /run.sh

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD wget -q -O /dev/null http://127.0.0.1:${MORDOMO_BRIDGE_PORT:-3781}/health || exit 1

CMD ["/run.sh"]
