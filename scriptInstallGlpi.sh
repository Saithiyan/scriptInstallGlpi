#!/bin/bash

# Install LAMP, dependances :
apt-get update && sudo apt-get upgrade -y
apt-get install apache2 php mariadb-server -y
apt-get install php-xml php-common php-json php-mysql php-mbstring php-curl php-gd php-intl php-zip php-bz2 php-imap php-apcu -y

# BDD insallation et configuration :
mysql_secure_installation
mysql -h localhost -u root -p -e "
CREATE DATABASE db23_glpi;
GRANT ALL PRIVILEGES ON db23_glpi.* TO 'glpi_adm'@'localhost' IDENTIFIED BY 'poseidon';
FLUSH PRIVILEGES;"

# Telcharger et installation GLPI 
cd /tmp
wget https://github.com/glpi-project/glpi/releases/download/10.0.16/glpi-10.0.16.tgz
tar -xzvf glpi-10.0.16.tgz -C /var/www/
chown www-data:www-data /var/www/glpi/ -R

mkdir /etc/glpi
chown -R www-data:www-data /etc/glpi/

mv /var/www/glpi/config /etc/glpi

mkdir /var/lib/glpi
chown -R www-data:www-data /var/lib/glpi/

mv /var/www/glpi/files /var/lib/glpi

mkdir /var/log/glpi
chown -R www-data:www-data /var/log/glpi

echo -e "
<?php
define('GLPI_CONFIG_DIR', '/etc/glpi/');
if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
    require_once GLPI_CONFIG_DIR . '/local_define.php';
}
" >> /var/www/glpi/inc/downstream.php

echo -e "
<?php
define('GLPI_VAR_DIR', '/var/lib/glpi/files');
define('GLPI_LOG_DIR', '/var/log/glpi');
" >> /etc/glpi/local_define.php

# Préparer la configuration Apache2 :
echo -e "
<VirtualHost *:80>
    ServerName glpi.labo

    DocumentRoot /var/www/glpi/public

    # If you want to place GLPI in a subfolder of your site (e.g. your virtual host is serving multiple applications),
    # you can use an Alias directive. If you do this, the DocumentRoot directive MUST NOT target the GLPI directory itself.
    # Alias \"/glpi\" \"/var/www/glpi/public\"

    <Directory /var/www/glpi/public>
        Require all granted

        RewriteEngine On

        # Redirect all requests to GLPI router, unless file exists.
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>
    <FilesMatch \.php$>
    	SetHandler \"proxy:unix:/run/php/php8.2-fpm.sock|fcgi://localhost/\"
    </FilesMatch>
</VirtualHost>
" >> /etc/apache2/sites-available/glpi.conf

a2ensite glpi.conf
a2dissite 000-default.conf
a2enmod rewrite
systemctl restart apache2

apt-get install php8.2-fpm
sed -i '1422s/^session.cookie_httponly\s*=.*/session.cookie_httponly = on/' /etc/php/8.2/fpm/php.ini
systemctl restart php8.2-fpm.service

a2enmod proxy_fcgi setenvif
a2enconf php8.2-fpm
systemctl reload apache2
