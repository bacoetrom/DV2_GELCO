---
goal: Risco Sacado — envio de títulos a receber ao banco e geração de título a pagar ao banco na baixa dos não pagos
version: 2.1
date_created: 2026-10-13
last_updated: 2026-10-13
status: 'In progress'
tags: [feature, SIGAFIN, SE1, SE2, SA6, FWMarkBrowse, FINM010, ExecAuto, TReport]
---

# Plano — Risco Sacado

## Introdução

Os títulos a receber (SE1) são marcados como **Risco Sacado** e enviados a um banco (SA6) em **lotes** (código sequencial de 6 dígitos, um lote por filial). O plano também controla a situação informada no retorno do banco.

- **Não pago ao Banco:** na baixa normal (`NOR`) que liquida o SE1, o sistema gera automaticamente um título a pagar (SE2). Ele é cópia do SE1 para o fornecedor do banco (`A6_XFORN`/`A6_XLOJA`), com a natureza do parâmetro `MV_XRSNAT`.
- **Pago ao Banco:** o usuário baixa o SE1 manualmente, sem gerar SE2.
- **Enviado ao Banco:** o título fica com a baixa bloqueada até alguém informar o retorno do banco.

## 1. Arquivos

| Arquivo | Conteúdo |
|---|---|
| `ROTINAS/PXFINA37.tlpp` | Tela: ParamBox + FWTemporaryTable + FWMarkBrowse. Ações: Marcar/Desmarcar/Inverter, Risco Sacado, Não Pago ao Banco, Pago ao Banco, Estornar Situação, Excluir Lote |
| `ROTINAS/PXFINA37S.tlpp` | Serviços compartilhados: fornecedor do banco, validação, geração/exclusão do SE2 (ExecAuto FINA050), log |
| `PONTOS DE ENTRADA/FINM010.tlpp` | PE MVC da baixa a receber. `MODELPOS`: bloqueios e pré-validações. `MODELCOMMITTTS`: gera/exclui o SE2; se falhar, chama `DisarmTransaction()` |
| `PONTOS DE ENTRADA/FA070TIT.tlpp` | Barreira antecipada no FINA070 (manual e ExecAuto) para o status `1` |
| `RELATORIOS/PXFINR25.tlpp` | TReport dos lotes (parâmetros via ParamBox), com totais por lote |
| `DICIONARIO.md` | Especificação de campos, índices, parâmetros (SX6) e menu (sem SX1: filtros via ParamBox) |

## 2. Requisitos

| ID | Requisito | Implementação |
|---|---|---|
| REQ-001 | Filtros: Filial de/até, Vencimento real de/até, Portador/Agência/Conta, Borderô de/até, Lote de/até, Situação e Banco do risco | `PXFINA37` – `CarregaTitulos` |
| REQ-002 | Marcar Todos, Desmarcar Todos e Inverter (também com clique no cabeçalho) | `MarcaTodos` |
| REQ-003 | Risco Sacado: um lote por filial (`GetSXENum("SE1","E1_XLOTRS")`), grava `E1_XLOTRS`, `E1_XBANCO`, `E1_XRISCO='S'`, `E1_XDTRISC`, `E1_XSTRIC='1'` | `AcaoRiscoSacado`/`ProcessaLote` |
| REQ-004 | Não Pago ao Banco: 1 → 2 | `AcaoSituacao` |
| REQ-005 | Pago ao Banco: 1 → 3 (baixa manual depois) | `AcaoSituacao` |
| REQ-006 | Estornar Situação: 2/3 → 1, só se não houver baixa após o envio nem SE2 gerado | `AcaoSituacao`/`ValidaSituacao` |
| REQ-007 | Na baixa `NOR` que zera o saldo, com status `2`, gerar SE2 pelo valor total (`E1_VALOR`), cópia do SE1, mudando só fornecedor/loja e natureza | `FINM010` `MODELCOMMITTTS` → `U_PXRSGeraPagar` |
| REQ-008 | Cancelamento da baixa com status `2`: excluir o SE2 se estiver aberto; bloquear se já foi baixado ou está em borderô | `FINM010` `MODELPOS`/`MODELCOMMITTTS` |
| REQ-009 | Natureza do SE2 vem do parâmetro `MV_XRSNAT` | `U_PXRSGeraPagar` |
| REQ-010 | Bloquear a baixa (de qualquer origem) com status `1` | `FINM010` `MODELPOS` + `FA070TIT` |
| REQ-011 | Falha ao gerar o SE2 desfaz a baixa | Pré-validação no `MODELPOS` + `DisarmTransaction()` no commit |
| REQ-012 | Ações de situação por seleção individual ou por lote (filtro Lote de/até + Marcar Todos) | `PXFINA37` |
| REQ-013 | Excluir Lote: devolve todos os títulos para "sem risco", só sem baixa após o envio e sem SE2 | `AcaoExcluirLote` |
| REQ-014 | Relatório do lote com totais | `PXFINR25` |

### Domínio `E1_XSTRIC`

| Valor | Significado | Efeito na baixa do SE1 |
|---|---|---|
| `1` | Enviado ao Banco | **Baixa bloqueada** |
| `2` | Não pago ao Banco | **Gera SE2** na baixa `NOR` que zera o saldo |
| `3` | Pago ao Banco | Nenhum (baixa manual) |

```text
(sem risco) --Risco Sacado--> 1 --Não Pago ao Banco--> 2 --baixa NOR total--> gera SE2
                              1 --Pago ao Banco------> 3 --baixa manual-----> sem SE2
                         2 / 3 --Estornar Situação--> 1   (sem baixa após envio / sem SE2)
            lote inteiro --Excluir Lote--> (sem risco)    (sem baixa após envio / sem SE2)
```

## 3. Restrições aplicadas

- Arquivos em TLPP com `tlpp-core.th` + `totvs.ch`, codificação CP-1252, sem `IIF`, sem `Function` pública, sem `ConOut`. O log usa `FWLogMsg`, grupo `RISCOSACADO`.
- As queries usam `FWExecStatement` com parâmetros (bind), `D_E_L_E_T_` e filtro de filial.
- Nenhuma interface dentro de `Begin Transaction` ou do commit do MVC. No FINM010, os erros vão para `SetErrorMessage`/`AutoGrLog`/log.
- A marca do browse fica em `FWTemporaryTable` (`TR_OK`). O `E1_OK` não é usado.
- Não há troca de `cFilAnt`, e o SM0 não é acessado diretamente (CA2000). O lote usa a sequência da filial logada, e a unicidade é garantida por filial com `LoteExiste`.
- Os PEs restauram a área da SE1 (`GetArea`/`RestArea`) para não interferir na rotina padrão.

## 4. Pesquisa TDN (2026-10-13)

| Símbolo | Situação | Uso |
|---|---|---|
| PE MVC `FINM010` | ✅ Documentado: modelo da Baixa a Receber; trata só o registro principal da baixa (FK1) | Gancho central |
| IDs `MODELPOS`, `MODELCOMMITTTS` (dentro da transação) | ✅ Documentados | Bloqueio / geração |
| `FA070TIT` | ✅ Retorno lógico; também executa no ExecAuto (`lF070Auto`) | Barreira no FINA070 |
| ExecAuto `FINA070` (3/5/6, `AUTMOTBX`) | ✅ | Testes |
| ExecAuto `FINA050` (3/5) | ✅ Padrão já usado em `PxFinA32AglutinacaoImpostos.tlpp` | Geração e exclusão do SE2 |
| `F200AVL` (CNAB) | ⚠️ Documentado, mas dispara para **todas** as ocorrências do retorno (inclusive as que não são baixa) e sem SE1 posicionado | **Não implementado**: o bloqueio no CNAB fica a cargo do `FINM010` |
| `F110TIT` (lote) | ⚠️ A semântica do retorno é ambígua no TDN | **Não implementado**: o bloqueio no lote fica a cargo do `FINM010` |
| `F070ACONT` | ❌ Não executa no ExecAuto | Descartado |
| `SE5FI070` | ❌ O TDN orienta usar MVC na P12 | Descartado |
| `F070CANCEL` | ❌ Só altera valores da tela | Descartado |
| `FA070CAN`/`FA070CA2-4` | ❌ Página "Em construção" | Descartado |

## 5. Validações pendentes em debug (ambiente de testes 12.1.2510)

Ligue `MV_XRSLOG = .T.`: o `FINM010` registra no log (`RISCOSACADO`) o ID, FunName, a operação, `FK1_TPDOC`, `FK1_MOTBX`, `FK1_VALOR`, `FK1_IDDOC`, o SE1, `E1_SALDO` e `E1_XSTRIC`.

| ID | Validação | Se falhar |
|---|---|---|
| VAL-001 | O `FINM010` (`MODELPOS`/`MODELCOMMITTTS`) dispara nas baixas por FINA070 manual, FINA070 ExecAuto, FINA110 e FINA200 | Criar PE específico na rotina (ex.: `F70GRSE1` para CNAB) |
| VAL-002 | O cancelamento passa pelo `FINM010` com `FK1_TPDOC='ES'` ou com operação DELETE | Ajustar `OperacaoBaixa` ou usar `F070EST` |
| VAL-003 | No `MODELCOMMITTTS`, `E1_SALDO` já está atualizado (regra "zera saldo") e `FK1_IDDOC` → FK7 localiza o título | Ajustar `ProcessaCommit`/`PosicionaTitulo` |
| VAL-004 | O retorno `.F.` no `MODELPOS` aborta a baixa sem erro técnico em FINA110/FINA200 (qual mensagem o lote/CNAB mostra) | Avaliar PE específico |
| VAL-005 | `DisarmTransaction()` dentro do `MODELCOMMITTTS` desfaz a baixa por inteiro | Mover a geração para validação prévia completa |
| VAL-006 | O ExecAuto `FINA050` aninhado na baixa funciona (variáveis privadas, `FWModelActive` restaurado) | Gerar fora da transação com reprocessamento |
| VAL-007 | Os PEs de inclusão a pagar existentes (`FA050INC`, `F050INC`, `F050GER`, `FA050FIN`...) não bloqueiam o SE2 do risco sacado | Tratar `E2_XORIRS` preenchido nesses PEs |
| VAL-008 | O FINA050 aceita a emissão/vencimento originais (datas retroativas, `MV_DATAFIN`) | Definir regra de datas com o usuário |

## 6. Tarefas

| Task | Descrição | Status |
|---|---|---|
| TASK-001 | Criar o dicionário (`DICIONARIO.md`) no ambiente de testes | ⏳ |
| TASK-002 | Compilar os 5 fontes (RDMake / TDS) | ⏳ |
| TASK-003 | Executar VAL-001 a VAL-008 com `MV_XRSLOG = .T.` | ⏳ |
| TASK-004 | Ajustes conforme as validações | ⏳ |
| TASK-005 | Testes de cenário (seção 7) | ⏳ |
| TASK-006 | Copiar os fontes para `protheus/SIGAFIN/...` e publicar | ⏳ |

## 7. Cenários de teste

1. Risco Sacado multi-filial: um lote por filial, sequência sem repetição e banco sem fornecedor em uma das filiais.
2. Baixa manual de título com status `1` → bloqueada (`FA070TIT`). O mesmo vale para ExecAuto, lote e CNAB (`FINM010`).
3. Status `2`: baixa parcial não gera SE2; a baixa total gera o SE2 (fornecedor do banco, natureza `MV_XRSNAT`, `E2_XORIRS`).
4. Status `2` com `MV_XRSNAT` vazio ou fornecedor inválido → baixa bloqueada no `MODELPOS`.
5. Cancelamento da baixa com SE2 em aberto → SE2 excluído. Com SE2 baixado ou em borderô → cancelamento bloqueado.
6. Status `3`: a baixa manual não gera SE2.
7. Baixa com motivo diferente de `NOR` (ex.: DAC, CMP) e status `2` → não gera SE2.
8. Estornar Situação 2/3 → 1, com e sem baixa e com SE2 gerado.
9. Excluir Lote com e sem baixa.
10. Relatório PXFINR25 com filtros e totais.

## 8. Riscos

- **RISK-001:** a natureza `MV_XRSNAT` com retenção (IR/PIS/COFINS/CSLL/ISS) calcularia impostos no SE2. Configure uma natureza sem retenção.
- **RISK-002:** o bloqueio do status `1` no CNAB rejeita a ocorrência. O título continua aberto, e o retorno deve ser reprocessado depois de informada a situação.
- **RISK-003:** `E1_XBANCO` guarda só o código. O fornecedor é lido da primeira agência/conta do banco com `A6_XFORN` preenchido.
- **RISK-004:** o usuário que gerou o lote só fica registrado no log do servidor (decisão: sem tabela de cabeçalho).
