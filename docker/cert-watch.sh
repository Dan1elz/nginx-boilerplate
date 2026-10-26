#!/bin/sh
# Recarrega o nginx quando o certificado muda: primeira emissão ou renovação pelo certbot.
# O nginx só lê o certificado ao (re)carregar; sem isso ele seguiria com o antigo até vencer.
# Substitui o "reload a cada 6h" da doc: só recarrega quando precisa, e sem docker.sock.

interval="${CERT_WATCH_INTERVAL:-300}"
name="${CERT_NAME:-example.com}"

fingerprint() {
    # cat segue o link de live/ para archive/; arquivo ausente vira hash de vazio
    cat "/etc/letsencrypt/live/$name/fullchain.pem" 2>/dev/null | sha256sum | cut -d' ' -f1
}

last="$(fingerprint)"
while :; do
    sleep "$interval"
    now="$(fingerprint)"
    [ "$now" = "$last" ] && continue

    origin="$(select-cert)"
    if nginx -t -q; then
        nginx -s reload
        echo "cert-watch: certificado mudou ($origin), nginx recarregado"
        last="$now"
    else
        # Não atualiza $last: tenta de novo na próxima volta
        echo "cert-watch: nginx -t falhou, mantendo a config em uso" >&2
    fi
done
