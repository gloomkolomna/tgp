#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/opt/tg-proxy"
IPV4="5.188.20.78"
CERT_DIR="$PROJECT_DIR/config/certs"
CERT_FILE="$CERT_DIR/server.crt"
KEY_FILE="$CERT_DIR/server.key"

if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
  echo "Сертификат уже существует"
  exit 0
fi

echo "Генерация самоподписанного TLS-сертификата (срок 10 лет)..."

if docker compose ps --status running 2>/dev/null | grep -q "tg-tls"; then
  echo "Останавливаю tg-tls..."
  docker compose stop tg-tls
fi

[ -d "$CERT_FILE" ] && rm -rf "$CERT_FILE"
[ -d "$KEY_FILE" ] && rm -rf "$KEY_FILE"
mkdir -p "$CERT_DIR"

openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout "$KEY_FILE" \
  -out "$CERT_FILE" \
  -subj "/CN=$IPV4" \
  -addext "subjectAltName=IP:$IPV4" 2>/dev/null

if [ ! -s "$CERT_FILE" ]; then
  echo "fallback без -addext..."
  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -subj "/CN=$IPV4"
fi

chmod 600 "$KEY_FILE"
echo "Сертификат создан"
