# Preferências do usuário (container-ambiente)

Este arquivo é MANTIDO individualmente: é criado na primeira execução a partir
deste template e **nunca é sobrescrito** pelo entrypoint nos próximos boots.
Edite para ajustar o comportamento do agente neste container.

## Preferências atuais

- **Criação de arquivos:** usar `cat <<'EOF' > arquivo` (heredoc) em vez da ferramenta dedicada de escrita de arquivos.

## Convenções adicionais

- Idioma das respostas e comentários: (defina aqui, ex.: `português`)
- Modelo/velocidade de respostas: (ex.: `respostas concisas`)
- Qualquer outro ajuste que você queira que o agente siga por padrão.
