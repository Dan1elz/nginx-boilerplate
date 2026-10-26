#!/bin/sh
# Testa cada site de nginx/sites/ por dentro do container (sem passar pela Cloudflare):
# conexão TLS no próprio nginx com o hostname certo, como a Cloudflare faria.
#
#   scripts/test-sites.sh            todos
#   scripts/test-sites.sh projeto    só os que contêm "projeto" no nome
#
# Mostra o status HTTP e o upstream. 502/504 = container parado, alias ou porta errados,
# ou fora da proxy-net (docker network inspect proxy-net).
. "$(dirname "$0")/lib.sh"

nginx_running || die "nginx não está rodando (docker compose up -d)"
filter="${1:-}"

printf '%-34s %-6s %-28s %s\n' HOSTNAME STATUS UPSTREAM CERTIFICADO
for f in nginx/sites/*.conf; do
    host="$(sed -n 's/^[[:space:]]*server_name[[:space:]]\{1,\}\([^;[:space:]]*\).*/\1/p' "$f" | head -1)"
    [ -n "$host" ] || continue
    case "$host" in *"$filter"*) ;; *) continue ;; esac
    upstream="$(sed -n 's/^[[:space:]]*set[[:space:]]\{1,\}\$upstream[[:space:]]\{1,\}http:\/\/\([^;]*\);.*/\1/p' "$f" | head -1)"

    out="$(docker compose exec -T nginx curl -sk -o /dev/null --max-time 10 \
        -w '%{http_code}' \
        --resolve "$host:443:127.0.0.1" "https://$host/" 2>/dev/null || true)"
    code="${out:-ERRO}"
    [ "$code" = 000 ] && code="ERRO"
    issuer="$(docker compose exec -T nginx sh -c \
        "echo | openssl s_client -connect 127.0.0.1:443 -servername $host 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null" \
        | sed 's/^issuer=//; s/.*CN *= *//' || true)"

    printf '%-34s %-6s %-28s %s\n' "$host" "$code" "${upstream:-?}" "${issuer:-?}"
done
