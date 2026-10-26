#!/bin/sh
# Escolhe o certificado que o nginx usa e grava /etc/nginx/generated/ssl-cert.conf
# (incluído por snippets/ssl.conf).
#
# - Existe data/letsencrypt/live/$CERT_NAME/ → usa o do Let's Encrypt.
# - Não existe → gera um autoassinado provisório para o nginx subir mesmo assim.
#   Com a Cloudflare em "Full" ele funciona; em "Full (strict)" dá 526 até o real existir.
#
# Imprime "letsencrypt" ou "selfsigned".
set -eu

name="${CERT_NAME:-example.com}"
live="/etc/letsencrypt/live/$name"
gen=/etc/nginx/generated
mkdir -p "$gen"

if [ -s "$live/fullchain.pem" ] && [ -s "$live/privkey.pem" ]; then
    origin=letsencrypt
    cert="$live/fullchain.pem"
    key="$live/privkey.pem"
else
    origin=selfsigned
    cert="$gen/selfsigned.crt"
    key="$gen/selfsigned.key"
    if [ ! -s "$cert" ]; then
        openssl req -x509 -nodes -days 30 \
            -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
            -subj "/CN=$name" \
            -addext "subjectAltName=DNS:$name,DNS:*.$name" \
            -keyout "$key" -out "$cert" 2>/dev/null
    fi
fi

# Escreve num temporário e troca: o nginx nunca lê um arquivo pela metade
cat > "$gen/ssl-cert.conf.tmp" <<EOF
# Gerado por select-cert ($origin). Não editar: é recriado a cada início e renovação.
ssl_certificate     $cert;
ssl_certificate_key $key;
EOF
mv "$gen/ssl-cert.conf.tmp" "$gen/ssl-cert.conf"

echo "$origin"
