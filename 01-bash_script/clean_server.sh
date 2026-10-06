#!/bin/bash

# Проверяем, что скрипт запущен под root (DevOps-защита)
if [ "$EUID" -ne 0 ]; then
  echo "❌ Ошибка: Этот скрипт нужно запускать с правами sudo или под пользователем root!"
  exit 1
fi

echo "=================================================="
echo "⚠️  ВНИМАНИЕ: ЗАПУЩЕНА ПОЛНАЯ ОЧИСТКА СЕРВЕРА! ⚠️"
echo "=================================================="

reset_firewall() {
    echo "--- 🛡️ Сброс и отключение Firewall (UFW) ---"
    echo "y" | ufw reset
    ufw disable
}

stop_services() {
    echo "--- 🛑 Удаление SSL-сертификатов и остановка сервисов ---"
    
    # Корректно отзываем/удаляем созданный сертификат через утилиту certbot, если она установлена
    if command -v certbot &> /dev/null; then
        sudo certbot delete --cert-name "artemdevops" --non-interactive 2>/dev/null || true
    fi

    systemctl stop apache2 nginx mysql php*-fpm certbot.timer 2>/dev/null || true
}

purge_packages() {
    echo "--- 🧹 Полное удаление (purge) пакетов, Nginx и Certbot ---"
    # Добавлены пакеты certbot и python3-certbot-nginx
    apt purge apache2* nginx* php* mysql-server mysql-client mysql-common certbot python3-certbot-nginx -y
}

remove_directories() {
    echo "--- 📂 Уничтожение конфигурационных файлов, сайтов и логов ---"
    # Добавлены директории /etc/letsencrypt, /var/lib/letsencrypt и логи certbot
    rm -rf /etc/apache2 \
           /etc/nginx \
           /etc/php \
           /etc/mysql \
           /etc/letsencrypt \
           /var/lib/mysql \
           /var/lib/letsencrypt \
           /var/www/* \
           /var/log/apache2 \
           /var/log/nginx \
           /var/log/mysql \
           /var/log/php \
           /var/log/letsencrypt
}

clean_system() {
    echo "--- 🧼 Финальная очистка остаточных пакетов и кэша ---"
    apt autoremove -y
    apt autoclean
}

# --- MAIN EXECUTIONS ---
reset_firewall
stop_services
purge_packages
remove_directories
clean_system

echo "=================================================="
echo "🎉 СЕРВЕР ПОЛНОСТЬЮ ОЧИЩЕН И ГОТОВ К НОВЫМ ТЕСТАМ! 🎉"
echo "=================================================="
