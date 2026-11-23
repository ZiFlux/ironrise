#!/usr/bin/env bash
# Разовая подготовка VPS (Ubuntu 22.04/24.04). Запуск на сервере от root:
#   bash /opt/ironrise/deploy/setup-server.sh
set -euo pipefail

echo "== Обновления и Docker"
apt-get update -y
apt-get install -y ca-certificates curl ufw unattended-upgrades
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi

echo "== Подкачка 2 ГБ (на 1 ГБ памяти база и сервер живут с запасом)"
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "== Файрвол: SSH, HTTP, HTTPS"
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "== SSH только по ключу, fail2ban от подбора паролей"
# 00- читается раньше 50-cloud-init.conf (там PasswordAuthentication yes): первое значение выигрывает.
cat > /etc/ssh/sshd_config.d/00-ironrise.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
MaxStartups 30:50:120
LoginGraceTime 20
MaxAuthTries 3
EOF
if [ -s /root/.ssh/authorized_keys ] && sshd -t; then
  systemctl reload ssh || systemctl reload sshd
fi
apt-get install -y fail2ban
cat > /etc/fail2ban/jail.d/ironrise.conf <<'EOF'
[sshd]
enabled = true
backend = systemd
maxretry = 4
findtime = 10m
bantime = 24h
bantime.increment = true
EOF
systemctl enable --now fail2ban
systemctl restart fail2ban

echo "== Папки и резервные копии базы раз в сутки (хранится 7 последних)"
mkdir -p /opt/ironrise/secrets /opt/ironrise/backups
chmod +x /opt/ironrise/deploy/backup.sh
cat > /etc/cron.d/ironrise-backup <<'CRON'
30 3 * * * root /opt/ironrise/deploy/backup.sh >> /var/log/ironrise-backup.log 2>&1
CRON

echo "== Готово. Дальше: заполните /opt/ironrise/.env.prod (образец .env.prod.example)"
