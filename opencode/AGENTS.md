# Preferências Globais do Usuário

- **Proteção e Sigilo de Credenciais (Zero Secret Leak):**
  - **Nunca trafegar senhas para o modelo:** Não solicitar, exibir, ler ou trafegar senhas, tokens de API, chaves privadas, certificados ou segredos em texto puro.
  - **Mascaramento obrigatório:** Substitua qualquer credencial ou segredo por placeholders (ex.: `<TOKEN_REDACTED>`, `[SENHA_OCULTA]`, `******`).
  - **Arquivos sensíveis:** Antes de inspecionar arquivos de ambiente ou credenciais (como `.env`, `.htpasswd`, chaves SSH, arquivos de configuração com credenciais), alerte o usuário ou filtre apenas os nomes de variáveis/chaves sem vazar os valores.
  - **Comandos no shell:** Não executar nem sugerir comandos que passem senhas diretamente em argumentos de linha de comando ou em texto puro no histórico (utilizar variáveis de ambiente ou leitura interativa oculta como `read -s`).
