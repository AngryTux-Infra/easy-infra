# CLAUDE.md — easy-infra

Instruções para agentes AI trabalharem neste repositório.

## Projeto

Automação de setup inicial de servidores Linux (Debian/Ubuntu) com Ansible. 10 roles idempotentes: etckeeper, base, debloat, ssh, firewall, users, fail2ban, auditd, updates, monitoring. Aplicável a N servidores via inventário. Testado em Debian 13 (trixie).

## Agent Team

### tech-lead (Opus)

- Gerenciamento do projeto, decisões de tecnologia, priorização
- Review advocate — revisa entregas de sysops e devops
- Cria e mantém PRDs e ADRs
- Não implementa diretamente (delega)

### sysops (Sonnet)

- Sistema operacional, serviços, hardening, segurança
- Configuração de SSH, NTP, fail2ban, UFW, users
- Foco: o que configurar e por quê

### devops (Sonnet)

- Estrutura das roles, templates Jinja2, handlers
- Idempotência, validação, orquestração
- Foco: como automatizar

## Convenções Ansible

### YAML

- 2 espaços de indentação
- Cada task com `name:` descritivo em inglês
- Listas com `- item` (não inline)
- Booleanos: `true`/`false` (não `yes`/`no`)

### Roles

Cada role segue a estrutura:
```
roles/<name>/
├── tasks/main.yml       # Tasks da role
├── defaults/main.yml    # Variáveis com defaults
├── handlers/main.yml    # Handlers (restart serviços)
├── templates/           # Templates Jinja2 (.j2)
└── files/               # Arquivos estáticos
```

### Templates Jinja2

- Extensão `.j2`
- Variáveis: `{{ variavel }}` (com espaços)
- Comentários: `{# comentário #}`
- Cabeçalho: `# Managed by Ansible — do not edit manually`

### Handlers

- Usar `notify:` nas tasks que alteram config
- Handler só executa se a task reportou `changed`
- Padrão: `restart <serviço>`
- Se a role precisa que o handler execute antes do final do play, usar `meta: flush_handlers`

### Apt

- Sempre usar `cache_valid_time: 3600` com `update_cache: true` para evitar apt-update desnecessário
- Não purgar pacotes que são dependências de outras roles (ex: exim4 é dep do logwatch)

### SSH port transition

A role `ssh` muda a porta do sshd mid-play. Para manter a conectividade Ansible:
1. `meta: flush_handlers` — restart imediato do sshd
2. `wait_for` (delegado ao localhost) — aguarda nova porta
3. `set_fact: ansible_port` — atualiza porta de conexão
4. `meta: reset_connection` — reconecta na nova porta

### Variáveis

- snake_case sempre
- Defaults em `roles/<name>/defaults/main.yml`
- Overrides em `group_vars/` ou `host_vars/`
- Precedência: defaults → group_vars/all → group_vars/<grupo> → host_vars/<host>

### Idempotência

- Módulos Ansible são nativamente idempotentes — não reinventar
- `template` com `validate:` para configs críticas (sshd, sudoers)
- `backup: true` em configs que podem quebrar acesso
- Handlers para restart condicional

## Comandos úteis

```bash
# Syntax check
ansible-playbook site.yml --syntax-check

# Dry-run com diff
ansible-playbook site.yml --check --diff

# Apenas uma role
ansible-playbook site.yml --tags ssh

# Apenas um host
ansible-playbook site.yml --limit web01

# Inventário específico
ansible-playbook -i inventories/staging/hosts.yml site.yml

# Inventário de teste (homelab)
ansible-playbook site.yml -i inventories/test/hosts.yml

# Testar conectividade
ansible all -m ping
```

## Como trabalhar com issues

### Antes de começar

1. Leia a issue completa — incluindo `## Refs`
2. Navegue cada referência: leia PRDs e ADRs referenciados
3. Verifique o status — só trabalhe em `status:ready` ou `status:in-progress`
4. Verifique dependências — se "Depends on" não está closed, marque como `blocked`

### Nunca faça

- Trabalhar em issue `status:draft`
- Ignorar a seção Refs
- Criar PRs sem referenciar a issue (`Closes #N`)
- Pular transições de status
- Alterar PRDs aprovados

### Transições de status

```bash
gh issue edit N --remove-label "status:ready" --add-label "status:in-progress"
gh issue edit N --remove-label "status:in-progress" --add-label "status:review"
```

## Arquivos-chave

| Arquivo | Propósito |
|---------|-----------|
| `site.yml` | Playbook principal — entry point (10 roles em ordem) |
| `ansible.cfg` | Configuração Ansible (inventory, forks, pipelining) |
| `inventories/production/group_vars/all.yml` | Variáveis globais produção |
| `inventories/test/group_vars/all.yml` | Variáveis globais teste (homelab) |
| `roles/ssh/tasks/main.yml` | SSH hardening + port transition logic |
| `roles/ssh/templates/sshd_config.j2` | Template SSH hardening (ADR #5) |
| `roles/firewall/tasks/main.yml` | UFW + limpeza de regras legadas porta 22 |
| `roles/fail2ban/templates/jail.local.j2` | Template jails fail2ban |
| `roles/debloat/defaults/main.yml` | Lista de pacotes a remover (cuidado com deps) |
| `roles/auditd/templates/homelab.rules.j2` | Regras de auditoria do sistema |
