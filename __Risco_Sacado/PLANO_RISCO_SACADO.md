---
goal: Risco Sacado em Contas a Pagar — disponibilizar títulos de fornecedores ao banco; na antecipação, baixar o título do fornecedor e gerar o título a pagar ao banco
version: 3.2
date_created: 2026-10-13
last_updated: 2026-10-19
status: 'In progress'
tags: [feature, SIGAFIN, SE2, SA6, FK2, FWMarkBrowse, FINM020, FINA080, FINA050, ExecAuto, TReport]
---

# Plano — Risco Sacado (Contas a Pagar)

## Introdução

O risco sacado (*confirming*) passa a ser feito no **Contas a Pagar (SE2)**. A empresa (sacada) envia ao banco, em **lotes**, os títulos que deve aos fornecedores. O banco oferece a antecipação ao fornecedor, que pode aceitar ou não:

```text
Disponível ──► Antecipado ──► baixa o SE2 do fornecedor + gera SE2 para o banco (A6_XFORN)
           └─► Em aberto  ──► o título volta ao fluxo normal do Contas a Pagar
```

- **Disponível (`1`):** o título foi enviado ao banco e aguarda a decisão do fornecedor. **Só a rotina de Risco Sacado pode movimentá-lo.**
- **Antecipado (`2`):** o fornecedor antecipou com o banco. A rotina baixa o título do fornecedor, com um motivo que não movimenta banco, e gera um título a pagar para o banco, com o mesmo valor e vencimento. O título original fica protegido: **só a rotina pode estornar**.
- **Em aberto (`3`):** o fornecedor não antecipou. O título segue em aberto, sem restrição: baixa, borderô, alteração etc. funcionam normalmente.

> **Substitui a v2.1** (risco sacado no Contas a Receber/SE1). A seção 9 lista o que muda.

## 1. Arquivos

| Arquivo | Conteúdo | Situação |
|---|---|---|
| `ROTINAS/PXFINA37.tlpp` | Tela: ParamBox + FWTemporaryTable + FWMarkBrowse sobre **SE2**. Ações: Marcar/Desmarcar/Inverter, Disponibilizar (gera lote), Antecipado, Em aberto, Estornar Situação, Excluir Lote | 🔄 Reescrever (SE1 → SE2) |
| `ROTINAS/PXFINA37S.tlpp` | Serviços: fornecedor do banco, validações, baixa do SE2 do fornecedor (ExecAuto `FINA080`), geração/exclusão do SE2 do banco (ExecAuto `FINA050`), estorno, regra de bloqueio `U_PXRSBloqueia`, log | 🔄 Reescrever |
| `PONTOS DE ENTRADA/FINM020.tlpp` | PE MVC da **baixa a pagar** (FK2). `MODELPOS`: bloqueia baixa e cancelamento de títulos `1`/`2` fora da rotina (cobre FINA080, FINA090, FINA430, FINA340, FINA290 etc.) | 🆕 Novo |
| `PONTOS DE ENTRADA/FA080TIT.tlpp` | Barreira antecipada na baixa manual/ExecAuto do FINA080 (status `1`/`2`) | 🆕 Novo |
| `PONTOS DE ENTRADA/FA050UPD.tlpp` | Pré-validação (antes da tela, fora da transação) que bloqueia a alteração e a exclusão do título `1`/`2` e do SE2 do banco fora da rotina. Substitui `FA050ALT`/`FA050DEL`: o `FA050DEL` roda dentro da transação de exclusão, e `Help()` ali violaria a CA1002 | 🆕 Novo |
| `PONTOS DE ENTRADA/F240TIT.tlpp` | Impede que um título `1`/`2` entre em borderô de pagamento (FINA240/FINA241) | 🆕 Novo |
| `PONTOS DE ENTRADA/FINM010.tlpp` | PE da baixa a receber | ❌ Remover do projeto e do RPO |
| `PONTOS DE ENTRADA/FA070TIT.tlpp` | Barreira da baixa a receber | ❌ Remover do projeto e do RPO |
| `RELATORIOS/PXFINR25.tlpp` | TReport dos lotes sobre SE2, com totais por lote e situação, e o SE2 do banco gerado | 🔄 Ajustar |
| `DICIONARIO.md` | Campos `E2_X*`, índices, parâmetros (SX6), motivo de baixa e menu | 🔄 Reescrever |

## 2. Requisitos

| ID | Requisito | Implementação |
|---|---|---|
| REQ-001 | Filtros: Filial de/até, Vencimento real de/até, Fornecedor/Loja de/até, Natureza de/até, Lote de/até, Situação e Banco do risco | `PXFINA37` – `CarregaTitulos` |
| REQ-002 | Marcar Todos, Desmarcar Todos e Inverter (também com clique no cabeçalho) | `MarcaTodos` (sem alteração) |
| REQ-003 | **Disponibilizar**: um lote por filial (`GetSXENum("SE2","E2_XLOTRS")`), grava `E2_XLOTRS`, `E2_XBANCO`, `E2_XRISCO='S'`, `E2_XDTRISC`, `E2_XSTRIC='1'`. Só para títulos elegíveis (REQ-004) | `AcaoDisponibilizar`/`ProcessaLote` |
| REQ-004 | Elegível: `E2_SALDO = E2_VALOR` (sem baixa parcial), fora de borderô (`E2_NUMBOR` vazio), sem liberação pendente, tipo diferente de `PA`, `NDF`, `PR`, abatimentos (`-` na 3ª posição) e impostos (`TX`, `ISS`, `INS`), e fornecedor diferente do fornecedor do banco | `ValidaElegivel` |
| REQ-005 | **Antecipado** (1 → 2), por título, em passos conferidos no banco de dados: (0) grava `E2_XSTRIC='9'` (Em processamento); (a) baixa total do SE2 do fornecedor com o motivo `MV_XRSMOT` (não movimenta banco); (b) inclusão do SE2 do banco; (c) grava `E2_XSTRIC='2'` e `E2_XDTANT`. **Não existe transação envolvendo os ExecAuto** — ver "Atomicidade" na seção de riscos: a falha de um passo dispara a **compensação** (exclui o SE2 do banco se existir e cancela a baixa), e se a compensação falhar o título fica em `9` para a ação **Conciliar**. O processamento segue para o próximo título, salvo se sobrar transação aberta | `AcaoAntecipado` → `U_PXRSAntecipa` → `ExecutaAntecipa`/`CompensaFalha` |
| REQ-006 | SE2 do banco: fornecedor `A6_XFORN`/`A6_XLOJA`, prefixo `MV_XRSPRF`, número = lote + sequência (`ProximoNumero`, sob `LockByName` do lote), tipo `MV_XRSTIP`, natureza `MV_XRSNAT`, emissão = data da antecipação, vencimento = `E2_VENCTO`/`E2_VENCREA` do original, valor = **valor líquido efetivamente baixado** do original (`E2_SALDO` antes da baixa menos as retenções geradas na baixa, lidas do `FK2_VALOR`/SE5 da baixa; ver RISK-001), histórico com fornecedor/título de origem, `E2_XORIRS` = chave do original e entidades contábeis copiadas | `U_PXRSGeraPagarBanco` |
| REQ-007 | **Em aberto** (1 → 3): só muda a situação. A partir daí o título não tem restrição | `AcaoSituacao` |
| REQ-008 | **Estornar Situação**: 3 → 1, só sem baixa e fora de borderô desde o envio. 2 → 1 só se o SE2 do banco estiver sem baixa e fora de borderô: grava `9`, exclui o SE2 do banco (`FINA050` 5), cancela a baixa do fornecedor (`FINA080` 5) e grava `1`. Cada passo é conferido no banco de dados; sem transação envolvendo os ExecAuto (mesmo motivo do REQ-005). Falha no meio deixa o título em `9` para a ação **Conciliar** | `AcaoEstorno` → `U_PXRSEstornaAntecipacao` → `DesfazAntecipa` |
| REQ-009 | **Excluir Lote**: devolve para "sem risco" os títulos do lote, só se nenhum estiver `2` (Antecipado) ou com movimento após o envio | `AcaoExcluirLote` |
| REQ-010 | **Bloqueio fora da rotina**, para títulos com `E2_XRISCO='S'` e `E2_XSTRIC` `1`, `2` ou `9`: baixa (todas as origens), cancelamento/exclusão da baixa, borderô, alteração e exclusão | PEs da seção 3 + `U_PXRSBloqueia` |
| REQ-011 | **Proteção do SE2 do banco** (`E2_XORIRS` preenchido): exclusão e alteração bloqueadas fora da rotina. Baixa, borderô e CNAB do SE2 do banco ficam **liberados** (é o pagamento ao banco) | `FA050UPD` |
| REQ-012 | Os PEs liberam os ExecAuto da própria rotina por `U_PXRSEmRotina()` = `FwIsInCallStack("U_PXRSANTECIPA")`, `FwIsInCallStack("U_PXRSESTORNAANTECIPACAO")` ou `FwIsInCallStack("U_PXRSCONCILIA")`, sem variável Private | `PXFINA37S` |
| REQ-013 | Ações por seleção individual ou por lote (filtro Lote de/até + Marcar Todos) | `PXFINA37` |
| REQ-014 | Relatório do lote com totais por situação e o título do banco gerado | `PXFINR25` |
| REQ-015 | **Conciliar**: resolve o título cuja antecipação ficou incompleta, decidindo pelo estado real dos registros — baixa + SE2 do banco presentes → grava `2`; baixa sem SE2 do banco → gera o SE2 do banco e grava `2`; demais casos → desfaz o que existir e grava `1`. Idempotente e também aplicável aos títulos que ficaram inconsistentes antes desta correção. O filtro `6-Inconsistentes` da tela lista os candidatos (`9`, `2` sem baixa, `1` já baixado) | `AcaoConcilia` → `U_PXRSConcilia` → `ConcluiAntecipa`/`DesfazAntecipa` |

### Domínio `E2_XSTRIC`

| Valor | Significado | Baixa / borderô / alteração / exclusão fora da rotina |
|---|---|---|
| `1` | Disponível | **Bloqueado** |
| `2` | Antecipado | **Bloqueado** (o original já está baixado; cancelar a baixa ou excluir também é bloqueado) |
| `3` | Em aberto | Liberado (fluxo normal) |
| `9` | Em processamento | **Bloqueado** (antecipação ou estorno interrompido e sem compensação possível; resolver pela ação Conciliar) |

```text
(sem risco) --Disponibilizar--> 1 --Antecipado--> 2   (baixa SE2 fornecedor + gera SE2 banco)
                                1 --Em aberto---> 3   (fluxo normal)
                           3 --Estornar--> 1          (sem baixa/borderô após o envio)
                           2 --Estornar--> 1          (SE2 do banco sem baixa/borderô: exclui SE2 banco + cancela baixa)
       lote --Excluir Lote--> (sem risco)             (nenhum título 2 e sem movimento após o envio)
```

### Pontos de bloqueio (REQ-010)

| Movimento | Rotina padrão | Barreira |
|---|---|---|
| Baixa manual | FINA080 / FINA750 | `FA080TIT` + `FINM020` `MODELPOS` |
| Baixa automática / lote | FINA090 / FINA091 | `FINM020` `MODELPOS` |
| Retorno CNAB a pagar | FINA430 | `FINM020` `MODELPOS` |
| Compensação a pagar | FINA340 | `FINM020` `MODELPOS` (VAL-002) |
| Fatura a pagar | FINA290 | `FINM020` `MODELPOS` (VAL-002) |
| Cancelamento/exclusão da baixa (status `2`) | FINA080 / FINA090 | `FINM020` `MODELPOS` (operação de estorno) |
| Borderô de pagamento | FINA240 / FINA241 | `F240TIT` (título não entra na seleção) |
| Alteração | FINA050 / FINA750 | `FA050UPD` (`FwIsInCallStack("FA050ALTER")`) |
| Exclusão | FINA050 / FINA750 | `FA050UPD` (`FwIsInCallStack("FA050DELET")`) |

A regra fica centralizada em `U_PXRSBloqueia(cOperacao) → cMsg`, com o SE2 posicionado. Assim todos os PEs usam a mesma decisão e a mesma mensagem: *"Título em Risco Sacado – <situação> (lote X). Movimente pela rotina PXFINA37."*

## 3. Restrições aplicadas

- Arquivos em TLPP com `tlpp-core.th` + `totvs.ch`, codificação CP-1252, sem `IIF`, sem `Function` pública e sem `ConOut`. O log usa `FWLogMsg`, grupo `RISCOSACADO`.
- Nome do arquivo de cada PE = nome do PE, sem prefixo `U_` na declaração.
- As queries usam `FWExecStatement` com parâmetros (bind), `D_E_L_E_T_` e filtro de filial.
- Nenhuma interface dentro de `Begin Transaction` ou do commit do MVC. Os erros de cada título vão para o array de log, exibido **depois** do processamento. Nos PEs, os erros vão para `SetErrorMessage` (MVC), `Help` (tela) ou `AutoGrLog` (ExecAuto/`IsBlind()`).
- **Nenhum `Begin Transaction` próprio envolvendo `MsExecAuto`.** As transações próprias existem só onde a rotina grava os campos `X` da SE2 (`U_PXRSMarcaStatus`, Disponibilizar, Em aberto, Excluir Lote) — blocos curtos, sem ExecAuto e sem interface.
- O sucesso de cada passo é confirmado pelo **estado dos registros** (`U_PXRSEstadoTitulo`), não só por `lMsErroAuto`: divergência entre o retorno do ExecAuto e o banco de dados é tratada como falha.
- As ações verificam `InTransact()` antes de começar (não executam ExecAuto dentro de transação de terceiros) e após cada título no laço: transação aberta interrompe o processamento, para não efetivar gravações pendentes do título anterior.
- O semáforo do lote (`LockByName`) só é liberado quando foi realmente obtido, e a liberação é garantida em todos os caminhos de saída, inclusive no `Catch`.
- `SuperGetMV` é lido **uma vez**, antes dos laços (parâmetros carregados num JSON `jCfg` no início da ação).
- A marca do browse fica em `FWTemporaryTable` (`TR_OK`). O `E2_OK` não é usado.
- Não há troca de `cFilAnt`. As ações processam a filial do título com `xFilial("SE2", cFilTit)`. O ExecAuto `FINA080`/`FINA050` roda na filial logada, então a tela **só permite Antecipar/Estornar títulos da filial logada** (os demais vão para o log). Disponibilizar e Em aberto, que só gravam campos `X`, continuam multi-filial.
- Os PEs restauram a área (`GetArea`/`RestArea`) e só agem quando `E2_XRISCO = 'S'` ou `E2_XORIRS` está preenchido. Nos demais títulos, o custo é só a leitura dos campos.
- `FWModelActive()` é salvo e restaurado em volta de cada ExecAuto aninhado.

## 4. Validação de símbolos (2026-10-19)

O TDN bloqueou o acesso automático (HTTP 403). Os símbolos foram validados nos **fontes padrão da release 12.1.2510** (`D:\99-FONTES\R2510-2026-Julho\...\adm`) e em PEs reais de outros projetos.

| Símbolo | Evidência | Uso |
|---|---|---|
| PE MVC `FINM020` | ✅ `FINM020.prw`: `MPFormModel():New('FINM020')`, `MASTER → FKADETAIL → FK2DETAIL`, `E5_OPERACAO` no MASTER, `FK2_TPDOC='ES'` no estorno | Barreira central da baixa (`MODELPOS`) |
| `FA080TIT` | ✅ `FINA080.PRX:3254`: `ExecBlock("FA080TIT")` antes do `Begin Transaction` (3411). `.F.` em ExecAuto aborta a baixa | Barreira antecipada no FINA080 |
| `FA050UPD` | ✅ `FINA050.PRX:1008/2095/4925`: pré-validação de inclusão (`FA050Inclu`), exclusão (`FA050Delet`) e alteração (`FA050Alter`), antes da tela | Bloqueio da alteração/exclusão |
| `FA050DEL` | ⚠️ `FINA050.PRX:2265`: executa **dentro** da transação de exclusão | **Descartado** (CA1002) |
| `FA050ALT` | ⚠️ `FINA050.PRX:4953`: entra no `TudoOk` da alteração | Descartado: `FA050UPD` cobre antes da tela |
| `F240TIT` | ✅ `FINA240.PRX:2145/2345/2459`: registro corrente = `cAliasSE2` (`SE2` ou `SE2TMP` com `NUM_REG`). PARAMIXB `.T.` na marcação individual (o PE desfaz a marca) | Bloqueio do borderô |
| `FINA080(xAutoCab, nOpc, lNoMBrowse, nOpBaixa, lExibeLanc, lOnline)` | ✅ `FINA080.PRX:152`. Sem `AUTVLRPG`, baixa `E2_SALDO + VA` (linha 2033). `E2_VALLIQ := nValPgto` (5883) | Baixa (3) / cancelamento (5), `lExibeLanc = .F.` |
| `FINA050(aRotAuto, nOpcion, nOpcAuto, bExecuta, aDadosBco, lExibeLanc)` | ✅ `FINA050.PRX:103` | Inclusão (3) / exclusão (5) do SE2 do banco |
| `MovBcoBx(cMotBx)` / `ReadMotBx()` | ✅ `finxfin.prx:7240` | Validação do motivo `MV_XRSMOT` |
| `FwIsInCallStack` | ✅ Usado no próprio FINA080 (`FwIsInCallStack("FINA450")`) | `U_PXRSEmRotina`, `FA050UPD` |
| `FINM010` / `FA070TIT` | — Receber | **Removidos** |

## 5. Validações pendentes em debug (ambiente de testes 12.1.2510)

Ligue `MV_XRSLOG = .T.`: o `FINM020` registra no log (`RISCOSACADO`) o ID, FunName, a operação, `FK2_TPDOC`, `FK2_MOTBX`, `FK2_VALOR`, `FK2_IDDOC`, o SE2, `E2_SALDO` e `E2_XSTRIC`.

| ID | Validação | Se falhar |
|---|---|---|
| VAL-001 | O `FINM020` (`MODELPOS`) dispara nas baixas por FINA080 (manual e ExecAuto), FINA090, FINA430 e FINA750, com `FK2_IDDOC` → FK7 localizando o SE2 | PE específico por rotina (ex.: `FA090TIT`/`F430...`) |
| VAL-002 | O `FINM020` dispara na compensação (FINA340) e na fatura (FINA290) | PE específico (ex.: filtro `FA340FIL`) |
| VAL-003 | O cancelamento/exclusão da baixa passa pelo `FINM020` com operação DELETE ou `FK2_TPDOC='ES'` | Ajustar `OperacaoBaixa` ou usar PE de cancelamento do FINA080 |
| VAL-004 | O ExecAuto `FINA080` com `AUTMOTBX = MV_XRSMOT` baixa sem gerar movimento bancário (SE5 sem banco, FK5 inexistente) | Revisar a configuração do motivo de baixa |
| VAL-005 | `U_PXRSEmRotina()` retorna `.T.` nos PEs durante os ExecAuto da rotina (nome na pilha `U_PXRSANTECIPA`) | Ajustar o nome consultado na pilha |
| VAL-006 | ~~`DisarmTransaction()` desfaz por inteiro a baixa + inclusão do SE2 do banco~~ — **reprovado em produção (2026-10-28)**: na falha da inclusão, a baixa permaneceu gravada, o SE2 do banco não foi criado e o `E2_XSTRIC` continuou em `1`, com a mensagem de erro correta no log. O `End Transaction` do próprio `FINA080` encerra a transação ao final da baixa, portanto o `DisarmTransaction()` posterior não tem o que desfazer. Resolvido pela compensação + situação `9` + ação Conciliar | Não aplicável — abordagem substituída (ver REQ-005 e `plan/refactor-risco-sacado-antecipacao-1.md`) |
| VAL-011 | A compensação (`FINA080` opção 5) cancela a baixa da antecipação logo após a falha da inclusão, inclusive com retenções geradas na baixa (RISK-001) | Título permanece em `9` e é resolvido manualmente pela ação Conciliar / Contas a Pagar |
| VAL-012 | `InTransact()` retorna `.F.` após o retorno de `BaixaOriginal` (confirma que o padrão encerrou a transação) — registrado no log `RISCOSACADO` a cada antecipação | Reavaliar o desenho se o comportamento mudar de release |
| VAL-007 | `F240TIT` impede a marcação no borderô (individual, inverter e marcar todos; FINA240 e FINA241) | Filtro no `F240FIL` |
| VAL-009 | `E2_VALLIQ` após a baixa do ExecAuto traz o líquido (com e sem PCC na baixa) | Ler o valor de FK2/SE5 da baixa |
| VAL-010 | `ChangeQuery` converte `\|\|` (concatenação) no JOIN do `PXFINR25` para o banco em uso | Montar a chave com `CONCAT` ou ler o título do banco por função |
| VAL-008 | Retenção na baixa (`MV_BX10925 = 1`): a antecipação gera os TX, o líquido lido da baixa bate com o SE2 do banco e o estorno exclui os TX | Ajustar a leitura do líquido / bloquear o estorno com TX movimentado (RISK-001) |

## 6. Tarefas

| Task | Descrição | Status |
|---|---|---|
| TASK-001 | Validar as assinaturas de `FINM020`, `F240TIT`, `FA050UPD` e `FA080TIT` (fontes padrão 2510, seção 4) | ✅ |
| TASK-002 | Reescrever `DICIONARIO.md` | ✅ — falta criar no ambiente de testes e apagar os `E1_X*`, se existirem |
| TASK-003 | Reescrever `PXFINA37S` (serviços SE2 + `U_PXRSBloqueia`) | ✅ |
| TASK-004 | Reescrever `PXFINA37` (tela SE2 e novas ações) | ✅ |
| TASK-005 | Criar `FINM020`, `FA080TIT`, `FA050UPD`, `F240TIT` | ✅ |
| TASK-006 | Remover `FINM010`/`FA070TIT` do projeto | ✅ — falta remover do RPO de testes |
| TASK-007 | Ajustar `PXFINR25` para SE2 | ✅ |
| TASK-008 | Compilar (RDMake/TDS) e executar VAL-001 a VAL-012 | ⏳ |
| TASK-009 | Testes de cenário (seção 8) e publicação | ⏳ |
| TASK-010 | **Correção da atomicidade da antecipação (2026-10-28)**: saga com compensação, situação `9`, conferência no banco de dados, `Try/Catch`, guarda `InTransact()`, correção do `LockByName` e ação **Conciliar**. Fontes: `PXFINA37S`, `PXFINA37`, `PXFINR25` | ✅ — pendente de compilação e teste |
| TASK-011 | Criar o valor `9` no `X3_CBOX` de `E2_XSTRIC` no ambiente | ⏳ |
| TASK-012 | Conciliar em homologação/produção os títulos que ficaram inconsistentes antes da TASK-010 (filtro `6-Inconsistentes`) | ⏳ |

## 7. Dicionário (resumo para o `DICIONARIO.md`)

**SE2 — campos novos** (todos `Real`, `Visual`; só a rotina altera):

| Campo | Tipo/Tam | Título | X3_CBOX / F3 |
|---|---|---|---|
| `E2_XRISCO` | C 1 | Risco Sacad | `S=Sim;N=Nao`, ini. `"N"` |
| `E2_XLOTRS` | C 6 | Lote R.Sac. | |
| `E2_XBANCO` | C 3 | Bco R.Sacad | F3 `SA6` |
| `E2_XDTRISC` | D 8 | Dt.Env.Bco | |
| `E2_XSTRIC` | C 1 | Sit.R.Sacad | `1=Disponivel;2=Antecipado;3=Em aberto;9=Em processamento` |
| `E2_XDTANT` | D 8 | Dt.Antecip. | |
| `E2_XORIRS` | C 40 | Orig.R.Sac. | Chave do SE2 original: `FILIAL+PREFIXO+NUM+PARCELA+TIPO+FORNECE+LOJA` (só no SE2 do banco) |

**SIX:** `E2_FILIAL+E2_XLOTRS` (`XLOTRS`); `E2_FILIAL+E2_XORIRS` (`XORIRS`).

**SA6:** `A6_XFORN`/`A6_XLOJA` (sem alteração).

**SX6:**

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `MV_XRSNAT` | C | Natureza do SE2 do banco (**sem retenção**) |
| `MV_XRSPRF` | C | Prefixo do SE2 do banco (ex.: `RSC`) |
| `MV_XRSTIP` | C | Tipo do SE2 do banco (ex.: `DP`) |
| `MV_XRSMOT` | C | Motivo de baixa da antecipação (ex.: `RSA`) |
| `MV_XRSLOG` | L | Log de diagnóstico dos PEs |

**Motivo de baixa** (cadastro de motivos de baixa do SIGAFIN): `RSA` – "Risco Sacado Antecipado", **sem movimentação bancária**, sem cheque, sem comissão.

**Removidos:** campos `E1_XRISCO`, `E1_XLOTRS`, `E1_XBANCO`, `E1_XDTRISC`, `E1_XSTRIC`, índice SE1 `XLOTRS` e a sequência `SE1/E1_XLOTRS`.

**Menu:** `U_PXFINA37` em Atualizações > Contas a Pagar; `U_PXFINR25` em Relatórios > Contas a Pagar.

## 8. Cenários de teste

1. Disponibilizar em várias filiais: um lote por filial. Títulos não elegíveis (baixa parcial, em borderô, PA/NDF/TX) são rejeitados com log.
2. Título `1`: baixa manual, baixa automática, CNAB, compensação, borderô, alteração e exclusão são **bloqueados**, cada um com a mensagem da rotina.
3. Antecipado: o original fica baixado pelo motivo `RSA`, sem movimento bancário. O SE2 do banco é gerado com fornecedor do banco, natureza `MV_XRSNAT`, prefixo/tipo dos parâmetros, vencimento original e `E2_XORIRS`.
4. Antecipado com `MV_XRSNAT` vazio ou banco sem fornecedor: título rejeitado e nada gravado (nem baixa).
5. Antecipado de vários títulos com um erro no meio: só o título com erro é desfeito, pela compensação (a baixa é cancelada e o título volta a `1`). Os demais seguem consistentes.
5b. Erro forçado na inclusão do SE2 do banco (ex.: natureza bloqueada, fornecedor do banco inativo): conferir no banco de dados que a baixa foi **cancelada**, o saldo voltou ao valor original e não sobrou SE2 do banco órfão.
5c. Falha também na compensação (TX da baixa já movimentado): o título fica em `9`, aparece no filtro `6-Inconsistentes` e a mensagem orienta a ação Conciliar.
5d. Conciliar nos quatro estados (baixa+banco, baixa sem banco, banco sem baixa, nenhum) e reexecução no mesmo título: idempotente.
5e. Erro de execução forçado durante a antecipação: a mensagem vem do `Try/Catch`, o lote é liberado (nova tentativa imediata não acusa "em processamento por outro usuário") e o título termina em `1` ou `9`.
5a. Antecipado de fornecedor com PCC/IR na baixa: TX gerados, SE2 do banco pelo líquido. Estorno exclui os TX; com TX já pago, o estorno é rejeitado.
6. Título `2`: cancelar ou excluir a baixa do original fora da rotina → **bloqueado**. Excluir ou alterar o SE2 do banco → **bloqueado**. Baixar o SE2 do banco ou colocá-lo em borderô → **permitido**.
7. Estornar 2 → 1 com o SE2 do banco em aberto: o SE2 do banco é excluído, a baixa do original é cancelada e o título volta a `1`. Com o SE2 do banco baixado ou em borderô → rejeitado.
8. Em aberto (3): baixa, borderô e alteração funcionam normalmente. Estornar 3 → 1 sem movimento é permitido; com baixa, é rejeitado.
9. Excluir Lote com e sem título `2`.
10. Antecipar título de outra filial → rejeitado com orientação para logar na filial.
11. Relatório PXFINR25 com filtros e totais por situação.

## 9. O que muda em relação à v2.1

| Tema | v2.1 (Receber) | v3.0 (Pagar) |
|---|---|---|
| Tabela base | SE1 (clientes) | **SE2 (fornecedores)** |
| Situações | 1-Enviado, 2-Não pago, 3-Pago | **1-Disponível, 2-Antecipado, 3-Em aberto** |
| Geração do SE2 do banco | Automática na baixa `NOR` do SE1 (PE `FINM010`, dentro da transação do padrão) | **Na própria rotina**, na ação "Antecipado", que também baixa o original. Não depende mais de PE para gravar |
| Baixa do título original | Pelo usuário, nas rotinas padrão | **Pela rotina**, via ExecAuto `FINA080` com motivo `MV_XRSMOT` |
| Bloqueios | Só a baixa do status `1` | Baixa, cancelamento, borderô, alteração e exclusão nos status `1` **e** `2`, mais a proteção do SE2 do banco |
| PEs | `FINM010`, `FA070TIT` | `FINM020`, `FA080TIT`, `FA050UPD`, `F240TIT` |
| Número do SE2 gerado | Cópia de prefixo/número do SE1 (risco de chave duplicada) | Prefixo/tipo por parâmetro e número = lote + sequência |
| Emissão do SE2 gerado | Emissão original (retroativa) | Data da antecipação (elimina o antigo VAL-008) |
| Estorno | Excluía o SE2 no cancelamento da baixa (via PE) | Ação "Estornar Situação" da rotina (exclui o SE2 do banco + cancela a baixa) |
| Parâmetros | `MV_XRSNAT`, `MV_XRSLOG` | + `MV_XRSPRF`, `MV_XRSTIP`, `MV_XRSMOT` |

## 10. Riscos e decisões em aberto

- **RISK-001 (impostos retidos na baixa) — aceito pelo usuário em 2026-10-19:** se o fornecedor tem PCC/IR retidos **na baixa** (`MV_BX10925 = 1`), a baixa por antecipação gera os títulos de retenção (TX) e o SE2 do banco é gerado pelo **valor líquido**. Consequências:
  - o valor do SE2 do banco pode **divergir do valor que o banco cobra** (normalmente o valor de face informado pelo banco). A diferença precisa ser conciliada manualmente com o banco/fornecedor;
  - os títulos de retenção ficam vinculados à baixa do original. No estorno (2 → 1), o cancelamento da baixa via `FINA080` exclui as retenções pelo padrão. Se algum TX já estiver pago/em borderô, o padrão rejeita o cancelamento e o estorno é desfeito (VAL-008);
  - a data de fato gerador das retenções passa a ser a data da antecipação, não o pagamento ao banco.
  - Mitigação: o relatório `PXFINR25` mostra valor original, retenções e valor do SE2 do banco, e o log da antecipação registra o líquido.
- **RISK-002:** a natureza `MV_XRSNAT` não pode ter retenção, senão o SE2 do banco calcula impostos de novo.
- **RISK-003:** `E2_XBANCO` guarda só o código. O fornecedor do banco é lido da primeira agência/conta com `A6_XFORN` preenchido (mesma regra da v2.1).
- **DEC-001 — decidido (2026-10-19):** um SE2 do banco **por título** antecipado. Facilita o estorno e a rastreabilidade (`E2_XORIRS`).
- **DEC-002 — decidido (2026-10-19):** o retorno do banco (quais títulos foram antecipados) é informado **manualmente** na tela. A importação de arquivo do banco fica fora do escopo.
- **DEC-003:** os juros/deságio da antecipação são do fornecedor com o banco e não entram no Protheus da empresa. O SE2 do banco usa o valor de face.
- **RISK-004:** o usuário que gerou o lote ou a antecipação só fica registrado no log do servidor.
- **RISK-005 (atomicidade da antecipação) — constatado em produção em 2026-10-28:** a baixa (`FINA080`) e a inclusão do SE2 do banco (`FINA050`) **não podem ser executadas numa transação única**. As duas rotinas controlam a própria transação e o `End Transaction` do `FINA080` encerra a transação ao final da baixa; o `DisarmTransaction()` da rotina chamadora, executado depois, não desfaz a baixa. Era isso que deixava o processo "pela metade" (original baixado, SE2 do banco inexistente, `E2_XSTRIC` em `1`, com a mensagem de erro correta no log). Agravante: o `FINA050` tem caminhos de erro que fazem `Return` de dentro da própria transação (`FINA050.PRX` linhas 7847, 7877, 8391 e 8646), dois deles sem desarmar, o que torna o estado da transação imprevisível em outros cenários — por isso o laço interrompe o processamento quando detecta `InTransact()`.
  - **Consequência aceita:** existe uma janela real em que o banco de dados fica em estado intermediário (entre a baixa e a inclusão). Ela é sinalizada pela situação `9`, bloqueada para qualquer movimentação e resolvida pela compensação automática ou pela ação **Conciliar**.
  - **Não compensável automaticamente:** quando o cancelamento da baixa falha (RISK-001, TX já movimentado), o título fica em `9` e exige intervenção no Contas a Pagar antes de conciliar.
- **DEC-004 — decidido (2026-10-28):** manter `E2_VALLIQ` como fonte do valor líquido do SE2 do banco. Confirmado nos fontes do padrão que o `FINA080` grava `E2_VALLIQ := nValPgto` na própria baixa (`FINA080.PRX:4701`, `:10289-10298`), portanto a leitura após a baixa já traz o líquido com as retenções descontadas.
