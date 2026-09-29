# Baseline de Segurança e Auditoria de Infraestrutura

## 1. Diretrizes para SSH (OpenSSH Server - sshd_config)
- `PermitRootLogin`: Deve ser configurado estritamente como `no` ou `prohibit-password`. Qualquer valor como `yes` é classificado como risco **CRÍTICO**.
- `PasswordAuthentication`: Deve ser desabilitado (`no`), exigindo autenticação exclusivamente por chaves públicas assimétricas (Ed25519 ou RSA >= 4096 bits).
- `MaxAuthTries`: Deve ser restrito a no máximo `3`.
- `X11Forwarding`: Deve ser mantido em `no` em servidores de produção.
- `Port`: Caso exposto para a Internet, recomenda-se uso de porta não padrão com rate-limiting no firewall.

## 2. Diretrizes de Banco de Dados (PostgreSQL - pg_hba.conf)
- Proibida a declaração `host all all 0.0.0.0/0 md5`. O algoritmo `md5` é criptograficamente vulnerável a ataques de colisão e quebra de dicionário.
- Obrigatório o uso de `scram-sha-256` para autenticação com senha.
- O acesso a bancos de produção deve ser restrito por faixas de IP de aplicação confiáveis (ex.: `10.0.0.0/16` ou `192.168.1.0/24`), nunca aberto para `0.0.0.0/0`.
- Certificados de conexão (`hostssl`) devem ser exigidos para tráfego externo.

## 3. Firewall de Host (UFW / Iptables / Nftables)
- Política padrão de entrada (`INPUT`): `DROP` ou `REJECT`.
- Política padrão de saída (`OUTPUT`): `ACCEPT` ou restrito por portas autorizadas.
- Portas administrativas (SSH 22, interfaces web de admin) devem ser restritas via VPN ou IP de gestão autorizado.
- Toda regra de liberação deve conter máscara de sub-rede ou IP de origem específico quando não for serviço público (80/443).

## 4. Integridade do Sistema de Arquivos e Permissões
- Arquivos de credenciais sensíveis (`/etc/shadow`, `/etc/gshadow`): permissão obrigatória `640` ou `600`, pertencente ao grupo `root:shadow`.
- Chaves privadas TLS (`/etc/ssl/private/*.key`): permissão obrigatória `600`, pertencente a `root:root`.
- Diretórios temporários (`/tmp`, `/var/tmp`): montados idealmente com opções `noexec,nosuid,nodev`.
