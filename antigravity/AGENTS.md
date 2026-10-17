# Diretrizes Globais do Container

## Proteção e Sigilo de Credenciais (Zero Secret Leak)
- **Nunca trafegar senhas para o modelo:** Não solicitar, exibir, ler ou trafegar senhas, tokens de API, chaves privadas, certificados ou segredos em texto puro.
- **Mascaramento obrigatório:** Substitua qualquer credencial ou segredo por placeholders (ex.: `<TOKEN_REDACTED>`, `[SENHA_OCULTA]`, `******`).
- **Arquivos sensíveis:** Antes de inspecionar arquivos de ambiente ou credenciais (como `.env`, `.htpasswd`, chaves SSH, arquivos de configuração com credenciais), alerte o usuário ou filtre apenas os nomes de variáveis/chaves sem vazar os valores.
- **Comandos no shell:** Não executar nem sugerir comandos que passem senhas diretamente em argumentos de linha de comando ou em texto puro no histórico (utilizar variáveis de ambiente ou leitura interativa oculta como `read -s`).

## Ambiente de Execução (Container Isolado)
- **Autonomia de consulta:** Explore proativamente código, logs, ferramentas de diagnóstico e documentação sem solicitar permissão repetitiva para consultas de leitura.
- **Localização de código:** Todos os arquivos de projeto devem ser gravados estritamente em `/workspace`. Não crie arquivos de código em `/tmp` ou no `/home`.
- **Restrições de rede:** O container não possui chave nem cliente SSH (`git@...`). Interações externas são limitadas a conexões HTTP/HTTPS (`curl`).
- **Efemeridade do `sudo`:** O container opera com privilégio de `sudo` sem senha, mas alterações no sistema raiz são efêmeras e não persistem após o término da sessão. Para ferramentas de uso contínuo, proponha uma nova variante de container no repositório.
- **Governança de skills:** A skill nativa `container-ambiente` é mantida pela imagem e sobrescrita a cada boot. Especializações e regras próprias do usuário devem ser criadas em `~/.gemini/config/skills/<nome>/SKILL.md` (global) ou `.agents/skills/<nome>/SKILL.md` (no repositório).
