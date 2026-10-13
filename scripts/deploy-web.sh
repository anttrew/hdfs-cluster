#!/usr/bin/env bash
set -euo pipefail

WEB_USER="${WEB_USER:-team36}"

if [ -z "${WEB_PASSWORD:-}" ]; then
    echo "WEB_PASSWORD is not set."
    echo "Run:"
    echo "  WEB_PASSWORD='your-password' ./scripts/deploy-web.sh"
    exit 1
fi

echo "Installing nginx dependencies..."

sudo apt-get update
sudo apt-get install -y nginx apache2-utils openssl

echo "Preparing TLS certificate..."

sudo mkdir -p /etc/nginx/tls
sudo mkdir -p /etc/nginx/snippets

if [ ! -f /etc/nginx/tls/team36.key ] ||
   [ ! -f /etc/nginx/tls/team36.crt ]; then

    sudo openssl req \
        -x509 \
        -nodes \
        -newkey rsa:2048 \
        -keyout /etc/nginx/tls/team36.key \
        -out /etc/nginx/tls/team36.crt \
        -days 365 \
        -subj "/CN=171.22.73.124"
fi

echo "Configuring basic authentication..."

printf '%s\n' "$WEB_PASSWORD" |
    sudo htpasswd -iBc /etc/nginx/team36.htpasswd "$WEB_USER"

echo "Deploying nginx configuration..."

sudo cp \
    config/nginx/team36-cluster.conf \
    /etc/nginx/conf.d/team36-cluster.conf

sudo cp \
    config/nginx/team36-proxy.conf \
    /etc/nginx/snippets/team36-proxy.conf

sudo nginx -t
sudo systemctl enable nginx
sudo systemctl reload nginx

echo
echo "Web proxy deployment finished."
echo "External ports: 9440-9449"
echo
echo "Note: external NAT/firewall rules are managed by the course infrastructure."
