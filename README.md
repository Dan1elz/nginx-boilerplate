# nginx — proxy de borda (boilerplate)

Modelo de proxy de borda para uma VM com vários projetos Docker: **um** nginx recebe 80/443, termina o HTTPS com um certificado wildcard (`<CERT_NAME>` + `*.<CERT_NAME>`, Let's Encrypt via DNS-01 na Cloudflare) e encaminha cada hostname para o container certo pela rede Docker `proxy-net`. Os projetos não publicam portas nem carregam certificado.

```
Navegador ─HTTPS─▶ Cloudflare ─HTTPS─▶ nginx (:443) ─HTTP, rede proxy-net─▶ projeto-web:80
                                                                          projeto-api:3000 ...
```

Desenho, decisões, como plugar um projeto e diagnóstico: [docs/](docs/README.md).

## Começar um projeto a partir daqui

```bash
cp -r nginx-boilerplate ~/projects/nginx && cd ~/projects/nginx
rm -rf .git && git init
scripts/setup.sh              # rede proxy-net, .env, secrets/, IPs da Cloudflare (idempotente)
```

1. `.env`: `CERT_NAME` (seu domínio), `LETSENCRYPT_EMAIL` e as portas. Para testar sem derrubar nada: `HTTP_BIND=127.0.0.1`, `HTTP_PORT=8010`, `HTTPS_BIND=127.0.0.1`, `HTTPS_PORT=8011`.
2. `docker compose up -d --build`. Sobe com um certificado **autoassinado provisório** (aviso no log): com a Cloudflare em *Full* já funciona.
3. Para cada hostname: `scripts/new-site.sh <hostname> <alias:porta> [web|api|s3]` e plugar o projeto ([como](docs/README.md#plugar-um-projeto)).
4. `scripts/reload.sh && scripts/test-sites.sh`.
5. Certificado real: token em `secrets/cloudflare.ini` (Zone → DNS → Edit, só na zona), `scripts/cert-issue.sh --staging`, depois `scripts/cert-issue.sh`. Cloudflare em **Full (strict)**.
6. Virada: no `.env`, `0.0.0.0` e portas 80/443; `docker compose up -d`.

## Dia a dia

| Quero | Comando |
|---|---|
| Validar a config | `scripts/check.sh` |
| Aplicar mudança num site | `scripts/reload.sh` (valida antes; config inválida não entra) |
| Testar todos os sites por dentro | `scripts/test-sites.sh [filtro]` |
| Projeto novo | `scripts/new-site.sh <hostname> <alias:porta> [web\|api\|s3]` |
| Ver certificados / testar renovação | `scripts/cert-status.sh [--dry-run]` |
| Atualizar IPs da Cloudflare | `scripts/update-cloudflare-ips.sh` (poucas vezes por ano) |
| Logs | `docker compose logs -f nginx` |

## O que acontece sozinho

- **Renovação**: o `certbot` roda `renew` a cada 12h (só renova o que vence em menos de 30 dias).
- **Recarga**: o `cert-watch`, dentro do container do nginx, confere o certificado a cada `CERT_WATCH_INTERVAL` segundos e recarrega quando ele muda. Sem `docker.sock`.
- **Container de destino parado**: só aquele site responde 502 (página amigável, ou JSON nas APIs); o nginx continua no ar.

## Estrutura

```
compose.yaml          nginx (imagem própria, config por volume) + certbot (renovação)
Dockerfile            nginx oficial + openssl + scripts de certificado
docker/               select-cert (qual certificado usar), cert-watch (recarga na renovação)
nginx/nginx.conf      global: logs, gzip, rate limit, realip, geo da Cloudflare, timeouts
nginx/conf.d/         00-default: /healthz, 80 → 443 para todo host, recusa host desconhecido na 443
nginx/snippets/       site.conf (comum a todo site), proxy, tls, ssl, headers, hsts, erros
nginx/sites/          UM arquivo por hostname (gerados por scripts/new-site.sh)
nginx/errors/         páginas 50x/429 (HTML e JSON)
scripts/              operação (tabela acima)
certbot/              modelo do cloudflare.ini
secrets/  data/       fora do git: token da Cloudflare, certificados e conta ACME
```

## Segurança, em uma linha cada

- Só conexões vindas dos IPs da Cloudflare chegam aos sites (`snippets/site.conf`); o resto leva 444. Ninguém contorna a Cloudflare pelo IP da VM.
- Hostname desconhecido nem recebe certificado (`ssl_reject_handshake`).
- TLS 1.2/1.3, perfil *intermediate* da Mozilla. HSTS desligado até tudo estar estável em https (`snippets/hsts.conf`).
- Rate limit por IP real nas APIs e mais apertado nos logins (429).
- `secrets/` com `chmod 600`; nada de `docker.sock` montado.

## Backup

`data/letsencrypt/` (conta ACME + certificados; pertence ao root, use `sudo tar`) e `secrets/`. Sem eles dá para emitir de novo, mas cuidado com os [limites](https://letsencrypt.org/docs/rate-limits/).
