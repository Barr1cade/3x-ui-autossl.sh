#!/usr/bin/env bash

# Define the database path and the SQL statements template (to be modified based on last ID)
DB_PATH="/etc/x-ui/x-ui.db"
SQL_INSERT_TEMPLATE="
INSERT INTO settings VALUES (%d, 'webCertFile', '/etc/ssl/certs/3x-ui-public.key');
INSERT INTO settings VALUES (%d, 'webKeyFile', '/etc/ssl/private/3x-ui-private.key');
"

# Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or using sudo."
    exit 1
fi

# Function to check if sqlite3 is installed
check_sqlite3() {
    if ! command -v sqlite3 &> /dev/null; then
        echo "sqlite3 could not be found, installing..."
        install_sqlite3
    else
        echo "sqlite3 is already installed."
    fi
}

# Function to install sqlite3
install_sqlite3() {
    if [ -x "$(command -v apt-get)" ]; then
        sudo apt-get update -y && sudo apt-get install -y sqlite3
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install -y sqlite
    elif [ -x "$(command -v dnf)" ]; then
        sudo dnf install -y sqlite
    elif [ -x "$(command -v pacman)" ]; then
        sudo pacman -S --noconfirm sqlite
    else
        echo "Package manager not found. Please install sqlite3 manually."
        exit 1
    fi
}

# Function to check if openssl is installed
check_openssl() {
    if ! command -v openssl &> /dev/null; then
        echo "openssl could not be found, installing..."
        install_openssl
    else
        echo "openssl is already installed."
    fi
}

# Function to install openssl
install_openssl() {
    if [ -x "$(command -v apt-get)" ]; then
        sudo apt-get update -y && sudo apt-get install -y openssl
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install -y openssl
    elif [ -x "$(command -v dnf)" ]; then
        sudo dnf install -y openssl
    elif [ -x "$(command -v pacman)" ]; then
        sudo pacman -S --noconfirm openssl
    else
        echo "Package manager not found. Please install openssl manually."
        exit 1
    fi
}

# Function to check if SSL entries are already present in the database
check_if_ssl_present() {
    local ssl_detected=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM settings WHERE key = 'webCertFile';")
    if [ "$ssl_detected" -gt 0 ]; then
        echo "SSL cert detected in settings, exiting."
        exit 0
    fi
}

# Function to get the last ID in the settings table
get_last_id() {
    LAST_ID=$(sqlite3 "$DB_PATH" "SELECT IFNULL(MAX(id), 0) FROM settings;")
    if ! [[ "$LAST_ID" =~ ^[0-9]+$ ]]; then
        echo "Error: Unable to retrieve last ID from database."
        exit 1
    fi
    echo "The last ID in the settings table is $LAST_ID"
}

# Function to execute SQL inserts
execute_sql_inserts() {
    local next_id=$((LAST_ID + 1))
    local second_id=$((next_id + 1))
    if printf "$SQL_INSERT_TEMPLATE" "$next_id" "$second_id" | sqlite3 "$DB_PATH"; then
        echo "SQL inserts executed with IDs $next_id and $second_id."
    else
        echo "Error: Failed to execute SQL inserts."
        exit 1
    fi
}

# Function to generate SSL certificates
gen_ssl_cert() {
    mkdir -p /etc/ssl/private /etc/ssl/certs
    chmod 700 /etc/ssl/private
    if openssl req -x509 -newkey rsa:4096 -nodes -sha256 \
        -keyout /etc/ssl/private/3x-ui-private.key \
        -out /etc/ssl/certs/3x-ui-public.key \
        -days 3650 -subj "/CN=APP"; then
        echo "SSL certificates generated successfully."
    else
        echo "Error: Failed to generate SSL certificates."
        exit 1
    fi
}

# Main script execution
check_sqlite3
check_if_ssl_present
check_openssl
gen_ssl_cert
get_last_id
execute_sql_inserts
