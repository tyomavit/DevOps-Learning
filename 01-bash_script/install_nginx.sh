#!/bin/bash
set -e # -е (errexit) Скрипт автоматически завершит работу, если любая команда вернет ошибку

# --- FUNCTIONS ---

update_system() {
    echo "--- Обновление списка пакетов ---"
    sudo apt update

    echo "--- Обновление установленных пакетов ---"
    sudo apt upgrade -y
}

setup_swap() {
    # Эта функция просто чтобы оптимизировать слабый VPS
    echo "--- Проверка и настройка SWAP-файла ---"
    if swapon --show | grep -q "swapfile"; then
        echo "✅ SWAP уже настроен и активен, пропускаем этот шаг."
    else
        echo "🔧 Создание SWAP-файла на 2 ГБ для защиты от Out-of-Memory..."
        sudo fallocate -l 2G /swapfile
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        if ! grep -q "/swapfile" /etc/fstab; then
            echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
        fi
        echo "✅ SWAP успешно создан и подключен к автозапуску."
    fi
}

install_nginx() {
    echo "--- Установка веб-сервера Nginx ---"
    sudo apt install nginx -y
}

install_certbot() {
    echo "--- Установка Certbot и Nginx plugin ---"
    sudo apt install certbot python3-certbot-nginx -y
}

config_nginx() {
    echo "--- Настройка Nginx-конфига artemdevops ---"
sudo tee /etc/nginx/sites-available/artemdevops > /dev/null <<'EOF'
    server {
        listen 80;

        server_name artemdevops.ru www.artemdevops.ru;

        # Все запросы Nginx пересылает в Apache на порт 8080
        location / {
            proxy_pass http://159.194.242.166:8080;
            
            # Apache и WordPress увидят исходный домен, IP клиента и схему запроса
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo ln -sfn \
    /etc/nginx/sites-available/artemdevops \
    /etc/nginx/sites-enabled/artemdevops
    
    nginx -t
    sudo systemctl reload nginx

    echo "✅ Nginx-конфиг создан и активирован."
}

install_ufw() {
    echo "--- Настройка Firewall ---"
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 22/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw logging on
    sudo ufw --force enable

    echo "--- Текущие правила UFW ---"
    sudo ufw status verbose
}

check_http() {
    echo "--- Проверка HTTP до настройки SSL ---"

    # --resolve: curl подключается к IP VPS 1,
    # но отправляет правильный Host для Nginx.
    curl -I \
        --resolve artemdevops.ru:80:159.194.254.117 \
        http://artemdevops.ru/

    curl -I \
        --resolve www.artemdevops.ru:80:159.194.254.117 \
        http://www.artemdevops.ru/
}


config_certbot() {
    echo "--- Получение и настройка SSL-сертификата ---"

    # Если сертификат уже существует, повторно не выпускаем его.
    if [ -d "/etc/letsencrypt/live/artemdevops" ]; then
        echo "⚠️ Сертификат artemdevops уже существует, выпуск пропускается."
        return
    fi

    # Certbot:
    # --nginx              — использует и настраивает Nginx;
    # --non-interactive    — не задаёт вопросов в терминале;
    # --agree-tos          — принимает правила Let's Encrypt;
    # --email              — email для уведомлений;
    # --no-eff-email       — не подписывает на письма EFF;
    # --redirect           — настраивает HTTP -> HTTPS;
    # -d                   — доменные имена сертификата.
    sudo certbot --nginx \
        --staging \
        --non-interactive \
        --agree-tos \
        --email "tyomavit@gmail.com" \
        --no-eff-email \
        --cert-name "artemdevops" \
        --redirect \
        -d "artemdevops.ru" \
        -d "www.artemdevops.ru"

    echo "✅ Сертификат получен."
}


check_ssl() {
    echo "--- Проверка SSL, Nginx и продления сертификата ---"

    sudo nginx -t
    sudo systemctl reload nginx

    echo "--- Данные о сертификате ---"
    sudo certbot certificates

    echo "--- Проверка автопродления сертификата ---"
    sudo certbot renew --dry-run

    echo "--- Проверка HTTP -> HTTPS redirect ---"
    curl -I http://artemdevops.ru/
    curl -I http://www.artemdevops.ru/

    echo "--- Проверка HTTPS ---"
    curl -I https://artemdevops.ru/
    curl -I https://www.artemdevops.ru/
}


# --- MAIN EXECUTIONS ---


update_system
setup_swap
install_nginx
install_certbot
config_nginx
install_ufw
check_http
config_certbot
check_ssl