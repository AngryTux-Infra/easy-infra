# Medindo Resultados entre Providers e Modelos

Este sistema de issues cria uma oportunidade natural para comparar a performance de diferentes AI agents.

## Por que medir

Modelos diferentes têm forças diferentes. Um pode ser melhor em analisar requisitos (PRD), outro em tomar decisões técnicas (ADR), outro em executar código (Task). Sem medir, você escolhe por hype.

## O que medir

### 1. Taxa de aprovação na primeira review

O agente entregou algo que passou na review sem precisar de feedback?

```
Aprovação 1ª tentativa = issues closed sem volta para in-progress / total de issues
```

Um agente que entrega certo na primeira vez economiza ciclos de review.

### 2. Aderência a critérios de aceite

Dos critérios listados na issue, quantos o agente atendeu?

```
Aderência = critérios atendidos / critérios totais
```

Isso mede se o agente **leu e seguiu** o que foi pedido, não se ele "fez algo".

### 3. Qualidade das referências

O agente navegou os Refs? O output demonstra que ele leu o PRD e ADR antes de agir?

Isso é qualitativo — você avalia lendo o output.

### 4. Autonomia de transições

O agente fez as transições de status corretamente? Pegou issues `ready`, moveu para `in-progress`, entregou em `review`?

```bash
# Ver histórico de labels de uma issue (via timeline)
gh api repos/org/repo/issues/N/timeline --paginate | jq '.[].event'
```

## Como comparar

### Método: mesma issue, diferentes agentes

1. Crie uma issue com requisitos claros e critérios verificáveis
2. Dê a mesma issue para dois agentes diferentes (em branches separados)
3. Compare os resultados contra os critérios de aceite

### Método: pipeline completo

1. Crie um PRD
2. Peça para o agente gerar ADR + Tasks a partir do PRD
3. Peça para executar as tasks
4. Avalie o resultado final

Isso testa a **cadeia completa**: compreensão de requisitos → decisão → execução.

### Registro

Use comentários na issue para registrar observações:

```bash
gh issue comment N --body "$(cat <<'EOF'
## Avaliação — [Provider/Modelo]

- Critérios atendidos: 4/5
- Precisou de feedback: sim, 1 rodada
- Navegou refs: sim, leu PRD #1 e ADR #2
- Transições corretas: sim
- Observações: não tratou edge case do critério 3
EOF
)"
```

## Comparações que fazem sentido

| Aspecto | O que revela |
|---------|-------------|
| PRD → ADR | Capacidade de análise e tomada de decisão |
| ADR → Tasks | Capacidade de decompor decisão em trabalho concreto |
| Task → Entrega | Capacidade de execução e atenção a critérios |
| Bug → Fix | Capacidade de diagnóstico e correção |
| Cadeia completa | Performance end-to-end em um projeto real |

## Limitações

- O resultado depende muito da **qualidade da issue** — issues vagas geram resultados incomparáveis
- Modelos mudam com frequência — uma medição de hoje pode não valer em 3 meses
- Este sistema mede **aderência a instruções**, não criatividade ou inovação
