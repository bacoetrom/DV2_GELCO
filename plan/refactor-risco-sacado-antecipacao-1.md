---
goal: Tornar a antecipação do Risco Sacado (baixa do título do fornecedor + geração do título a pagar do banco) atômica do ponto de vista do negócio, eliminando o estado "pela metade" quando um dos passos falha
version: 1.0
date_created: 2026-10-28
last_updated: 2026-10-28
owner: Customizações ADVPL/TLPP - GELCO (SIGAFIN / Risco Sacado)
status: 'In progress'
tags: [bug, refactor, financeiro, risco-sacado, transacao, execauto]
---

# Introduction

![Status: In progress](https://img.shields.io/badge/status-In%20progress-yellow)

> **Execução (2026-10-28):** fases 1 a 5 implementadas nos fontes (`PXFINA37S.tlpp`, `PXFINA37.tlpp`, `PXFINR25.tlpp`) e documentação atualizada (`DICIONARIO.md`, `PLANO_RISCO_SACADO.md`). Pendentes: criação do valor `9` no `X3_CBOX` de `E2_XSTRIC` no ambiente, compilação, os testes da seção 6 e as tarefas da fase 6 (TASK-031/TASK-032/TASK-033, validações preventivas).

A ação **Antecipado** da rotina `PXFINA37` executa, hoje, dois `MsExecAuto` (baixa `FINA080` opção 3 e inclusão `FINA050` opção 3) dentro de um único `Begin Transaction` próprio, confiando em `DisarmTransaction()` para desfazer tudo em caso de erro. Esse desenho **não garante atomicidade no Protheus**: as rotinas automáticas controlam a própria transação e o `End Transaction` do `FINA080` encerra a transação ativa **antes** de o segundo ExecAuto começar — a baixa já está efetivada quando o erro acontece, e o `DisarmTransaction()` posterior não tem mais o que desfazer. Sintoma confirmado em campo: **título do fornecedor baixado, título a pagar do banco não gerado e `E2_XSTRIC` ainda em `1`**, com a mensagem de erro aparecendo corretamente no log da rotina.

Este plano substitui a "transação única" por **saga com estado persistido + compensação + conciliação**, mantém todo o tratamento de erro fora de interface (CA1002) e inclui o reparo dos títulos que já ficaram inconsistentes em produção.

---

## 0. Diagnóstico

### 0.1 Observação de campo (informada pelo usuário em 2026-10-28) — fato primário

Quando o erro ocorre na geração do título a pagar do banco:

- a **baixa do título do fornecedor permanece gravada** (não foi desfeita);
- o **título a pagar do banco não existe**;
- `E2_XSTRIC` continua em **`1` (Disponível)**;
- a **mensagem de erro aparece normalmente** no log da rotina (`MostraLog`/`FWAlertInfo`).

Isso define o mecanismo e descarta parte da análise anterior:

- o fluxo de erro previsto **funcionou**: `lMsErroAuto` foi setado, `MontaErroAuto()` montou a mensagem, `cMsg` voltou preenchido e o código desviou para `DisarmTransaction()` ([PXFINA37S.tlpp:317-319](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L317-L319)). Logo, **D-010 não é a causa** no cenário relatado;
- o que falhou foi **exclusivamente o rollback**: `DisarmTransaction()` + `End Transaction` não desfizeram a baixa já gravada pelo `FINA080`;
- a direção que eu havia descrito em D-004 (commit **atrasado**, efetivado no título seguinte do laço) está **incorreta**. O comportamento observado é o oposto: **commit antecipado** — o `End Transaction` interno do `FINA080` (`FINA080.PRX:3006`) encerra a transação ativa (o Protheus não suporta aninhamento real de transação), a baixa é efetivada ali, e o nosso `DisarmTransaction()`, executado depois, não tem mais nada para desfazer.

**Consequência para a solução:** não existe ajuste de `Begin Transaction`/`DisarmTransaction` capaz de tornar os dois passos atômicos, porque o primeiro passo é efetivado antes do segundo começar. A única saída é **compensar** (cancelar a baixa) quando a etapa 2 falha — que é o núcleo deste plano.

### 0.2 Fatos verificados em fonte

| # | Fato verificado | Evidência |
|---|---|---|
| D-001 | `U_PXRSAntecipa` abre a própria transação e chama os dois ExecAuto dentro dela | [PXFINA37S.tlpp:295-320](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L295-L320), [:534](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L534), [:641](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L641) |
| D-002 | `FINA080` e `FINA050` abrem transação própria → transação **aninhada**; o commit/rollback real só ocorre quando o contador de transação volta a zero | `FINA080.PRX:2564→3006` (baixa), `FINA080.PRX:4672→5817` (cancelamento), `FINA050.PRX:7812→8835` (inclusão) |
| D-003 | **Causa do sintoma (consistente com 0.1):** o `End Transaction` do `FINA080` é alcançado **antes** do segundo ExecAuto e encerra a transação ativa — a baixa é efetivada ali. A partir desse ponto o nosso bloco já não tem transação para desarmar | `FINA080.PRX:2564→3006`; [PXFINA37S.tlpp:296](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L296) → [:308](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L308) |
| D-004 | Agravante (não é o sintoma relatado, mas vale como defesa): dentro da transação de inclusão do `FINA050` existem `Return` que não alcançam o `End Transaction` — dois deles sem nem desarmar a transação. Isso torna o estado da transação imprevisível em outros caminhos de erro, por isso o processamento em laço precisa abortar quando detectar transação aberta | `FINA050.PRX:7847`, `:7877` (`Return` puro), `:8391`, `:8646` (`Help(); return` puro) |
| D-005 | `MSExecAuto` **não possui tratamento de erro**: só salva/restaura variáveis e faz `eval(bRotina, ...)`. Erro de execução (não de validação) não é capturado — a execução de `PXRSAntecipa` é abandonada, o `End Transaction` nunca roda, o `UnLockByName` não roda (lote fica preso) e o que foi gravado fica no limbo | `matxfunb.prx:2947-3021`; lock em [PXFINA37S.tlpp:289](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L289) e [:323-325](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L323-L325) |
| D-006 | `lMsErroAuto` é hoje a única fonte de verdade ([:539](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L539), [:646](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L646)). Não há conferência no banco de que a baixa ocorreu e de que o título do banco existe. Os caminhos `FINA050.PRX:7877` e `:8646` não garantem `AutoGrLog` | — |
| D-007 | ~~`nValor := SE2->E2_VALLIQ` usa o líquido do título, não o da baixa~~ — **AVALIAÇÃO INCORRETA, CORRIGIDA EM 2026-10-28**: o `FINA080` grava `SE2->E2_VALLIQ := nValPgto` na própria baixa (`FINA080.PRX:4701`, `:10289-10298`). A leitura de `E2_VALLIQ` após a baixa em [:301](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L301) está **correta**, assim como o comentário de [:299](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L299). Permanece válido apenas: `ProximoNumero` pode retornar vazio ([:607-611](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L607-L611)) **já com a baixa feita**, gerando falha depois do efeito colateral | `FINA080.PRX:4701`, `:10289-10298` |
| D-008 | `U_PXRSEstornaAntecipacao` tem o mesmo desenho (FINA050 op.5 + FINA080 op.5 na nossa transação) → mesmo risco | [PXFINA37S.tlpp:398-416](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L398-L416) |
| D-009 | `ProcessaLote` chama `GetSXENum` antes do `Begin Transaction` e `ConfirmSX8` depois; em rollback o número do lote é consumido | [PXFINA37.tlpp:538-566](../__Risco_Sacado/ROTINAS/PXFINA37.tlpp#L538-L566) |
| D-010 | **Não é a causa do sintoma relatado (ver 0.1), mas permanece como risco a cobrir:** quando um ExecAuto falha **sem** setar `lMsErroAuto`, `BaixaOriginal`/`GeraPagarBanco` retornam mensagem vazia e a rotina **grava sucesso** (`E2_XSTRIC = '2'`) e commita. Nesse cenário a transação funciona perfeitamente — o estado parcial é gravado porque **nós** afirmamos que deu certo. Não há nenhuma conferência no banco de que a baixa ocorreu e de que o título do banco existe | [PXFINA37S.tlpp:539](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L539), [:646](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L646), [:311-316](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L311-L316); caminho sem log no padrão: `FINA050.PRX:7877` |
| D-011 | **Defeito confirmado (concorrência):** `cLock` é preenchido em [:288](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L288) **antes** da tentativa de lock. Quando `cMsg` já estava preenchido (validação reprovada), o `.And.` curto-circuita e o `LockByName` **nunca é executado** — mas [:323-325](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L323-L325) executa `UnLockByName` de todo modo, liberando um semáforo que esta thread não possui (pode derrubar o lock de outro usuário no mesmo lote) | [PXFINA37S.tlpp:288-292](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L288-L292), [:323-325](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L323-L325) |

> **Conclusão:** não existe ajuste de `DisarmTransaction()` que resolva D-003/D-005, porque o problema está no fonte do produto (sai de dentro da própria transação) e no `MSExecAuto` (sem captura de erro). A correção precisa ser arquitetural: **não envolver `MsExecAuto` em transação própria** e passar a controlar o processo por estado + compensação.

---

## 1. Requirements & Constraints

- **REQ-001**: Nenhum `Begin Transaction` próprio pode envolver uma chamada `MsExecAuto`.
- **REQ-002**: Toda interrupção (erro de validação, erro de execução, queda de conexão) deve deixar o título em um estado **identificável** e **reprocessável**, nunca em estado silenciosamente parcial.
- **REQ-003**: O sucesso de cada etapa deve ser confirmado **pelo estado no banco**, não apenas por `lMsErroAuto`.
- **REQ-004**: Falha na etapa 2 (geração do título do banco) deve **compensar** a etapa 1 (cancelar a baixa) e conferir a compensação. Se a compensação falhar, o título permanece marcado como inconsistente, com log `ERROR` e mensagem explícita ao usuário.
- **REQ-005**: Reexecutar a ação sobre um título interrompido deve **concluir ou desfazer** o que falta, sem duplicar baixa nem título do banco (idempotência).
- **REQ-006**: Deve existir forma de **conciliar/reparar** os títulos que já ficaram inconsistentes em produção antes desta correção.
- **REQ-007**: Um erro em um título não pode contaminar os demais do laço; se for detectado desbalanceamento de transação, o processamento do lote é **abortado** (continuar commitaria lixo).
- **REQ-008**: O lock do lote (`LockByName`) deve ser liberado em **todos** os caminhos de saída, inclusive em erro de execução.
- **REQ-009**: `U_PXRSEstornaAntecipacao` recebe o mesmo tratamento (simetria).
- **CON-001**: Não é possível alterar os fontes do produto (`FINA050.PRX`, `FINA080.PRX`, `matxfunb.prx`).
- **CON-002**: `MsExecAuto` não captura erro de execução — a proteção tem de ser nossa (`Try/Catch`).
- **CON-003**: Nenhuma chamada de interface (`MsgAlert`, `MsgYesNo`, `Help`, `Aviso`, `ParamBox`) dentro de `Begin Transaction` nem dentro do commit MVC — SonarQube **CA1002**.
- **CON-004**: `E2_XSTRIC` é `C(1)`; o novo estado tem de caber em uma posição (usar `9`).
- **CON-005**: Fontes em **CP-1252**; `IIF()`/`IF()` inline proibidos; logs somente via `FWLogMsg` (`U_PXRSLog`); SQL sempre com `FWExecStatement` + `D_E_L_E_T_ = ' '` + filial.
- **GUD-001**: Declarações `Local`/`Private` no topo da função, antes de qualquer linha executável.
- **GUD-002**: `Begin Transaction` próprio permitido **apenas** para gravação de campos nossos na SE2 (bloco curto, sem ExecAuto e sem interface).
- **PAT-001**: Padrão **Saga com compensação**: estado persistido antes de cada efeito colateral; verificação após cada efeito; compensação no caminho de falha; conciliação para o que não puder ser compensado.

---

## 2. Implementation Steps

### Implementation Phase 1 — Hotfix: compensar a baixa quando a etapa 2 falha

- GOAL-001: Eliminar o sintoma relatado (baixa efetivada sem título do banco) sem alteração de dicionário, com o menor número de mudanças possível. Esta fase, isolada, já resolve o caso que o cliente reproduz.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | Em `U_PXRSAntecipa`, no caminho de falha ([PXFINA37S.tlpp:317-319](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L317-L319)): quando a falha ocorrer **após** a baixa (erro no líquido ou em `GeraPagarBanco`), chamar `CancelaBaixaOriginal(nRecSE2)` e confirmar o cancelamento pelo estado da SE2 (`E2_SALDO` de volta ao valor e `E2_BAIXA` vazio). Acrescentar o resultado da compensação à mensagem devolvida ao chamador. | ✅ | 2026-10-28 |
| TASK-002 | Remover `Begin Transaction`/`End Transaction`/`DisarmTransaction()` de `U_PXRSAntecipa` ([:295-321](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L295-L321)): comprovadamente não protegem a baixa e dão falsa garantia. Manter transação própria somente na gravação do status (TASK-007). | ✅ | 2026-10-28 |
| TASK-003 | Corrigir D-011: preencher `cLock` **somente após** `LockByName` retornar `.T.` ([:288-292](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L288-L292)), para que `UnLockByName` ([:323-325](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L323-L325)) não libere semáforo de outro usuário. | ✅ | 2026-10-28 |
| TASK-004 | Envolver o corpo de `U_PXRSAntecipa` em `Try/Catch` (TLPP), convertendo erro de execução em mensagem de retorno + log `ERROR` com `oErro:Description`, e garantindo `UnLockByName` em todos os caminhos de saída. | ✅ | 2026-10-28 |
| TASK-005 | Prova do mecanismo (1 linha, baixo custo): logar `InTransact()` imediatamente após o retorno de `BaixaOriginal`. Retorno `.F.` confirma que o `FINA080` encerrou a transação e que o `DisarmTransaction()` nunca teria efeito. Registrar o resultado na seção 0.1. | | |
| TASK-006A | Em `ProcessaAntecipacao` (`PXFINA37.tlpp`), testar `InTransact()` após cada título; quando `.T.` (transação aberta deixada pelo padrão — D-004), log `ERROR`, mensagem no `aLog` e `Exit` do laço, para não arrastar estado pendente para o título seguinte. | ✅ | 2026-10-28 |

### Implementation Phase 2 — Saga da antecipação (núcleo da correção)

- GOAL-002: Reescrever `U_PXRSAntecipa` sem transação envolvendo ExecAuto, com verificação no banco a cada etapa e compensação da baixa.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-006 | Reorganizar `U_PXRSAntecipa` na sequência da saga (a remoção da transação já foi feita na TASK-002): (1) validações; (2) `LockByName`; (3) marca `E2_XSTRIC = '9'`; (4) baixa + verificação; (5) líquido; (6) título do banco + verificação; (7) marca `E2_XSTRIC = '2'`; (8) `UnLockByName`. | ✅ | 2026-10-28 |
| TASK-007 | Criar `User Function PXRSMarcaStatus(nRecSE2 as numeric, cStatus as character, dDtAnt as variant) as character` em `PXFINA37S.tlpp`: grava `E2_XSTRIC` e `E2_XDTANT` em `Begin Transaction` curto (apenas SE2, `RecLock`/`MsUnlock`), sem ExecAuto e sem interface. Retorna mensagem de erro ou vazio. | ✅ | 2026-10-28 |
| TASK-008 | Criar `User Function PXRSEstadoTitulo(nRecSE2 as numeric, jCfg as json) as json` retornando `{"status", "temBaixa", "recBco", "valBaixa"}`: reposiciona a SE2 (`DbGoTo` + `DbSkip(0)` para descartar buffer), avalia a baixa (`E2_SALDO <= RS_TOLERANCIA .And. !Empty(E2_BAIXA)` confirmado por `PXRSBaixaAntec`) e localiza o título do banco por `U_PXRSBuscaPagar`. Fonte única de verdade para antecipação, estorno e conciliação. | ✅ | 2026-10-28 |
| TASK-009 | Criar `Static Function PXRSBaixaAntec(nRecSE2 as numeric, cMotBx as character) as json` (`{"recno", "valor"}`): consulta `FWExecStatement` na `SE5` pela chave do título (`E5_PREFIXO+E5_NUMERO+E5_PARCELA+E5_TIPO+E5_CLIFOR+E5_LOJA`), `E5_RECPAG = 'P'`, `E5_MOTBX = cMotBx`, `E5_SITUACA <> 'C'`, `E5_TIPODOC` de baixa, `D_E_L_E_T_ = ' '` e `E5_FILIAL = xFilial('SE5', <filial do título>)`, com `%nolock%`. Usada para confirmar a baixa e para ler o valor efetivamente baixado. | ✅ | 2026-10-28 |
| TASK-010 | **Manter** `nValor := SE2->E2_VALLIQ` ([:300-304](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L300-L304)): o `FINA080` grava `E2_VALLIQ` na própria baixa (`FINA080.PRX:4701`, `:10289-10298`), portanto a leitura atual está correta. Apenas (a) conferir o valor contra `PXRSBaixaAntec` quando o log de diagnóstico estiver ligado e (b) logar o valor usado. Nenhuma troca de fonte do valor. | ✅ | 2026-10-28 |
| TASK-011 | Em `BaixaOriginal` e `GeraPagarBanco`, após o `MsExecAuto`: em erro, chamar `RollBackSX8()`; em sucesso, `ConfirmSX8()`. Manter a restauração de `FWModelActive()` já existente. | ✅ | 2026-10-28 |
| TASK-012 | Em `GeraPagarBanco`, não confiar apenas em `lMsErroAuto`: após o ExecAuto, confirmar com `U_PXRSBuscaPagar(...) > 0`. Divergência (`lMsErroAuto = .F.` e título inexistente, ou vice-versa) gera log `ERROR` e é tratada como falha. | ✅ | 2026-10-28 |
| TASK-013 | Criar `Static Function CompensaBaixa(nRecSE2 as numeric, jCfg as json) as character`: chama `CancelaBaixaOriginal` e confirma pelo estado (`PXRSEstadoTitulo`: `temBaixa` deve voltar `.F.`). Em sucesso, volta `E2_XSTRIC` para `'1'`. Em falha, mantém `'9'`, log `ERROR` e devolve mensagem instruindo a conciliação. | ✅ | 2026-10-28 |
| TASK-014 | Encadear no caminho de falha de `U_PXRSAntecipa`: falha na baixa → compensar se houver baixa parcial gravada e voltar para `'1'`; falha no líquido ou na geração do título do banco → `CompensaBaixa`; falha ao marcar `'2'` com título do banco já criado → manter `'9'` (a conciliação conclui). | ✅ | 2026-10-28 |
| TASK-015 | Mover o `LockByName`/`UnLockByName` para envolver toda a saga, com liberação garantida no `Catch` e em todos os `Return`. Manter o nome do lock (`"PXRS" + filial + lote`). | ✅ | 2026-10-28 |
| TASK-015A | ~~Correção do `cLock` (D-011)~~ — antecipada para a **TASK-003** (Fase 1). Aqui apenas validar que a correção continua válida após a reorganização da saga. | ✅ | 2026-10-28 |

### Implementation Phase 3 — Estado "Em processamento" e reflexos

- GOAL-003: Dar visibilidade ao estado intermediário e impedir qualquer movimentação de título em processamento.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-016 | `DICIONARIO.md`: alterar o `X3_CBOX` de `E2_XSTRIC` para `1=Disponivel;2=Antecipado;3=Em aberto;9=Em processamento`. Documentar o novo domínio e o procedimento de conciliação. | ✅ | 2026-10-28 |
| TASK-017 | `PXFINA37S.tlpp`: adicionar `#define RS_PROCESSANDO "9"` e tratar o valor em `U_PXRSDescSituacao` ("Em processamento"). | ✅ | 2026-10-28 |
| TASK-018 | `U_PXRSBloqueia`: incluir `RS_PROCESSANDO` na condição de bloqueio total ([:461](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L461)), com mensagem específica ("título em processamento pelo Risco Sacado; use a conciliação em PXFINA37"). Reflete automaticamente em `FINM020`, `FA080TIT`, `FA050UPD` e `F240TIT`. | ✅ | 2026-10-28 |
| TASK-019 | `U_PXRSValidaElegivel` e `U_PXRSAntecipa`: recusar título em `'9'` fora do fluxo de conciliação. | ✅ | 2026-10-28 |
| TASK-020 | `PXFINA37.tlpp`: incluir a opção `6-Inconsistentes` no combo Situação (`Parametros`, `#define SIT_INCONSIST 6`) e o filtro correspondente em `CarregaTitulos` (`E2_XSTRIC = '9'` **ou** `E2_XSTRIC = '2'` sem título do banco **ou** `'1'` com baixa pelo motivo `MV_XRSMOT`). | ✅ | 2026-10-28 |
| TASK-021 | `PXFINR25.tlpp`: incluir a situação `9` nas legendas/filtros e um bloco "Inconsistências" no relatório. | ✅ | 2026-10-28 |

### Implementation Phase 4 — Estorno simétrico

- GOAL-004: Aplicar o mesmo desenho ao estorno da antecipação (2 → 1).

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-022 | Remover `Begin Transaction`/`DisarmTransaction` de `U_PXRSEstornaAntecipacao` ([:398-416](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L398-L416)) e aplicar a saga: marca `'9'` → exclui o título do banco (`ExcluiPagarBanco`) → confirma por `U_PXRSBuscaPagar == 0` → cancela a baixa (`CancelaBaixaOriginal`) → confirma por `PXRSEstadoTitulo` → marca `'1'`. | ✅ | 2026-10-28 |
| TASK-023 | Falha após a exclusão do título do banco: não recriar o título (risco de duplicidade/numeração). Manter `'9'` com log `ERROR` e mensagem para conciliação. | ✅ | 2026-10-28 |
| TASK-024 | Aplicar `Try/Catch` + guarda `InTransact()` + log por etapa também no estorno. | ✅ | 2026-10-28 |

### Implementation Phase 5 — Conciliação e reparo do passivo

- GOAL-005: Permitir identificar e resolver, pela própria rotina, todo título inconsistente — inclusive os que já ficaram pela metade antes da correção.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-025 | Criar `User Function PXRSConcilia(nRecSE2 as numeric, jCfg as json) as character` em `PXFINA37S.tlpp`: lê `PXRSEstadoTitulo` e decide — (a) baixa **e** título do banco presentes → marca `'2'`; (b) baixa presente, título do banco ausente → gera o título do banco e marca `'2'`; (c) baixa ausente, título do banco presente → exclui o título do banco e marca `'1'`; (d) nada presente → marca `'1'`. Cada efeito é verificado no banco antes do passo seguinte. | ✅ | 2026-10-28 |
| TASK-026 | `PXFINA37.tlpp`: novo botão **"Conciliar"** → `Static Function AcaoConcilia(oMark, aPar)`, com `MsgYesNo` de confirmação (fora de transação), execução via `FWMsgRun` sobre `Static Function ProcessaConciliacao(aSel, jCfg, aLog)`, log por título e `Recarrega`. | ✅ | 2026-10-28 |
| TASK-027 | Em `ProcessaConciliacao`, exibir no log o diagnóstico de cada título ("baixado sem título do banco", "título do banco sem baixa", "consistente") antes da ação tomada, para o usuário validar o que será feito. | ✅ | 2026-10-28 |
| TASK-028 | Levantar o passivo atual com consulta SQL (SE2 x SE5 x `E2_XORIRS`) e tratar os títulos existentes pela ação **Conciliar** em homologação antes de liberar em produção. Registrar a lista tratada. | | |
| TASK-029 | Documentar em `PLANO_RISCO_SACADO.md` o fluxo de conciliação, incluindo o caso não compensável (retenções da baixa já movimentadas — RISK-001), que exige intervenção manual no Contas a Pagar. | ✅ | 2026-10-28 |

### Implementation Phase 6 — Redução da causa raiz (menos erro na etapa 2)

- GOAL-006: Antecipar para a fase de validação tudo o que hoje só falha depois da baixa.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-030 | Mover a geração do número (`ProximoNumero`) para **antes** da baixa, ainda sob o lock do lote, e abortar a antecipação quando vier vazio ([:607-611](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L607-L611)) — hoje isso falha com a baixa já feita. | ✅ | 2026-10-28 |
| TASK-031 | Ampliar `U_PXRSValidaConfig`: validar que a natureza `MV_XRSNAT` não tem retenção (RISK-002), que o fornecedor do banco (`A6_XFORN/A6_XLOJA`) existe, está ativo e não bloqueado na `SA2`, e que o tipo `MV_XRSTIP` existe na tabela de tipos. Executar **antes** da baixa. | | |
| TASK-032 | Validar antes da baixa a existência dos campos usados na cópia contábil (`aCopia` em `GeraPagarBanco`, [:632-637](../__Risco_Sacado/ROTINAS/PXFINA37S.tlpp#L632-L637)) e o preenchimento mínimo exigido pela natureza, evitando que o `FINA050` rejeite depois da baixa. | | |
| TASK-033 | `ProcessaLote` ([PXFINA37.tlpp:538-566](../__Risco_Sacado/ROTINAS/PXFINA37.tlpp#L538-L566)): mover `GetSXENum` para imediatamente antes do `Begin Transaction` e garantir `RollBackSX8()` em todo caminho sem gravação, evitando consumo de lote. | | |

### Implementation Phase 7 — Testes, compilação e documentação

- GOAL-007: Comprovar a correção e deixar o comportamento documentado.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-034 | Executar os testes TEST-001 a TEST-010 da seção 6 em homologação, com `MV_XRSLOG = .T.`, conferindo o log `RISCOSACADO` em cada cenário. | | |
| TASK-035 | Compilar `PXFINA37.tlpp`, `PXFINA37S.tlpp`, `PXFINR25.tlpp` e os PEs alterados (skill `advpl-tlpp-compile`), confirmando CP-1252 e ausência de violações SonarQube novas. | | |
| TASK-036 | Atualizar `PLANO_RISCO_SACADO.md` (REQ-005, REQ-008, VAL-006 e a seção de riscos) e `DICIONARIO.md` com o estado `9`, a saga e a conciliação. | ✅ | 2026-10-28 |
| TASK-037 | Apresentar ao usuário a análise de completude (item a item: comportamento antigo → novo) antes de considerar a tarefa concluída. | | |

---

## 3. Alternatives

- **ALT-001 — Manter a transação única e apenas "melhorar" o `DisarmTransaction()`**: descartado. O produto sai de dentro da própria transação sem `End Transaction` (`FINA050.PRX:7877`, `:8391`, `:8646`) e `MSExecAuto` não captura erro de execução (`matxfunb.prx:2947`). Nenhum ajuste no nosso lado garante commit/rollback nesse cenário.
- **ALT-002 — Transação única com `TCCommit`/controle manual de conexão**: descartado. Interfere no controle de transação do framework e do MVC (`FINM020`), com risco de corromper gravações do padrão.
- **ALT-003 — Gerar o título do banco por gravação direta na SE2 (`RecLock`) em vez de `FINA050`**: descartado. Perde natureza, rateio, contabilização, integrações e PEs do padrão; gera título inconsistente para o Contas a Pagar.
- **ALT-004 — Processar a antecipação em job/`StartJob` assíncrono com fila**: descartado nesta etapa (aumenta complexidade operacional). A saga resolve o problema relatado; a fila pode ser avaliada no futuro para volumes altos.
- **ALT-005 — Não baixar o título original (só gerar o título do banco)**: descartado — muda a regra de negócio aprovada (REQ-005 do `PLANO_RISCO_SACADO.md`).

## 4. Dependencies

- **DEP-001**: Campo `E2_XSTRIC` com `X3_CBOX` atualizado para incluir `9=Em processamento` (dicionário do ambiente).
- **DEP-002**: Parâmetros `MV_XRSNAT`, `MV_XRSPRF`, `MV_XRSTIP`, `MV_XRSMOT`, `MV_XRSLOG` configurados; `MV_XRSMOT` sem movimentação bancária.
- **DEP-003**: Fontes do produto `FINA050.PRX` / `FINA080.PRX` / `matxfunb.prx` na versão 12.1.2510 (referência das linhas citadas); revalidar as linhas ao atualizar a release.
- **DEP-004**: Permissão de cancelamento de baixa (`FINA080` opção 5) para o usuário que executar antecipação/estorno/conciliação.
- **DEP-005**: Ambiente de homologação com dados que reproduzam o erro relatado (necessário para TASK-005 e TEST-003).

## 5. Files

- **FILE-001**: `__Risco_Sacado/ROTINAS/PXFINA37S.tlpp` — reescrita de `U_PXRSAntecipa` e `U_PXRSEstornaAntecipacao`; novas funções `PXRSMarcaStatus`, `PXRSEstadoTitulo`, `PXRSBaixaAntec`, `CompensaBaixa`, `PXRSConcilia`, `TransacaoAberta`; ajustes em `BaixaOriginal`, `CancelaBaixaOriginal`, `GeraPagarBanco`, `ExcluiPagarBanco`, `U_PXRSBloqueia`, `U_PXRSDescSituacao`, `U_PXRSValidaConfig`, `U_PXRSValidaElegivel`, `ProximoNumero`.
- **FILE-002**: `__Risco_Sacado/ROTINAS/PXFINA37.tlpp` — guarda `InTransact()` e `Try/Catch` em `ProcessaAntecipacao`/`ProcessaEstorno`; botão e ações de conciliação; nova opção de situação no `ParamBox` e no filtro de `CarregaTitulos`; ajuste de SX8 em `ProcessaLote`.
- **FILE-003**: `__Risco_Sacado/RELATORIOS/PXFINR25.tlpp` — situação `9` e bloco de inconsistências.
- **FILE-004**: `__Risco_Sacado/DICIONARIO.md` — novo domínio de `E2_XSTRIC`.
- **FILE-005**: `__Risco_Sacado/PLANO_RISCO_SACADO.md` — atualização de REQ-005, REQ-008, VAL-006 e riscos.
- **FILE-006**: Pontos de entrada (`FINM020.tlpp`, `FA080TIT.tlpp`, `FA050UPD.tlpp`, `F240TIT.tlpp`) — sem alteração de código; herdam a nova regra via `U_PXRSBloqueia`. Validar em teste.

## 6. Testing

- **TEST-001**: Antecipação feliz de 1 título → baixa gravada, título do banco gerado pelo líquido correto, `E2_XSTRIC = '2'`, `E2_XDTANT` preenchido, nenhum título em `'9'`, `InTransact()` `.F.` ao final.
- **TEST-002**: Antecipação de 5 títulos sem erro → 5 processados; lote e numeração sequenciais sem buraco.
- **TEST-003**: Erro **forçado** na geração do título do banco (ex.: natureza `MV_XRSNAT` bloqueada ou fornecedor do banco inativo) → baixa **cancelada**, `E2_XSTRIC` de volta em `'1'`, saldo original restaurado, mensagem no log da rotina e nenhum título do banco órfão.
- **TEST-004**: Erro no título 3 de 5 → títulos 1, 2 consistentes; título 3 revertido ou em `'9'` identificado; o processamento **não** commita estado parcial dos demais; se houver desbalanceamento, o laço é abortado com mensagem.
- **TEST-005**: Erro de execução forçado (ex.: parâmetro inválido provocando exceção) → `Try/Catch` devolve mensagem, lock liberado (nova tentativa imediata não acusa "lote em processamento"), título em `'9'` ou `'1'`.
- **TEST-006**: Falha na compensação (baixa com retenção TX já movimentada) → título permanece `'9'`, log `ERROR`, mensagem orientando a conciliação; o título aparece no filtro `6-Inconsistentes`.
- **TEST-007**: Conciliação dos quatro estados possíveis (baixa+banco, baixa sem banco, banco sem baixa, nenhum) → em cada caso o resultado final é consistente e idempotente (segunda execução não altera nada).
- **TEST-008**: Estorno da antecipação (2 → 1) feliz e com erro forçado na exclusão do título do banco → sem baixa cancelada indevidamente, título em `'9'` quando necessário.
- **TEST-009**: Bloqueios — título em `'9'` não pode ser baixado (`FINA080`/`FINA090`), alterado/excluído (`FINA050`) nem entrar em borderô (`FINA240`); mensagem cita a conciliação.
- **TEST-010**: Concorrência — dois usuários antecipando o mesmo lote: o segundo recebe a mensagem de lote em processamento; nenhuma numeração duplicada em `E2_NUM`.

## 7. Risks & Assumptions

- **RISK-001**: Compensação não garantida — se a baixa por antecipação gerou títulos de retenção (TX) já movimentados, o `FINA080` opção 5 falha. Mitigação: estado `'9'` + conciliação + mensagem explícita; tratamento manual no Contas a Pagar. (Alinhado ao RISK-001 já aceito em `PLANO_RISCO_SACADO.md`.)
- **RISK-002**: Janela de inconsistência real — entre a baixa e a geração do título do banco existe um intervalo em que o banco de dados está, de fato, em estado intermediário (é o preço de abandonar a transação única, que não funciona). Mitigação: estado `'9'` persistido, bloqueio de qualquer movimentação nesse estado e conciliação.
- **RISK-003**: Contabilização gerada pela baixa pode não ser integralmente revertida pelo cancelamento em todos os cenários (depende de `MV_PARCTB`/parametrização). Validar em TEST-003 e documentar.
- **RISK-004**: Numeração do título do banco gerada antes da baixa (TASK-030) pode "pular" números quando a antecipação é abortada. Impacto aceito: o número é sequencial por lote, não fiscal.
- **RISK-005**: As linhas citadas dos fontes do produto são da release instalada; uma atualização de versão pode mover/alterar esses caminhos. O desenho proposto não depende delas, apenas o diagnóstico.
- **ASSUMPTION-001**: `E2_XSTRIC` aceita `'9'` sem validação adicional no dicionário além do `X3_CBOX`.
- **ASSUMPTION-002**: A baixa da antecipação é sempre total e única por título (garantido por `U_PXRSValidaElegivel`), o que permite identificá-la na SE5 pelo motivo `MV_XRSMOT`.
- **ASSUMPTION-003**: O usuário aceita a nova ação **Conciliar** na tela como procedimento operacional para os casos não compensáveis automaticamente.

## 8. Related Specifications / Further Reading

- [`__Risco_Sacado/PLANO_RISCO_SACADO.md`](../__Risco_Sacado/PLANO_RISCO_SACADO.md) — REQ-005, REQ-008, VAL-006, VAL-008, RISK-001 a RISK-004.
- [`__Risco_Sacado/DICIONARIO.md`](../__Risco_Sacado/DICIONARIO.md) — campos `E2_X*`, `A6_XFORN/A6_XLOJA`, numeração do título do banco.
- Fontes do produto (referência do diagnóstico): `d:\99-FONTES\Fontes\Adm\FINA050.PRX` (7812-8835), `d:\99-FONTES\Fontes\Adm\FINA080.PRX` (2564-3006, 4672-5817), `d:\99-FONTES\Fontes\Infra-Estrutura\matxfunb.prx` (2947-3021).
- `.claude/skills/code-review/references/code-quality-patterns.md` — CA1002 (interface em transação) e padrão de coleta de erro + exibição após a transação.
- TDN — `DisarmTransaction`, `InTransact`, `MSExecAuto`, `FINA050`/`FINA080` em rotina automática.
