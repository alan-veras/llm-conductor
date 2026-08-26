# PLANO DE POST, `llm-conductor`

> O repo está construído e publicado, falta só o post LinkedIn. Este plano define ângulo,
> matéria-prima auditável, esqueleto, prompt de execução e análise adversarial do POST.
> **Estilo OBRIGATÓRIO:** anatomia de 7 blocos de [POST-STYLE.md](../../POST-STYLE.md), 
> o esqueleto da seção 4 já é uma instância dela (link só no primeiro comentário).
>
> **Posição na sequência: 3º**, depois dos posts de `llm-redteam-lab` (ataque) e
> `llm-security-evals` (defesa). Este mostra amplitude: **arquitetura de agentes com freio**.

---

## 1. Objetivo & público

| | |
|---|---|
| Objetivo | Mostrar engenharia de sistemas de agentes (custo, determinismo, controle), não segurança agora; converter para o repo |
| Público primário | Devs construindo produtos com LLM/agents que já sentiram a conta de tokens e o medo do passo errado |
| Público secundário | Tech leads/arquitetos; quem segue a série e quer ver outro lado das habilidades |
| Ação desejada | Clonar, rodar `make demo` e depois alimentar doc de 2 palavras para VER o freio funcionar |

## 2. Matéria-prima auditável (só cite isso, nada fora daqui)

| Claim possível | Fonte no repo |
|---|---|
| Inversão central: pipeline é código determinístico; o LLM só decide ENTRE estágios (`proceed`/`override`/`abort`) | README + `docs/architecture.md` |
| Gate entre todo par de estágios; `run all` para no primeiro gate que não for `pass` | architecture.md §Gate semantics |
| Economia de token: gate inteiro ~300-600 bytes; `inspect --jq` lê fatia de ~50 tokens | architecture.md §Token economy |
| Resultado agregado (honesto): disciplina de gates + `--jq` cortou run ponta-a-ponta estimado de ~315k para <50k tokens (**~-84%**, workload-específico; a alavanca é geral) | README + architecture.md |
| Estado atômico: `flock` + `jq` em temp-file + `mv`; estágios idempotentes e resumíveis | README §What I built |
| Armazenamento híbrido por padrão de acesso: JSON p/ estado por-run; SQLite (WAL) p/ métricas cross-run | architecture.md §Hybrid storage |
| 3 papéis least-privilege: operator / analyst / reviewer (2 on-demand); nada irreversível sem gate | `agents/` |
| Schemas JSON versionados MAJOR.MINOR, forward-compat estrita | architecture.md §Schema versioning |
| Demo observável do freio: documento de 2 palavras → gate `analyze` retorna `warn` → run PARA esperando decisão | README §Run it |
| Suite pura em bash: smoke + schema, 14 checks | README |

## 3. Ângulo & hooks (escolher 1, gerar variantes na execução)

- **A (controle, recomendado):** *"Deixei um LLM dirigir meu pipeline. Antes disso, instalei um freio."*
- **B (dinheiro):** *"Cortei ~84% do custo em tokens de um sistema agêntico. O segredo não foi prompt engineering."*
- **C (anti-hype):** *"O problema de 'agente roda pipeline' não é o agente. É deixar ele decidir tudo em texto livre."*

Regra: o número -84% SEMPRE vem acompanhado da ressalva "estimativa workload-específica", 
a honestidade aqui é o mesmo diferencial dos outros repos.

## 4. Esqueleto do post, instância dos 7 blocos ([POST-STYLE.md](../../POST-STYLE.md))

| # | Bloco | Conteúdo deste repo |
|---|---|---|
| 1 | Origem conversacional + tese não-dita | construí um sistema agêntico inteiro e aprendi o que ninguém posta: o difícil não é fazer o agente AGIR, é fazer ele PARAR |
| 2 | Concessão ("Beleza.") | hoje um LLM roda pipeline inteiro sozinho: chama tool, decide tudo. Impressionante |
| 3 | Pergunta-pivô | mas quando ele erra no meio do caminho, quem freia, e quanto custa descobrir tarde? |
| 4 | Exagero | se agente autônomo sem freio funcionasse, já não existiria bug em produção nenhum |
| 5 | Bullets-pergunta (3-5) | o run estoura o budget de token e você só vê na fatura? · mesma entrada, caminho diferente: como auditar o que aconteceu? · passo errado no estágio 2 cascata até o fim, quem para isso? · ação irreversível sem humano no loop: coragem ou negligência? (o "-84% com ressalva" entra aqui dentro, como dado) |
| 6 | Aforismo espelhado | deixar o agente agir é o caminho feliz; instalar o freio é o que sobra quando o caminho feliz chega na fatura |
| 7 | Pergunta aberta final | o seu agente pede permissão entre os passos, ou você confia e reza? |

How-to-run (`make demo` + doc de 2 palavras pra ver o freio parar o run), teaser da série e o link vão no PRIMEIRO COMENTÁRIO.

## 5. Checklist de conversão LinkedIn

- [ ] Primeira linha funciona SOZINHA antes do "ver mais"
- [ ] ≤1300 chars; parágrafos de 1-2 linhas
- [ ] -84% citado COM a ressalva workload-específica (sempre juntos, sem exceção)
- [ ] Zero buzzword vazio ("autonomia total", "agente revolucionário")
- [ ] Diferente dos 2 posts anteriores: aqui é arquitetura/custo, não ataque/defesa, leitor da série vê amplitude
- [ ] Bloco 2 existe: o texto CONCEDE antes de virar a mesa ("Beleza.")
- [ ] Termina em interrogação (bloco 7)
- [ ] Zero link no corpo; primeiro comentário preparado (link + how-to-run)
- [ ] Máx 2 hashtags no fim (#LLM #Agents)

## 6. Prompt de execução (colar em sessão nova do opencode)

```
CONTEXTO: quero criar o post LinkedIn do repo llm-conductor (já publicado).
Leia README.md, docs/architecture.md, agents/, schemas/ e docs/POST-PLAN.md
(a especificação deste post).

TAREFAS:
1. Gere 3 variantes do post em pt-BR seguindo a ANATOMIA DE 7 BLOCOS de ../../POST-STYLE.md
   (a seção 4 deste plano é a instância concreta), variando o bloco 1 entre os hooks A/B/C
   da seção 3. Tom informal real, parágrafos curtos, SEM link no corpo, terminando em pergunta.
   Gere também o texto do PRIMEIRO COMENTÁRIO (link + make demo + teaser da série).
2. Audite cada variante claim a claim contra a matéria-prima §2: o -84% vem sempre com a
   ressalva? Algum número inventado ou arredondado além do documentado? Marque OK/NOK.
3. Recomende a vencedora com justificativa (conversão, clareza, honestidade, amplitude
   em relação aos posts anteriores da série).
4. Salve tudo em docs/post-draft.md com o checklist §5 marcado item a item.
5. Sugira 2 melhorias concretas na vencedora.

REGRAS: nada fora da matéria-prima §2; a ressalva do -84% NUNCA pode ser cortada;
zero hype de agentes autônomos; link SOMENTE no primeiro comentário; nunca inventar
pessoa/diálogo real no bloco 1. NÃO publique nada, só gerar arquivos locais.
```

## 7. 🔴 Análise adversarial do POST

Rodar numa sessão nova depois do rascunho pronto. Não edita nada, só julga.

```
CONTEXTO: análise ADVERSARIAL do rascunho em docs/post-draft.md do repo llm-conductor.
Leia o rascunho, README.md, docs/architecture.md e docs/POST-PLAN.md.
Você é revisor hostil triplo: usuário cético de LinkedIn, arquiteto de sistemas cético
(já viu 100 projetos de agent framework prometerem demais), hiring manager técnico de 45s.
NÃO edite nada.

EIXOS DE ATAQUE:
1. HONESTIDADE: o -84% aparece sem ressalva em algum lugar do rascunho? Parece benchmark
   generalizável quando é estimativa workload-específica?
2. GANCHO: a linha 1 para o scroll? Promete exatamente o que as linhas seguintes entregam?
3. CLAREZA EM 45s: alguém que NUNCA construiu agente entende a inversão (pipeline determinístico,
   LLM decide entre estágios)? Jargão (gate, WAL, jq) sem tradução?
4. POSICIONAMENTO: diferencia do mar de "agent frameworks"? Vende PRINCÍPIO (freio, economia,
   determinismo) ou mais uma tool?
5. TOM: engenheiro mostrando decisão de arquitetura com trade-offs, ou pitch?
6. CONVERSÃO: CTA único? O "como sentir o freio" (make demo + doc de 2 palavras) está presente
   e é irresistível?
7. FORMATO: cabe no feed? Respira? Listas renderizam em texto simples?

SAÍDA OBRIGATÓRIA: relatório markdown, achados P1/P2/P3 com evidência (linha do rascunho)
e correção de 1 linha. Veredito: "pronto para publicar: SIM/NÃO" + top 3 fixes.
Eixos limpos: declare "sem achados".
```

## 8. Fluxo pós-análise & publicação

1. P1 → corrigir → re-rodar eixos afetados.
2. Veredito SIM → aplicar P2 → publicar **~3-7 dias após o post do llm-security-evals**
   (mesma janela: terça/quarta 8h-10h SP).
3. Primeiro comentário próprio: link do repo + 1 linha sobre os dois posts anteriores
   (quem chegou agora entende que é uma série).
4. Responder comentários técnicos nas primeiras 2h.

### Fechamento da trilogia

Com os 3 posts no ar, o perfil conta: *eu ataco LLMs (lab), travo regressões deles (evals)
e sei construir a infraestrutura de agentes com freio (conductor)*. Os próximos posts
(devsecops-pipeline, k8s-security-lab, poisoned-annotations) herdam essa audiência.
