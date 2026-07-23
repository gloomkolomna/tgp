# MTProto Telegram Proxy

Официальный MTProto-прокси от Telegram в Docker.

## Требования

- Linux-сервер (Debian/Ubuntu)
- Docker и Docker Compose
- Открыт порт: 443 (TCP+UDP)

## Пошаговая установка

### 1. Подготовка сервера

```bash
apt update && apt upgrade -y
apt install -y docker.io docker-compose-v2 git curl openssl
systemctl enable --now docker
```

### 2. Клонировать репозиторий

```bash
git clone https://github.com/gloomkolomna/tgp.git /opt/tg-proxy
cd /opt/tg-proxy
```

### 3. Первый запуск

```bash
bash scripts/deploy.sh
```

Скрипт создаст `.env` и запросит настройку секрета.

### 4. Генерация секрета

```bash
openssl rand -hex 16
```

### 5. Настройка

```bash
nano /opt/tg-proxy/.env
```

Укажите `SECRET=<32 hex символа>`.

### 6. Запуск

```bash
bash scripts/deploy.sh
```

## Подключение в Telegram

- Тип: **MTProto**
- Хост: `5.188.20.78`
- Порт: `443`
- Секрет: из `.env`

## Оптимизация под LTE / мобильные сети

Симптом «по WiFi всё ок, по LTE подключено, но сообщения/медиа не доходят»
вызван двумя свойствами мобильных сетей:

1. **Half-open NAT.** Операторский NAT «забывает» неактивное соединение
   (часто за 60–300 с) без всякого RST/ICMP. Прокси думает, что клиент ещё
   онлайн, и отправляет данные в пустоту — поэтому статус «подключено»,
   а сообщение, отправленное с ПК, на телефон не приходит.
2. **MTU black hole.** Маленькие handshake-пакеты проходят («подключено»),
   а большие пакеты данных упираются в маленький мобильный MTU и тихо
   пропадают.

Лечение применяется скриптами:

```bash
sudo bash scripts/sysctl-apply.sh    # BBR, буферы, MTU-probing, conntrack
sudo bash scripts/firewall-setup.sh  # MSS clamping (фикс MTU black hole)
```

Что именно делается:

| Мера | Эффект |
|------|--------|
| TCP **BBR** вместо cubic | держит скорость на lossy-линке, не «душится» на каждой потере |
| TCP-буферы (до 8 МБ) | поглощают burst-трафик с потерями, без обжорства RAM |
| `tcp_slow_start_after_left=0` | не сбрасывать скорость после idle/потери |
| `tcp_mtu_probing=1` + **MSS clamping** | лечит MTU black hole — данные перестают пропадать |
| `network_mode: host` | убирает Docker NAT/conntrack на входе |
| `ready_timeout_sec=300` | зомби-соединения от отвалившегося LTE переподключаются быстрее |
| `domain_fronting: sni` | неудачные fake-TLS handshake'и (DPI-пробы) форвардятся на реальный домен |

**Важно про keepalive.** Приложение не выставляет `SO_KEEPALIVE` на клиентские
сокеты, поэтому чистый TCP keepalive здесь не работает. Поэтому упор сделан на
MSS clamping + BBR + host-networking + укороченный `ready_timeout_sec` — это
именно то, что чинит симптом на LTE.

## Сервер с малыми ресурсами (1 vCPU / 1 GB RAM / ~5 пользователей)

Конфигурация специально урезана под слабый сервер — все цифры подобраны так,
чтобы LTE-выигрыши остались, а риска OOM не было:

- **Буферы ядра**: до 8 МБ на сокет (не 64 МБ), `netdev_max_backlog=5000`.
- **conntrack_max = 10000** (не сотни тысяч) — на 5 пользователей более чем
  достаточно, и таблица не съест RAM при сканировании портов.
- **Контейнер: `mem_limit: 384m`** — хард-кап, чтобы прокси никогда не уронил
  хост; при превышении Docker его перезапустит (`restart: unless-stopped`).
- **`max_connections: 500`** — отсекает скан-всплески (5 реальных юзеров
  уложатся в пару десятков соединений).
- **`tcp_max_orphans=1024`, `vm.swappiness=10`** — не раздувать память под
  брошенные сокеты, предпочитать RAM свопу.

**Обязательно создайте swap**, иначе при пиковом потреблении Erlang+Docker
хост может упасть в OOM-kill. `deploy.sh` предупредит, если swap < 256 MB:

```bash
fallocate -l 1G /swapfile && chmod 600 /swapfile
mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

Проверить состояние памяти и контейнера в любой момент:

```bash
bash scripts/diagnose.sh    # покажет RAM/Swap, RSS контейнера, BBR, retrans
free -h
docker stats tg-proxy
```

## Команды

Запускать из директории проекта (`/opt/tg-proxy`):

```bash
docker compose ps              # Статус
docker compose logs -f         # Логи
docker compose restart         # Перезапуск
bash scripts/deploy.sh         # Полный деплой (git pull + sysctl + firewall + up)
bash scripts/diagnose.sh       # Диагностика: BBR, retrans, conntrack, MSS, MTU
```

`deploy.sh` запускает sysctl/firewall только под root — если запускаете без
sudo, apply-скрипты пропускаются с предупреждением (прокси всё равно поднимется).

> Скрипты резолвят свои пути через `dirname "$0"` — их можно вызывать из любого
> каталога (`sudo bash /opt/tg-proxy/scripts/sysctl-apply.sh` тоже сработает).

`deploy.sh` запускает sysctl/firewall только под root — если запускаете без
sudo, apply-скрипты пропускаются с предупреждением (прокси всё равно поднимется).

## Диагностика

```bash
bash scripts/diagnose.sh
```

Скрипт показывает: активный congestion control (должен быть `bbr`), состояние
`tcp_mtu_probing`, наличие правил MSS clamping, счётчики conntrack, и
per-соединения retransmits/rtt через `ss -tin`. Подсказывает, что именно
подкрутить, если что-то не так.

## Файлы

```
├── docker-compose.yml          # host-network + tune-опции в command
├── .env / .env.example         # SECRET и настройки
├── config/
│   └── 99-tg-proxy.conf        # sysctl-тюнинг ядра под LTE
├── scripts/
│   ├── deploy.sh               # Деплой (sysctl + firewall + up + верификация)
│   ├── sysctl-apply.sh         # Применение sysctl (BBR, буферы, conntrack)
│   ├── firewall-setup.sh       # MSS clamping (nftables/iptables)
│   ├── diagnose.sh             # Диагностика LTE-проблем
│   ├── generate-secret.sh      # Генерация секрета (Linux)
│   └── generate-secret.ps1     # Генерация секрета (Windows)
└── README.md
```
