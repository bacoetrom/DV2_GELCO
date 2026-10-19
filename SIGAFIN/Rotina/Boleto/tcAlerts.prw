/*****************************************************************************************************
Autor....: Odair Batista
Data.....: 13 de novembro de 2015
Descrição: Classe para tratamento de mensagens de alerta nos programas
******************************************************************************************************/

#include "totvs.ch"
#include "colors.ch"

#define CRLF chr(13) + chr(10)
                                                      
user function tcAlerts()
return .t. 


/*/{Protheus.doc} tcAlerts
Classe principal da API tcAlerts
@author Odair Batista - odair.batista@gmail.com
@since 05/07/2016
@version 1.0
@type class
/*/
class tcAlerts from LongClassName
	data cClassName as string hidden
	
    data aRowAlerts  as array   hidden
    data isAllOption as boolean hidden
	
	method New() constructor
	method ClassName()
	method Destroy()
	  
	method Empty()
	method Add(cCode, cTitle, cType, cMessage)
	method AddFrom(oHelper)
	method AddFromArray(aAlerts)
	method Show()

	method SetAllOption(isAllOption)
	  
	method GetAlerts()
	method GetErrors()
	method HasAlerts()
	method HasErrors()
	method GetErrorExecAuto(allLog)
	method isAllOption()
	
	method Ask(cTitle, cText, lCancel)
	method Message(cTitle, cText)
	method Select(aOptions)
endClass               

                   
/*/{Protheus.doc} tcAlerts:New
Método construtor da classe tcAlerts
@author Odair Batista - odair.batista@gmail.com
@since 05/07/2016
@version 1.0                        
@type constructor
@example
local oTcAlerts := tcAlerts():New()
@type method
/*/
method New() class tcAlerts
	::cClassName  := "tcAlerts"	
	::aRowAlerts  := {}		//Mensagens de alerta
    ::isAllOption := .f.	//Habilita resposta igual para todos os casos
return

           
 /*/{Protheus.doc} tcAlerts:ClassName
Método responsável por retornar o nome da classe
@author Odair Batista - odair.batista@gmail.com
@since 05/07/2016
@version 1.0
@type method     
@return caractere, retorna o nome da classe
/*/
method ClassName() class tcAlerts
return ::cClassName


 /*/{Protheus.doc} tcAlerts:Destroy
Método destrutor do objeto, responsável pela desalocação da memória
@author Odair Batista - odair.batista@gmail.com
@since 05/07/2016
@version 1.0
@type method     
/*/  
method Destroy(oObj as object) class tcAlerts    
	freeObj(oObj)	       
return


/*/{Protheus.doc} tcAlerts:Empty
Método para limpar as mensagens 
@author Odair Batista - odair.batista@gmail.com
@since 05/07/2016
@version 1.0                        
@type method
@example
oTcAlerts:Empty()
/*/
method Empty() class tcAlerts
	::aRowAlerts := {}                                              
return                                   


/*/{Protheus.doc} tcAlerts:Show
Método para Apresentar as mensagens 
@author Odair Batista - odair.batista@gmail.com
@since 05/07/2016
@version 1.0                        
@type method
@example
oTcAlerts:Show()
/*/
method Show() class tcAlerts
	if empty(::aRowAlerts)
		return
	endIf
	
	private oDlg	   := nil
	private oGrpBrw	   := nil
	private oGrpAlert  := nil
	private oHelp	   := nil, nHelp := 1, aHelp := {}	
	private oBtExit    := nil
	private oBtLog     := nil
	private oShow      := nil
	private aRowFields := {} 			//Campos da tabela temporária
	private aRowCols   := {}			//Campos que montarão as colunas no browser
	private ttRowAlias := "alert_" + retCodUsr()

	//Cria estrutura para msSelect (browser)
	ttDefine()
	ttCreate()

	//Criando dialog
	oDlg := msDialog():New(000, 000, 400, 600, "Mensagens de Processamento",,, .f.,,,,,, .t.,,, .t.)

    oGrpBrw   := tGroup():New(000, 005, 110, 298, 'Mensagens', oDlg,,, .t.)
    oGrpAlert := tGroup():New(110, 005, 180, 298, 'Descrição', oDlg,,, .t.)
 	
	//Criando botões
	oBtExit := tButton():New(185, 005, "Fechar"   , oGrpBrw, {||oDlg:End()}, 40, 10,,, .f., .t., .f.,, .f.,,, .f.)   
	oBtLog  := tButton():New(185, 050, "Gerar Log", oGrpBrw, {||showLog()} , 40, 10,,, .f., .t., .f.,, .f.,,, .f.)   
	
	dbSelectArea(ttRowAlias)

	//Criação do browser
	oShow := msSelect():New(ttRowAlias,,, aRowCols, .f.,, {010, 010, 105, 292},,, oGrpBrw,,)
	oHelp := TListBox():New(120, 010, {|u| if(pCount() == 0, nHelp, nHelp := u)}, aHelp, 283, 055, /*bChange*/, oGrpAlert, /*bValid*/,,, .t.,, /*bLDBLClick*/,,,, /*bWhen*/,,,,, /*bRClicked*/)
	
    oShow:oBrowse:bChange := {|| brwChange()}	
	loadAlerts(::aRowAlerts)    
	
	oDlg:Activate(,,,.t.)
return                                   


/*/{Protheus.doc} tcAlerts:Add
Método para adicionar mensagens 
@author Odair Batista - odair.batista@gmail.com
@since 05/07/2016
@version 1.0                        
@type method
@param cCode, caractere, Código da mensagem
@param cTitle, caractere, Título da mensagem
@param cType, caractere, Tipo da mensagem (E=Error, A=Alert)
@param cMessage, caractere, Mensagem de alerta
@example
oTcAlerts:Add('1', 'Atenção!!!', 'E', 'Erro no processamento.')
/*/
method Add(cCode, cTitle, cType, cMessage) class tcAlerts
	if empty(cCode)
		cCode := ''
	endIf
	
	if !(cType $ 'EWIA')
		cType := 'E'
	endIf
	
	aAdd(::aRowAlerts, {cCode, cTitle, cType, cMessage})
return                                   


/*/{Protheus.doc} tcAlerts:AddFrom
Método para adicionar mensagens a partir de outro objeto tcAlerts 
@author Odair Batista - odair.batista@gmail.com
@since 11/07/2016
@version 1.0                        
@type method
@param oHelper, objeto, Objeto container de mensagens
@example
oTcAlerts:AddFrom(oHelper)
/*/
method AddFrom(oHelper) class tcAlerts
	local nRow    := 0
	local aHelper := {}
	
	if valType(oHelper) <> 'O' ;
		.or. empty(oHelper:GetAlerts())
		
		return
	endIf 
	
	aHelper := oHelper:GetAlerts()

	for nRow := 1 to len(aHelper)
		::Add(aHelper[nRow, 1], aHelper[nRow, 2], aHelper[nRow, 3], aHelper[nRow, 4])
	next nRow
return                                   


/*/{Protheus.doc} tcAlerts:AddFromArray
Método para adicionar mensagens a partir de um array no padrão do objeto tcAlerts 
@author Odair Batista - odair.batista@gmail.com
@since 11/07/2016
@version 1.0                        
@type method
@param aAlerts, Array, Array container de mensagens
@example
oTcAlerts:AddFromArray(aAlerts)
/*/
method AddFromArray(aAlerts) class tcAlerts
	local nRow := 0
	
	if valType(aAlerts) <> 'A' ;
		.or. empty(aAlerts)
		
		return
	endIf 
	
	for nRow := 1 to len(aAlerts)
		::Add(aAlerts[nRow, 1], aAlerts[nRow, 2], aAlerts[nRow, 3], aAlerts[nRow, 4])
	next nRow
return                                   


/*/{Protheus.doc} tcAlerts:SetAllOption
Método para setar se habilita a opção de gravar resposta como padrão para outras perguntas 
@author Odair Batista - odair.batista@gmail.com
@since 05/07/2016
@version 1.0                        
@type method
@param isAllOption, lógico, Indica se habilita
/*/
method SetAllOption(isAllOption) class tcAlerts
	::IsAllOption := isAllOption
return                                    


/*/{Protheus.doc} tcAlerts:GetAlerts
Método para retornar um array contendo as mensagens 
@author Odair Batista - odair.batista@gmail.com
@since 05/07/2016
@version 1.0                        
@type method
@return aRowAlerts, array, Mensagens postadas
@example
aRowAlerts := oTcAlerts:GetAlerts()
/*/
method GetAlerts() class tcAlerts
return ::aRowAlerts                                   


/*/{Protheus.doc} tcAlerts:GetErrors
Método para retornar um array contendo somente os erros 
@author Odair Batista - odair.batista@gmail.com
@since 05/07/2016
@version 1.0                        
@type method
@return aRowErrors, array, Erros postadas
@example
aRowErrors := oTcAlerts:GetErrors()
/*/
method GetErrors() class tcAlerts
	local aRowErrors := {}
	local nRow       := 0
	
	for nRow := 1 to len(::aRowAlerts)
		if ::aRowAlerts[nRow, 3] == 'E'
			aAdd(aRowErrors ;
			     , {::aRowAlerts[nRow, 1] ;
			     	, ::aRowAlerts[nRow, 2] ;
			     	, ::aRowAlerts[nRow, 3] ;
			     	, ::aRowAlerts[nRow, 4]}) 
		endIf
	next nRow
return(aRowErrors)                                   


/*/{Protheus.doc} tcAlerts:HasAlerts
Método para retornar se existem mensagens postadas, retorna "true" se encontrar qualquer tipo de mensagem   
@author Odair Batista - odair.batista@gmail.com
@since 04/08/2016
@version 1.0                        
@type method
@return true/false, lógico, Existe mensagem no processo?
@example
oTcAlerts:HasAlerts()
/*/
method HasAlerts() class tcAlerts
return(len(::aRowAlerts) > 0)                                   


/*/{Protheus.doc} tcAlerts:HasErrors
Método para retornar se existem erros postados, retorna "true" se encontrar uma mensagem do tipo "Error"   
@author Odair Batista - odair.batista@gmail.com
@since 05/07/2016
@version 1.0                        
@type method
@return true/false, lógico, Existe erro no processo?
@example
oTcAlerts:HasError()
/*/
method HasErrors() class tcAlerts
	local nRow := 0
	
	for nRow := 1 to len(::aRowAlerts)
		if ::aRowAlerts[nRow, 3] == 'E'
			return(.t.)
		endIf
	next nRow
return(.f.)                                   


/*/{Protheus.doc} tcAlerts:GetErrorExecAuto
Método para retornar os erros gerados pelo comando ExecAuto   
@author Odair Batista - odair.batista@gmail.com
@since 05/07/2016
@version 1.0                        
@type method
@param allLog, lógico, Indica se o LOG todo será postado
@return true/false, lógico, Existe erro no processo?
@example
oTcAlerts:GetErrorExecAuto()		//Por padrão somente as linhas contendo erros
oTcAlerts:GetErrorExecAuto(.t.)		//Log completo
/*/
method GetErrorExecAuto(allLog) class tcAlerts
	local cText    := mostraErro('c:\temp\LOGs\', strZero(randomize(1, 999999), 6) + '.log') 
	local cError   := ''
	local nRow     := 0
	local nLastRow := mlCount(cText)
	local cBuffer  := ''
         
	if empty(allLog)
		allLog := .f.
	endIf         
	               
	for nRow := 1 to nLastRow
		cBuffer := rTrim(memoLine(cText,, nRow))

		if allLog ;
			.or. upper(substr(cBuffer, (len(cBuffer) - 7), len(cBuffer))) == "INVALIDO"

			cError += cBuffer + chr(13) + chr(10)
		endIf
	next nRow
return(cError)


/*/{Protheus.doc} tcAlerts:IsAllOption
Método para retornar se habilita a opção de gravar resposta como padrão para outras perguntas 
@author Odair Batista - odair.batista@gmail.com
@since 05/07/2016
@version 1.0                        
@type method
@return isAllOption, lógico, Indica se habilita
/*/
method IsAllOption() class tcAlerts
return(::IsAllOption)                                    


/*/{Protheus.doc} tcAlerts:Ask
Método gerar uma pergunta com interação de resposta 
@author Odair Batista - odair.batista@gmail.com
@since 13/07/2016
@version 1.0                        
@type method
@param cTitle, caractere, Título para a pergunta 
@param cText, caractere, Texto para a pergunta
@param lCancel, lógico, Insere botão de cancelar
@return cReturn, caracter, respota ('Yes', 'No' ou 'Cancel') 
@example
oTcAlerts:Ask('Título', 'Pergunta?', .f.)
/*/
method Ask(cTitle_, cText_, lCancel_) class tcAlerts
	local cReturn := 'No'
	
	private oDlg	    := nil
	private oFont       := tFont():New('Helvetica',, 17, .t.)
	private oTitle      := nil, cTitle  := cTitle_
	private oGrpAlert   := nil
	private oHelp	    := nil, nHelp := 1, aHelp := {}	
	private oBtYes      := nil
	private oBtNo       := nil
	private oBtCancel   := nil
	private oAllAnswers := nil, isAllAnswers := .f. 
	
	if empty(cTitle)
		cTitle := 'Responda'
	endIf

	//Criando dialog
	oDlg := msDialog():New(000, 000, 218, 444, 'Pergunta',,, .f.,,,,,, .t.,,, .t.)

    oGrpAlert := tGroup():New(027, 005, 088, 220,, oDlg,,, .t.)

	cTitle := substr(cTitle, 1, 50)
 	
	//Criando campos apenas para display
	if !empty(U_tcGetImage('ask.jpg')) 
		oTBitMap := TBitMap():New(002, 005, 040, 042, nil, U_tcGetImage('ask.jpg'), .t., oDlg,,, .f., .f.,,, .f.,, .t.,, .f.)
	endIf
		
    oTitle := tSay():New(010, 028, {| u | if(pCount() == 0, cTitle , cTitle  := u)}, oDlg, /*"@!"*/, oFont,,,, .t., CLR_BLACK, CLR_WHITE, 205, 009,,,,,,)

	oHelp := TListBox():New(032, 010, {|u| if(pCount() == 0, nHelp, nHelp := u)}, aHelp, 205, 050, /*bChange*/, oGrpAlert, /*bValid*/,,, .t.,, /*bLDBLClick*/,,,, /*bWhen*/,,,,, /*bRClicked*/)
 	
	//Criando botões
	//oBtYes := tButton():New(093, 005, "Sim", oDlg, {||cReturn := iIf(::IsAllOption .and. isAllAnswers, 'Yes-All', 'Yes'), oDlg:End()}, 40, 10,,, .f., .t., .f.,, .f.,,, .f.)   
	//oBtNo  := tButton():New(093, 050, "Não", oDlg, {||cReturn := iIf(::IsAllOption .and. isAllAnswers, 'No-All', 'No')  , oDlg:End()}, 40, 10,,, .f., .t., .f.,, .f.,,, .f.)   

	oBtYes := tButton():New(093, 005, "Sim", oDlg, {||cReturn := 'Yes', oDlg:End()}, 40, 10,,, .f., .t., .f.,, .f.,,, .f.)   
	oBtNo  := tButton():New(093, 050, "Não", oDlg, {||cReturn := 'No' , oDlg:End()}, 40, 10,,, .f., .t., .f.,, .f.,,, .f.)   

	if lCancel_
		oBtCancel := tButton():New(093, 095, "Cancelar", oDlg, {||cReturn := 'Cancel', oDlg:End()}, 40, 10,,, .f., .t., .f.,, .f.,,, .f.)   
	endIf

	//if ::IsAllOption
	If cReturn = "Yes"
	    oIsAllAnswers := tCheckBox():New(093, 145, 'Repete para Todos', {| u | if(pCount() == 0, isAllAnswers, isAllAnswers := u)}, oDlg, 080, 009,, /*{|| onChkAll()}*/,,, CLR_BLACK, CLR_WHITE,, .t.,,,)
	endIf

	showAlert(cText_, 80)
	
	oDlg:Activate(,,,.t.)
return cReturn                                   


/*/{Protheus.doc} tcAlerts:Message
Método apresentar uma mensagem simples em tela 
@author Odair Batista - odair.batista@gmail.com
@since 13/07/2016
@version 1.0                        
@type method
@param cTitle, caractere, Título para a pergunta 
@param cText, caractere, Texto para a pergunta
@example
oTcAlerts:Message('Título', 'Texto')
/*/
method Message(cTitle_, cText_) class tcAlerts
	private oDlg	  := nil
	private oFont     := tFont():New('Helvetica',, 17, .t.)
	private oTitle    := nil, cTitle  := cTitle_
	private oGrpAlert := nil
	private oHelp	  := nil, nHelp := 1, aHelp := {}	
	private oBtOk     := nil

	if empty(cTitle)
		cTitle := 'Mensagem'
	endIf

	//Criando dialog
	oDlg := msDialog():New(000, 000, 218, 444, 'Mensagem',,, .f.,,,,,, .t.,,, .t.)

    oGrpAlert := tGroup():New(027, 005, 088, 220,, oDlg,,, .t.)

	cTitle := substr(cTitle, 1, 50)
 	
	//Criando campos apenas para display
	if !empty(U_tcGetImage('msg.jpg')) 
		oTBitMap := TBitMap():New(002, 005, 040, 042, nil, U_tcGetImage('msg.jpg'), .t., oDlg,,, .f., .f.,,, .f.,, .t.,, .f.)
	endIf
		
    oTitle := tSay():New(010, 028, {| u | if(pCount() == 0, cTitle , cTitle  := u)}, oDlg, /*"@!"*/, oFont,,,, .t., CLR_BLACK, CLR_WHITE, 205, 009,,,,,,)

	oHelp := TListBox():New(032, 010, {|u| if(pCount() == 0, nHelp, nHelp := u)}, aHelp, 205, 050, /*bChange*/, oGrpAlert, /*bValid*/,,, .t.,, /*bLDBLClick*/,,,, /*bWhen*/,,,,, /*bRClicked*/)
 	
	//Criando botões
	oBtOk := tButton():New(093, 005, "OK", oDlg, {|| oDlg:End()}, 40, 10,,, .f., .t., .f.,, .f.,,, .f.)   

	showAlert(cText_, 80)
	
	oDlg:Activate(,,,.t.)
return()                                   


/*/{Protheus.doc} tcAlerts:Select
Método seleçao de opções 
@author Odair Batista - odair.batista@gmail.com
@since 13/07/2016
@version 1.0                        
@type method
@param aOptions, array, Opções para seleção 
@return nOption, inteiro, Número da opção selecionada 
@example
oTcAlerts:Select({'Opção 1', 'Opção 2', 'Opção 3'})
/*/
method Select(aOptions) class tcAlerts
	local nHgtOpt := 0 
	local nHgtGrp := 0 
	local nHgtDlg := 0
	local nReturn := 0
	 	
	private oDlg	  := nil
	private oGrpAlert := nil
	private oOptions  := nil, nOption := 1
	private oBtOk     := nil
	private oBtCancel := nil

	if empty(aOptions)
		return 0
	endIf

	nHgtOpt := (len(aOptions) * 9)
	nHgtGrp := (nHgtOpt + 15) 
	nHgtDlg := (nHgtGrp + 60 + (len(aOptions) * 9)) 

	//Criando dialog
	oDlg := msDialog():New(000, 000, nHgtDlg, 444, 'Seleção',,, .f.,,,,,, .t.,,, .t.)

    oGrpAlert := tGroup():New(005, 005, nHgtGrp, 220,, oDlg,,, .t.)
 	
	//Criando radio-set
	oOptions := TRadMenu():Create(oGrpAlert,, 010, 015, aOptions,,,,,,,, 150, nHgtOpt,,,, .t., .f.) 
	oOptions:bSetGet := {|u|iIf(pCount() == 0, nOption, nOption := u)}
	
	//Criando botões
	oBtOk     := tButton():New((nHgtGrp + 8), 005, "OK"      , oDlg, {||nReturn := nOption, oDlg:End()}, 40, 10,,, .f., .t., .f.,, .f.,,, .f.)   
	oBtCancel := tButton():New((nHgtGrp + 8), 050, "Cancelar", oDlg, {||nReturn := 0      , oDlg:End()}, 40, 10,,, .f., .t., .f.,, .f.,,, .f.)   
	
	oDlg:Activate(,,,.t.)
return nReturn                                   


//-------------------------------------------------------------------
/*/{Protheus.doc} ttDefine
Define estrutura do MsSelect (browser)
@author odair.batista
@type static function
@since 05/07/2016
@version 1.0
/*/
//-------------------------------------------------------------------
static function ttDefine()
    //Monta as colunas que serão apresentadas no browser
	aRowCols := {{"ROW_CODE",, "Código", ""} ;			//Código da mensagem		
				 , {"ROW_TITLE",, "Titulo", ""} ; 		//Título da mensagem
				 , {"ROW_TYPE",, "Tipo", ""}}    		//Descrição da mensagem

	aAdd(aRowFields, {"ROW_CODE" , "C", 20, 0})		//Código da mensagem
	aAdd(aRowFields, {"ROW_TITLE", "C", 50, 0})		//Titulo da mensagem
	aAdd(aRowFields, {"ROW_TYPE" , "C", 10, 0})		//Tipo da mensagem
	aAdd(aRowFields, {"ROW_HELP" , "C", 2000, 0})	//Descrição da mensagem
return


//-------------------------------------------------------------------
/*/{Protheus.doc} ttCreate
Criação da tabela temporária
@author odair.batista
@type static function
@since 14/07/2016
@version 1.0
/*/
//-------------------------------------------------------------------
static function ttCreate()
	local rowFile := ""
	
    //Excluindo dados da tabela temporária, se tiver aberta, fecha a tabela
	if select(ttRowAlias) <> 0
		dbSelectArea(ttRowAlias)
		(ttRowAlias)->(dbCloseArea())
	endIf
	
	//Cria tabela temporária 
	rowFile := criaTrab(aRowFields, .t.)
	dbUseArea(.t.,, rowFile, ttRowAlias, .t., .f.)
return


//-------------------------------------------------------------------
/*/{Protheus.doc} loadAlerts
Carregar dados de mensagens
@author odair.batista
@type static function
@since 05/07/2016
@version 1.0
/*/
//-------------------------------------------------------------------
static function loadAlerts(aRowAlerts)
	local nRow    := 1
	local typeMsg := ''
	
	dbSelectArea(ttRowAlias)
	
	for nRow := 1 to len(aRowAlerts)
		do case
			case aRowAlerts[nRow, 3] == 'I'
				typeMsg := 'Informação'
			case aRowAlerts[nRow, 3] == 'A'
				typeMsg := 'Alerta'
			otherwise
				typeMsg := 'Erro'
		end case 
	
		if (ttRowAlias)->(recLock(ttRowAlias, .t.))
			(ttRowAlias)->ROW_CODE  := aRowAlerts[nRow, 1]
			(ttRowAlias)->ROW_TITLE := aRowAlerts[nRow, 2]
			(ttRowAlias)->ROW_TYPE  := typeMsg
			(ttRowAlias)->ROW_HELP  := aRowAlerts[nRow, 4]
			(ttRowAlias)->(msUnlock())
		endIf
	next nRow

	(ttRowAlias)->(dbGoTop())
	if !(ttRowAlias)->(eof())
		showAlert((ttRowAlias)->ROW_HELP, 110)
	endIf
		
	oShow:oBrowse:Refresh()
return 


//-------------------------------------------------------------------
/*/{Protheus.doc} brwChange
evento ao mudar linha do browser
@author odair.batista
@type static function
@since 05/07/2016
@version 1.0
/*/
//-------------------------------------------------------------------
static function brwChange()
	if !(ttRowAlias)->(eof())
		showAlert((ttRowAlias)->ROW_HELP, 110)
	endIf
return


//-------------------------------------------------------------------
/*/{Protheus.doc} showAlert
Apresentar texto 
@author odair.batista
@type static function
@since 05/07/2016
@version 1.0
/*/
//-------------------------------------------------------------------
static function showAlert(text_, nSize_)
	//aHelp := U_tcPutText(trim(text_), nSize_)
	
	if empty(aHelp)
		return
	endIf

	oHelp:Reset()
	oHelp:SetArray(aHelp)
	oHelp:GoTop()	
return


//-------------------------------------------------------------------
/*/{Protheus.doc} showLog
Gerar texto de log 
@author odair.batista
@type static function
@since 29/07/2016
@version 1.0
/*/
//-------------------------------------------------------------------
static function showLog()
	local typeMsg  := ''
	local cFile    := allTrim(cUserName) + '_tcAlerts.log'
	local nHandle  := nil
	local xArea    := (ttRowAlias)->(getArea()) 
	local aHelp    := {}
	local nRow     := 0
	
	nHandle := fCreate('\spool\' + cFile)

	fWrite(nHandle, '*******************************************************************' + CRLF) 
	fWrite(nHandle, '** LOG de mensagens de processamento gerado pela Classe tcAlerts **' + CRLF) 
	fWrite(nHandle, '*******************************************************************' + CRLF + CRLF) 
 
	dbSelectArea(ttRowAlias)
	
	(ttRowAlias)->(dbGoTop())
	
	do while !(ttRowAlias)->(eof())
		fWrite(nHandle, '--------------------------------------------------------------------------------' + CRLF + CRLF)
		fWrite(nHandle, (ttRowAlias)->ROW_TITLE ;
						 + ' (' + allTrim((ttRowAlias)->ROW_CODE) + ')' ;
						 + ' [' + allTrim((ttRowAlias)->ROW_TYPE) + ']' + CRLF + CRLF)

		//aHelp := U_tcPutText(allTrim((ttRowAlias)->ROW_HELP), 80)

		if len(aHelp) > 0
			for nRow := 1 to len(aHelp)
				fWrite(nHandle, space(5) + aHelp[nRow] + CRLF) 
			next nRow 
		endIf
		
		fWrite(nHandle, CRLF)
	
		(ttRowAlias)->(dbSkip())
	endDo
	
	fWrite(nHandle, CRLF + '--------------------------------------------------------------------------------' + CRLF)
	
	fClose(nHandle)
	
	restArea(xArea)
 
	cpyS2T('\spool\' + cFile, 'c:\temp\', .t.) 	
 
	U_tcOpFile('c:\temp\' + cFile, "log")
return
