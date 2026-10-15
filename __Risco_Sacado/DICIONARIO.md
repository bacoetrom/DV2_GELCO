# Dicionário de Dados — Risco Sacado

Crie estes itens no Configurador (SIGACFG) **antes** de compilar e usar os fontes. Os pontos de entrada `FINM010` e `FA070TIT` leem os campos `E1_X*`. Sem os campos, as baixas a receber passam a dar erro.

## SX3 — Campos

### SE1 — Contas a Receber

| Campo | Tipo | Tam. | Dec. | Título | Descrição | Contexto | Visual | Opções (X3_CBOX) | Ini. Padrão | F3 |
|---|---|---|---|---|---|---|---|---|---|---|
| `E1_XRISCO` | C | 1 | 0 | Risco Sacad | Título em risco sacado | Real | V | `S=Sim;N=Nao` | `"N"` | |
| `E1_XLOTRS` | C | 6 | 0 | Lote R.Sac. | Lote de risco sacado | Real | V | | | |
| `E1_XBANCO` | C | 3 (= A6_COD) | 0 | Bco R.Sacad | Banco do risco sacado | Real | V | | | SA6 |
| `E1_XDTRISC` | D | 8 | 0 | Dt.Env.Bco | Data de envio ao banco | Real | V | | | |
| `E1_XSTRIC` | C | 1 | 0 | Sit.R.Sacad | Situação do risco sacado | Real | V | `1=Enviado ao Banco;2=Nao pago ao Banco;3=Pago ao Banco` | | |

Os campos são apenas visuais (`V`). Somente a rotina PXFINA37 os altera.

### SA6 — Bancos

| Campo | Tipo | Tam. | Título | Descrição | F3 | Validação |
|---|---|---|---|---|---|---|
| `A6_XFORN` | C | = A2_COD | Forn.R.Sac. | Fornecedor do título a pagar do risco sacado | SA2 | `Vazio() .Or. ExistCpo("SA2", M->A6_XFORN)` |
| `A6_XLOJA` | C | = A2_LOJA | Loja R.Sac. | Loja do fornecedor do risco sacado | | `Vazio() .Or. ExistCpo("SA2", M->A6_XFORN + M->A6_XLOJA)` |

### SE2 — Contas a Pagar

| Campo | Tipo | Tam. | Título | Descrição | Visual |
|---|---|---|---|---|---|
| `E2_XORIRS` | C | soma de E1_FILIAL + E1_PREFIXO + E1_NUM + E1_PARCELA + E1_TIPO (sugestão: 30) | Orig.R.Sac. | Chave do título a receber de origem (risco sacado) | V |

## SIX — Índices

| Tabela | Ordem | Chave | Nickname | Descrição |
|---|---|---|---|---|
| SE1 | próxima livre | `E1_FILIAL+E1_XLOTRS` | `XLOTRS` | Lote de risco sacado |
| SE2 | próxima livre | `E2_FILIAL+E2_XORIRS` | `XORIRS` | Origem risco sacado |

## SX6 — Parâmetros

| Parâmetro | Tipo | Conteúdo padrão | Descrição |
|---|---|---|---|
| `MV_XRSNAT` | C | (definir) | Natureza do título a pagar gerado pelo risco sacado. Usar natureza **sem retenção de impostos** |
| `MV_XRSLOG` | L | `.F.` | Liga o log de diagnóstico do PE FINM010 (grupo `RISCOSACADO`) |

## Parâmetros de tela (ParamBox — sem SX1)

A tela `PXFINA37` e o relatório `PXFINR25` usam `ParamBox`, então **não há perguntas para criar no SX1**. A última seleção fica salva por usuário (chaves `PXFINA37` e `PXFINR25`).

| Rotina | Parâmetros |
|---|---|
| `PXFINA37` | Filial de/até, Vencto real de/até, Portador, Agência e Conta (vazio = todos), Borderô de/até, Lote de/até, Situação (1-Sem risco, 2-Enviado, 3-Não pago, 4-Pago, 5-Todos em risco), Banco do risco sacado (F3 SA6) |
| `PXFINR25` | Filial de/até, Lote de/até, Situação (1-Todas, 2-Enviado, 3-Não pago, 4-Pago) |

## Sequência (SXE/SXF)

O código do lote vem de `GetSXENum("SE1", "E1_XLOTRS")`. Se precisar começar em um número específico, ajuste o controle de numeração pelo Configurador.

## Menu (SIGAFIN)

| Item | Função | Local sugerido |
|---|---|---|
| Risco Sacado | `U_PXFINA37` | Atualizações > Contas a Receber |
| Lotes de Risco Sacado | `U_PXFINR25` | Relatórios > Contas a Receber |
