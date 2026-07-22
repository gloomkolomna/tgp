FROM telegrammessenger/proxy:latest

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    openssl \
    && rm -rf /var/lib/apt/lists/*

COPY docker-compose.yml /build/
