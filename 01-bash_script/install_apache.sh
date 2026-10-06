#!/bin/bash
set -e # -е (errexit) Скрипт автоматически завершит работу, если любая команда вернет ошибку

# --- FUNCTIONS ---

update_system() {
    echo "--- Обновление пакетов ---"
    sudo apt update
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

install_apache() {
    echo "--- Установка веб-сервера и клиента MySQL ---"
    sudo apt install apache2 -y mysql-client-core -y #чтобы проверять соединение с БД
}

install_php() {
    echo "--- Установка PHP ---"
    sudo apt install php libapache2-mod-php php-mysql -y
    sudo apt install php-curl php-gd php-mbstring php-xml php-zip php-intl php-bcmath -y
    php -v
}

install_wp() {
    echo "--- Установка WordPress ---"
    sudo mkdir -p /var/www
    cd /var/www
    wget -O latest.tar.gz https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    sudo rm latest.tar.gz
    cd
    sudo mv /var/www/wordpress /var/www/artemdevops
    sudo chown -R www-data:www-data /var/www/artemdevops
}

config_wp() {
    echo "--- Настройка wp-config.php ---"
    sudo tee /var/www/artemdevops/wp-config.php > /dev/null <<'EOF' 
<?php

// PHP-код для настройки Nginx Reverse Proxe (блок должен быть в начале)

if (
    isset($_SERVER['HTTP_X_FORWARDED_PROTO']) &&
    strpos($_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false
) {
    $_SERVER['HTTPS'] = 'on';
    $_SERVER['SERVER_PORT'] = '443';
}

// Настройка базы данных
define( 'DB_NAME', 'bash_db' );
define( 'DB_USER', 'dediuser' );
define( 'DB_PASSWORD', 'BashPwd2026' );
define( 'DB_HOST', '85.117.235.31' ); // IP VPS MySQL
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );

// Принудительно HTTPS для админки и авторизации
define('FORCE_SSL_ADMIN', true);

// Фиксируем домен (чтобы настройки не переопределялись)
define('WP_HOME', 'https://artemdevops.ru');
define('WP_SITEURL', 'https://artemdevops.ru');

// Уникальные ключи и соли (Salt) шифрования


// Системные настройки и запуск
$table_prefix = 'wp_';
define( 'WP_DEBUG', false );

if ( ! defined( 'ABSPATH' ) ) {
define( 'ABSPATH', __DIR__ . '/' );
}

// Инициализация настроек WordPress и запуск ядра
require_once ABSPATH . 'wp-settings.php';
EOF
}

config_apache() {

    sudo tee /etc/apache2/ports.conf > /dev/null <<'EOF'
    Listen 159.194.242.166:8080
EOF

    sudo tee /etc/apache2/sites-available/artemdevops.conf > /dev/null <<'EOF'
    <VirtualHost *:8080>
        ServerName artemdevops.ru
        ServerAlias www.artemdevops.ru
        
        DocumentRoot /var/www/artemdevops

        <Directory /var/www/artemdevops>
            Options Indexes FollowSymLinks
            AllowOverride All
            Require all granted
        </Directory>

        SetEnvIf X-Forwarded-Proto https HTTPS=on

        ErrorLog ${APACHE_LOG_DIR}/artemdevops-error.log
        CustomLog ${APACHE_LOG_DIR}/artemdevops-access.log combined
    </VirtualHost>
EOF
    sudo a2enmod rewrite
    sudo a2dissite 000-default.conf
    sudo a2ensite artemdevops.conf
    sudo apache2ctl configtest
    sudo apache2ctl -S

    echo "✅ Apache-конфиг создан и активирован."
}

install_ufw() {
    echo "--- Настройка Firewall ---"
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 22/tcp
    sudo ufw allow from 159.194.254.117 to any port 8080 proto tcp
    sudo ufw logging on
    sudo ufw --force enable

    echo "--- Текущие правила UFW ---"
    sudo ufw status verbose
}

restart_apache() {
    echo "--- Перезагрузка Apache2 ---"
    sudo systemctl restart apache2
}

check_services() {
    echo "Apache:"
    sudo systemctl is-active apache2

    echo "Порты Apache:"
    sudo ss -tulnp | grep ':8080'

    echo "Проверка ответа Apache локально:"
    curl -sS -I -H "Host: artemdevops.ru" http://159.194.242.166:8080/

    echo "Проверка подключения к MySQL:"
    mysql -h 85.117.235.31 -u dediuser -p'BashPwd2026' -e "SELECT 1;" bash_db

    echo "✅ Базовые проверки завершены."
}

# --- MAIN EXECUTIONS ---

update_system
setup_swap
install_apache
install_php
install_wp
config_wp
config_apache
install_ufw
restart_apache
check_services