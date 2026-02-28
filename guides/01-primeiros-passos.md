# Primeiros Passos

Como começar a usar este template no seu projeto.

## Pré-requisitos

- Conta no GitHub
- `gh` CLI instalado e autenticado (`gh auth login`)
- Um projeto (novo ou existente) onde quer aplicar o sistema

## Caminho A — Projeto novo (começar do zero)

Use este caminho quando está criando algo do zero e quer o sistema de issues desde o início.

### 1. Clone o template

```bash
git clone https://github.com/AngryTux-Infra/agile-issues-template.git
```

### 2. Crie seu repo

```bash
gh repo create meu-org/meu-projeto --private --clone
cd meu-projeto
```

### 3. Copie o que precisa

```bash
cp ../agile-issues-template/templates/CONTRIBUTING.md .
cp -r ../agile-issues-template/templates/issues/ docs/templates/
cp -r ../agile-issues-template/guides/ docs/guides/
```

### 4. Aplique os labels

```bash
# Ver os labels definidos
cat ../agile-issues-template/templates/labels.json | jq '.[].name'

# Criar cada label (exemplo)
gh label create "type:prd" --repo meu-org/meu-projeto \
  --color "0052CC" --description "Product Requirements Document (RF/RNF) — only editable manually"
```

Faça isso para todos os 14 labels. Se preferir, crie um script que leia o JSON.

**Remova os labels default** do GitHub que não usamos:

```bash
for label in "bug" "duplicate" "enhancement" "good first issue" \
  "help wanted" "invalid" "question" "wontfix" "documentation"; do
  gh label delete "$label" --repo meu-org/meu-projeto --yes 2>/dev/null
done
```

## Caminho B — Projeto existente (organizar o que já existe)

Use este caminho quando já tem código e quer organizar o trabalho usando o sistema de issues.

### 1. Clone o template dentro do seu projeto

```bash
cd ~/meu-projeto-existente
git clone https://github.com/AngryTux-Infra/agile-issues-template.git .standards
```

### 2. Copie os arquivos relevantes

```bash
cp .standards/templates/CONTRIBUTING.md .
cp -r .standards/templates/issues/ docs/templates/
cp -r .standards/guides/ docs/guides/

# Se usa Claude Code
cp .standards/claude/CLAUDE.md .
```

### 3. Remova o clone temporário

```bash
rm -rf .standards
```

### 4. Aplique os labels e remova os defaults

Mesmo processo do Caminho A — use o `labels.json` como referência.

### 5. Mapeie o trabalho existente em issues

Olhe para o estado atual do projeto e crie issues para o que já existe:

- **Funcionalidades planejadas** → PRDs
- **Decisões técnicas já tomadas** → ADRs (documente retroativamente)
- **Trabalho em andamento** → Tasks com `status:in-progress`
- **Bugs conhecidos** → Bugs com `status:draft` ou `status:ready`

## Depois de configurar (qualquer caminho)

### Crie sua primeira issue

Use o template de PRD como base:

```bash
gh issue create --repo meu-org/meu-projeto \
  --label "type:prd,status:draft,P1" \
  --title "Definir cardápio do evento" \
  --body "$(cat <<'EOF'
## Contexto
Evento corporativo para 50 pessoas em 15/04.

## Requisitos Funcionais (RF)
- [ ] Entrada + prato principal + sobremesa
- [ ] Opções para vegetarianos (min 30% do cardápio)
- [ ] Pelo menos uma opção sem glúten

## Requisitos Não-Funcionais (RNF)
- [ ] Orçamento máximo: R$2.000
- [ ] Fornecedor deve entregar no local até 11h

## Critérios de aceite
- [ ] Menu cobre todas as restrições alimentares listadas
- [ ] Total dentro do orçamento
- [ ] Fornecedor confirmado com 7 dias de antecedência

## Fora de escopo
- Decoração
- Bebidas alcoólicas

## Refs
<!-- Primeira issue — sem refs -->
EOF
)"
```

### Convide o agente

Quando a issue estiver `status:ready`, aponte o agente para ela:

> "Leia a issue #1 do repo meu-org/meu-projeto e trabalhe nela seguindo as convenções do CONTRIBUTING.md."

Ou no modo autônomo:

> "Leia o CONTRIBUTING.md deste repo. Crie um PRD para implementar autenticação OAuth2 na API, decomponha em tasks, e execute. Eu reviso quando chegar em review."

O agente navega issues, entende contexto via Refs, e produz o output esperado. Você acompanha tudo pelos labels.

## Próximos passos

- Leia [Criando Issues](02-criando-issues.md) para entender modos manual vs automático
- Leia [Agentes](03-agentes.md) para entender como agentes navegam o sistema
- Leia [Convenções](../docs/convencoes.md) para entender por que PRD, ADR, Task e Bug existem
