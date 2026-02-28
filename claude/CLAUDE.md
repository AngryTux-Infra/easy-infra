# CLAUDE.md — easy-infra

Instruções para agentes AI trabalharem neste repositório.

## Projeto

Setup inicial de servidor Linux (Debian/Ubuntu). Scripts bash idempotentes para hardening, firewall, usuários, fail2ban, updates e monitoramento.

## Agent Team

Este projeto opera com três agentes especializados:

### tech-lead (Opus)

- **Papel**: Gerenciamento do projeto, decisões de tecnologia, priorização de atividades
- **Atua como**: Review advocate — revisa PRs e trabalho dos outros agentes
- **Responsabilidades**:
  - Criar e manter PRDs e ADRs
  - Definir prioridades e dependências entre issues
  - Revisar entregas de sysops e devops
  - Aprovar ou solicitar mudanças em PRs
  - Garantir coerência arquitetural entre scripts
- **Não faz**: Implementação direta de scripts (delega para sysops/devops)

### sysops (Sonnet)

- **Papel**: Especialista em sistema operacional e infraestrutura
- **Responsabilidades**:
  - Configuração de serviços do sistema (SSH, NTP, fail2ban, UFW)
  - Hardening e segurança do OS
  - Gestão de usuários, grupos e permissões
  - Configurações de rede e hostname
  - Logs e auditoria do sistema
  - Arquivos de configuração em `configs/`
- **Foco**: O que configurar no servidor e por quê (visão do sistema)

### devops (Sonnet)

- **Papel**: Especialista em automação e estrutura de scripts
- **Responsabilidades**:
  - Estrutura e organização dos scripts em `scripts/`
  - Idempotência — scripts podem rodar múltiplas vezes sem efeitos colaterais
  - Tratamento de erros e logging nos scripts
  - Validação de pré-requisitos (OS, permissões, dependências)
  - Ordem de execução e orquestração
  - Portabilidade entre distribuições quando aplicável
- **Foco**: Como automatizar (visão da engenharia de scripts)

## Convenções de código

### Scripts bash

- Shebang: `#!/usr/bin/env bash`
- `set -euo pipefail` em todo script
- Padrão obrigatório no header:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "${SCRIPT_DIR}/../lib/common.sh"
  require_root
  log_info "Iniciando: $(basename "$0")"
  ```
- Funções do `lib/common.sh`: `log_info`, `log_warn`, `log_error`, `require_root`, `is_installed`, `ensure_package`
- Variáveis em UPPER_CASE para constantes/config, lower_case para locais
- Nomes de arquivo: `NN-descricao.sh` (numerados por ordem de execução)
- Idempotência: verificar estado antes de alterar (md5sum, grep, etc)
- Validar antes de aplicar (ex: `sshd -t`, `visudo -cf`)
- Rollback em caso de falha de validação

### Configurações

- Arquivos em `configs/` são templates com placeholders `{{VARIABLE}}`
- Substituição via `sed` ou expansão bash em runtime
- Comentar toda diretiva não-default

## Como trabalhar com issues

### Antes de começar

1. Leia a issue completa — incluindo `## Refs`
2. Navegue cada referência: leia PRDs e ADRs referenciados
3. Verifique o status — só trabalhe em `status:ready` ou `status:in-progress`
4. Verifique dependências — se "Depends on" não está closed, marque como `blocked`

### Nunca faça

- Trabalhar em issue `status:draft` — está incompleta
- Ignorar a seção Refs — contém contexto essencial
- Criar PRs sem referenciar a issue (`Closes #N`)
- Pular transições de status
- Deletar issues (apenas feche)
- Alterar PRDs aprovados

### Output por tipo

| Tipo | O que produzir |
|------|---------------|
| `type:prd` | Issue body com requisitos e critérios de aceite |
| `type:adr` | Análise de opções + decisão documentada |
| `type:task` | Entregável concreto referenciando a issue |
| `type:bug` | Fix referenciando a issue |

### Transições de status

```bash
# Pegar uma task
gh issue edit N --remove-label "status:ready" --add-label "status:in-progress" --add-assignee "@me"

# Terminar e pedir review
gh issue edit N --remove-label "status:in-progress" --add-label "status:review"
```

### Consultas úteis

```bash
gh issue list --label "status:ready"     # O que posso pegar?
gh issue list --label "status:review"    # O que precisa de review?
gh issue list --label "blocked"          # O que está travado?
```

## Testes

```bash
# Validar sintaxe de todos os scripts
for f in scripts/*.sh lib/*.sh run-all.sh; do bash -n "$f" && echo "OK: $f"; done

# Shellcheck (se disponível)
shellcheck scripts/*.sh lib/common.sh run-all.sh

# Dry-run do orquestrador
sudo ./run-all.sh --dry-run

# Health-check do servidor (pós-setup)
server-health
```

## Arquivos-chave

| Arquivo | Propósito |
|---------|-----------|
| `run-all.sh` | Entry point — orquestra todos os scripts |
| `lib/common.sh` | Funções compartilhadas (logging, package mgmt, .env) |
| `.env.example` | Template de variáveis configuráveis |
| `configs/sshd_config` | Template SSH hardening (ADR #3) |
| `configs/fail2ban/jail.local` | Template jails fail2ban |
