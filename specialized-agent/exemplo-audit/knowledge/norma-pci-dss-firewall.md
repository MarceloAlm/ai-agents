# Norma de Segurança Operacional e Segmentação de Serviços Web (PCI-DSS / ISO 27001)

## 1. Segmentação e Proxies Reversos (Nginx / HAProxy)
- Todo serviço web em produção deve operar atrás de um Reverse Proxy ou API Gateway com terminação TLS segura (TLS 1.2 e TLS 1.3 apenas).
- Cabeçalhos de segurança obrigatórios em todas as respostas HTTP:
  - `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`
  - `X-Frame-Options: SAMEORIGIN` ou `DENY`
  - `X-Content-Type-Options: nosniff`
  - `Content-Security-Policy` adequado à aplicação
- Proteção contra injeção de cabeçalhos de host (`proxy_set_header Host $host;`).
- Certificados TLS devem ser renovados automaticamente com antecedência mínima de 30 dias do vencimento.

## 2. Autenticação Centralizada e Provedores de Identidade (Keycloak / OAuth2 / OIDC)
- O console administrativo deve ser restrito estritamente a faixas de IP de gerência interna (`10.0.0.0/8`).
- Políticas de bloqueio de conta (*Account Lockout*) ativas após no máximo 5 tentativas falhas em uma janela de 15 minutos.
- Uso de tokens de curta duração (Access Token <= 5 minutos, Refresh Token com rotação ativada).
- Rate limiting obrigatório no endpoint de autenticação (`/auth/realms/.../protocol/openid-connect/token`) contra ataques de credential stuffing.

## 3. Diretrizes de Validação Prévia de Comandos (Dry-run e Sintaxe)
- Toda proposta de script de remediação deve ser sintaticamente validável com ferramentas padrão como `bash -n`.
- Comandos devem conter verificação de pré-requisitos antes da aplicação e rotina de backup/rollback prévia (ex.: `cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak`).
