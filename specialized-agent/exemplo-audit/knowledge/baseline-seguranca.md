# Baseline de Segurança e Auditoria de Infraestrutura

## 1. Diretrizes para SSH (OpenSSH Server)
- `PermitRootLogin`: Deve ser configurado como `no` ou `prohibit-password`.
- `PasswordAuthentication`: Deve ser desabilitado (`no`), exigindo autenticação por chave pública (Ed25519/RSA 4096).
- `MaxAuthTries`: Deve ser restrito a no máximo `3`.
- `X11Forwarding`: Deve ser mantido em `no` em servidores de produção.

## 2. Firewall de Host (UFW / Iptables / Nftables)
- Política padrão de entrada (`INPUT`): `DROP` ou `REJECT`.
- Política padrão de saída (`OUTPUT`): `ACCEPT` ou restrito por portas autorizadas.
- Portas administrativas (SSH 22) devem ser restritas via VPN ou IP de gestão autorizado.

## 3. Integridade do Sistema de Arquivos
- Diretórios sensíveis (`/etc/shadow`, `/etc/gshadow`): permissão `640` ou `600` pertencente a `root:shadow`.
- Diretório `/tmp` e `/var/tmp` devem idealmente estar montados com opções `noexec,nosuid,nodev`.
