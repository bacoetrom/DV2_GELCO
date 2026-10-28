#include "totvs.ch"
#include "Protheus.ch"
#include "rwmake.ch"
#include "topConn.ch"
#include "font.ch"
#include "colors.ch"
#include "fwMvcDef.ch"
#include "fwPrintSetup.ch"
#include "rptDef.ch"

#define ENTER chr(13) + chr(10)

/*
Programa.: TFin0001.prw
Tipo.....: Tarefa
Autor....: Odair Batista - TOTVS Unidade Londrina
Data.....: 25/01/2018
Descrição: Emissor de Boleto Bancário
Notas....:

Tipo.....: Tarefa
Autor....: Wiliam Campana
Data.....: 30/10/2018
Descrição: Adicionado campo do Valor Total selecionado quando marcar os Itens.
Notas....:

Tipo.....: Tarefa
Autor....: Wiliam Campana
Data.....: 12/11/2018
Descrição: Adicionado Layout do Banco Sofisa (637)
Notas....:

Tipo.....: Tarefa
Autor....: Wiliam Campana
Data.....: 21/02/2019
Descrição: Adicionado opção para incluir Mensagem no Corpo do E-Mail
Notas....:

Tipo.....: Tarefa
Autor....: Wiliam Campana
Data.....: 08/10/2019
Descrição: Adicionado opção para Imprimir Duplicata Mercantil
Notas....:

Tipo.....: Tarefa
Autor....: Wiliam Campana
Data.....: 28/07/2020
Descrição: Adicionado algums opções para controle de execução via Job
Notas....:

Tipo.....: Tarefa
Autor....: Wiliam Campana
Data.....: 29/09/2020
Descrição: Query (loadData) estava com filtro errado (no campo Saldo)
Notas....:

Tipo.....: Tarefa
Autor....: Wiliam Campana
Data.....: 15/07/2022
Descrição: Adicionado chamada para banco 084 (Uniprime)
Notas....:
*/

static oAlerts  := tcAlerts():New()
static cProgram := "TFin0001"
static cTitle   := 'Emissor de Boleto Bancário'


//-------------------------------------------------------------------
/*/{Protheus.doc} TFin0001
Função principal para chamada externa
@author odair.batista
@since 25/01/2018
@version 1.0
@type function
@param cDevice, caracter, Indica o dispositivo de saída ('File', 'Screen', 'Printer', 'E-mail')
@param aParam , array   , Vetor contendo parâmetros de filtragem (Não obrigatório)
@example
U_TFin0001('Printer', aParam)
@obs
	aParam:
		[01] MV_PAR01: Data Emissão De    
		[02] MV_PAR02: Data Emissão Até  
		[03] MV_PAR03: Data Vencimento De 
		[04] MV_PAR04: Data Vencimento Até
		[05] MV_PAR05: Prefixo De		   
		[06] MV_PAR06: Prefixo Até		   
		[07] MV_PAR07: Tipo De			   
		[08] MV_PAR08: Tipo Até		
		[09] MV_PAR09: Número De		
		[10] MV_PAR10: Número Até		   
		[11] MV_PAR11: Parcela De
		[12] MV_PAR12: Parcela Até	   	   
		[13] MV_PAR13: Cliente De	 	   
		[14] MV_PAR14: Loja De			   
		[15] MV_PAR15: Cliente Até		   
		[16] MV_PAR16: Loja Até		
		[17] MV_PAR17: Situação
		[18] MV_PAR18: Job (se é executado pelo Job)
/*/
//-------------------------------------------------------------------
user function TFin0001(cDevice, aParam)
	local aArea       := getArea()
	local nRow        := 0
	local oUser       := nil
	local cDirSrv     := '\spool\boleto\'
	local cDirLoc     := 'c:\totvs\boleto\'

	private aData     := {}
	private aFiles    := {}
	private isAuto    := .f.
	private oBrowse   := nil
	private cFilter   := ''
	private aStack    := {1,.f.,.f.}
	private cUserName := ''
	private _cDirBase := iif(allTrim(funName()) == 'HJOB0008', cDirSrv, cDirLoc)

	private cMsg1     := space(120)
	private cMsg2     := 'Boletos anexados ao e-mail em formato PDF' + space(79)
	privaTE cMsg3     := space(120)

	default cDevice   := 'Printer'
	default aParam    := {}
	default isJob     := .f.
	/*
	//Obtem o nome do usuario logado
	oUser := tcUser():New()
	
	oUser:FindByID(__cUserID)
	
	if oUser:Available()
		cUserName := oUser:GetUserName()
	endIf

	oUser:Destroy()
	
	/* Inicio do tratamento para parâmetro de saída */
	
	if allTrim(cDevice) == 'Email'
		cDevice := 'E-mail'
	endIf

	if empty(cDevice) ;
		.or. (allTrim(cDevice) <> 'File' ;
			  .and. allTrim(cDevice) <> 'Screen' ;
			  .and. allTrim(cDevice) <> 'Printer' ;
			  .and. alltrim(cDevice) <> 'E-mail')
		
		cDevice := 'Printer'
	endIf
	
	cDevice := allTrim(cDevice)
	/* Término do tratamento para parâmetro de saída */

	/*
	Se o array de parâmetros aParam estiver carregado, esta rotina faz a carga automática dos
	títulos baseando-se em seus dados e imprime automaticamente os boletos sem abrir a interface
	do programa.
	*/
	if !empty(aParam)
		isAuto := .t.

		for nRow := 1 to len(aParam)
			&("mv_par" + strZero(nRow, 2)) := aParam[nRow]
		next nRow

		isJob := mv_par18

		loadData()
		doPrinter(cDevice)

		return()
	endIf

	oBrowse := fwMarkBrowse():New()		//Instanciando o objeto mark browse

	oBrowse:SetAlias("SE1")				//Setando a tabela
	oBrowse:SetSemaphore(.t.)
	oBrowse:SetDescription(cTitle)		//Setando a descrição da rotina
	oBrowse:SetFieldMark('E1_OK')

	//Adicionando legendas
	oBrowse:AddLegend("empty(SE1->E1_NUMBCO)" , "GREEN", "Pendente")
	oBrowse:AddLegend("!empty(SE1->E1_NUMBCO)", "RED"  , "Impresso")

	oBrowse:SetUseFilter(.f.)						//Desabilita o uso do filtro padrão da Window
	oBrowse:SetIniWindow({|| initialWindow()})		//Executa procedimentos iniciais da Window que contém o browse
	oBrowse:SetAfterMark({|| onMark()})

	oBrowse:AddButton('Filtrar'                     , {|| onFilter()},, 6,)
	oBrowse:AddButton('Imprimir Boleto'             , {|| onPrinter(cDevice)},, 6,)
	oBrowse:AddButton('Enviar Boleto por E-mail'    , {|| onSendMail()},, 6,)
	//oBrowse:AddButton('Geração de Nosso Número'     , {|| onGenerate()},, 6,)
	oBrowse:AddButton('Marcar Todos'                , {|| onMarkAll(.t.)},, 6,)
	oBrowse:AddButton('Desmarcar Todos'             , {|| onMarkAll(.f.)},, 6,)
	//oBrowse:AddButton('Alterar Banco Padrão'        , {|| onUpdBanco()},, 6,)
	oBrowse:AddButton('Legenda'				        , {|| onLegend()},, 6,)
	//oBrowse:AddButton('Registros Marcados <F7>'     , {|| onRecords()},, 6,)
	//oBrowse:AddButton('Incluir Mensagem E-Mail'     , {|| onMsgMail()},, 6,)
	//oBrowse:addButton('Imprimir Duplicata Mercantil', {|| onPrintDup()},, 6,)

	onFilter()				//Setando filtro padrão do browser e carregando os títulos (aData)

	setKey(VK_F7, {|| onRecords()})

	oBrowse:Activate()		//Ativa a Browse

	restArea(aArea)
return nil


//-------------------------------------------------------------------
/*/{Protheus.doc} initialWindow
Função executada quando a windows é iniciada
@author odair.batista
@since 25/01/2018
@version 1.0
@type function
/*/
//-------------------------------------------------------------------
static function initialWindow()
return


//-------------------------------------------------------------------
/*/{Protheus.doc} onMark
Função para marcar/desmarcar o item corrente
@author odair.batista
@since 26/01/2018
@version 1.0
@type function
/*/
//-------------------------------------------------------------------
static function onMark()
	local nRow := aScan(aData, {|x| x[1] == SE1->(recno())})

	if nRow == 0
		return
	endIf

	aData[nRow, 2] := oBrowse:IsMark()
return


//-------------------------------------------------------------------
/*/{Protheus.doc} onMarkAll
Função para marcar/desmarcar todos os itens no Browser
@author odair.batista
@since 25/01/2018
@version 1.0
@type function
@param isMark, lógico, indica a ação a ser executada (marcar/desmarcar)
/*/
//-------------------------------------------------------------------
static function onMarkAll(isMark)
	local areaSE1 := SE1->(getArea())
	local nRow    := 0

	dbSelectArea('SE1')
	SE1->(dbGoTop())

	for nRow := 1 to len(aData)
		SE1->(dbGoTo(aData[nRow, 1]))

		if !SE1->(eof()) ;
				.and. SE1->(msRLock())

			if !isMark ;
					.and. SE1->E1_OK == oBrowse:cMark

				SE1->E1_OK 	   := '  '
				aData[nRow, 2] := .f.
			endIf

			if isMark ;
					.and. SE1->E1_OK <> oBrowse:cMark

				SE1->E1_OK 	   := oBrowse:cMark
				aData[nRow, 2] := .t.
			endIf

			SE1->(msUnlock())
		endIf
	next nRow

	restArea(areaSE1)

	oBrowse:Refresh(.t.)
return


//-------------------------------------------------------------------
/*/{Protheus.doc} onMsgMail
Apresenta tela contendo as mensagens que vai no e-mail
@author william.campana
@since 21/02/2019
@version 1.0
@type function
/*/
//-------------------------------------------------------------------
static function onMsgMail()
	private oDlg   := nil
	private oGroup := nil
	private oMsg1  := nil
	private oMsg2  := nil
	private oMsg3  := nil
	private oBtOk  := nil

	//Criando dialog
	oDlg := msDialog():New(0, 0, 185, 600, "Mensagem no E-Mail",,, .f.,,,,,, .t.,,, .t.)

	//Criando grupo
	oGroup := tGroup():New(000, 005, 075, 295, 'Mensagem', oDlg,,, .t.)

	oMsg1 := TGet():New(010, 010, {|u| if(PCount() == 0, cMsg1, cMsg1 := u)}, oGroup, 280, 009, nil, {|| }, 0,,,.F.,,.T.,,.F.,,.F.,.F.,,.F.,.F.,"",cMsg1,,,,,,,"Mensagem 1", 1)
	oMsg2 := TGet():New(030, 010, {|u| if(PCount() == 0, cMsg2, cMsg2 := u)}, oGroup, 280, 009, nil, {|| }, 0,,,.F.,,.T.,,.F.,,.F.,.F.,,.F.,.F.,"",cMsg2,,,,,,,"Mensagem 2", 1)
	oMsg3 := TGet():New(050, 010, {|u| if(PCount() == 0, cMsg3, cMsg3 := u)}, oGroup, 280, 009, nil, {|| }, 0,,,.F.,,.T.,,.F.,,.F.,.F.,,.F.,.F.,"",cMsg3,,,,,,,"Mensagem 3", 1)

	//Criando botões
	oBtOk := tButton():New(080, 240, "OK", oDlg, {|| oDlg:End()}, 40, 10,,, .f., .t., .f.,, .f.,,, .f.)

	set key VK_ESCAPE to oDlg:End()

	//Ativação do dialog
	oDlg:Activate(,,, .t.)
return

//-------------------------------------------------------------------
/*/{Protheus.doc} onRecords
Apresenta tela contendo os dados dos registros marcados
@author odair.batista
@since 26/07/2018
@version 1.0
@type function
/*/
//-------------------------------------------------------------------
static function onRecords()
	local aMark := sumMark()

	private oDlg   := nil
	private oGroup := nil
	private oSE1   := nil, nSE1   := aMark[1]
	private oSA1   := nil, nSA1   := aMark[2]
	private oVLSE1 := nil, nVLSE1 := aMark[3]
	private oBtOk  := nil

	//Criando dialog
	oDlg := msDialog():New(0, 0, 180, 260, "Registros Marcados",,, .f.,,,,,, .t.,,, .t.)

	//Criando grupo
	oGroup := tGroup():New(000, 005, 085, 085, 'Marcações', oDlg,,, .t.)

	oSE1   := tGet():New(010, 010, {| u | if(pCount() == 0, nSE1,   nSE1   := u)}, oGroup, 040, 009, "@E 99999",,          CLR_BLACK, CLR_WHITE,,,, .t., "",, {|| .f.}, .f., .f.,, .f., .f., "", "",,,, .t.,,, 'Títulos Marcados',  1)
	oSA1   := tGet():New(030, 010, {| u | if(pCount() == 0, nSA1,   nSA1   := u)}, oGroup, 040, 009, "@E 99999",,          CLR_BLACK, CLR_WHITE,,,, .t., "",, {|| .f.}, .f., .f.,, .f., .f., "", "",,,, .t.,,, 'Clientes Marcados', 1)
	oVLSE1 := tGet():New(050, 010, {| u | if(pCount() == 0, nVLSE1, nVLSE1 := u)}, oGroup, 070, 009, "@E 999,999,999.99",, CLR_BLACK, CLR_WHITE,,,, .t., "",, {|| .f.}, .f., .f.,, .f., .f., "", "",,,, .t.,,, 'Valor Selecionado', 1)

	//Criando botões
	oBtOk := tButton():New(005, 090, "OK", oDlg, {|| oDlg:End()}, 40, 10,,, .f., .t., .f.,, .f.,,, .f.)

	set key VK_ESCAPE to oDlg:End()

	//Ativação do dialog
	oDlg:Activate(,,, .t.)
return


//-------------------------------------------------------------------
/*/{Protheus.doc} sumMark
Efetua o calculo dos dados dos registros marcados
@author odair.batista
@since 26/07/2018
@version 1.0
@type function
@return aMark, array, [1]Quantidade de títulos marcados, [2]Quantidade de clientes marcados
/*/
//-------------------------------------------------------------------
static function sumMark()
	local nRow   := 0
	local nSE1   := 0
	local nSA1   := 0
	local nVLSE1 := 0
	local aMark := {}

	for nRow := 1 to len(aData)
		if aData[nRow, 2]
			SE1->(dbGoTo(aData[nRow, 1]))

			if !SE1->(eof())
				nSE1 += 1
				nVLSE1 += SE1->E1_VALOR

				if !aScan(aMark, SE1->E1_CLIENTE + SE1->E1_LOJA)
					aAdd(aMark, SE1->E1_CLIENTE + SE1->E1_LOJA)
					nSA1 += 1
				endIf
			endIf
		endIf
	next nRow

	aMark := {nSE1, nSA1, nVLSE1}
return(aMark)


//-------------------------------------------------------------------
/*/{Protheus.doc} menuDef
Definição do menu MVC
@author odair.batista
@since 25/01/2018
@version 1.0
@type function
/*/
//-------------------------------------------------------------------
static function menuDef()
	local aRot := {}

	//Adicionando opções
	add option aRot title 'Visualizar' action 'ViewDef.TFin0001' operation 1 access 0
return aRot


//-------------------------------------------------------------------
/*/{Protheus.doc} modelDef
Definição do modelo de Dados
@author odair.batista
@since 25/01/2018
@version 1.0
@type function
/*/
//-------------------------------------------------------------------
static Function modelDef()
	local oModel  := nil
	local oStrSE1 := FWFormStruct(1, 'SE1')

	oModel := MPFormModel():New('MainModel' ;
		, /*{|oModel| preValidDef(oModel)}*/ ;
		, /*{|oModel| validDef(oModel)}*/ ;
		, /*{|oModel| saveDef(oModel)}*/ ;
		,, /*{|oModel| cancelDef(oModel)}*/)

	oModel:SetDescription(cTitle)

	//Criação de objetos de interface
	oModel:addFields('MFieldSE1',, oStrSE1)

	oModel:SetPrimaryKey({"E1_FILIAL", "E1_DOC", "E1_PARCELA"})		//Indicando índice primário

	//Informando as descrições para os modelos de dados
	oModel:getModel('MFieldSE1'):SetDescription('Título a Receber')
return oModel


//-------------------------------------------------------------------
/*/{Protheus.doc} viewDef
Definição do interface
@author odair.batista
@since 25/01/2018
@version 1.0
@type function
/*/
//-------------------------------------------------------------------
static function viewDef()
	local oView	  := nil
	local oModel  := ModelDef()
	local oStrSE1 := FWFormStruct(2, 'SE1')

	oView := FWFormView():New()		//Instanciando a View para interface

	oView:SetModel(oModel)			//Indicando o modelo de dados para a View

	//Adicionando objetos de interface
	oView:AddField('formSE1', oStrSE1, 'MFieldSE1')

	oView:CreateHorizontalBox("boxSE1", 100)
	oView:SetOwnerView("formSE1", "boxSE1")

	//Força o fechamento da janela na confirmação
	oView:SetCloseOnOk({|| .t.})
return oView


//-------------------------------------------------------------------
/*/{Protheus.doc} onFilter
Gatilho para filtragem do browser 
@author odair.batista
@since 25/01/2018
@version 1.0
@type function

//-------------------------------------------------------------------
/*/
static function onFilter()
	oAlerts:Empty()

	if !filter()
		oAlerts:Add('1' ;
			, 'Filtro cancelado pelo usuário!' ;
			, 'E' ;
			, 'A execução do filtro foi cancelado pelo usuário.')
	endIf

	oAlerts:Show()

	if oAlerts:HasErrors()
		return
	endIf

	cFilter := createFilter()

	oBrowse:SetFilterDefault(cFilter)
return


//-------------------------------------------------------------------
/*/{Protheus.doc} createFilter
Montagem da estrutura de filtro do browser e efetua carga de dados da query 
@author odair.batista
@since 25/01/2018
@version 1.0
@type function
/*/
//-------------------------------------------------------------------
static function createFilter()
	local cFilter      := ".t."
	local cEmptyNumBco := padR(' ', len(SE1->E1_NUMBCO), ' ')

	//cFilter += " .and. subStr(SE1->E1_UFORMA, 1, 3) = 'BOL' "
	if !empty(mv_par01)
		cFilter += " .and. SE1->E1_NUMBOR >= '" + mv_par01 + "'"
	endIf

	if !empty(mv_par02)
		cFilter += " .and. SE1->E1_NUMBOR <= '" + mv_par02 + "'"
	endIf

	if !empty(mv_par03)
		cFilter += " .and. dToS(SE1->E1_EMISSAO) >= '" + dToS(mv_par03) + "'"
	endIf

	if !empty(mv_par04)
		cFilter += " .and. dToS(SE1->E1_EMISSAO) <= '" + dToS(mv_par04) + "'"
	endIf

	if !empty(mv_par05)
		cFilter += " .and. dToS(SE1->E1_VENCTO) >= '" + dToS(mv_par05) + "'"
	endIf

	if !empty(mv_par06)
		cFilter += " .and. dToS(SE1->E1_VENCTO) <= '" + dToS(mv_par06) + "'"
	endIf

	if !empty(mv_par07)
		cFilter += " .and. SE1->E1_PREFIXO >= '" + mv_par07 + "'"
	endIf

	if !empty(mv_par08)
		cFilter += " .and. SE1->E1_PREFIXO <= '" + mv_par08 + "'"
	endIf

	if !empty(mv_par09)
		cFilter += " .and. SE1->E1_TIPO >= '" + mv_par09 + "'"
	endIf

	if !empty(mv_par10)
		cFilter += " .and. SE1->E1_TIPO <= '" + mv_par10 + "'"
	endIf

	if !empty(mv_par11)
		cFilter += " .and. SE1->E1_NUM >= '" + mv_par11 + "'"
	endIf

	if !empty(mv_par12)
		cFilter += " .and. SE1->E1_NUM <= '" + mv_par12 + "'"
	endIf

	if !empty(mv_par13)
		cFilter += " .and. SE1->E1_PARCELA >= '" + mv_par13 + "'"
	endIf

	if !empty(mv_par14)
		cFilter += " .and. SE1->E1_PARCELA <= '" + mv_par14 + "'"
	endIf

	if !empty(mv_par15)
		cFilter += " .and. SE1->E1_CLIENTE >= '" + mv_par15 + "'"
	endIf

	if !empty(mv_par16)
		cFilter += " .and. SE1->E1_LOJA >= '" + mv_par16 + "'"
	endIf

	if !empty(mv_par17)
		cFilter += " .and. SE1->E1_CLIENTE <= '" + mv_par17 + "'"
	endIf

	if !empty(mv_par18)
		cFilter += " .and. SE1->E1_LOJA <= '" + mv_par18 + "'"
	endIf

	if valType(mv_par19) <> 'N'
		mv_par19 := 1
	endIf
	
	if mv_par19 == 1
		cFilter += " .and. SE1->E1_SITUACA <> '0' "
		cFilter += " .and. SE1->E1_NUMBCO  == '" + cEmptyNumBco + "' "
	else
		cFilter += " .and. SE1->E1_NUMBCO <> '" + cEmptyNumBco + "' "
	endIf

	cFilter += " .and. SE1->E1_SALDO > 0 "
	//cFilter += " .and. posicione('SA1', 1, xFilial('SA1') + SE1->E1_CLIENTE + SE1->E1_LOJA, 'A1_UENVBOL') <> '2' "

	loadData()
return(cFilter)


//-------------------------------------------------------------------
/*/{Protheus.doc} loadData
Carga de dados para impressão baseando-se no array de parâmetros recebidos. Impressão automática 
@author odair.batista
@since 25/01/2018
@version 1.0
@type function
/*/
//-------------------------------------------------------------------
static function loadData()
	local cEmptyNumBco := padR(' ', len(SE1->E1_NUMBCO), ' ')
	local cQuery 	   := ''
	local areaSE1	   := SE1->(getArea())

	cQuery := "SELECT SE1.R_E_C_N_O_ AS RECNO, SE1.E1_OK "
	cQuery += "FROM " + retSqlName('SE1') + " SE1 "
	cQuery += "INNER JOIN " + retSqlName('SA1') + " SA1 "
	cQuery += "   ON SA1.D_E_L_E_T_  = ' ' "
	cQuery += "  AND SA1.A1_FILIAL   = '" + xFilial('SA1') + "' "
	cQuery += "  AND SA1.A1_COD      = SE1.E1_CLIENTE "
	cQuery += "  AND SA1.A1_LOJA     = SE1.E1_LOJA "
	//cQuery += "  AND SA1.A1_UENVBOL <> '2' "
	cQuery += "WHERE SE1.D_E_L_E_T_  = ' ' "
	cQuery += "  AND SE1.E1_FILIAL   = '" + xFilial('SE1') + "' "
	//cQuery += "  AND SUBSTRING(SE1.E1_UFORMA, 1, 3) = 'BOL' "

	if !empty(mv_par01)
		cQuery += " AND SE1.E1_NUMBOR >= '" + mv_par01 + "'"
	endIf

	if !empty(mv_par02)
		cQuery += " AND SE1.E1_NUMBOR <= '" + mv_par02 + "'"
	endIf

	if !empty(mv_par03)
		cQuery += "  AND SE1.E1_EMISSAO >= '" + dToS(mv_par03) + "' "
	endIf

	if !empty(mv_par04)
		cQuery += "  AND SE1.E1_EMISSAO <= '" + dToS(mv_par04) + "' "
	endIf

	if !empty(mv_par05)
		cQuery += "  AND SE1.E1_VENCTO >= '" + dToS(mv_par05) + "' "
	endIf

	if !empty(mv_par06)
		cQuery += "  AND SE1.E1_VENCTO <= '" + dToS(mv_par06) + "' "
	endIf

	if !empty(mv_par07)
		cQuery += "  AND SE1.E1_PREFIXO >= '" + mv_par07 + "' "
	endIf

	if !empty(mv_par08)
		cQuery += "  AND SE1.E1_PREFIXO <= '" + mv_par08 + "' "
	endIf

	if !empty(mv_par09)
		cQuery += "  AND SE1.E1_TIPO >= '" + mv_par09 + "' "
	endIf

	if !empty(mv_par10)
		cQuery += "  AND SE1.E1_TIPO <= '" + mv_par10 + "' "
	endIf

	if !empty(mv_par11)
		cQuery += "  AND SE1.E1_NUM >= '" + mv_par11+ "' "
	endIf

	if !empty(mv_par12)
		cQuery += "  AND SE1.E1_NUM <= '" + mv_par12 + "' "
	endIf

	if !empty(mv_par13)
		cQuery += "  AND SE1.E1_PARCELA >= '" + mv_par13 + "' "
	endIf

	if !empty(mv_par14)
		cQuery += "  AND SE1.E1_PARCELA <= '" + mv_par14 + "' "
	endIf

	if !empty(mv_par15)
		cQuery += "  AND SE1.E1_CLIENTE >= '" + mv_par15 + "' "
	endIf

	if !empty(mv_par16)
		cQuery += "  AND SE1.E1_LOJA >= '" + mv_par16 + "' "
	endIf

	if !empty(mv_par17)
		cQuery += "  AND SE1.E1_CLIENTE <= '" + mv_par17 + "' "
	endIf

	if !empty(mv_par18)
		cQuery += "  AND SE1.E1_LOJA <= '" + mv_par18 + "' "
	endIf

	if valType(mv_par19) <> 'N'
		mv_par19 := 1
	endIf

	if mv_par19 == 1
		cQuery += "  AND SE1.E1_SITUACA <> '0' "
		cQuery += "  AND SE1.E1_NUMBCO  = '" + cEmptyNumBco + "' "
	else
		cQuery += "  AND SE1.E1_NUMBCO <> '" + cEmptyNumBco + "' "
	endIf

	cQuery += " AND SE1.E1_SALDO > 0 "
	cQuery += "ORDER BY SE1.R_E_C_N_O_"

	cQuery := changeQuery(cQuery)
	tcQuery cQuery new alias "qSQL"

	aData := {}

	dbSelectArea('SE1')

	dbSelectArea('qSQL')
	qSQL->(dbGoTop())

	do while !qSQL->(eof())
		SE1->(dbGoTo(qSQL->RECNO))

		if !SE1->(eof())
			SE1->(recLock('SE1', .f.))
			SE1->E1_OK := '  '
			SE1->(msUnlock())

			aAdd(aData, {qSQL->RECNO, isAuto})
		endIf

		qSQL->(dbSkip())
	endDo

	qSQL->(dbCloseArea())

	restArea(areaSE1)
return


//-------------------------------------------------------------------
/*/{Protheus.doc} onPrinter
Gatilho para impressão dos boletos 
@author odair.batista
@since 25/01/2018
@version 1.0
@type function
@param cDevice, caracter, Indica o dispositivo de saída ('File', 'Screen', 'Printer', 'E-mail')
/*/
//-------------------------------------------------------------------
static function onPrinter(cDevice)
	/*
	if oAlerts:Ask('Confirma impressão?' ;
				   , 'Após a confirmação os boletos serão impressos.') <> 'Yes'

		return
	endIf
	*/

	if !output()
		return
	endIf

	if aStack[1] == 1
		cDevice := 'Printer'

		oPrint := fwMsPrinter():New('printer.pdf', IMP_PDF, .f., _cDirBase, .t.,,,,,, .f.,)
		oPrint:Setup()
		oPrint := nil
	elseIf aStack[1] == 2
		cDevice := 'File'
	elseIf aStack[1] == 3
		cDevice := 'Screen'
	endIf

	doPrinter(cDevice)
return


//-------------------------------------------------------------------
/*/{Protheus.doc} syncMarked
Sincroniza aData com os títulos marcados no browse (campo E1_OK).
Se o filtro já foi executado (cFilter), atualiza a marcação dos itens carregados;
caso contrário, carrega os títulos da filial marcados com a marca do browse.
@author pablo.regis
@since 22/10/2026
@version 1.0
@type function
/*/
//-------------------------------------------------------------------
static function syncMarked()
	local areaSE1 := SE1->(getArea())
	local cMark   := oBrowse:Mark()
	local cQuery  := ''
	local nRow    := 0

	if !empty(cFilter)		//Filtro executado: aData já contém os títulos do browse
		dbSelectArea('SE1')

		for nRow := 1 to len(aData)
			SE1->(dbGoTo(aData[nRow, 1]))

			aData[nRow, 2] := (!SE1->(eof()) .and. SE1->E1_OK == cMark)
		next nRow
	else
		aData := {}

		cQuery := "SELECT SE1.R_E_C_N_O_ AS RECNO "
		cQuery += "FROM " + retSqlName('SE1') + " SE1 "
		cQuery += "WHERE SE1.D_E_L_E_T_ = ' ' "
		cQuery += "  AND SE1.E1_FILIAL  = '" + xFilial('SE1') + "' "
		cQuery += "  AND SE1.E1_OK      = '" + cMark + "' "
		cQuery += "  AND SE1.E1_SALDO   > 0 "
		cQuery += "ORDER BY SE1.R_E_C_N_O_"

		cQuery := changeQuery(cQuery)
		tcQuery cQuery new alias "qMRK"

		do while !qMRK->(eof())
			aAdd(aData, {qMRK->RECNO, .t.})

			qMRK->(dbSkip())
		endDo

		qMRK->(dbCloseArea())
	endIf

	restArea(areaSE1)
return


//-------------------------------------------------------------------
/*/{Protheus.doc} onSendMail
Gatilho para envio de e-mail dos boletos gerados 
@author odair.batista
@since 01/02/2018
@version 1.0
@type function
/*/
//-------------------------------------------------------------------
static function onSendMail()
	syncMarked()			//Atualiza aData com as marcas gravadas pelo browse (E1_OK)

	aMark := sumMark()

	oAlerts:Empty()

	if aMark[1] == 0
		oAlerts:Add('onSendMail' ;
			, 'Nenhum título selecionado!' ;
			, 'E' ;
			, 'Marque os títulos desejados no browse e clique novamente em "Enviar Boleto por E-mail".')
	endIf

	if aMark[2] > 2000
		oAlerts:Add('onSendMail' ;
			, 'Quantidade de marcação não permitida!' ;
			, 'E' ;
			, 'A quantidade de clientes para envio de e-mail está limitada a 2000 envios. ' ;
			+ 'Cada cliente representa um envio de e-mail e a quantidade de marcações ' ;
			+ 'totalizam <' + cValToChar(aMark[2]) + '> clientes. Verifique!')
	endIf

	oAlerts:Show()

	if !oAlerts:HasErrors()
		if !isAuto
			if !inputMail()
				return
			endIf
		endIf

		aFiles := {}

		doPrinter('E-mail')
	endIf
return


//-------------------------------------------------------------------
/*/{Protheus.doc} classLoad
Carga das classes especializadas de bancos 
@author odair.batista
@since 25/01/2018
@version 1.0
@type function
@param numBco , caracter, Código do banco (EE_CODIGO)
@param cSubCta, caracter, Subconta do parâmetro de banco (EE_SUBCTA) - define o layout do banco 637
@return oBoleto, objeto, Classe especializada do banco ou nil se não houver classe para o banco/subconta

@history 15/07/2022, william.campana, adicionado chamada para banco 084 (uniprime)
@history 19/10/2026, Pablo Regis, banco 637 separado em tcBco1637 (Santander) e tcBco2637 (Itaú) pela subconta
/*/
//-------------------------------------------------------------------
static function classLoad(numBco, cSubCta)
	local oBoleto := nil

	default cSubCta := ''

	cSubCta := allTrim(cSubCta)

	numBco := allTrim(numBco)

	if numBco == '001'
		//Classe derivada do tcBoleto() para especialização do banco do Brasil
		oBoleto := tcBco001():New()
	elseIf numBco == '033'
		//Classe derivada do tcBoleto() para especialização do banco do Santander
		oBoleto := tcBco033():New()
	elseIf numBco == '084'
		//Classe derivada do tcBoleto() para especialização do banco do Uniprime
		oBoleto := tcBco084():New()
	elseIf numBco == '237'
		//Classe derivada do tcBoleto() para especialização do banco do Bradesco
		oBoleto := tcBco237():New()
	elseIf numBco == '246'
		//Classe derivada do tcBoleto() para especialização do banco do ABC Brasil
		oBoleto := tcBco246():New()
	elseIf numBco == '341'
		//Classe derivada do tcBoleto() para especialização do banco do Itaú
		oBoleto := tcBco341():New()
	elseIf numBco == '422'
		//Classe derivada do tcBoleto() para especialização do banco do Safra
		oBoleto := tcBco422():New()
	elseIf numBco == '637'
		//Classe derivada do tcBoleto() para especialização do banco Sofisa - layout definido pela subconta
		if cSubCta == '001'
			oBoleto := tcBco1637():new()		//Layout Santander
		elseIf cSubCta == '002'
			oBoleto := tcBco2637():new()		//Layout Itaú
		endIf
	elseIf numBco == '756'
		//Classe derivada do tcBoleto() para especialização do banco Sicoob
		oBoleto := tcBco756():new()
	endIf
return(oBoleto)


//-------------------------------------------------------------------
/*/{Protheus.doc} onGenerate
Gatilho para envio somente a geração do Nosso Número 
@author odair.batista
@since 05/11/2018
@version 1.0
@type function
/*/
//-------------------------------------------------------------------
static function onGenerate(recno_SEE)
	local oBoleto   := nil
	local isBcoInf  := .f.
	local oHelper   := tcAlerts():New()
	local rowid_SEE := nil
	Local nRow      := 0

	default recno_SEE := 0

	oAlerts:Empty()

	if mv_par17 > 1
		oAlerts:Add('onGenerate' ;
			, 'Opção de geração não disponível!' ;
			, 'E' ;
			, 'A opção de geração do Nosso Número somente estará disponível quando for filtrado como "Impressão".')
	endIf

	if !oAlerts:HasErrors()
		if oAlerts:Ask('Confirma geração de Nosso Número?' ;
				, 'Após a confirmação serão gerados os identificadores bancários denominados "Nosso Número". ' ;
				+ 'Caso seja necessário a impressão do mesmo após a geração, utilize re-impressão do boleto bancário.') <> 'Yes'
			return
		endIf

		isBcoInf := (recno_SEE <> nil .and. !empty(recno_SEE))

		dbSelectArea('SEE')

		if isBcoInf
			SEE->(dbGoTo(recno_SEE))

			if SEE->(eof())
				oAlerts:Add('onGenerate' ;
					, 'Parâmetro de Banco/Agência/Conta/Sub-conta não encontrado!' ;
					, 'E' ;
					, 'O registro <' + cValToChar(recno_SEE) + '> de parâmetro de ' ;
					+ 'Banco/Agência/Conta/Sub-conta não foi encontrado. <Informado>')
			endIf
		endIf
	endIf

	if !oAlerts:HasErrors()
		cursorWait()

		dbSelectArea('SE1')

		for nRow := 1 to len(aData)
			if aData[nRow, 2]
				oHelper:Empty()

				SE1->(dbGoTo(aData[nRow, 1]))

				if SE1->(eof())
					oHelper:Add('onGenerate' ;
						, 'Título não encontrado!' ;
						, 'E' ;
						, 'O registro <' + cValToChar(aData[nRow, 1]) + '> de título não foi encontrado.')
				elseIf !isBcoInf
					rowid_SEE := U_TFin001a(SE1->E1_CLIENTE, SE1->E1_LOJA)		//Retorna recno da tabela SEE baseado em regras pré-definidas

					SEE->(dbGoTo(rowid_SEE))

					if SEE->(eof())
						oHelper:Add('onGenerate' ;
							, 'Parâmetro de Banco/Agência/Conta/Sub-conta não encontrado!' ;
							, 'E' ;
							, 'O registro <' + cValToChar(rowid_SEE) + '> de parâmetro de ' ;
							+ 'Banco/Agência/Conta/Sub-conta não foi encontrado. ' ;
							+ 'Verifique o cadastro do cliente a tabela <ZAY>. <Regra>')
					endIf
				endIf

				if !oHelper:HasErrors()
					oBoleto := classLoad(SEE->EE_CODIGO, SEE->EE_SUBCTA)

					if oBoleto == nil
						oHelper:Add('onGenerate' ;
							, 'Banco sem layout de boleto!' ;
							, 'E' ;
							, 'Não existe classe de boleto para o banco <' + allTrim(SEE->EE_CODIGO) ;
							+ '> e subconta <' + allTrim(SEE->EE_SUBCTA) + '>. Verifique o cadastro de parâmetros de banco (SEE).')
					endIf
				endIf

				if !oHelper:HasErrors()
					oBoleto:SetAssign(.t.)		//Indica se o nosso número será gravado no título e incrementado na faixa

					oBoleto:Empty()
					oBoleto:FindByRowId(SEE->(recno()))

					if !oBoleto:HasErrors()
						oBoleto:AddBy(SE1->(recno()))

						if !oBoleto:HasErrors()
							oBoleto:Generate()
						endIf
					endIf

					oHelper:AddFrom(oBoleto)

					oBoleto:Destroy(oBoleto)
				endIf

				oAlerts:AddFrom(oHelper)
			endIf
		next nRow

		cursorArrow()
	endIf

	oAlerts:Show()

	if !isAuto
		oBrowse:SetFilterDefault(cFilter)
	endIf
return


//-------------------------------------------------------------------
/*/{Protheus.doc} doPrinter
Impressão de boletos bancários 
@author odair.batista
@since 25/01/2018
@version 1.0
@type function
@param cDevice  , caracter, Indica o dispositivo de saída ('File', 'Screen', 'Printer', 'E-mail')
@param recno_SEE, inteiro , Indica o parâmetro de banco/agência/conta/sub-conta.
@obs
Se o Recno da tabela SEE não for informado, será usado para emissão do boleto o portador 
identificado por meio de regras pré-estabelecidas na função TFin001a().
/*/
//-------------------------------------------------------------------
static function doPrinter(cDevice, recno_SEE)
	local oBoleto   := nil
	local nRow 	    := 0
	local isBcoInf  := .f.
	local oHelper   := tcAlerts():New()
	local rowid_SEE := nil
	local isEmail   := .f.
	local oPrint    := nil

	default cDevice   := 'Printer'
	default recno_SEE := 0

	cursorWait()

	if allTrim(cDevice) == 'Email'
		cDevice := 'E-mail'
	endIf

	if empty(cDevice) ;
			.or. (allTrim(cDevice) <> 'File' ;
			.and. allTrim(cDevice) <> 'Screen' ;
			.and. allTrim(cDevice) <> 'Printer' ;
			.and. alltrim(cDevice) <> 'E-mail')

		cDevice := 'Printer'
	endIf

	cDevice := allTrim(cDevice)

	if cDevice == 'E-mail'
		cDevice := 'File'
		isEmail := .t.
	endIf

	isBcoInf := (recno_SEE <> nil .and. !empty(recno_SEE))

	oAlerts:Empty()

	dbSelectArea('SEE')
	if isBcoInf
		SEE->(dbGoTo(recno_SEE))

		if SEE->(eof())
			oAlerts:Add('doPrinter' ;
				, 'Parâmetro de Banco/Agência/Conta/Sub-conta não encontrado!' ;
				, 'E' ;
				, 'O registro <' + cValToChar(recno_SEE) + '> de parâmetro de ' ;
				+ 'Banco/Agência/Conta/Sub-conta não foi encontrado. <Informado>')
		endIf
	endIf

	if aScan(aData, {|x| x[2]}) == 0
		oAlerts:Add('doPrinter' ;
			, 'Nenhum título selecionado!' ;
			, 'E' ;
			, 'Nenhum título foi marcado para impressão. Utilize o botão "Filtrar" para carregar ' ;
			+ 'os títulos e marque os boletos desejados.')
	endIf

	if !oAlerts:HasErrors()
		dbSelectArea('SE1')

		for nRow := 1 to len(aData)
			if aData[nRow, 2]
				oHelper:Empty()

				SE1->(dbGoTo(aData[nRow, 1]))

				if SE1->(eof())
					oHelper:Add('doPrinter' ;
						, 'Título não encontrado!' ;
						, 'E' ;
						, 'O registro <' + cValToChar(aData[nRow, 1]) + '> de título não foi encontrado.')
				elseIf !isBcoInf
					rowid_SEE := U_TFin001a(SE1->E1_CLIENTE, SE1->E1_LOJA)		//Retorna recno da tabela SEE baseado em regras pré-definidas

					SEE->(dbGoTo(rowid_SEE))

					if SEE->(eof())
						oHelper:Add('doPrinter' ;
							, 'Parâmetro de Banco/Agência/Conta/Sub-conta não encontrado!' ;
							, 'E' ;
							, 'O registro <' + cValToChar(rowid_SEE) + '> de parâmetro de ' ;
							+ 'Banco/Agência/Conta/Sub-conta não foi encontrado. ' ;
							+ 'Verifique o cadastro do cliente a tabela <ZAY>. <Regra>')
					endIf
				endIf

				if !oHelper:HasErrors() ;
						.and. !existDir(_cDirBase)

					if !createDir(_cDirBase)
						//Sem acesso ao disco local (ex.: SmartClient HTML/WebApp ou sem permissão): usa a pasta temporária
						oHelper:Add('doPrinter' ;
							, 'Diretório não pode ser criado!' ;
							, 'A' ;
							, 'O diretório "' + _cDirBase + '" não pode ser criado. ' ;
							+ 'Os boletos serão gerados na pasta temporária "' + getTempPath() + '".')

						_cDirBase := getTempPath()
					endIf
				endIf

				if !oHelper:HasErrors()
					oBoleto := classLoad(SEE->EE_CODIGO, SEE->EE_SUBCTA)

					if oBoleto == nil
						oHelper:Add('doPrinter' ;
							, 'Banco sem layout de boleto!' ;
							, 'E' ;
							, 'Não existe classe de boleto para o banco <' + allTrim(SEE->EE_CODIGO) ;
							+ '> e subconta <' + allTrim(SEE->EE_SUBCTA) + '>. Verifique o cadastro de parâmetros de banco (SEE).')
					endIf
				endIf

				if !oHelper:HasErrors()
					oBoleto:SetPath(_cDirBase)	        //Indica o caminho para geração dos arquivos
					oBoleto:SetOutput(cDevice)			//Indica o dispositivo de saída ['File', 'Screen', 'Printer']
					oBoleto:SetAssign(.t.)				//Indica se o nosso número será gravado no título e incrementado na faixa

					oBoleto:Empty()
					oBoleto:FindByRowId(SEE->(recno()))

					if !oBoleto:HasErrors()
						oBoleto:AddBy(SE1->(recno()))

						if !oBoleto:HasErrors()		//Não imprime boleto sem nosso número/código de barras
							oBoleto:Printer()

							if cDevice == 'File'
								if file(oBoleto:GetFileName())
									oHelper:Add('doPrinter' ;
										, 'Arquivo gerado com sucesso!' ;
										, 'I' ;
										, 'O arquivo <' + oBoleto:GetFileName() + '> foi gerado para o título <' ;
										+ allTrim(SE1->E1_PREFIXO) + '/' + allTrim(SE1->E1_NUM) + '/' + allTrim(SE1->E1_PARCELA) ;
										+ '> do cliente <' + allTrim(SE1->E1_CLIENTE) + '> e loja <' + allTrim(SE1->E1_LOJA) + '>.')
								else
									oHelper:Add('doPrinter' ;
										, 'Arquivo não foi gerado!' ;
										, 'A' ;
										, 'O arquivo <' + oBoleto:GetFileName() + '> não foi encontrado após a geração do título <' ;
										+ allTrim(SE1->E1_PREFIXO) + '/' + allTrim(SE1->E1_NUM) + '/' + allTrim(SE1->E1_PARCELA) + '>.')
								endIf
							endIf

							aAdd(aFiles ;
								, {SE1->E1_CLIENTE ;			//Código do cliente
								, SE1->E1_LOJA ;			//Loja do cliente
								, oBoleto:GetFileName()})   //Nome do PDF gerado com o boleto
						endIf
					endIf

					oHelper:AddFrom(oBoleto)

					oBoleto:Destroy()
				endIf

				oAlerts:AddFrom(oHelper)
			endIf
		next nRow
	endIf

	if isEmail ;
			.and. !oAlerts:HasErrors()

		doSendMail()
	endIf

	cursorArrow()

	if (!isJob)
		oAlerts:Show()
	endIf

	if !isAuto
		oBrowse:SetFilterDefault(cFilter)
	endIf
return


//-------------------------------------------------------------------
/*/{Protheus.doc} createDir
Cria o diretório informado, nível a nível
@author Pablo Regis
@since 19/10/2026
@version 1.0
@type function
@param cPath, caracter, Caminho a ser criado (ex.: 'c:\totvs\boleto\' ou '\spool\boleto\')
@return lOk, lógico, Indica se o diretório existe ao final do processo
/*/
//-------------------------------------------------------------------
static function createDir(cPath)
	local aLevels := strTokArr(allTrim(cPath), '\')
	local cDir    := ''
	local nLevel  := 0
	local lOk     := .t.

	if left(allTrim(cPath), 1) == '\'		//Caminho a partir do RootPath do servidor
		cDir := '\'
	endIf

	for nLevel := 1 to len(aLevels)
		cDir += aLevels[nLevel]

		if lOk ;
				.and. right(cDir, 1) <> ':' ;		//Unidade de disco (ex.: C:) não é criada
				.and. !existDir(cDir)

			makeDir(cDir)
			lOk := existDir(cDir)
		endIf

		cDir += '\'
	next nLevel

return(lOk)


//-------------------------------------------------------------------
/*/{Protheus.doc} doSendMail
Função para envio de e-mail dos boletos gerados 
@author odair.batista
@since 01/02/2018
@version 1.0
@type function
/*/
//-------------------------------------------------------------------
static function doSendMail()
	local nRow     := 0
	local cCliente := ''
	local cLoja    := ''
	local aAttach  := {}

	if empty(aFiles)
		oAlerts:Add('doSendMail' ;
			, 'Não existem boletos para envio!' ;
			, 'E' ;
			, 'Não foram gerados boletos para envio')
	endIf

	if !oAlerts:HasErrors()
		aSort(aFiles,,, {|x,y,z| x[1] < y[1] .and. x[2] < y[2]})

		cCliente := aFiles[1, 1]
		cLoja    := aFiles[1, 2]
		aAttach  := {}

		for nRow := 1 to len(aFiles)
			if cCliente <> aFiles[nRow, 1] ;
					.or. cLoja <> aFiles[nRow, 2]

				toSend(cCliente, cLoja, aAttach)

				cCliente := aFiles[nRow, 1]
				cLoja    := aFiles[nRow, 2]
				aAttach  := {}
			endIf

			aAdd(aAttach, aFiles[nRow, 3])
		next nRow

		if !empty(aAttach)
			toSend(cCliente, cLoja, aAttach)
		endIf
	endIf
return


//-------------------------------------------------------------------
/*/{Protheus.doc} toSend
Função para gerar o e-mail ao cliente 
@author odair.batista
@since 01/02/2018
@version 1.0
@type function
@param cCliente, caracter, código do cliente
@param cLoja   , caracter, loja do cliente
@param aAttach , array   , array contendo os arquivos de boletos do cliente
@obs
Os arquivo serão zipados para ser anexado ao e-mail
/*/ 
//-------------------------------------------------------------------
static function toSend(cCliente, cLoja, aAttach)
	local areaSA1   := SA1->(getArea())
	local cLocal    := getTempPath()
	local cZipFile  := ''
	local cNomDocto := ''
	local cDesDocto := ''
	local cNumDocto := ''
	local cDigDocto := ''
	local oMail     := nil
	local oHelper   := tcAlerts():New()
	local nRow      := 0
	local isZip     := iIf(!isAuto, aStack[2], superGetMV('MV_UZIPBOL', .f., "",))	//Se .t. = Compacta ; .f. = Não compacta
	local isPasswd  := iIf(!isAuto, aStack[3], superGetMV('MV_UZIPPWD', .f., "",))	//Se .t. = Aplica senha ; .f. = Não aplica senha
	local nZip      := 0
	local cInstru1
	local cInstru2
	local cInstru3
	local cBody     := ''
	local cFileName := ''

	oHelper:Empty()

	dbSelectArea('SA1')
	SA1->(dbSetOrder(1))

	if !SA1->(dbSeek(xFilial('SA1') + cCliente + cLoja))
		oHelper:Add('toSend' ;
			, 'Cliente não encontrado!' ;
			, 'E' ;
			, 'Não foi possível encontrar o cliente com código <' + allTrim(cCliente) ;
			+ '> e loja <' + allTrim(cLoja) + '>.')
	endIf

	if !oHelper:HasErrors()
		if SA1->A1_UENVBOL == '2'
			oHelper:Add('toSend' ;
				, 'Cliente não recebe boleto por e-mail!' ;
				, 'E' ;
				, 'O cliente com código <' + allTrim(cCliente) + '> e loja <' ;
				+ allTrim(cLoja) + '> não está parametrizado para receber boleto por e-mail.')
		elseIf empty(SA1->A1_UEMAIL)
			oHelper:Add('toSend' ;
				, 'Cliente sem e-mail definido!' ;
				, 'E' ;
				, 'O cliente com código <' + allTrim(cCliente) + '> e loja <' ;
				+ allTrim(cLoja) + '> não possui um e-mail definido.')
		endIf
	endIf

	if !oHelper:HasErrors() ;
			.and. isZip

		//Zipar arquivos
		cZipFile := cLocal + SA1->A1_CGC + '.7z'

		if file(cZipFile)
			if fErase(cZipFile) == -1
				oHelper:Add('toSend' ;
					, 'Arquivo ZIP já existe e não foi eliminado!' ;
					, 'E' ;
					, 'O cliente com código <' + allTrim(cCliente) + '> e loja <' ;
					+ allTrim(cLoja) + '> já possui um arquivo ZIP criado ' ;
					+ 'com o nome <' + cZipFile + '> e o mesmo não pode ser eliminado.' ;
					+ ' Veirifique!')
			endIf
		endIf

		if !isPasswd
			nZip := fZip(cZipFile, aAttach)
		else
			nZip := fZip(cZipFile, aAttach,, subStr(allTrim(SA1->A1_CGC), 1, 5))
		endIf

		if nZip <> 0
			oHelper:Add('toSend' ;
				, 'Arquivo ZIP não pode ser criado!' ;
				, 'E' ;
				, 'Não pode ser criado o arquivo ZIP <' + cZipFile + '> para o cliente ' ;
				+ 'com código <' + allTrim(cCliente) + '> e loja <' ;
				+ allTrim(cLoja) + '>. Veirifique!')
		else
			aAttach := {}
			aAdd(aAttach, cZipFile)
		endIf
	endIf

	if !oHelper:HasErrors()
		if SA1->A1_PESSOA == 'J'
			cNomDocto := 'CNPJ'
			cDesDocto := cNomDocto + ': XX.XXX.XXX/XXX'
			cNumDocto := transform(allTrim(SA1->A1_CGC), '@R 99.999.999/9999-99')
		elseif SA1->A1_PESSOA == 'F'
			cNomDocto := 'CPF'
			cDesDocto := cNomDocto + ': XXX.XXX.XX'
			cNumDocto := transform(allTrim(SA1->A1_CGC), '@R 999.999.999-99')
		else
			cNomDocto := 'documento'
			cDesDocto := upper(cNomDocto) + ': XXXXX'
			cNumDocto := allTrim(SA1->A1_CGC)
		endIf

		cDigDocto := subStr(cNumDocto, (len(cNumDocto) - 3), 4)

		if !isZip
			// cInstru1 := ''
			// cInstru2 := 'Boletos anexados ao e-mail em formato PDF'
			// cInstru3 := ''

			cInstru1 := cMsg1
			cInstru2 := cMsg2
			cInstru3 := cMsg3
		else
			cInstru1 := '1 - Realizar a instalação do programa WinRar em seu computador'
			cInstru2 := '2 - Baixe o arquivo ZIP em seu computador'
			cInstru3 := '3 - Descompacte seus boletos' + iIf(!isPasswd, "", " (Senha: 5 primeiros dígitos do seu " + cNomDocto + ")")
		endIf

		//Corpo do e-mail em HTML (substitui a classe tcPMail, que não existe no projeto)
		cBody := '<html><body style="font-family: Arial, Helvetica, sans-serif; font-size: 12px;">'
		cBody += '<h3>WORKFLOW - GERAÇÃO DE BOLETOS BANCÁRIOS</h3>'
		cBody += '<p><b>CLIENTE:</b> ' + allTrim(SA1->A1_NOME) + ' (' + allTrim(SA1->A1_COD) + ', ' + allTrim(SA1->A1_LOJA) + ')<br>'
		cBody += cDesDocto + cDigDocto + '<br>'
		cBody += 'EMITIDO EM ' + dToC(date()) + ' AS ' + time() + '</p>'
		cBody += '<p>' + allTrim(cInstru1) + '<br>' + allTrim(cInstru2) + '<br>' + allTrim(cInstru3) + '</p>'
		cBody += '<p><b>Documentos Gerados</b></p>'
		cBody += '<ul>'

		for nRow := 1 to len(aAttach)
			cFileName := allTrim(aAttach[nRow])
			cFileName := subStr(cFileName, rat('\', cFileName) + 1)

			cBody += '<li>' + cFileName + '</li>'
		next nRow

		cBody += '</ul>'
		cBody += '</body></html>'

		oMail := tcEMail():New()

		oMail:SetTo(allTrim(SA1->A1_UEMAIL))
		oMail:SetSubject('Boletos Bancários')
		oMail:SetBody(cBody)

		for nRow := 1 to len(aAttach)
			oMail:Attach(aAttach[nRow])
		next nRow

		if !oMail:Send()
			oHelper:Add('toSend' ;
				, 'E-mail não enviado!' ;
				, 'E' ;
				, 'Não foi possível enviar o e-mail para o cliente com código <' + allTrim(cCliente) ;
				+ '> e loja <' + allTrim(cLoja) + '> (' + allTrim(SA1->A1_UEMAIL) + '). ' ;
				+ 'Motivo: ' + oMail:GetLastError() + '. ' ;
				+ 'Verifique os parâmetros MV_RELSERV, MV_RELACNT, MV_RELPSW, MV_RELFROM e MV_RELAUTH.')
		else
			oHelper:Add('toSend' ;
				, 'E-mail enviado com sucesso!' ;
				, 'I' ;
				, 'E-mail enviado para o cliente com código <' + allTrim(cCliente) ;
				+ '> e loja <' + allTrim(cLoja) + '> (' + allTrim(SA1->A1_UEMAIL) + ') ' ;
				+ 'com ' + cValToChar(len(aAttach)) + ' anexo(s).')
		endIf

		oMail:Destroy()
	endIf

	restArea(areaSA1)

	oAlerts:AddFrom(oHelper)
return


//-------------------------------------------------------------------
/*/{Protheus.doc} getSA6Name
Apresentar os dados do banco 
@author odair.batista
@since 01/02/2018
@version 1.0
@param cNumBco, caracter, Número do banco
/*/
//-------------------------------------------------------------------
static function getSA6Name(cNumBco)
	local cNomBco := ''
	local areaSA6 := SA6->(getArea())

	dbSelectArea('SA6')
	SA6->(dbSetOrder(1))

	if SA6->(dbSeek(xFilial('SA6') + cNumBco))
		cNomBco := SA6->A6_NOME
	else
		cNomBco := ''
	endIf

	restArea(areaSA6)
return(cNomBco)


//-------------------------------------------------------------------
/*/{Protheus.doc} onUpdBanco
Gatilho para tela de alteração do banco padrão (ZAY) 
@author odair.batista
@since 01/02/2018
@version 1.0
@type function
/*/
//-------------------------------------------------------------------
static function onUpdBanco()
	private oDlg2     := nil
	private oGroup    := nil
	private oCbxBco   := nil, cCbxBco := space(len(SA6->A6_COD) + 3 + len(SA6->A6_NOME)), aCbxBco := {}
	private oBtOk     := nil
	private oBtCancel := nil

	//Inicio de rotina para inicializar os dados do comboBox
	aCbxBco := {}

	dbSelectArea('SA6')
	SA6->(dbSetOrder(1))
	SA6->(dbGoTop())

	do while !SA6->(eof())
		cCbxBco := SA6->A6_COD + ' - ' + getSA6Name(SA6->A6_COD)

		if aScan(aCbxBco, cCbxBco) == 0
			aAdd(aCbxBco, cCbxBco)
		endIf

		SA6->(dbSkip())
	endDo
	//Término de rotina para inicializar os dados do comboBox

	//Obtem o banco setado para o momento
	dbSelectArea('ZAY')
	ZAY->(dbSetOrder(1))	//ZAY_FILIAL+ZAY_USUAR

	if ZAY->(dbSeek(xFilial("ZAY") + cUserName))
		cCbxBco := ZAY->ZAY_BANCO
		cCbxBco += ' - ' + getSA6Name(cCbxBco)
	endIf

	//Criando dialog
	oDlg2 := msDialog():New(0, 0, 120, 390, "Banco Padrão de Boleto Bancário",,, .f.,,,,,, .t.,,, .t.)

	//Criando grupo
	oGroup := tGroup():New(000, 005, 055, 150, 'Informação Obrigatória', oDlg2,,, .t.)

	//Criando campos
	oCbxBco := tComboBox():New(010, 010, {| u | if(pCount() == 0, cCbxBco, cCbxBco := u)}, aCbxBco, 135, 013, oGroup,, {|| onCbxBco()},,,, .t.,,,,,,,,, 'Bancos')

	//Criando botões
	oBtOk     := tButton():New(005, 155, "OK"     , oDlg2, {|| onOkUpdBco()}, 40, 10,,, .f., .t., .f.,, .f.,,, .f.)
	oBtCancel := tButton():New(020, 155, "Cancela", oDlg2, {|| oDlg2:End()} , 40, 10,,, .f., .t., .f.,, .f.,,, .f.)

	set key VK_ESCAPE to oDlg2:End()

	//Ativação do dialog
	oDlg2:Activate(,,, .t.)
return


//-------------------------------------------------------------------
/*/{Protheus.doc} onCbxBco
Trigger do combo-box dos campos de seleção de bancos
@author odair.batista
@since 01/02/2018
@version 1.0
/*/
//-------------------------------------------------------------------
static function onCbxBco()
return


//-------------------------------------------------------------------
/*/{Protheus.doc} onOkUpdBco
confirmar digitação do banco para gravação no parâmetro 
@author odair.batista
@since 01/02/2017
@version 1.0
/*/
static function onOkUpdBco()
	local cNumBco := subStr(cCbxBco, 1, len(SA6->A6_COD))

	oAlerts:Empty()

	if empty(cNumBco)
		oAlerts:Add('1' ;
			, 'Banco não informado!' ;
			, 'E' ;
			, 'Não foi informado um Banco para alteração.')
	else
		dbSelectArea('SA6')
		SA6->(dbSetOrder(1))

		if !SA6->(dbSeek(xFilial('SA6') + cNumBco))
			oAlerts:Add('1' ;
				, 'Banco não encontrado!' ;
				, 'E' ;
				, 'Não foi encontrado o Banco com código <' + alltrim(cNumBco) + '>.')
		endIf
	endIf

	oAlerts:Show()

	if oAlerts:HasErrors()
		return(.f.)
	endIf

	//Gravação do novo banco padrão
	dbSelectArea('ZAY')
	ZAY->(dbSetOrder(1))	//ZAY_FILIAL+ZAY_USUAR

	if ZAY->(dbSeek(xFilial("ZAY") + cUserName))
		ZAY->(recLock('ZAY', .f.))
		ZAY->ZAY_BANCO := cNumBco
		ZAY->(msUnlock())
	else
		ZAY->(recLock('ZAY', .t.))
		ZAY->ZAY_FILIAL := xFilial("ZAY")
		ZAY->ZAY_USUAR  := cUserName
		ZAY->ZAY_BANCO  := cNumBco
		ZAY->(msUnlock())
	endIf

	oDlg2:End()
return(.t.)


//-------------------------------------------------------------------
/*/{Protheus.doc} onLegend
Tela de apresentação das legendas 
@author odair.batista
@since 25/01/2018
@version 1.0
@type function
/*/
//-------------------------------------------------------------------
static function onLegend()
	local aLegenda := {}

	//Monta as cores
	aAdd(aLegenda,{"BR_VERDE"   , "Pendente"})
	aAdd(aLegenda,{"BR_VERMELHO", "Impresso"})

	brwLegenda(cTitle, "Situação", aLegenda)
return


//-------------------------------------------------------------------
/*/{Protheus.doc} TFin001a
Localiza o portador (SEE) baseando-se nas regras de emissão de boleto bancário 
@author odair.batista
@since 26/01/2018
@version 1.0
@type function
/*/
//-------------------------------------------------------------------
user function TFin001a(cCliente, cLoja)
	local rowid_SEE := 0
	local areaSA1   := SA1->(getArea())
	local areaSEE   := SEE->(getArea())
	local cNumBco   := space(len(SA6->A6_COD))
/*
	dbSelectArea('ZAY')
	ZAY->(dbSetOrder(1))	//ZAY_FILIAL+ZAY_USUAR
	
	if ZAY->(dbSeek(xFilial("ZAY") + cUserName))
*/
	cNumBco := SE1->E1_PORTADO	//Obtem o banco setado para o momento
/*
	endIf

	dbSelectArea('SA1')
	SA1->(dbSetOrder(1))

	//Se o cliente tiver um banco pré-definido mantém o do cliente	
	if SA1->(dbSeek(xFilial('SA1') + cCliente + cLoja)) ;
		.and. !empty(SA1->A1_BCO1)   
		
		cNumBco := SA1->A1_BCO1
	endIf
	*/	
	//Se for reimpressão mantem o que estiver no título

	if !SE1->(eof()) .and. !empty(SE1->E1_NUMBCO)

		cNumBco := padR(allTrim(SE1->E1_PORTADO), len(SA6->A6_COD), ' ')	//Obtem o banco setado para o titulo
	endIf

	if SEE->(dbSeek(xFilial('SEE') + cNumBco))
	/*
		do while !SEE->(eof())
			if SEE->EE_UIMPBOL == '1'
			*/
		rowid_SEE := SEE->(recno())
				/*
				exit
			endIf
		
			SEE->(dbSkip())
		endDo
		*/
	endIf

	restArea(areaSA1)
	restArea(areaSEE)
return(rowid_SEE)


//-------------------------------------------------------------------
/*/{Protheus.doc} filter
Entrada de dados para filtro do browser
@author odair.batista
@since 25/01/2018
@version 1.0
@type function
/*/
//-------------------------------------------------------------------
static function filter()
	local aParamBox  := {}
	local aRet       := {}
	local bOk        := {|| .t.}
	local aButtons   := {}
	local lCentered  := .t.
	local nPosX      := nil
	local nPosY      := nil
	local oDlgWizard := nil
	local cLoad      := allTrim(cProgram) + ".pbx"
	local lCanSave   := .t.
	local lUserSave  := .t.
	local okPress    := .f.

	aAdd(aParamBox, {1, "Borderô De"		 , space(6)      , "@!", "", ""   , "", 50, .f.})
	aAdd(aParamBox, {1, "Borderô Até"		 , space(6)      , "@!", "", ""   , "", 50, .f.})
	aAdd(aParamBox, {1, "Data Emissão De"    , cToD(space(8)), ""  , "", ""   , "", 50, .f.})
	aAdd(aParamBox, {1, "Data Emissão Até"   , cToD(space(8)), ""  , "", ""   , "", 50, .f.})
	aAdd(aParamBox, {1, "Data Vencimento De" , cToD(space(8)), ""  , "", ""   , "", 50, .f.})
	aAdd(aParamBox, {1, "Data Vencimento Até", cToD(space(8)), ""  , "", ""   , "", 50, .f.})
	aAdd(aParamBox, {1, "Prefixo De"		 , space(3)		 , "@!", "", ""   , "", 30, .f.})
	aAdd(aParamBox, {1, "Prefixo Até"		 , space(3)		 , "@!", "", ""   , "", 30, .f.})
	aAdd(aParamBox, {1, "Tipo De"			 , space(3)      , "@!", "", "05" , "", 30, .f.})
	aAdd(aParamBox, {1, "Tipo Até"			 , space(3)      , "@!", "", "05" , "", 30, .f.})
	aAdd(aParamBox, {1, "Número De"			 , space(9)      , "@!", "", ""   , "", 50, .f.})
	aAdd(aParamBox, {1, "Número Até"		 , space(9)      , "@!", "", ""   , "", 50, .f.})
	aAdd(aParamBox, {1, "Parcela De"		 , space(3)      , "@!", "", ""   , "", 30, .f.})
	aAdd(aParamBox, {1, "Parcela Até"	 	 , space(3)      , "@!", "", ""   , "", 30, .f.})
	aAdd(aParamBox, {1, "Cliente De"		 , space(9)      , "@!", "", "SA1", "", 50, .f.})
	aAdd(aParamBox, {1, "Loja De"			 , space(4)      , "@!", "", ""   , "", 30, .f.})
	aAdd(aParamBox, {1, "Cliente Até"		 , space(9)      , "@!", "", "SA1", "", 50, .f.})
	aAdd(aParamBox, {1, "Loja Até"			 , space(4)      , "@!", "", ""   , "", 30, .f.})

	aAdd(aParamBox, {3, "Situação", 1, {"Impressão", "Reimpressão"}, 060, "", .f.})

	okPress := paramBox(aParamBox ;						//Array: 	Array contendo as perguntas
	, 'Filtro da ' + cTitle ;		//Caracter:	Título da tela
	, aRet ;						//Array:	Array contendo as respostas
	, bOk ;							//Array:	Code block para validar o botão Ok
	, aButtons; 					//Array:	Array contendo definições dos botões opcionais, além dos botões de Ok e Cancel
	, lCentered ; 					//Lógico:	Indica se será centralizada a janela
	, nPosX ;						//Numérico:	Se não centralizar janela, coordenada X da janela
	, nPosY ;						//Numérico:	Se não centralizar janela, coordenada Y da janela
	, oDlgWizard ;					//Objeto: 	Objeto referente à janela ativa
	, cLoad ;						//Caracter:	Nome arquivo para gravar respostas
	, lCanSave ; 					//Lógico:	Indica se pode salvar o arquivo com respostas
	, lUserSave)					//Lógico:	Indica se salva nome do usuario no arquivo

	if !okPress
		return .f.
	endIf
return(.t.)


//-------------------------------------------------------------------
/*/{Protheus.doc} output
Indica o dispositivo de saída
@author odair.batista
@since 19/11/2018
@version 1.0
@type function
/*/
//-------------------------------------------------------------------
static function output()
	local aParamBox  := {}
	local aRet       := {}
	local bOk        := {|| .t.}
	local aButtons   := {}
	local lCentered  := .t.
	local nPosX      := nil
	local nPosY      := nil
	local oDlgWizard := nil
	local cLoad      := allTrim(cProgram) + ".output.pbx"
	local lCanSave   := .t.
	local lUserSave  := .t.
	local okPress    := .f.

	aAdd(aParamBox, {3, "Saída", 1, {"Impressora", "Arquivo", "Terminal"}, 080, "", .f.})

	okPress := paramBox(aParamBox ;						//Array: 	Array contendo as perguntas
	, 'Dispositivo de Saída' ;		//Caracter:	Título da tela
	, aRet ;						//Array:	Array contendo as respostas
	, bOk ;							//Array:	Code block para validar o botão Ok
	, aButtons; 					//Array:	Array contendo definições dos botões opcionais, além dos botões de Ok e Cancel
	, lCentered ; 					//Lógico:	Indica se será centralizada a janela
	, nPosX ;						//Numérico:	Se não centralizar janela, coordenada X da janela
	, nPosY ;						//Numérico:	Se não centralizar janela, coordenada Y da janela
	, oDlgWizard ;					//Objeto: 	Objeto referente à janela ativa
	, cLoad ;						//Caracter:	Nome arquivo para gravar respostas
	, lCanSave ; 					//Lógico:	Indica se pode salvar o arquivo com respostas
	, lUserSave)					//Lógico:	Indica se salva nome do usuario no arquivo

	if !okPress
		return .f.
	endIf

	aStack[1] := aRet[1]
return(.t.)


//-------------------------------------------------------------------
/*/{Protheus.doc} inputMail
Indica opções para envio de e-mail
@author odair.batista
@since 19/11/2018
@version 1.0
@type function
/*/
//-------------------------------------------------------------------
static function inputMail()
	local aParamBox  := {}
	local aRet       := {}
	local bOk        := {|| .t.}
	local aButtons   := {}
	local lCentered  := .t.
	local nPosX      := nil
	local nPosY      := nil
	local oDlgWizard := nil
	local cLoad      := allTrim(cProgram) + ".inputMail.pbx"
	local lCanSave   := .t.
	local lUserSave  := .t.
	local okPress    := .f.

	aAdd(aParamBox, {5, "Compactar Boletos?"          , .f., 120, "", .f.})
	aAdd(aParamBox, {5, "Senha em Arquivo Compactado?", .f., 120, "", .f.})

	okPress := paramBox(aParamBox ;						//Array: 	Array contendo as perguntas
	, 'Envio de E-mail' ;		    //Caracter:	Título da tela
	, aRet ;						//Array:	Array contendo as respostas
	, bOk ;							//Array:	Code block para validar o botão Ok
	, aButtons; 					//Array:	Array contendo definições dos botões opcionais, além dos botões de Ok e Cancel
	, lCentered ; 					//Lógico:	Indica se será centralizada a janela
	, nPosX ;						//Numérico:	Se não centralizar janela, coordenada X da janela
	, nPosY ;						//Numérico:	Se não centralizar janela, coordenada Y da janela
	, oDlgWizard ;					//Objeto: 	Objeto referente à janela ativa
	, cLoad ;						//Caracter:	Nome arquivo para gravar respostas
	, lCanSave ; 					//Lógico:	Indica se pode salvar o arquivo com respostas
	, lUserSave)					//Lógico:	Indica se salva nome do usuario no arquivo

	if !okPress
		return .f.
	endIf

	aStack[2] := aRet[1]
	aStack[3] := aRet[2]
return(.t.)



//-------------------------------------------------------------------
/*/{Protheus.doc} onPrintDupl()
Imprimir Duplicata Mercanet
@author william.campana
@since 08/10/2019
@version 1.0
@type function
/*/
//-------------------------------------------------------------------
static function onPrintDupl()
	local nRow := 0

	for nRow := 1 to len(aData)
		if (aData[nRow, 2])
			SE1->(dbGoTo(aData[nRow, 1]))
			U_HFIN0009(SE1->E1_NUM, SE1->E1_PARCELA, SE1->E1_FILORIG)
		endIf
	next nRow
return
