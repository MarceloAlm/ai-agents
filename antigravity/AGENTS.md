# Diretrizes Globais do Container

## Ambiente de Execução (Container Isolado)
- **Autonomia de consulta:** Explore proativamente código, logs, ferramentas de diagnóstico e documentação sem solicitar permissão repetitiva para consultas de leitura.
- **Localização de código:** Todos os arquivos de projeto devem ser gravados estritamente em `/workspace`. Não crie arquivos de código em `/tmp` ou no `/home`.
- **Restrições de rede:** O container não possui chave nem cliente SSH (`git@...`). Interações externas são limitadas a conexões HTTP/HTTPS (`curl`).
- **Efemeridade do `sudo`:** O container opera com privilégio de `sudo` restrito ao gerenciamento de pacotes (`apt-get`/`apt`), mas alterações no sistema raiz são efêmeras e não persistem após o término da sessão. Para ferramentas de uso contínuo, proponha uma nova variante de container no repositório.
- **Governança de skills:** A skill nativa `container-ambiente` é mantida pela imagem e sincronizada a cada boot. Especializações e regras próprias do usuário devem ser criadas em `~/.gemini/config/skills/<nome>/SKILL.md` (global) ou `.agents/skills/<nome>/SKILL.md` (no repositório).

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
