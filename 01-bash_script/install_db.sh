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
    echo "--- 🧠 Проверка и настройка SWAP-файла ---"
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

install_mysql() {
    echo "--- Установка MySQL ---"
    sudo apt install mysql-server -y

    echo "--- Создание базы и пользователей ---"
    sudo mysql <<EOF
DROP USER IF EXISTS ''@'localhost';
DROP USER IF EXISTS ''@'localhost.localdomain';
DROP DATABASE IF EXISTS test;

CREATE DATABASE IF NOT EXISTS bash_db;

CREATE USER IF NOT EXISTS 'bash_user'@'localhost' IDENTIFIED BY 'BashPwd2026';
GRANT ALL PRIVILEGES ON bash_db.* TO 'bash_user'@'localhost';

CREATE USER IF NOT EXISTS 'dediuser'@'159.194.242.166' IDENTIFIED BY 'BashPwd2026';
GRANT ALL PRIVILEGES ON bash_db.* TO 'dediuser'@'159.194.242.166';

FLUSH PRIVILEGES;
EOF
}



config_mysql() {
    sudo sed -i 's/^bind-address.*/bind-address = 85.117.235.31/g' /etc/mysql/mysql.conf.d/mysqld.cnf
    sudo sed -i 's/^mysqlx-bind-address.*/mysqlx-bind-address = 85.117.235.31/g' /etc/mysql/mysql.conf.d/mysqld.cnf
    sudo systemctl restart mysql
}

install_ufw() {
    echo "--- Настройка Firewall ---"
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 22/tcp
    sudo ufw allow from 159.194.242.166 to any port 3306 proto tcp
    sudo ufw logging on
    sudo ufw --force enable

    echo "--- Текущие правила UFW ---"
    sudo ufw status verbose
}

check_mysql() {
    echo "--- Проверка работы ---"
    
    sudo systemctl is-active --quiet mysql
    echo "✅ MySQL запущен."
    
    echo "--- Прослушивание порта 3306 ---"
    sudo ss -tulnp | grep :3306

    echo "--- Локальная проверка базы ---"
    mysql -u bash_user -p'BashPwd2026' -D bash_db -e "SELECT 'Подключение к bash_db успешно' AS result;"
}

# --- MAIN EXECUTIONS ---

update_system
setup_swap
install_mysql
config_mysql
install_ufw
check_mysql