# Proxy de borda — como funciona e como usar em um projeto

Modelo para uma VM com vários projetos Docker atrás de **um** nginx: ele é o único que publica 80/443, termina o HTTPS com um certificado wildcard e encaminha cada hostname para o container certo. Os projetos não publicam portas nem carregam certificado.

| Documento | Para quê |
|---|---|
| [README da raiz](../README.md) | Subir do zero e operar (comandos) |
| Este arquivo | Desenho, decisões, como plugar um projeto, diagnóstico |
| [estudos.md](estudos.md) | O que ler, em ordem, para entender cada peça |

## Como funciona

```
Navegador ──HTTPS──▶ Cloudflare (nuvem laranja) ──HTTPS :443──▶ VM
                                                                │
                                                  ┌─────────────▼─────────────┐
                                                  │ nginx (este projeto)      │
                                                  │ certificado *.SEU_DOMINIO │
                                                  └───┬─────────┬─────────┬───┘
                                    rede proxy-net    │         │         │   HTTP puro, interno
                                                      ▼         ▼         ▼
                                               projeto-web  projeto-api  outro-web ...
```

1. A Cloudflare recebe o HTTPS do navegador e abre uma **nova** conexão HTTPS com a VM (modo *Full (strict)*).
2. O nginx atende na 443 com o certificado, olha o hostname (`Host`) e escolhe o destino em `nginx/sites/<hostname>.conf`.
3. Do nginx para os containers é HTTP puro, dentro da rede Docker `proxy-net`, pelo **alias** de cada serviço.

## Decisões

| Decisão | Por quê |
|---|---|
| Um projeto próprio na borda, dono das portas 80/443 | Só um processo ocupa a porta; nenhum projeto de aplicação deve ser dono dela |
| Rede `proxy-net` criada à mão (`external` em todos) | Projeto novo só se conecta à rede, sem editar o compose do nginx; a rede sobrevive ao nginx parado |
| Só o que é público entra na `proxy-net` | Banco, Redis, filas ficam nas redes privadas de cada projeto e nunca são alcançáveis pelo proxy |
| **Alias único** por serviço (`<projeto>-<servico>[-dev]`) | Vários projetos têm serviços chamados `api`/`web`; com o mesmo nome na mesma rede o Docker alterna entre eles |
| Um arquivo por site + `snippets/` | Previsível e fácil de revisar; `snippets/site.conf` concentra o que vale para todos |
| `resolver` + variável no `proxy_pass` (`set $upstream`) | O nginx sobe mesmo com um container parado: só aquele site dá 502 |
| Certbot com DNS-01 (Cloudflare) e certificado wildcard | Um certificado para todos os subdomínios, sem depender da porta 80 |
| Sem certificado ainda: sobe com um autoassinado provisório | O nginx nunca deixa de subir por falta de arquivo; com a Cloudflare em *Full* já funciona |
| `cert-watch` recarrega quando o certificado muda | Renovação aplicada em até 5 min, sem `docker.sock` montado |
| Sites só aceitam conexões dos IPs da Cloudflare | Ninguém contorna a Cloudflare (e o WAF dela) pelo IP da VM |
| HSTS dos upstreams escondido; HSTS decidido em `snippets/hsts.conf` | Aplicações mandam HSTS de 1 ano sozinhas; quem decide é a borda |
| No dev, `ports` dos projetos só em `127.0.0.1`; no staging, sem `ports` | No PC o dev continua em `localhost`; na VM nada fica exposto nem briga com o nginx |

## Convenções

- **Hostname de um nível só**: `projeto-api.SEU_DOMINIO`, nunca `api.projeto.SEU_DOMINIO`. O wildcard `*.SEU_DOMINIO` (e o certificado gratuito da Cloudflare) não cobre dois níveis.
- **Alias** `<projeto>-<servico>` no staging e `<projeto>-<servico>-dev` no dev. Enquanto só existir o dev na VM, o hostname sem sufixo pode apontar para o alias `-dev`; quando o staging chegar, troca só o arquivo do site.
- URL que o navegador usa é sempre `https://<hostname>`, sem porta.

Mantenha aqui a tabela do que está publicado:

| Hostname | Serviço | Alias na `proxy-net` | Porta interna |
|---|---|---|---|
| `exemplo.SEU_DOMINIO` | front do exemplo | `exemplo-web` | 80 |

## Plugar um projeto

1. **DNS**: registro A `<hostname>` → IP da VM, com proxy (nuvem laranja).
2. **Compose do projeto**, no serviço público:

   ```yaml
   services:
     api:
       # sem "ports" no staging; no dev, só "127.0.0.1:3000:3000"
       networks:
         projeto-net:                 # rede privada do projeto (banco etc.)
         proxy-net:
           aliases: [projeto-api]     # nome que o nginx usa
   networks:
     projeto-net:
       external: true
     proxy-net:
       external: true
   ```

3. **Site**: `scripts/new-site.sh projeto-api.SEU_DOMINIO projeto-api:3000 api` (tipos: `web`, `api`, `s3`).
4. `scripts/reload.sh && scripts/test-sites.sh projeto`.
5. **Aplicação**: URLs públicas com `https://` (CORS, URL pública, `VITE_API_URL`...). Atrás do proxy, a aplicação precisa confiar nos `X-Forwarded-*` vindos de rede privada para enxergar o IP do visitante e o esquema `https`:
   - Express/Nest: `app.set('trust proxy', 'loopback, linklocal, uniquelocal')`
   - ASP.NET: `UseForwardedHeaders` como primeiro middleware, com `KnownNetworks` das redes privadas
   - Vite (dev): `server.allowedHosts` com o hostname
6. Atualizar a tabela de convenções acima.

Cuidados por tipo:

- **Storage S3**: subdomínio próprio. A URL assinada inclui host e caminho; o proxy repassa os dois intactos, e a URL pública configurada na aplicação tem que ser exatamente `https://<hostname>`.
- **Front buildado (Vite)**: `VITE_API_URL` entra no build: mudou, reconstrua a imagem.
- **Upload grande**: `client_max_body_size` no arquivo do site (padrão global: 10 MB).

## Diagnóstico

| Sintoma | Causa provável | Onde olhar |
|---|---|---|
| **521** da Cloudflare | Nada escuta na 443 (nginx parado ou firewall) | `docker compose ps`, `ss -ltn \| grep 443` |
| **522** | Cloudflare não alcança a VM (timeout) | Firewall do provedor |
| **525** | Handshake TLS recusado: hostname sem arquivo em `sites/` | `nginx/sites/`, `server_name` |
| **526** | Certificado inválido para *Full (strict)*: provisório, de staging, vencido ou de outro domínio | `scripts/cert-status.sh`, log do nginx |
| **502** do nginx | Container parado, alias/porta errados ou fora da `proxy-net` | `scripts/test-sites.sh`, `docker network inspect proxy-net` |
| **504** | Aplicação lenta | `proxy_read_timeout` no site |
| **413** | Upload maior que `client_max_body_size` | Arquivo do site |
| **429** | Rate limit (`per_ip` ou `login`) | `burst` no site, zonas no `nginx.conf` |
| **444** / conexão fechada | Acesso sem passar pela Cloudflare (IP direto ou nuvem cinza) | `snippets/site.conf`; para depurar, comente o `if` |
| **403** do Vite "host not allowed" | Hostname fora do `allowedHosts` | `vite.config.ts` / variável do projeto |
| Erro de CORS | Origem configurada difere do `Origin` real (inclui `https`) | `.env` da API |
| Conteúdo misto | Página https chamando `http://` | `VITE_API_URL`, URL pública do storage |
| URL assinada do S3 dá 403 | Host ou caminho alterados, ou URL pública diferente do host usado | Site do s3, `.env` da API |
| Certificado renovado e o site segue com o antigo | `cert-watch` não rodou ainda (até `CERT_WATCH_INTERVAL`) | `docker compose logs nginx \| grep cert-watch` |
| `certbot` reclama de "unsafe permissions" | `cloudflare.ini` aberto demais | `chmod 600 secrets/cloudflare.ini` |
