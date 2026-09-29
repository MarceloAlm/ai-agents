# Metodologia de Investigação Forense e Resposta a Incidentes (MITRE ATT&CK)

## 1. Normalização Temporal e Linha do Tempo (Timeline Analysis)
- Fontes de logs corporativas costumam reportar eventos em fusos horários distintos:
  - Logs de WAF/Cloud: frequentemente em **UTC (Z)**.
  - Logs de Servidores Linux (Syslog / Journald): frequentemente em **horário local (ex.: UTC-3 Brasília)**.
  - Logs de Firewall de Rede / NetFlow: frequentemente em **Unix Epoch Timestamp (segundos desde 1970)**.
- **Regra Fundamental de Perícia:** Toda correlação de causa e efeito exige a conversão de todos os registros para um referencial único antes de estabelecer a ordem dos acontecimentos. A ordem de apresentação dos logs no dossiê NÃO reflete necessariamente a ordem cronológica real dos fatos.

## 2. Distratores vs. Vetores Reais de Infiltração
- Ataques sofisticados utilizam ruído coordenado (*Distraction Attack*):
  - **Ataque Distrator:** Scanners automatizados, SQLi grosseiros ou tentativas de força bruta repetidas com alta visibilidade que acionam alertas no SIEM.
  - **Ataque Real (Stealth):** Utilização simultânea de credenciais legítimas comprometidas, bypass de autenticação por cabeçalhos, persistência via tarefas agendadas (`cron` ou `systemd units`) e exfiltração em baixa frequência via protocolos não monitorados (ex.: consultas DNS TXT/AAAA para subdomínios controlados pelo atacante com payloads codificados em Base64).
- O perito deve diferenciar o tráfego ruidoso (sem sucesso) do vetor de comprometimento real (com sucesso e impacto).

## 3. Preservação de Evidências e Cadeia de Custódia (RFC 3227)
- **Ordem de Volatilidade:** Memória RAM e conexões de rede ativas são os dados mais voláteis e devem ser preservados antes de qualquer desligamento ou reinicialização.
- **RESTRIÇÃO ABSOLUTA:** É terminantemente proibido reiniciar (`reboot`, `shutdown`, `init 0`), desativar swap (`swapoff`) ou encerrar processos indiscriminadamente sem antes coletar dump de memória do processo (`gcore` ou cópia de `/proc/$PID/`).
- **RESTRIÇÃO DE CONECTIVIDADE OPERACIONAL:** A contenção de rede deve ser cirúrgica (bloqueio do IP malicioso e do domínio C2). É estritamente proibido derrubar interfaces globais ou bloquear faixas de serviço essenciais (como tráfego de controle do Kubernetes `10250` ou VPN de missão crítica).
