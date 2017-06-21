#!/bin/bash

OPSMAN_FQDN=$1
CERT_EMAIL=$2

if [ $# -ne 2 ]; then
    echo -e "\nusage: opsmgr-cert-ssl.sh {opsmgr FQDN} {cert renewal email}"
    echo -e "   eg: opsmgr-cert-ssl.sh opsman.pcf.mycompany.com cert-notices@mycompany.com\n"
    exit 1
fi

case "$2" in
*@*.*)
    ;;
*)
    echo You have entered an invalid email address! >&2
    exit 1
    ;;
esac

sudo add-apt-repository -y ppa:certbot/certbot
sudo /usr/bin/apt-get -qy update
sudo apt-get -qy install certbot
sudo sed -i '/Pass everything to tempest-web-app/a\    location ~ /.well-known {\n\      allow all;\n\    }' /etc/nginx/nginx.conf
sudo service nginx restart
sudo certbot certonly --webroot --webroot-path=/usr/share/nginx/html -d $OPSMAN_FQDN --agree-tos -m $CERT_EMAIL -n

if [ "$?" -eq 0 ]; then
  sudo mv /var/tempest/cert/tempest.crt /var/tempest/cert/tempest.crt.old && sudo mv /var/tempest/cert/tempest.key /var/tempest/cert/tempest.key.old
  sudo ln -s /etc/letsencrypt/live/$OPSMAN_FQDN/fullchain.pem /var/tempest/cert/tempest.crt && sudo ln -s /etc/letsencrypt/live/$OPSMAN_FQDN/privkey.pem /var/tempest/cert/tempest.key
else
  exit 1
fi

sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
sudo sed -i '/ssl_prefer_server_ciphers On;/a\    ssl_session_cache shared:SSL:10m;\n\    ssl_stapling on;\n\    ssl_stapling_verify on;\n\    ssl_session_timeout 1d;\n\    ssl_dhparam /etc/ssl/certs/dhparam.pem;' /etc/nginx/nginx.conf
sudo sed -i 's/ssl_protocols TLSv1 TLSv1.1 TLSv1.2;/ssl_protocols TLSv1.2;/g' /etc/nginx/nginx.conf
sudo sed -i 's/ssl_ciphers DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!3DES:!MD5:!PSK;/ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!3DES:!MD5:!PSK;/g' /etc/nginx/nginx.conf
sudo sed -i 's/rewrite ^ https:\/\/$host$request_uri? permanent;/return 301 https:\/\/$host$request_uri?;/g' /etc/nginx/nginx.conf

sudo echo "5 3 * * * /usr/bin/certbot renew --quiet --renew-hook \"/usr/sbin/service nginx reload\"" >/tmp/mycron
sudo crontab /tmp/mycron
sudo rm -rf /tmp/mycron

sudo rm -rf /var/tmp
sudo ln -s /tmp /var/tmp

sudo service nginx restart
