# Preferências Globais do Usuário

As diretrizes desta política são obrigatórias e valem para qualquer sessão.

Cópia gerada no perfil (`~/.config/opencode/AGENTS.md`) a cada inicialização a partir de `/etc/opencode/AGENTS.md` (imagem). As regras canônicas imutáveis (Zero Secret Leak) ficam em `/etc/opencode/rules/zero-secret-leak.md`.

## Proteção de Segredos (Zero Secret Leak)

Regra obrigatória e inegociável para qualquer sessão neste ambiente. O sigilo prevalece sobre a conveniência: em caso de dúvida, não exponha.

### Princípios

- Credenciais, segredos e tokens não trafegam para o modelo em nenhuma hipótese.
- Qualquer segredo exibido inadvertidamente é mascarado imediatamente.
- Segredos não são persistidos em repositório, logs ou histórico de comandos.

### Diretrizes

- **Nunca solicitar, exibir, ler ou transmitir** senhas, tokens de API, chaves privadas, certificados ou segredos em texto puro.
- **Mascaramento obrigatório:** substitua qualquer credencial por um placeholder (ex.: `<TOKEN_REDACTED>`, `[SENHA_OCULTA]`, `******`).
- **Arquivos sensíveis:** antes de inspecionar `.env`, `.htpasswd`, chaves SSH ou configurações que contenham credenciais, alerte o usuário ou liste apenas nomes de variáveis e chaves, sem os valores.
- **Comandos no shell:** não execute nem sugira comandos que passem senhas em argumentos de linha de comando (visíveis no histórico e em `ps`). Utilize variáveis de ambiente ou leitura interativa oculta (`read -s`).
- **Saída e depuração:** não use `echo`, `set -x` ou qualquer log que imprima segredos.
- **Repositório:** nunca versione arquivos que contenham credenciais; `.env` e similares permanecem fora do controle de versão (`.gitignore`).
- **Build de imagens:** não passe segredos como `--build-arg` (persistem no histórico de camadas). Use `--secret` do Buildah/Docker ou injeção em tempo de execução.
