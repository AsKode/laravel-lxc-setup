# Laravel LXC Container Setup Script
Automated setup script for Laravel development inside Ubuntu 22.04 LXC containers, installing Nginx, PHP 8.4, MariaDB 10, Node.js 22, Composer, and Laravel 12 Installer.

## Features

### **System Setup**
- System package updates and essential development tools
- User creation with sudo privileges
- SSH server configuration with security hardening
- Fail2ban protection for SSH and Nginx
- UFW firewall configuration
- Automatic security updates

### **Development Environment**
- **PHP 8.4** with all required Laravel extensions
- **Composer** package manager
- **Laravel Installer** (global installation)
- **Node.js 22 LTS** via fnm (Fast Node Manager)
- **MariaDB** with optimized configuration
- **Nginx** web server with PHP-FPM integration
- **phpMyAdmin** for database management

### **Security Features**
- Root login disabled via SSH
- Fail2ban intrusion prevention
- Firewall configuration (ports 22, 80, 443)
- Automatic security updates
- Secure database installation

## Installation

1. **Download / copy the script**
3. **Make the script executable:**
   ```bash
   chmod +x setup.sh
   ```
4. **Run the script as root:**
   ```bash
   sudo ./setup.sh
   ```

## Interactive Setup Process

The script will prompt you for the following information:

### User Configuration
- **Username**: Create a new user account
- **Password**: Set password for the new user
- **SSH Public Key**: Optional SSH key for secure access

### Network Configuration
- **Container IP**: IP address of your LXC container

### Database Configuration
- **Database Name**: Name for your Laravel database
- **Database Username**: Database user for Laravel
- **Database Password**: Password for the database user
- **MySQL Root Password**: Set during MariaDB secure installation

### Laravel Project
- **Project Name**: Name for your Laravel project

## What Gets Installed

### System Packages
- git, curl, wget, unzip, vim, nano
- software-properties-common, apt-transport-https
- openssh-server, fail2ban, ufw
- unattended-upgrades

### Development Stack
- **PHP 8.4** with extensions:
  - php8.4-fpm, php8.4-mysql, php8.4-xml
  - php8.4-mbstring, php8.4-curl, php8.4-zip
  - php8.4-bcmath, php8.4-tokenizer, php8.4-gd
  - php8.4-intl, php8.4-cli, php8.4-common

- **Composer** (latest version)
- **Laravel Installer** (global)
- **Node.js 22 LTS** via fnm
- **MariaDB** (latest from Ubuntu repos)
- **Nginx** with PHP-FPM configuration
- **phpMyAdmin**

## Post-Installation

### Access Your Application
- **Laravel App**: `http://[CONTAINER_IP]` or `http://[PROJECT_NAME]`
- **phpMyAdmin**: `http://[CONTAINER_IP]/phpmyadmin`

### File Locations
- **Laravel Project**: `/var/www/[PROJECT_NAME]/`
- **Nginx Configuration**: `/etc/nginx/sites-available/[PROJECT_NAME]`
- **PHP-FPM Configuration**: `/etc/php/8.4/fpm/`
- **MariaDB Configuration**: `/etc/mysql/mariadb.conf.d/99-laravel.cnf`

### User Environment
- **Composer bin path**: Added to user's `.bashrc`
- **fnm (Node.js manager)**: Configured for the created user
- **Laravel installer**: Available globally for the user

## Security Configuration

### SSH Security
- Root login disabled
- Password authentication enabled for user accounts
- SSH key authentication configured (if provided)

### Firewall Rules
- **Port 22**: SSH access
- **Port 80**: HTTP traffic
- **Port 443**: HTTPS traffic (ready for SSL)
- Default deny incoming, allow outgoing

### Fail2ban Protection
- SSH brute force protection (3 attempts)
- Nginx HTTP auth protection
- Nginx rate limiting protection
- Bot search protection

### Log Locations
- **Nginx**: `/var/log/nginx/`
- **PHP-FPM**: `/var/log/php8.4-fpm.log`
- **MariaDB**: `/var/log/mysql/`
- **Fail2ban**: `/var/log/fail2ban.log`

### Database Optimization
The script includes basic MariaDB optimization in `/etc/mysql/mariadb.conf.d/99-laravel.cnf`. Adjust based on your container's resources.

**Note**: This script is designed for development environments. For production use, additional security hardening and performance optimization may be required.
