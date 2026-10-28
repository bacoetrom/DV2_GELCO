# Dicionário de Dados — Risco Sacado (Contas a Pagar)

Crie estes itens no Configurador (SIGACFG) **antes** de compilar e usar os fontes. Os pontos de entrada `FINM020`, `FA080TIT`, `FA050UPD` e `F240TIT` só agem quando os campos existem (`U_PXRSDicionario`). Mesmo assim, crie o dicionário antes de compilar.

> **Versão anterior (Contas a Receber):** se os campos `E1_XRISCO`, `E1_XLOTRS`, `E1_XBANCO`, `E1_XDTRISC` e `E1_XSTRIC`, o índice SE1 `XLOTRS` e a sequência `SE1/E1_XLOTRS` já foram criados no ambiente, remova-os. Antes, tire do RPO os PEs `FINM010` e `FA070TIT`.

## SX3 — Campos

### SE2 — Contas a Pagar

| Campo | Tipo | Tam. | Dec. | Título | Descrição | Contexto | Visual | Opções (X3_CBOX) | Ini. Padrão | F3 |
|---|---|---|---|---|---|---|---|---|---|---|
| `E2_XRISCO` | C | 1 | 0 | Risco Sacad | Título em risco sacado | Real | V | `S=Sim;N=Nao` | `"N"` | |
| `E2_XLOTRS` | C | 6 | 0 | Lote R.Sac. | Lote de risco sacado | Real | V | | | |
| `E2_XBANCO` | C | 3 (= A6_COD) | 0 | Bco R.Sacad | Banco do risco sacado | Real | V | | | SA6 |
| `E2_XDTRISC` | D | 8 | 0 | Dt.Env.Bco | Data em que o título foi disponibilizado ao banco | Real | V | | | |
| `E2_XSTRIC` | C | 1 | 0 | Sit.R.Sacad | Situação do risco sacado | Real | V | `1=Disponivel;2=Antecipado;3=Em aberto;9=Em processamento` | | |
| `E2_XDTANT` | D | 8 | 0 | Dt.Antecip. | Data da antecipação pelo fornecedor | Real | V | | | |
| `E2_XORIRS` | C | 40 | 0 | Orig.R.Sac. | Chave do título de origem (FILIAL+PREFIXO+NUM+PARCELA+TIPO+FORNECE+LOJA). Preenchido só no título a pagar do banco | Real | V | | | |

Os campos são apenas visuais (`V`). Só a rotina `PXFINA37` os altera.

**Situação `9` (Em processamento)** — gravada pela própria rotina antes de qualquer ExecAuto da antecipação ou do estorno. Um título fica nessa situação apenas quando o processo é interrompido e a compensação automática também falha; nesse estado toda movimentação do título é bloqueada (PEs `FINM020`, `FA080TIT`, `FA050UPD`, `F240TIT`) e a resolução é feita pela ação **Conciliar** da `PXFINA37`. Se o ambiente ainda não tiver o `9` no `X3_CBOX`, a rotina funciona (o campo é `C(1)`), mas o browse e o relatório mostram a descrição vinda de `U_PXRSDescSituacao`, não a do dicionário.

> `E2_XORIRS` precisa comportar a soma dos tamanhos de `E2_FILIAL + E2_PREFIXO + E2_NUM + E2_PARCELA + E2_TIPO + E2_FORNECE + E2_LOJA` no ambiente. O padrão (2+3+9+2+3+6+2 = 27) cabe em 40.

### SA6 — Bancos

| Campo | Tipo | Tam. | Título | Descrição | F3 | Validação |
|---|---|---|---|---|---|---|
| `A6_XFORN` | C | = A2_COD | Forn.R.Sac. | Fornecedor do título a pagar do banco no risco sacado | SA2 | `Vazio() .Or. ExistCpo("SA2", M->A6_XFORN)` |
| `A6_XLOJA` | C | = A2_LOJA | Loja R.Sac. | Loja do fornecedor do risco sacado | | `Vazio() .Or. ExistCpo("SA2", M->A6_XFORN + M->A6_XLOJA)` |

## SIX — Índices

| Tabela | Ordem | Chave | Nickname | Descrição |
|---|---|---|---|---|
| SE2 | próxima livre | `E2_FILIAL+E2_XLOTRS` | `XLOTRS` | Lote de risco sacado |
| SE2 | próxima livre | `E2_FILIAL+E2_XORIRS` | `XORIRS` | Origem do risco sacado |

## SX6 — Parâmetros

| Parâmetro | Tipo | Conteúdo sugerido | Descrição |
|---|---|---|---|
| `MV_XRSNAT` | C | (definir) | Natureza do título a pagar do banco. Use natureza **sem retenção de impostos** |
| `MV_XRSPRF` | C | `RSC` | Prefixo do título a pagar do banco |
| `MV_XRSTIP` | C | `DP` | Tipo do título a pagar do banco (precisa existir na tabela 05 do SX5) |
| `MV_XRSMOT` | C | `RSA` | Motivo de baixa usado na antecipação (precisa estar cadastrado e **sem movimentação bancária**) |
| `MV_XRSLOG` | L | `.F.` | Liga o log de diagnóstico do PE `FINM020` (grupo `RISCOSACADO`) |

## Motivo de baixa

Cadastre no cadastro de motivos de baixa do SIGAFIN:

| Sigla | Descrição | Movimenta banco | Observação |
|---|---|---|---|
| `RSA` | RISCO SACADO ANTEC | **Não** | Baixa do título do fornecedor quando ele antecipa com o banco. A rotina valida com `MovBcoBx()` |

## Numeração do título do banco

O número é `E2_XLOTRS` (6) + sequência com zeros no restante de `E2_NUM`, por filial + prefixo (`MV_XRSPRF`) + tipo (`MV_XRSTIP`) + fornecedor do banco. Exemplo: lote `000123`, 1º título antecipado → `000123001`. Com `E2_NUM` de 9 posições, cabem 999 títulos antecipados por lote.

## Parâmetros de tela (ParamBox, sem SX1)

A tela `PXFINA37` e o relatório `PXFINR25` usam `ParamBox`, então **não há perguntas para criar no SX1**. A última seleção fica salva por usuário (chaves `PXFINA37` e `PXFINR25`).

| Rotina | Parâmetros |
|---|---|
| `PXFINA37` | Filial de/até, Vencto real de/até, Fornecedor de/até, Natureza de/até, Lote de/até, Situação (1-Sem risco, 2-Disponível, 3-Antecipado, 4-Em aberto, 5-Todos em risco), Banco do risco sacado (F3 SA6) |
| `PXFINR25` | Filial de/até, Lote de/até, Situação (1-Todas, 2-Disponível, 3-Antecipado, 4-Em aberto) |

## Sequência (SXE/SXF)

O código do lote vem de `GetSXENum("SE2", "E2_XLOTRS")`. Para começar num número específico, ajuste o controle de numeração no Configurador.

## Menu (SIGAFIN)

| Item | Função | Local sugerido |
|---|---|---|
| Risco Sacado | `U_PXFINA37` | Atualizações > Contas a Pagar |
| Lotes de Risco Sacado | `U_PXFINR25` | Relatórios > Contas a Pagar |
