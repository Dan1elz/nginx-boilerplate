#!/bin/sh
# Baixa os intervalos de IP da Cloudflare e regenera:
#   nginx/snippets/cloudflare-realip.conf  IP real do visitante (set_real_ip_from)
#   nginx/snippets/cloudflare-geo.conf     quem pode falar com os sites (snippets/site.conf)
# Depois recarrega o nginx (a menos que receba --no-reload).
# A lista muda poucas vezes por ano: https://www.cloudflare.com/ips/
. "$(dirname "$0")/lib.sh"

reload=1
[ "${1:-}" = "--no-reload" ] && reload=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

info "baixando a lista de IPs da Cloudflare"
curl -fsS --max-time 20 https://www.cloudflare.com/ips-v4 > "$tmp/v4"
curl -fsS --max-time 20 https://www.cloudflare.com/ips-v6 > "$tmp/v6"

# Só aceita linhas com cara de CIDR: uma resposta quebrada não pode zerar a lista
cat "$tmp/v4" "$tmp/v6" | tr -d '\r' | grep -E '^[0-9a-fA-F:.]+/[0-9]+$' > "$tmp/all" || true
count="$(wc -l < "$tmp/all" | tr -d ' ')"
[ "$count" -ge 10 ] || die "lista veio com $count intervalos; nada foi alterado"

stamp="$(date -u +%Y-%m-%dT%H:%MZ)"
{
    echo "# Gerado por scripts/update-cloudflare-ips.sh em $stamp ($count intervalos). Não editar."
    echo "# Só confia no cabeçalho CF-Connecting-IP quando a conexão vem da Cloudflare."
    sed 's/.*/set_real_ip_from &;/' "$tmp/all"
    echo "real_ip_header CF-Connecting-IP;"
} > "$tmp/realip.conf"
{
    echo "# Gerado por scripts/update-cloudflare-ips.sh em $stamp ($count intervalos). Não editar."
    echo "# Corpo do bloco geo \$from_cloudflare do nginx.conf."
    sed 's/.*/& 1;/' "$tmp/all"
} > "$tmp/geo.conf"

mv "$tmp/realip.conf" nginx/snippets/cloudflare-realip.conf
mv "$tmp/geo.conf" nginx/snippets/cloudflare-geo.conf
chmod 644 nginx/snippets/cloudflare-realip.conf nginx/snippets/cloudflare-geo.conf
info "$count intervalos gravados"

if [ "$reload" = 1 ] && nginx_running; then
    "$ROOT/scripts/reload.sh"
fi
