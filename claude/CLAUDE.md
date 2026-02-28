# CLAUDE.md — easy-infra

Instruções para agentes AI trabalharem neste repositório.

## Projeto

Automação de setup inicial de servidores Linux (Debian/Ubuntu) com Ansible. Roles idempotentes para hardening, firewall, usuários, fail2ban, updates e monitoramento. Aplicável a N servidores via inventário.

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
| `site.yml` | Playbook principal — entry point |
| `ansible.cfg` | Configuração Ansible (inventory, forks, pipelining) |
| `inventories/production/group_vars/all.yml` | Variáveis globais |
| `roles/ssh/templates/sshd_config.j2` | Template SSH hardening (ADR #5) |
| `roles/fail2ban/templates/jail.local.j2` | Template jails fail2ban |
| `scripts/` | Codebase bash original (referência de migração) |
