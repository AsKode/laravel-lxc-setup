#!/bin/bash

# Laravel LXC Container Setup Script for Ubuntu 22.04
# This script sets up a complete Laravel development environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root"
    exit 1
fi

print_status "Starting Laravel LXC Container Setup..."

# Update system
print_status "Updating system packages..."
apt update && apt upgrade -y

# Install essential tools
print_status "Installing essential development tools..."
apt install -y git gh htop curl wget unzip vim nano software-properties-common apt-transport-https ca-certificates gnupg lsb-release

# Setup machine
print_status "=== MACHINE SETUP ==="

# Add user
echo ""
read -p "Enter username for new user: " USERNAME
read -s -p "Enter password for $USERNAME: " PASSWORD
echo ""

useradd -m -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
usermod -aG sudo "$USERNAME"
print_status "User $USERNAME created and added to sudoers"

# Install OpenSSH
print_status "Installing OpenSSH server..."
apt install -y openssh-server
systemctl enable ssh
systemctl start ssh

# Configure SSH to disable root login
print_status "Configuring SSH security..."
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh

# Add SSH key
echo ""
print_status "Please paste your SSH public key (press Enter on empty line to finish):"
SSH_KEY=""
while IFS= read -r line; do
    [ -z "$line" ] && break
    SSH_KEY="$SSH_KEY$line"
done

if [ -n "$SSH_KEY" ]; then
    mkdir -p /home/$USERNAME/.ssh
    echo "$SSH_KEY" > /home/$USERNAME/.ssh/authorized_keys
    chmod 700 /home/$USERNAME/.ssh
    chmod 600 /home/$USERNAME/.ssh/authorized_keys
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
    print_status "SSH key added for user $USERNAME"
fi

# Install and configure fail2ban
print_status "Installing and configuring fail2ban..."
apt install -y fail2ban

# Configure fail2ban for SSH and Nginx
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10

[nginx-botsearch]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 2
EOF

systemctl enable fail2ban
systemctl start fail2ban
print_status "fail2ban configured for SSH and Nginx"

# Setup networking
print_status "=== NETWORK SETUP ==="

echo ""
read -p "Enter container IP address (e.g., 192.168.1.100, it'll be used in nginx config): " CONTAINER_IP


# Set up firewall
print_status "Configuring UFW firewall..."
apt install -y ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
print_status "Firewall configured"

# Set up automatic security updates
print_status "Configuring automatic security updates..."
apt install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
print_status "Automatic security updates configured"

# Setup development environment
print_status "=== DEVELOPMENT ENVIRONMENT SETUP ==="

# Install PHP 8.4
print_status "Installing PHP 8.4..."
add-apt-repository -y ppa:ondrej/php
apt update
apt install -y php8.4 php8.4-fpm php8.4-mysql php8.4-xml php8.4-mbstring php8.4-curl php8.4-zip php8.4-bcmath php8.4-tokenizer php8.4-gd php8.4-intl php8.4-cli php8.4-common

# Configure PHP-FPM
systemctl enable php8.4-fpm
systemctl start php8.4-fpm
print_status "PHP 8.4 installed and configured"

# Install Composer
print_status "Installing Composer..."
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer
print_status "Composer installed"
# Add composer vendor bin to user .bashrc
print_status "Adding Composer bin path to .bashrc..."
echo 'export PATH="$PATH:$HOME/.config/composer/vendor/bin:$HOME/.composer/vendor/bin"' >> /home/$USERNAME/.bashrc
chown $USERNAME:$USERNAME /home/$USERNAME/.bashrc

# Install Laravel installer as the new user
print_status "Installing Laravel installer globally for $USERNAME..."
sudo -u $USERNAME composer global require laravel/installer

# Fetch the PATH as seen by the new user with bashrc sourced
USER_PATH=$(sudo -u $USERNAME bash -i -c 'echo $PATH')
print_status "Detected PATH for $USERNAME: $USER_PATH"

# Install fnm for Node.js version management
print_status "Installing fnm for Node.js version management..."
sudo -u $USERNAME bash -c 'curl -fsSL https://fnm.vercel.app/install | bash'

# Add fnm env command to .bashrc so it works in interactive shells
echo 'eval "$(fnm env --use-on-cd)"' >> /home/$USERNAME/.bashrc
chown $USERNAME:$USERNAME /home/$USERNAME/.bashrc

# Refresh PATH with interactive shell
USER_PATH=$(sudo -u $USERNAME bash -i -c 'echo $PATH')
print_status "Updated PATH after fnm install: $USER_PATH"

# Install Node 22 LTS via fnm in user's environment
print_status "Installing Node.js 22 LTS using fnm..."
sudo -u $USERNAME bash -i -c 'fnm install 22 && fnm use 22 && fnm default 22'

# Verify Node and npm
NODE_VERSION=$(sudo -u $USERNAME bash -i -c 'node --version')
NPM_VERSION=$(sudo -u $USERNAME bash -i -c 'npm --version')
print_status "Installed Node.js version: $NODE_VERSION"
print_status "Installed npm version: $NPM_VERSION"

# Install MariaDB
print_status "Installing MariaDB..."
apt install -y mariadb-server mariadb-client

# Configure MariaDB for optimal performance
cat > /etc/mysql/mariadb.conf.d/99-laravel.cnf << 'EOF'
[mysqld]
# Strict mode
sql_mode = STRICT_ALL_TABLES

# Slow queries
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 1

# Character set
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

# Security
symbolic-links = 0

EOF

systemctl restart mariadb
systemctl enable mariadb
print_status "MariaDB installed and configured"

# Secure MariaDB installation
print_status "Securing MariaDB installation..."
mysql_secure_installation

# Create database and user for Laravel projects
echo ""
print_status "Database setup for Laravel project..."
read -p "Enter database name: " DB_NAME
read -p "Enter database username: " DB_USER
read -s -p "Enter database password: " DB_PASSWORD
echo ""
read -s -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
echo ""

mysql -u root -p$MYSQL_ROOT_PASSWORD << EOF
CREATE DATABASE ${DB_NAME};
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

print_status "Database '${DB_NAME}' and user '${DB_USER}' created"

# Install Nginx
print_status "Installing Nginx..."
apt install -y nginx
systemctl enable nginx
systemctl start nginx

# Configure Nginx with PHP-FPM 8.4
print_status "Configuring Nginx with PHP-FPM 8.4..."
rm -f /etc/nginx/sites-enabled/default

# Install phpMyAdmin
print_status "Installing phpMyAdmin..."
sudo apt install phpmyadmin
ln -s /usr/share/phpmyadmin /var/www/html/phpmyadmin

# Prep /var/www
print_status "Preparing /var/www for Laravel project..."
mkdir -p /var/www
chown -R $USERNAME:www-data /var/www

# Create Laravel project
print_status "Creating Laravel project..."
echo ""
read -p "Enter Laravel project name: " PROJECT_NAME

# Use the user's interactive PATH to call laravel new

sudo -u $USERNAME bash -i -c "cd /var/www && laravel new $PROJECT_NAME"
print_status "Laravel project '$PROJECT_NAME' created in /var/www/$PROJECT_NAME"

# Set proper permissions for Laravel
chown -R $USERNAME:www-data /var/www
chmod -R 755 /var/www
chmod -R 775 /var/www/$PROJECT_NAME/storage
chmod -R 775 /var/www/$PROJECT_NAME/bootstrap/cache

# Configure Nginx for the Laravel project
print_status "Configuring Nginx for Laravel project..."
cat > /etc/nginx/sites-available/$PROJECT_NAME << EOF
server {
    listen 80;
    server_name $PROJECT_NAME $CONTAINER_IP;
    root /var/www/$PROJECT_NAME/public;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }

    location /phpmyadmin {
        alias /var/www/html/phpmyadmin;
        index index.php index.html index.htm;

        location ~ ^/phpmyadmin/(.+\.php)$ {
            alias /var/www/html/phpmyadmin/\$1;
            fastcgi_pass unix:/var/run/php/php8.4-fpm.sock;
            fastcgi_param SCRIPT_FILENAME \$request_filename;
            include fastcgi_params;
        }

        location ~* ^/phpmyadmin/(.+\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot))$ {
            alias /var/www/html/phpmyadmin/\$1;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/
systemctl restart nginx
print_status "Nginx configured for Laravel project '$PROJECT_NAME'"

# Configure Laravel environment
print_status "Configuring Laravel environment..."
cd /var/www/$PROJECT_NAME
sudo -u $USERNAME cp .env.example .env
sudo -u $USERNAME sed -i "s/DB_DATABASE=laravel/DB_DATABASE=$DB_NAME/" .env
sudo -u $USERNAME sed -i "s/DB_USERNAME=root/DB_USERNAME=$DB_USER/" .env
sudo -u $USERNAME sed -i "s/DB_PASSWORD=/DB_PASSWORD=$DB_PASSWORD/" .env
sudo -u $USERNAME bash -i -c 'php artisan key:generate'
print_status "Laravel environment configured"

print_status "=== SETUP COMPLETE ==="
print_status "Laravel development environment is ready!"
