# Estudos — o que ler para construir isso

Organizado por assunto, do conceito à operação. Em cada bloco: leia primeiro o que está marcado como **essencial**; o resto é consulta.

## Trilha sugerida

| Ordem | Assunto | Onde aparece aqui |
|---|---|---|
| 1 | Proxy reverso e TLS (conceito) | o desenho todo |
| 2 | Redes do Docker | `proxy-net`, aliases |
| 3 | nginx: estrutura, `server`, `location`, `proxy_pass` | `nginx/`, `sites/` |
| 4 | Let's Encrypt, ACME e certbot | `scripts/cert-issue.sh`, serviço `certbot` |
| 5 | Cloudflare: modos SSL e erros 5xx | *Full (strict)*, diagnóstico |
| 6 | Como as aplicações se comportam atrás de um proxy | "Plugar um projeto" |
| 7 | Segurança e endurecimento | `snippets/site.conf`, `tls.conf`, `hsts.conf` |
| 8 | Alternativas (nginx-proxy, Traefik, Caddy) | quando quiser descoberta automática |

---

## 1. Conceitos: proxy reverso e HTTPS

| Leitura | Por quê |
|---|---|
| **Essencial** — [O que é um proxy reverso (Cloudflare Learning)](https://www.cloudflare.com/learning/cdn/glossary/reverse-proxy/) | O papel exato do que você vai construir |
| **Essencial** — [O que é TLS (Cloudflare Learning)](https://www.cloudflare.com/learning/ssl/transport-layer-security-tls/) | O que o certificado faz de fato |
| [Transport Layer Security (MDN)](https://developer.mozilla.org/en-US/docs/Web/Security/Transport_Layer_Security) | Versão mais técnica |
| [Conteúdo misto (MDN)](https://developer.mozilla.org/en-US/docs/Web/Security/Mixed_content) | Por que página `https` não pode chamar `http` |
| [Cabeçalho `X-Forwarded-For` (MDN)](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Forwarded-For) | Como a aplicação descobre o IP real atrás de proxies |

## 2. Docker: redes e Compose

| Leitura | Por quê |
|---|---|
| **Essencial** — [Redes no Compose](https://docs.docker.com/compose/how-tos/networking/) | Redes por projeto, `external`, como os nomes são resolvidos |
| **Essencial** — [Referência: `networks` no Compose](https://docs.docker.com/reference/compose-file/networks/) | `aliases`, `external`, `name` |
| [Visão geral de rede do Docker](https://docs.docker.com/engine/network/) | Bridge, DNS interno (`127.0.0.11`) |
| [`healthcheck` no Compose](https://docs.docker.com/reference/compose-file/services/#healthcheck) | Para `depends_on: condition: service_healthy` |
| [Driver de log `json-file`](https://docs.docker.com/engine/logging/drivers/json-file/) | `max-size`/`max-file`, para o log do nginx não encher o disco |
| [Imagem oficial do nginx (Docker Hub)](https://hub.docker.com/_/nginx) | Tags, caminhos, `templates` com variáveis de ambiente |

Perguntas para você saber responder depois: o que acontece se dois containers na mesma rede têm o alias `api`? Por que o proxy não deve entrar na rede do banco?

## 3. nginx

| Leitura | Por quê |
|---|---|
| **Essencial** — [Beginner's Guide](https://nginx.org/en/docs/beginners_guide.html) | Estrutura, `server`, `location`, `proxy_pass` básico |
| **Essencial** — [Como o nginx processa uma requisição](https://nginx.org/en/docs/http/request_processing.html) | Como ele escolhe o `server` (por `listen` e `server_name`) e o `location` |
| **Essencial** — [Módulo `proxy`](https://nginx.org/en/docs/http/ngx_http_proxy_module.html) | `proxy_pass` (com e sem URI), `proxy_set_header`, buffering, timeouts |
| [Nomes de servidor (`server_name`)](https://nginx.org/en/docs/http/server_names.html) | Host exato, wildcard, `default_server` |
| [Módulo `ssl`](https://nginx.org/en/docs/http/ngx_http_ssl_module.html) | Certificado, protocolos, sessões, `ssl_reject_handshake` |
| [Proxy de WebSocket](https://nginx.org/en/docs/http/websocket.html) | `Upgrade` e `Connection`, o `map` do `$connection_upgrade` |
| [Módulo `core`](https://nginx.org/en/docs/http/ngx_http_core_module.html) | `client_max_body_size`, `resolver`, `listen`, `return` |
| [Módulo `realip`](https://nginx.org/en/docs/http/ngx_http_realip_module.html) | IP real do visitante atrás da Cloudflare |
| [Módulo `limit_req`](https://nginx.org/en/docs/http/ngx_http_limit_req_module.html) | Rate limit (login, API) |
| [Módulo `log`](https://nginx.org/en/docs/http/ngx_http_log_module.html) | `log_format`, `access_log` |
| [Módulo `upstream`](https://nginx.org/en/docs/http/ngx_http_upstream_module.html) | Balanceamento e várias réplicas, para quando escalar |

Pontos de atenção a procurar na documentação (são as pegadinhas deste projeto):

- `proxy_pass` **com variável** não resolve o nome só na inicialização: precisa do `resolver`. Veja a seção sobre `proxy_pass` com variáveis no módulo `proxy`.
- Com variável no `proxy_pass`, o nginx **não** acrescenta nem corta caminho sozinho.
- `add_header` dentro de um `location` **substitui** os herdados do `server` (não soma).
- `client_max_body_size` padrão é 1 MB.

## 4. Let's Encrypt, ACME e certbot

| Leitura | Por quê |
|---|---|
| **Essencial** — [Como o Let's Encrypt funciona](https://letsencrypt.org/how-it-works/) | A ideia de "provar que o domínio é seu" |
| **Essencial** — [Tipos de desafio](https://letsencrypt.org/docs/challenge-types/) | HTTP-01 x DNS-01, e por que wildcard exige DNS-01 |
| **Essencial** — [Guia do usuário do certbot](https://eff-certbot.readthedocs.io/en/stable/using.html) | `certonly`, `renew`, `certificates`, `delete`, hooks |
| [Certbot via Docker](https://eff-certbot.readthedocs.io/en/stable/install.html#running-with-docker) | O modo que vamos usar |
| [Plugin `dns-cloudflare`](https://certbot-dns-cloudflare.readthedocs.io/en/stable/) | Formato do `cloudflare.ini`, permissões do token |
| [Ambiente de staging](https://letsencrypt.org/docs/staging-environment/) | Testar sem estourar limites |
| [Limites de uso (rate limits)](https://letsencrypt.org/docs/rate-limits/) | O que bloqueia a emissão se você errar muitas vezes |
| [RFC 8555 — ACME](https://datatracker.ietf.org/doc/html/rfc8555) | O protocolo em si (opcional, para quem quer ir fundo) |

## 5. Cloudflare

| Leitura | Por quê |
|---|---|
| **Essencial** — [Modos de SSL/TLS](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/) | Off, Flexible, Full, Full (strict): qual conexão cada um criptografa |
| **Essencial** — [Erros 5xx da Cloudflare](https://developers.cloudflare.com/support/troubleshooting/cloudflare-errors/troubleshooting-cloudflare-5xx-errors/) | 520, 521, 522, 525, 526, que você já viu (521) |
| [Portas atendidas pelo proxy](https://developers.cloudflare.com/fundamentals/reference/network-ports/) | Por que `:8000` não funciona pelo domínio |
| [Origin CA (certificado de origem)](https://developers.cloudflare.com/ssl/origin-configuration/origin-ca/) | Alternativa ao Let's Encrypt, para comparar |
| [Authenticated Origin Pulls](https://developers.cloudflare.com/ssl/origin-configuration/authenticated-origin-pull/) | Só aceitar conexões vindas da Cloudflare (mTLS) |
| [Restaurar o IP do visitante](https://developers.cloudflare.com/support/troubleshooting/restoring-visitor-ips/restoring-original-visitor-ips/) | `CF-Connecting-IP` e `set_real_ip_from` |
| [Intervalos de IP da Cloudflare](https://www.cloudflare.com/ips/) | Lista para o `realip` e para o firewall |
| [Criar um token de API](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/) | Escopo mínimo para o certbot |

## 6. As aplicações atrás do proxy

| Leitura | Por quê |
|---|---|
| [Express atrás de proxies](https://expressjs.com/en/guide/behind-proxies.html) | `trust proxy` (base do Nest com Express) |
| [CORS no Nest](https://docs.nestjs.com/security/cors) | `enableCors` com lista de origens |
| [CORS (MDN)](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS) | Por que `https://site` e `http://site` são origens diferentes |
| [ASP.NET Core atrás de proxy](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/proxy-load-balancer) | `UseForwardedHeaders`, `KnownNetworks`, esquema `https` |
| [CORS no ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/security/cors) | Política padrão x nomeada, restringir origens |
| [Quando usar proxy reverso com Kestrel](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/kestrel/when-to-use-a-reverse-proxy) | Por que nginx na frente de uma API .NET |
| [Vite: `server.allowedHosts`](https://vite.dev/config/server-options.html#server-allowedhosts) | O 403 "host not allowed" |
| [Assinatura de URL do S3 (SigV4, query string)](https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-query-string-auth.html) | Por que o proxy não pode mexer em host e caminho |

## 7. Segurança e endurecimento

| Leitura | Por quê |
|---|---|
| **Essencial** — [Gerador de config TLS da Mozilla](https://ssl-config.mozilla.org/) | Protocolos e ciphers recomendados para nginx |
| [HSTS (MDN)](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security) | O que é, e por que subir o `max-age` aos poucos |
| [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/) | Quais headers de segurança importam |
| [Teste do SSL Labs](https://www.ssllabs.com/ssltest/) | Nota e diagnóstico do seu TLS |
| [Segurança do daemon Docker](https://docs.docker.com/engine/security/#docker-daemon-attack-surface) | Por que não montar o `docker.sock` à toa |

## 8. Alternativas e evolução

| Leitura | Por quê |
|---|---|
| [nginx-proxy](https://github.com/nginx-proxy/nginx-proxy) | O modelo automático por variáveis `VIRTUAL_HOST` |
| [acme-companion](https://github.com/nginx-proxy/acme-companion) | O "certbot automático" do par acima |
| [Docs do acme-companion](https://github.com/nginx-proxy/acme-companion/tree/main/docs) | Variáveis, desafio DNS-01, múltiplos domínios |
| [docker-gen](https://github.com/nginx-proxy/docker-gen) | A peça que gera a config a partir dos containers |
| [Traefik](https://doc.traefik.io/traefik/) | Proxy com descoberta por labels e certificados integrados |
| [Caddy](https://caddyserver.com/docs/) | Servidor com HTTPS automático e config mínima |


## Para fechar: vocabulário para saber explicar

Se você consegue explicar cada item abaixo com suas palavras, entendeu o projeto: terminar TLS, `Host` header, `default_server`, desafio DNS-01, wildcard de um nível, modo Full (strict), alias de rede, `resolver` do Docker, URL assinada e por que o proxy não pode mudar o caminho dela.
