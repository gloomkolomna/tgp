#!/usr/bin/env bash
set -euo pipefail

SECRET=$(openssl rand -hex 16)

echo "Ваш секрет MTProto-прокси (сохраните его в .env, SECRET):"
echo ""
echo "$SECRET"
echo ""
echo "Секрет нужно скопировать в SECRET= в файле .env"
echo ""
echo "Подключение: https://t.me/proxy?server=<IP_СЕРВЕРА>&port=443&secret=$SECRET"
echo "Подключение с фейковым TLS: https://t.me/proxy?server=<IP_СЕРВЕРА>&port=443&secret=ee$SECRET"
