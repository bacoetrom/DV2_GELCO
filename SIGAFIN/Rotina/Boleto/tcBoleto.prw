/*
 Programa.: tcBoleto.prw
 Tipo.....: Classe 
 Autor....: Odair Batista
 Data.....: 18/01/2018
 Descrição: Classe para impressão de boleto bancário 
 Notas....: De acordo com as configurações dos bancos, o tamanho do campo E1_NUMBCO na tabela SE1
		    deve possuir um tamanho mínimo de 20 caracteres. Sugere-se deixá-lo com 25 caracteres
		    como contingência visando novos layouts de bancos que possam vir a usar mais de 20
		    caracteres. 

 Autor....: William Campana
 Data.....: 03/08/2020
 Descrição: Classe para impressão de boleto bancário 
 Notas....: Alterações das mensagens no corpo do boleto conforme solicitação: 12623 

 Autor....: William Campana
 Data.....: 26/08/2020
 Descrição: Classe para impressão de boleto bancário 
 Notas....: Inclusão do CNPJ do Beneficiário no Boleto.  
  
*/

#include "totvs.ch"
#include "protheus.ch"
#include "topConn.ch"
#include "rptDef.ch"
#include "fwPrintSetup.ch"

#define CRLF chr(13) + chr(10)


user function tcBoleto()
return .t.


/*/{Protheus.doc} tcBoleto
Classe principal da classe tcBoleto
@author Odair Batista - TOTVS Unidade Londrina
@since 18/01/2018
@version 1.0
@type class
/*/
	class tcBoleto from tcAlerts
		data cClassName as string  hidden

		data rowid_SEE as integer hidden		//Recno da tabela SEE
		data toOutput  as boolean hidden		//Indica a saída para o PDF após a geração ['File', 'Screen', 'Printer']
		data toAssign  as boolean hidden		//Indica se a impressão grava dados no sistema ou não na SEE e SE1 - Default .t.
		data nPointer  as integer hidden		//Ponteiro para o vetor aData - Registro corrente
		data aData     as array   hidden		//Vetor de dados para impressão
		data aDataSM0  as array   hidden		//Vetor de dados da empresa beneficiária
		data cPathFile as string  hidden		//Caminho para geração do arquivo PDF
		data cFileName as string  hidden		//Nome do arquivo PDF gerado
		data lServer   as boolean hidden		//Indica se o PDF é gerado no servidor (envio por e-mail/job) - Default .f.

    /*
    Conteúdo do Vetor de dados (aData)
    ==================================
    [ 1] Código do banco
    [ 2] Nome do banco
    [ 3] Endereço do logo do banco
    [ 4] Local de pagamento
    [ 5] Código Febraban
    [ 6] Número da agência
    [ 7] Dígito da agência
    [ 8] Conta corrente
    [ 9] Dígito da conta corrente
    [10] Nosso número
    [11] Código do Beneficiário 
    [12] Nome do Beneficiário
    [13] Espécie 
    [14] Instruções bancárias (array) - É levado em conta no máximo 7 linhas
    [15] Valor do juro diário
    [16] Valor do juro mensal
    [17] Valor do desconto
    [18] Data de vencimento
    [19] Data de emissão
    [20] Número do documento (Título)
    [21] Valor do documento (Título)
    [22] Código da carteira
    [23] Código do sacado
    [24] Nome do sacado
    [25] Endereço do sacado
    [26] Cidade do sacado
    [27] UF do sacado
    [28] CEP do sacado
    [29] Telefone do sacado
    [30] ID Federal (CNPJ ou CPF)
    [31] E-mail do sacado
    [32] Linha digitável
    [33] Código de barras
    [34] Nosso número impressão
    [35] Sacador/Avalista
    [36] Dados do SAC - Linha 1
    [37] Dados do SAC - Linha 2
    [38] Dados do SAC - Linha 3
    [39] Dados do SAC - Linha 4
	[40] Código do convênio
	[41] Tipo da carteira/Modalidade de cobrança
	[42] Recno do SE1
	[43] Descrição Sacado ou Sacador
	[44] CNPJ do Beneficiario
	*/

		method New() constructor
		method ClassName()
		method Destroy(oObj)
		method Empty()

		method SetPath(cPathFile)
		method SetArray(aData)
		method SetOutput(toOutput)
		method SetAssign(toAssign)
		method SetServer(lServer)

		method GetPath()
		method GetArray()
		method GetOutput()
		method GetAssign()
		method GetRowId()
		method GetRowArray()
		method GetFileName()

		method FindByRowId(rowId_SEE)
		method AddBy(rowId_SE1)
		method NextNossoNumero(nDigit)
		method SaveNossoNumero()
		method CalcMod10(cCode)
		method CalcMod11(cCode, nInitFactor, nLimitFactor, cChrCode)
		method CreateBarCode(cDigCode)
		method FatorVencimento(dVencto)
		method GetLogo(cCodBco)
		method CreateLine(cBarCode)
		method Generate()
		method Printer()
		method PutRecibo()
		method PutRecSacado()
		method PutRecCompensacao()
	endClass


/*/{Protheus.doc} tcBoleto:New
Método construtor da classe tcBoleto
@author Odair Batista - TOTVS Unidade Londrina
@since 18/01/2018
@version 1.0                        
@type constructor
@example
local oBoleto := tcBoleto():New()
/*/
method New() class tcBoleto
	_Super:New()

	::cClassName := "tcBoleto"
	::rowId_SEE  := ''
	::nPointer   := 0
	::toOutput	 := 'Screen'
	::toAssign   := .t.
	::aData		 := {}
	::aDataSM0   := loadSM0()
	::cFileName  := ''
	::lServer    := .f.
return


 /*/{Protheus.doc} tcBoleto:ClassName
	Método responsável por retornar o nome da classe
	@author Odair Batista - TOTVS Unidade Londrina
	@since 18/01/2018
	@version 1.0
	@type method
	@return caractere, retorna o nome da classe
/*/
method ClassName() class tcBoleto
return ::cClassName


 /*/{Protheus.doc} tcBoleto:Destroy
	Método destrutor do objeto, responsável pela desalocação da memória
	@author Odair Batista - TOTVS Unidade Londrina
	@since 18/01/2018
	@version 1.0
	@type method
/*/  
method Destroy(oObj as object) class tcBoleto
	freeObj(oObj)
return


/*/{Protheus.doc} tcBoleto:Empty
Método para limpar a classe 
@author Odair Batista - odair.batista@gmail.com
@since 18/01/2018
@version 1.0                        
@type method
@example
oBoleto:Empty()
/*/
method Empty() class tcBoleto
	_Super:Empty()

	::rowId_SEE := ''
	::nPointer  := 0
	::aData	    := {}
return


/*/{Protheus.doc} tcBoleto:SetPath
Método para informar caminho para geração do arquivo 
@author Odair Batista - TOTVS Unidade Londrina
@since 18/01/2018
@version 1.0                        
@type method
@param cPathFile, caracter, Caminho para geração do arquivo
@example
oBoleto:SetPath(cPathFile)
/*/
method SetPath(cPathFile) class tcBoleto
	::cPathFile := cPathFile
return


/*/{Protheus.doc} tcBoleto:SetArray
Método para informar os dados para impressão do boleto 
@author Odair Batista - TOTVS Unidade Londrina
@since 18/01/2018
@version 1.0                        
@type method
@param aData, array, Conteúdo dos dados a serem impressos
@example
oBoleto:SetArray(aData)
/*/
method SetArray(aData) class tcBoleto
	::aData := aData
return


/*/{Protheus.doc} tcBoleto:SetOutput
Método para informar se o PDF será visualizado após a geração 
@author Odair Batista - TOTVS Unidade Londrina
@since 18/01/2018
@version 1.0                        
@type method
@param toOutput, lógico, Indica se será o PDF será visualizado Sim (.t.) ou Não (.f.)
@example
oBoleto:SetOutput('Screen')
/*/
method SetOutput(toOutput) class tcBoleto
	if toOutput <> 'File' ;
			.and. toOutput <> 'Screen' ;
			.and. toOutput <> 'Printer'

		toOutput := 'Screen'
	endIf

	::toOutput := toOutput
return


/*/{Protheus.doc} tcBoleto:SetAssign
Método para informar se o processo irá gravar os dados gerados nas tabelas SEE e SE1  
@author Odair Batista - TOTVS Unidade Londrina
@since 25/01/2018
@version 1.0                        
@type method
@param toAssign, lógico, Indica se será gravado os dados gerados no processo
@example
oBoleto:SetAssign(toAssign)
/*/
method SetAssign(toAssign) class tcBoleto
	::toAssign := toAssign
return


/*/{Protheus.doc} tcBoleto:SetServer
Método para informar se o PDF será gerado no servidor (parâmetro lServer do FWMsPrinter)
@author Pablo Regis
@since 21/10/2026
@version 1.0
@type method
@param lServer, lógico, .t. = gera o PDF no caminho do servidor informado em SetPath()
@example
oBoleto:SetServer(.t.)
/*/
method SetServer(lServer) class tcBoleto
	::lServer := lServer
return


/*/{Protheus.doc} tcBoleto:GetPath
Método para retornar caminho para geração do arquivo 
@author Odair Batista - TOTVS Unidade Londrina
@since 18/01/2018
@version 1.0                        
@type method
@return cPathFile, caracter, Caminho para geração do arquivo
@example
oBoleto:GetPath()
/*/
method GetPath() class tcBoleto
return(::cPathFile)


/*/{Protheus.doc} tcBoleto:GetArray
Método para retornar os dados para impressão do boleto 
@author Odair Batista - TOTVS Unidade Londrina
@since 18/01/2018
@version 1.0                        
@type method
@return aData, array, Conteúdo dos dados a serem impressos
@example
oBoleto:GetArray()
/*/
method GetArray() class tcBoleto
return(::aData)


/*/{Protheus.doc} tcBoleto:GetOutput
Método para retornar se o PDF será visualizado após a geração 
@author Odair Batista - TOTVS Unidade Londrina
@since 25/01/2018
@version 1.0                        
@type method
@return toOutput, lógico, Indica se será o PDF será visualizado Sim (.t.) ou Não (.f.)
@example
oBoleto:GetOutput()
/*/
method GetOutput() class tcBoleto
return(::toOutput)


/*/{Protheus.doc} tcBoleto:GetAssign
Método para retornar se o processo irá gravar os dados gerados nas tabelas SEE e SE1  
@author Odair Batista - TOTVS Unidade Londrina
@since 25/01/2018
@version 1.0                        
@type method
@return toAssign, lógico, Indica se será gravado os dados gerados no processo
@example
oBoleto:GetAssign()
/*/
method GetAssign() class tcBoleto
return(::toAssign)


/*/{Protheus.doc} tcBoleto:GetRowId
Método para retornar o Recno da tabela SEE 
@author Odair Batista - TOTVS Unidade Londrina
@since 24/01/2018
@version 1.0                        
@type method
@return nRowId_SEE, inteiro, Recno da tabela SEE posicionada
@example
oBoleto:GetRowId()
/*/
method GetRowId() class tcBoleto
return(::rowid_SEE)


/*/{Protheus.doc} tcBoleto:GetRowArray
Método para obter o ponteiro do registro corrente no vetor de dados ::aData  
@author Odair Batista - TOTVS Unidade Londrina
@since 19/01/2018
@version 1.0                        
@type method
@return nPointer, inteiro, Número do ponteiro de registro corrente do vetor
@example
oBoleto:GetRowArray()
/*/
method GetRowArray() class tcBoleto
return(::nPointer)


/*/{Protheus.doc} tcBoleto:GetFileName
Método para obter o nome do arquivo PDF gerado  
@author Odair Batista - TOTVS Unidade Londrina
@since 01/02/2018
@version 1.0                        
@type method
@return cFileName, caracter, Nome do arquivo PDF gerado
@example
oBoleto:GetFileName()
/*/
method GetFileName() class tcBoleto
return(::cFileName)


/*/{Protheus.doc} tcBoleto:FindByRowId
Método para localizar o registro na tabela SEE pelo número do registro (Recno) 
@author Odair Batista - TOTVS Unidade Londrina
@since 18/01/2018
@version 1.0                        
@type method
@param rowId_SEE, inteiro, Número do registro da tabela SEE (Recno)
@example
oBoleto:FindByRowId(rowId_SEE)
/*/
method FindByRowId(rowId_SEE) class tcBoleto
	dbSelectArea("SEE")
	SEE->(dbGoTo(rowId_SEE))

	if SEE->(eof())
		_Super:Add('FindByRowId' ;
			, 'Parâmetro de Banco/Agência/Conta/Sub-Conta não encontrado!' ;
			, 'E' ;
			, 'O registro de parâmetro de Banco/Agência/Conta/Sub-Conta com ID <' + cValToChar(rowId_SEE) ;
			+ '> não foi encontrado. (SEE)')
	else
		//Esta validação foi customizada para evitar erros operacionais
		/*
		if SEE->EE_UIMPBOL <> '1'
			_Super:Add('FindByRowId' ;
					   , 'Banco/Agência/Conta/Sub-Conta inválido!' ;
					   , 'E' ;
					   , 'O Banco: <' + allTrim(SEE->EE_CODIGO) + '>' ;
					     + ', Agência: <' + allTrim(SEE->EE_AGENCIA) + '>' ;
					     + ', Conta: <' + allTrim(SEE->EE_CONTA) + '>' ;
					     + ' e Sub-Conta: <' + allTrim(SEE->EE_SUBCTA) + '>' ;
				  		 + ' não possui permissão para imprimir boleto bancário.')
		endIf
		*/
		dbSelectArea("SA6")
		SA6->(dbSetOrder(1))

		if !SA6->(dbSeek(xFilial("SA6") + SEE->EE_CODIGO + SEE->EE_AGENCIA + SEE->EE_CONTA)) 	//Posiciona cadastro de banco SA6
			_Super:Add('FindByRowId' ;
				, 'Banco/Agência/Conta não encontrado' ;
				, 'E' ;
				, 'O banco <' + allTrim(SEE->EE_CODIGO) + '>, com agência <' + allTrim(SEE->EE_AGENCIA) ;
				+ '> e conta corrente <' + allTrim(SEE->EE_CONTA) + '> não foi encontrado. (SA6)')
		else
			/*
			//Verifica se a agência e conta está bloqueada
			if SA6->A6_MSBLQL == '1' 	                  
				_Super:Add('FindByRowId' ;
						   , 'Banco/Agência/Conta inválidos!' ;
						   , 'E' ;
						   , 'O banco <' + allTrim(SEE->EE_CODIGO) + '>, com agência <' + allTrim(SEE->EE_AGENCIA) ;
					  		 + '> e conta corrente <' + allTrim(SEE->EE_CONTA) + '> está bloqueado. (SA6)')
			endIf
			*/
		endIf
	endIf

	if _Super:HasErrors()
		SEE->(dbGoTo(0))
	else
		::rowid_SEE := rowId_SEE
	endIf
return


/*/{Protheus.doc} tcBoleto:AddBy
Método para alimentar o array com dados básicos do título para emissão do boleto   
@author Odair Batista - TOTVS Unidade Londrina
@since 18/01/2018
@version 1.0                        
@type method
@param rowId_SE1, inteiro, número do registro no banco de dados (Recno) 
@example
oBoleto:AddBy(rowId_SE1)
/*/
method AddBy(rowId_SE1) class tcBoleto
	local cNNumero := ''
	local aInfBco  := {}
	local nRow	   := 0

	if SEE->(eof())
		_Super:Add('AddBy' ;
			, 'Banco/Agência/Conta/Sub-Conta não encontrados!' ;
			, 'E' ;
			, 'Não foi posicionado os parâmetros de Banco/Agência/Conta/Sub-Conta com número de ' ;
			+ 'registro <' + allTrim(cValToChar(::rowId_SEE)) + '>. Favor executar o método ' ;
			+ 'FindRowIdBy(rowId_SEE)')
	endIf

	dbSelectArea("SE1")
	SE1->(dbGoTo(rowId_SE1))

	if SE1->(eof())
		_Super:Add('AddBy' ;
			, 'Título não encontrado!' ;
			, 'E' ;
			, 'O título com ID <' + allTrim(cValToChar(rowId_SE1)) + '> não foi encontrado. (SE1)')
	else
		dbSelectArea("SA1")
		SA1->(dbSetOrder(1))

		if !SA1->(dbSeek(xFilial('SA1') + SE1->E1_CLIENTE + SE1->E1_LOJA))
			_Super:Add('AddBy' ;
				, 'Sacado não encontrado!' ;
				, 'E' ;
				, 'O cliente com código <' + allTrim(SE1->E1_CLIENTE) + ', ' ;
				+ allTrim(SE1->E1_LOJA) + '> não foi encontrado. (SA1)')
		endIf
	endIf

	if _Super:HasErrors()
		return
	endIf

	/* Dados de informações bancárias para o boleto - Limitado em 7 linhas */
	//Inicio da rotina
	//aAdd(aInfBco, 'ATÉ O VENCIMENTO, PREFERENCIALMENTE NO ' + SA6->A6_NOME)
	//aAdd(aInfBco, 'APÓS O VENCIMENTO, SOMENTE NO ' + SA6->A6_NOME)

	aadd(aInfBco, 'DEPOSITO BANCÁRIO NÃO EFETUA QUITAÇÃO DO BOLETO')
	aadd(aInfBco, 'APÓS ' + dToC(SE1->E1_VENCTO) + ' COBRAR DE R$ ' + AllTrim(transform(((SE1->E1_SALDO * 0.04)/30), '@E 999,999.99') + ' DE MORA DIA POR ATRASO'))
	aadd(aInfBco, 'TITULO SUJEITO A PROTESTO')



	//for nRow := 1 to 2

	//	if !empty(&("SEE->EE_FORMEN" + str(nRow, 1, 0)))
	//		aAdd(aInfBco, &(&("SEE->EE_FORMEN" + str(nRow, 1, 0))))
	//	endIf
	//next nRow

	//for nRow := 1 to 2
	//	if !empty(&("SEE->EE_FOREXT" + str(nRow, 1, 0)))
	//		aAdd(aInfBco, &(&("SEE->EE_FOREXT" + str(nRow, 1, 0))))
	//	endIf
	//next nRow

	for nRow := len(aInfBco) to 7		//Faz complemento se não houver 7 linhas
		aAdd(aInfBco, '')
	next nRow

	//Término da rotina

	aAdd(::aData ;
		, {allTrim(SEE->EE_CODIGO) ;		            			//[ 1] Código do banco
	, SA6->A6_NOME ;    			            			//[ 2] Nome do banco
	, ::GetLogo(SEE->EE_CODIGO) ;                             //[ 3] Endereço do logo do banco
		, 'PAGÁVEL EM QUALQUER BANCO' ;						//[ 4] Local de pagamento
	, SEE->EE_CODIGO ;				                    	//[ 5] Código Febraban
	, SEE->EE_AGENCIA ;				                        //[ 6] Número da agência
	, SEE->EE_DVAGE ;				                        //[ 7] Dígito da agência
	, SEE->EE_CONTA ;				                        //[ 8] Conta corrente
	, SEE->EE_DVCTA ;				                        //[ 9] Dígito da conta corrente
	, allTrim(SE1->E1_NUMBCO) ;				                //[10] Nosso número
	, allTrim(SEE->EE_AGENCIA) ;							//[11] Código do Beneficiário
	+ '/' + alltrim(SEE->EE_CONTA) ;
		+ '-' + allTrim(SEE->EE_DVCTA) ;
		, allTrim(::aDataSM0[1]);
		+ ' - ';
		+ allTrim(::aDataSM0[6]);                             //[12] Nome do Beneficiário + CNPJ
	, 'DM' ;						                        //[13] Espécie
	, aInfBco ;						                        //[14] Instruções bancárias (array)
	, 0 ;							                        //[15] Valor do juro diário
	, 0 ; 							                        //[16] Valor do juro mensal
	, SE1->E1_DECRESC;				                        //[17] Valor do desconto
	, SE1->E1_VENCTO ;				                        //[18] Data de vencimento
	, SE1->E1_EMISSAO ;				                        //[19] Data de emissão
	, allTrim(SE1->E1_NUM) ;							    //[20] Número do documento (Título)
	+ iIf(empty(SE1->E1_PARCELA) ;
		, '' ;
		, '/' + allTrim(SE1->E1_PARCELA)) ;
		, SE1->E1_SALDO	;								     	//[21] Valor do documento (Título)
	, SEE->EE_CODCART ;									    //[22] Código da carteira
	, allTrim(SA1->A1_COD) ;							    //[23] Código do sacado
	+ '-' + allTrim(SA1->A1_LOJA) ;
		, SA1->A1_NOME ;									    //[24] Nome do sacado
	, SA1->A1_END ;										    //[25] Endereço do sacado
	, SA1->A1_MUN ;										    //[26] Cidade do sacado
	, SA1->A1_EST ;										    //[27] UF do sacado
	, SA1->A1_CEP ;										    //[28] CEP do sacado
	, '' ;												    //[29] Telefone do sacado
	, iIf(SA1->A1_PESSOA == 'J' ;						    //[30] ID Federal (CNPJ ou CPF)
	, transform(SA1->A1_CGC, '@R 99.999.999/9999-99') ;
		, transform(SA1->A1_CGC, '@R 999.999.999-99')) ;
		, SA1->A1_EMAIL ;								        //[31] E-mail do sacado
	, '' ;										            //[32] Linha digitável
	, '' ;										            //[33] Código de barras
	, allTrim(SE1->E1_NUMBCO) ;					            //[34] Nosso número composto
	, '' ;										            //[35] Sacador/Avalista
	, '' ;										            //[36] Dados do SAC - Linha 1
	, '' ;										            //[37] Dados do SAC - Linha 2
	, '' ;										            //[38] Dados do SAC - Linha 3
	, '' ;										            //[39] Dados do SAC - Linha 4
	, SEE->EE_CODEMP ;									    //[40] Código do convênio
	, SEE->EE_TIPCART ;										//[41] Tipo da carteira/Modalidade de cobrança
	, SE1->(recno()) ; 										//[42] Recno do SE1
	, 'Sacador' ;                                            //[43] Descrição Sacado ou Sacador
	, ::aDataSM0[6] ;                                       //[44] CNPJ do Beneficiario
	, iif(allTrim(SE1->E1_PARCELA) == '', '001', SE1->E1_PARCELA) ; //[45] Numero da Parcela
	,  allTrim(::aDataSM0[2]) ;                    //[46] Endereço Beneficiario
	,  allTrim(::aDataSM0[3]) ;                    //[47] Bairro, Cidade e UF Beneficiario
	,  allTrim(::aDataSM0[4]) ;                    //[48] Cep Beneficiário
	,  ''})                                     //[49] Linha digitavel para enviar no CNAB E1_CODDIG

	::nPointer := len(::aData)		//Posiciona o ponteiro do registro corrente no vetor
return


/*/{Protheus.doc} tcBoleto:NextNossoNumero
Método para obter o próximo código do Nosso Numero  
@author Odair Batista - TOTVS Unidade Londrina
@since 18/01/2018
@version 1.0                        
@type method
@param nDigit, inteiro, Quantidade dígitos
@return nNNumero, caracter, Nosso número
@example
oBoleto:NextNossoNumero(9)
@obs
A tabela SEE deverá estar posicionada para utilização deste método
/*/
method NextNossoNumero(nDigit) class tcBoleto
	local cNNumero := ''

	default nDigit := 9

	if !::toAssign
		cNNumero := strZero(1, nDigit, 0)
	else
		if SEE->(eof())
			_Super:Add('NextNossoNumero' ;
				, 'Banco/Agência/Conta e Dígito não encontrados!' ;
				, 'E' ;
				, 'Não foi posicionado os parâmetros de Banco/Agência/Conta e Dígito com número de ' ;
				+ 'registro <' + allTrim(cValToChar(::rowId_SEE)) + '>. Favor executar o método ' ;
				+ 'FindRowIdBy(rowId_SEE)')
		else
			cNNumero := strZero((val(SEE->EE_FAXATU) + 1), nDigit, 0)

			if SEE->(recLock("SEE", .f.))
				SEE->EE_FAXATU := cNNumero
				SEE->(msUnlock())
			endIf
		endIf
	endIf
return(cNNumero)


/*/{Protheus.doc} tcBoleto:SaveNossoNumero
Método para gravar o Nosso Numero no título  
@author Odair Batista - TOTVS Unidade Londrina
@since 24/01/2018
@version 1.0                        
@type method
@example
oBoleto:SaveNossoNumero()
@obs
  16/02/2019 - William: gravando Linha Digitavel e Codigo Barras
/*/
method SaveNossoNumero() class tcBoleto
	if !::toAssign
		return
	endIf

	dbSelectArea('SE1')
	SE1->(dbGoTo(::aData[::nPointer, 42]))

	if SE1->(eof())
		_Super:Add('SaveNossoNumero' ;
			, 'Título não encontrado!' ;
			, 'E' ;
			, 'Não foi encontrado o título a receber com número de ' ;
			+ 'registro <' + allTrim(cValToChar(::aData[::nPointer, 42])) + '>.')
	else
		if empty(SE1->E1_NUMBCO)
			SE1->(recLock("SE1", .f.))
			SE1->E1_NUMBCO  := ::aData[::nPointer, 10]
			SE1->E1_PORTADO := ::aData[::nPointer, 5]
			SE1->E1_CODDIG  := ::aData[::nPointer, 49]
			SE1->E1_CODBAR  := ::aData[::nPointer, 33]
			SE1->(msUnlock())
		endIf
/*		
		if empty(SE1->E1_CODDIG)
			SE1->(recLock("SE1", .f.))
			SE1->E1_CODDIG  := ::aData[::nPointer, 32]
			SE1->(msUnlock())
		endIf
		
		if (empty(SE1->E1_CODBAR))
		   SE1->(recLock("SE1", .f.))
		   SE1->E1_CODBAR := ::aData[::nPointer, 33]
		   SE1->(msUnlock())
		endIf
		*/
	endIf
return()


/*/{Protheus.doc} tcBoleto:CalcMod10
Método para calcular o dídigito verificador baseado em módulo 10  
@author Odair Batista - TOTVS Unidade Londrina
@since 18/01/2018
@version 1.0                        
@type method
@param  cCode , caracter, Código para calculo do dígito
@return cDigit, caractet, Dígito verificador do calculo de módulo 10
@example
oBoleto:CalcMod10(cCode)
/*/
method CalcMod10(cCode) class tcBoleto
	local nSize    := len(cCode)
	local nDigCode := 0
	local nDigit   := 0
	local isCheck  := .t.

	do while nSize > 0
		nDigCode := val(subStr(cCode, nSize, 1))

		if (isCheck)
			nDigCode := (nDigCode * 2)

			if nDigCode > 9
				nDigCode := (nDigCode - 9)
			endIf
		endIf

		nDigit  := (nDigit + nDigCode)
		nSize   := (nSize - 1)
		isCheck := !isCheck
	end

	nDigit := (10 - (mod(nDigit, 10)))

	if nDigit = 10
		nDigit := 0
	endIf
return(cValToChar(nDigit))


/*/{Protheus.doc} tcBoleto:CalcMod11
Método para calcular o dídigito verificador baseado em módulo 11  
@author Odair Batista - TOTVS Unidade Londrina
@since 18/01/2018
@version 1.0                        
@type method
@param  cCode 	    , caracter, Código para calculo do dígito
@param  nInitFactor , inteiro , Número initial do fator de multiplicação
@param  nLimitFactor, inteiro , Número limite do fator de multiplicação
@param  cChrCode    , caracter, Carater para composição de dígito
@return cDigit		, caractet, Dígito verificador do calculo de módulo 10
@example
oBoleto:CalcMod11(cCode, 2, 9, '')
/*/
method CalcMod11(cCode, nInitFactor, nLimitFactor, cChrCode) class tcBoleto
	local nAccum   := 0
	local nResto   := 0
	local nPosicao := 0
	local nNumero  := ''
	local nFactor  := 0
	local cDigit   := ''

	default nInitFactor  := 2
	default nLimitFactor := 9

	if nInitFactor < 2
		nInitFactor := 2
	endIf

	if nLimitFactor > 9
		nLimitFactor := 9
	endIf

	nFactor := nInitFactor

	for nPosicao := len(cCode) to 1 step -1
		nNumero  := subStr(cCode, nPosicao, 1)
		nAccum   += (val(nNumero) * nFactor)
		nFactor  := iIf(nFactor < nLimitFactor, (nFactor + 1), nInitFactor)
	next nPosicao

	nResto = round(mod(nAccum, 11), 0)

	if cChrCode <> 'DAC-BarCode' ;
			.and. nResto <= 1

		nResto := 0
	endIf

	if cChrCode == 'DAC-BarCode' ;
			.and. (nResto == 0 ;
			.or. nResto = 1 ;
			.or. nResto = 10 ;
			.or. nResto = 11)

		nResto := 1
	endIf

	if nResto > 1
		nResto := (11 - nResto)
	endIf

	cDigit := cValToChar(nResto)

	if cChrCode <> '' ;
			.and. cChrCode <> 'DAC-BarCode' ;
			.and. nResto == 10

		cDigit := cChrCode
	endIf
return(cDigit)


/*/{Protheus.doc} tcBoleto:CreateBarCode
Método para geração do código de barras  
@author Odair Batista - TOTVS Unidade Londrina
@since 24/01/2018
@version 1.0                        
@type method
@param  cFree   , caracter, Campo Livre
@return cBarCode, caracter, Código de barras
@example
cBarCode := oBoleto:CreateBarCode(cDigCode)
@obs
Composição do código de barras
==============================
Posição  Tamanho  Formato    Conteúdo
-------  -------  ---------  --------
01 a 03  03       9(03)      Código do Banco na Câmara de Compensação
04 a 04  01       9(01)      Código da Moeda = 9 (Real)
05 a 05  01       9(01)      Digito Verificador (DV) do código de Barras*
06 a 09  04       9(04)      Fator de Vencimento **
10 a 19  10       9(08)V(2)  Valor
/*/
method CreateBarCode(cFree) class tcBoleto
	local cFatorVcto := ::FatorVencimento(::aData[::nPointer, 18])
	local cCodBco    := strZero(val(::aData[::nPointer, 1]), 3)
	local cValor     := strZero((::aData[::nPointer, 21] * 100), 10)
	local cBarCode   := cCodBco + '9' + cFatorVcto + cValor + cFree

	//Acrescenta dígito ao código de barras
	cBarCode := subStr(cBarCode, 1, 4) ;
		+ ::CalcMod11(cBarCode, 2, 9, 'DAC-BarCode') ;
		+ subStr(cBarCode, 5, 44)
return(cBarCode)


/*/{Protheus.doc} tcBoleto:FatorVencimento
Método para calcular o fator de vencimento do código de barras (posições 06 a 09)
@author Pablo Regis
@since 19/10/2026
@version 1.0
@type method
@param  dVencto, data    , Data de vencimento do título
@return cFator , caracter, Fator de vencimento com 4 dígitos
@example
cFator := oBoleto:FatorVencimento(SE1->E1_VENCTO)
@obs
Regra FEBRABAN: o fator é a quantidade de dias desde 07/10/1997. Ao atingir 9999 (21/02/2025)
o fator reinicia em 1000 (22/02/2025), repetindo o ciclo a cada 9000 dias.
/*/
method FatorVencimento(dVencto) class tcBoleto
	local nFator := dVencto - sToD('19971007')

	do while nFator > 9999
		nFator -= 9000
	endDo
return(strZero(nFator, 4))


/*/{Protheus.doc} tcBoleto:GetLogo
Método para retornar o caminho do logo do banco no servidor
@author Pablo Regis
@since 19/10/2026
@version 1.0
@type method
@param  cCodBco, caracter, Código do banco (ex.: '001')
@return cLogo  , caracter, Caminho do arquivo a partir do RootPath (\system\tcImage\banco\bancoXXX.jpg)
@example
cLogo := oBoleto:GetLogo('001')
/*/
method GetLogo(cCodBco) class tcBoleto
	local cLogo := '\system\tcImage\banco\banco' + allTrim(cCodBco) + '.jpg'

	if !file(cLogo)
		_Super:Add('GetLogo' ;
			, 'Logo do banco não encontrado!' ;
			, 'A' ;
			, 'O arquivo <' + cLogo + '> não foi encontrado no servidor. O boleto será impresso sem o logo.')
	endIf
return(cLogo)


/*/{Protheus.doc} tcBoleto:CreateLine
Método para geração da linha digitável  
@author Odair Batista - TOTVS Unidade Londrina
@since 24/01/2018
@version 1.0                        
@type method
@param  cBarCode  , caracter, Código de barras
@return cDigitLine, caracter, Linha digitável gerada
@example
cLinhaDigitavel := oBoleto:CreateLine(cBarCode)
/*/
method CreateLine(cBarCode) class tcBoleto
	cDigitLine := ""
	cCodeCut   := ""

	//Campo 1
	cCodeCut   := subStr(cBarCode, 1, 3) + subStr(cBarCode, 4, 1) + subStr(cBarCode, 20, 5)
	cDigitLine := subStr(cBarCode, 1, 3) + subStr(cBarCode, 4, 1) + subStr(cBarCode, 20, 1) ;
		+ '.' + subStr(cBarCode, 21, 4) + ::CalcMod10(cCodeCut) + space(1)

	//Campo 2
	cCodeCut   := subStr(cBarCode, 25, 10)
	cDigitLine += subStr(cCodeCut,  1,  5) + '.' + subStr(cCodeCut, 6, 5) + ::CalcMod10(cCodeCut) + space(1)

	//Campo 3
	cCodeCut   := subStr(cBarCode, 35, 10)
	cDigitLine += subStr(cCodeCut,  1,  5) + '.' + subStr(cCodeCut, 6, 5) + ::CalcMod10(cCodeCut) + space(1)

	//Campo 4
	cDigitLine += subStr(cBarCode, 5, 1) + space(1)

	//Campo 5
	cDigitLine += subStr(cBarCode, 6, 4) + subStr(cBarCode, 10, 10)
return(cDigitLine)


/*/{Protheus.doc} tcBoleto:Generate
Método para somente a geração do Nosso Número  
@author Odair Batista - TOTVS Unidade Londrina
@since 18/01/2018
@version 1.0                        
@type method
@example
oBoleto:Generate()
/*/
method Generate() class tcBoleto
	local nRow 	:= 0
	local nSize	:= 0

	if empty(::aData)
		_Super:Add('Generate', 'Geração abortada!', 'E', 'Não existem dados para serem gerados')
		return
	endIf

	procRegua(0)
	incProc("Gerando Nosso Número...")

	nSize := len(::aData)

	for nRow := 1 to nSize
		::nPointer := nRow

		/*
		Gravar o Nosso Número no título antes da impressão. O método somente grava se não houver um 
		número já armazenado.
		*/
		::SaveNossoNumero()
	next nRow
return


/*/{Protheus.doc} tcBoleto:Printer
Método para impressão do boleto bancário  
@author Odair Batista - TOTVS Unidade Londrina
@since 18/01/2018
@version 1.0                        
@type method
@example
oBoleto:Printer()
/*/
method Printer() class tcBoleto
	local lAdjustToLegacy := .f.
	local lDisableSetup   := .t.
	local cLocal          := ''
	local cPdfFile        := ''
	local nRow 			  := 0
	local nSize			  := 0

	private oFnHel09  := nil
	private oFnHel09b := nil
	private oFnHel10  := nil
	private oFnHel14b := nil
	private oFnHel16b := nil
	private oFnHel19b := nil
	private oFnCou10  := nil
	private oFnCou11  := nil
	private oFnCou12  := nil

	if !empty(::cPathFile)
		cLocal := ::cPathFile
	else
		cLocal := getTempPath()
	endIf

	::cFileName := ''

	if ::toOutput <> 'Printer'
		oFnHel09  := TFont():New("Helvetica-Normal", 0, 09,, .f.,,,,, .f., .f.,) //Helvetica 09
		oFnHel09b := TFont():New("Helvetica-Normal", 0, 09,, .t.,,,,, .f., .f.,) //Helvetica 09 Negrito
		oFnHel10  := TFont():New("Helvetica-Normal", 0, 10,, .f.,,,,, .f., .f.,) //Helvetica 10
		oFnHel14b := TFont():New("Helvetica-Normal", 0, 14,, .t.,,,,, .f., .f.,) //Helvetica 14 Negrito
		oFnHel16b := TFont():New("Helvetica-Normal", 0, 16,, .t.,,,,, .f., .f.,) //Helvetica 16 Negrito
		oFnHel19b := TFont():New("Helvetica-Normal", 0, 19,, .t.,,,,, .f., .f.,) //Helvetica 19 Negrito
		oFnCou10  := TFont():New("Courier"         , 0, 10,, .f.,,,,, .f., .f.,) //Courier 10
		oFnCou11  := TFont():New("Courier"         , 0, 11,, .f.,,,,, .f., .f.,) //Courier 11
		oFnCou12  := TFont():New("Courier"         , 0, 12,, .f.,,,,, .f., .f.,) //Courier 12
	else
		oFnHel09  := TFont():New("Helvetica-Normal", 0, 07,, .f.,,,,, .f., .f.,) //Helvetica 07
		oFnHel09b := TFont():New("Helvetica-Normal", 0, 07,, .t.,,,,, .f., .f.,) //Helvetica 07 Negrito
		oFnHel10  := TFont():New("Helvetica-Normal", 0, 08,, .f.,,,,, .f., .f.,) //Helvetica 08
		oFnHel14b := TFont():New("Helvetica-Normal", 0, 10,, .t.,,,,, .f., .f.,) //Helvetica 10 Negrito
		oFnHel16b := TFont():New("Helvetica-Normal", 0, 12,, .t.,,,,, .f., .f.,) //Helvetica 12 Negrito
		oFnHel19b := TFont():New("Helvetica-Normal", 0, 15,, .t.,,,,, .f., .f.,) //Helvetica 15 Negrito
		oFnCou10  := TFont():New("Courier"         , 0, 08,, .f.,,,,, .f., .f.,) //Courier 08
		oFnCou11  := TFont():New("Courier"         , 0, 08,, .f.,,,,, .f., .f.,) //Courier 08
		oFnCou12  := TFont():New("Courier"         , 0, 09,, .f.,,,,, .f., .f.,) //Courier 09
	endIf

	private oPrinter   := nil
	private cThickLine := '-4'
	private cSlimLine  := '-2'

	if empty(::aData)
		_Super:Add('Printer', 'Impressão abortada!', 'E', 'Não existem dados para serem impressos')
		return
	endIf

	cPdfFile := "boleto_" ;
		+ subStr(alltrim(::aData[1, 1]), 1, 3) ;
		+ strZero(year(date()), 4) ;
		+ strZero(month(date()), 2) ;
		+ strZero(day(date()), 2) ;
		+ strTran(time(), ':', '') ;
		+ '_' + cValToChar(randomize(1, 999999999)) ;
		+ '.pdf'

	::cFileName := cLocal + cPdfFile

	procRegua(0)
	incProc("Imprimindo...")

	oPrinter := fwMsPrinter():New(cPdfFile, iIf(::toOutput == 'Printer', IMP_SPOOL, IMP_PDF), lAdjustToLegacy, cLocal, lDisableSetup,,,, ::lServer,,, .f.,)

	oPrinter:SetResolution(72)
	oPrinter:SetPortrait()
	oPrinter:SetPaperSize(DMPAPER_A4)		//Papel A4

	nSize := len(::aData)

	for nRow := 1 to nSize
		::nPointer := nRow

		/*
		Gravar o Nosso Número no título antes da impressão. O método somente grava se não houver um 
		número já armazenado.
		*/
		::SaveNossoNumero()

		oPrinter:StartPage()

		::PutRecibo()
		::PutRecSacado()
		::PutRecCompensacao()

		oPrinter:EndPage()
	next nRow

	//geração do visualização do PDF
	file2Printer(cLocal + cPdfFile, "pdf")
	oPrinter:cPathPDF := cLocal

	if ::toOutput == 'Screen'
		oPrinter:SetViewPDF(.t.)
		oPrinter:Preview()      //Enviar para tela
	else
		if ::toOutput == 'File'
			oPrinter:SetViewPDF(.f.)
		endIf

		oPrinter:Print()		//Enviar para arquivo ou impressora
	endIf
return


/*/{Protheus.doc} tcBoleto:PutRecibo
Método para impressão do boleto bancário - Recibo  
@author Odair Batista - TOTVS Unidade Londrina
@since 18/01/2018
@version 1.0                        
@type method
@example
oBoleto:PutRecibo()
/*/
method PutRecibo() class tcBoleto
	local nBaseRow := 0

	//Moldura: Linhas, labels e dados do top
	oPrinter:Line((nBaseRow + 024), 120, (nBaseRow + 044), 120,, cThickLine)
	oPrinter:Line((nBaseRow + 024), 170, (nBaseRow + 044), 170,, cThickLine)
	oPrinter:Line((nBaseRow + 044), 010, (nBaseRow + 044), 580,, cThickLine)

	oPrinter:SayBitmap((nBaseRow + 024), 010, ::aData[::nPointer, 03], 108, 018)

	oPrinter:Say((nBaseRow + 040), 123, allTrim(::aData[::nPointer, 1]) , oFnHel19b,,,,)		//Código do banco
	oPrinter:Say((nBaseRow + 040), 173, allTrim(::aData[::nPointer, 32]), oFnHel16b,,,,)		//Linha digitável

	//Moldura: Linhas horizontais
	oPrinter:Line((nBaseRow + 064), 010, (nBaseRow + 064), 580,, cSlimLine)
	oPrinter:Line((nBaseRow + 084), 010, (nBaseRow + 084), 580,, cSlimLine)
	oPrinter:Line((nBaseRow + 104), 010, (nBaseRow + 104), 580,, cSlimLine)

	//Moldura: Linhas verticais
	oPrinter:Line((nBaseRow + 064), 110, (nBaseRow + 104), 110,, cSlimLine)
	oPrinter:Line((nBaseRow + 084), 147, (nBaseRow + 104), 147,, cSlimLine)
	oPrinter:Line((nBaseRow + 084), 220, (nBaseRow + 104), 220,, cSlimLine)
	oPrinter:Line((nBaseRow + 064), 240, (nBaseRow + 084), 240,, cSlimLine)
	oPrinter:Line((nBaseRow + 064), 300, (nBaseRow + 104), 300,, cSlimLine)
	oPrinter:Line((nBaseRow + 064), 330, (nBaseRow + 084), 330,, cSlimLine)
	oPrinter:Line((nBaseRow + 044), 420, (nBaseRow + 104), 420,, cSlimLine)

	//Labels
	oPrinter:Say((nBaseRow + 050), 012, 'Beneficiário'  	       	 , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 050), 422, 'Agência/Código Beneficiário', oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 070), 012, 'Data do documento'	         , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 070), 112, 'Nº do Documento'	         , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 070), 242, 'Espécie Doc.'	   	         , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 070), 302, 'Aceite'	   	   		     , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 070), 332, 'Data processamento'	     , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 070), 422, 'Nosso Número'	             , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 090), 012, 'Uso do Banco'	             , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 090), 112, 'Carteira'	                 , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 090), 149, 'Espécie Moeda'	             , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 090), 222, 'Quantidade'	             , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 090), 312, 'Assinatura'	             , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 090), 422, '(=) Valor do Documento'     , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 112), 012, ::aData[::nPointer, 43]      , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 112), 400, 'Cliente:'                   , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 122), 400, 'CGC/CNPJ:'                  , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 132), 400, 'Documento:'                 , oFnHel09,,,,)

	//Dados
	// oPrinter:Say((nBaseRow + 060), 012, allTrim(::aData[::nPointer, 12]), oFnCou12,,,,)		//Nome do beneficiário

	oPrinter:Say((nBaseRow + 052), 080, allTrim(::aData[::nPointer, 12]), oFnCou11,,,,)		//Nome do beneficiário
	oPrinter:Say((nBaseRow + 062), 080, allTrim(::aData[::nPointer, 46]) + ' '  + ;
		allTrim(::aData[::nPointer, 47]) + '  ' + ;
		allTrim(::aData[::nPointer, 48]), oFnCou11,,,,)		//Endereço do beneficiário

	oPrinter:Say((nBaseRow + 060), 450, allTrim(::aData[::nPointer, 11]), oFnHel10,,,,)		//Beneficiário
	oPrinter:Say((nBaseRow + 080), 450, allTrim(::aData[::nPointer, 34]), oFnHel10,,,,)		//Nosso número
	oPrinter:Say((nBaseRow + 080), 012, dToC(::aData[::nPointer, 19])   , oFnCou11,,,,)		//Data de emissão
	oPrinter:Say((nBaseRow + 080), 112, allTrim(::aData[::nPointer, 20]), oFnCou11,,,,)		//Número do documento
	oPrinter:Say((nBaseRow + 080), 242, allTrim(::aData[::nPointer, 13]), oFnCou11,,,,)		//Espécie
	oPrinter:Say((nBaseRow + 080), 312, 'N'					            , oFnCou11,,,,)		//Aceite
	oPrinter:Say((nBaseRow + 080), 332, dToC(dDatabase)	                , oFnCou11,,,,)		//Data de processamento
	oPrinter:Say((nBaseRow + 100), 012, ''					            , oFnCou11,,,,)		//Uso do banco
	oPrinter:Say((nBaseRow + 100), 112, allTrim(::aData[::nPointer, 22]), oFnCou11,,,,)		//Carteira
	oPrinter:Say((nBaseRow + 100), 149, 'Real'				            , oFnCou11,,,,)		//Espécie da moeda

	oPrinter:SayAlign(((nBaseRow + 100) - 9), 422, transform(::aData[::nPointer, 21], '@E 999,999,999.99'), oFnCou11, 155, 10,, 1, 1) //Valor do Documento

	//oPrinter:SayAlign(((nBaseRow + 200) - 9), 422, transform(::aData[::nPointer, 17], '@E 999,999,999.99'), oFnCou11, 155, 10,, 1, 1) //Valor do Desconto

	oPrinter:Say((nBaseRow + 112), 045, allTrim(::aData[::nPointer, 24]), oFnCou10,,,,)			//Nome do sacado
	oPrinter:Say((nBaseRow + 122), 045, allTrim(::aData[::nPointer, 25]), oFnCou10,,,,)			//Endereço do sacado
	oPrinter:Say((nBaseRow + 132), 045, allTrim(::aData[::nPointer, 26]) ;				        //Cidade/UF/CEP do sacado
	+ ' - ' + allTrim(::aData[::nPointer, 27]) ;
		+ iIf(empty(allTrim(::aData[::nPointer, 28])), '', ' - ' + allTrim(::aData[::nPointer, 28])), oFnCou10,,,,)
	oPrinter:Say((nBaseRow + 112), 445, allTrim(::aData[::nPointer, 23]), oFnCou10,,,,)			//Código do sacado
	oPrinter:Say((nBaseRow + 122), 445, allTrim(::aData[::nPointer, 30]), oFnCou10,,,,)			//ID federal do sacado CNPJ ou CPF
	oPrinter:Say((nBaseRow + 132), 445, allTrim(::aData[::nPointer, 20]), oFnCou10,,,,)			//Número do documento dados do sacado

	//Separador
	oPrinter:Say((nBaseRow + 145), 220, 'Corte na linha pontilhada', oFnHel10,,,,)
	putDashLine((nBaseRow + 150), 010, (nBaseRow + 150), 580, 0, cSlimLine, 5, 2, oPrinter)
return


/*/{Protheus.doc} tcBoleto:PutRecSacado
Método para impressão do boleto bancário - Recibo do Sacado  
@author Odair Batista - TOTVS Unidade Londrina
@since 18/01/2018
@version 1.0                        
@type method
@example
oBoleto:PutRecSacado()
/*/
method PutRecSacado() class tcBoleto
	local nBaseRow := 160
	local aInfBco  := ::aData[::nPointer, 14]	//Instruções bancárias

	//Moldura: Linhas, labels e dados do top
	oPrinter:Say((nBaseRow + 010), 470, 'Recibo do ' + ::aData[::nPointer, 43], oFnHel14b,,,,)

	oPrinter:Line((nBaseRow + 024), 120, (nBaseRow + 044), 120,, cThickLine)
	oPrinter:Line((nBaseRow + 024), 170, (nBaseRow + 044), 170,, cThickLine)
	oPrinter:Line((nBaseRow + 044), 010, (nBaseRow + 044), 580,, cThickLine)

	oPrinter:SayBitmap((nBaseRow + 024), 010, ::aData[::nPointer, 03], 108, 018)

	oPrinter:Say((nBaseRow + 040), 123, allTrim(::aData[::nPointer, 1]) , oFnHel19b,,,,)		//Código do banco
	oPrinter:Say((nBaseRow + 040), 173, allTrim(::aData[::nPointer, 32]), oFnHel16b,,,,)		//Linha digitável

	//Moldura: Linhas horizontais
	oPrinter:Line((nBaseRow + 064), 010, (nBaseRow + 064), 580,, cSlimLine)
	oPrinter:Line((nBaseRow + 084), 010, (nBaseRow + 084), 580,, cSlimLine)
	oPrinter:Line((nBaseRow + 104), 010, (nBaseRow + 104), 580,, cSlimLine)
	oPrinter:Line((nBaseRow + 124), 010, (nBaseRow + 124), 580,, cSlimLine)
	oPrinter:Line((nBaseRow + 144), 420, (nBaseRow + 144), 580,, cSlimLine)
	oPrinter:Line((nBaseRow + 164), 420, (nBaseRow + 164), 580,, cSlimLine)
	oPrinter:Line((nBaseRow + 184), 420, (nBaseRow + 184), 580,, cSlimLine)
	oPrinter:Line((nBaseRow + 204), 420, (nBaseRow + 204), 580,, cSlimLine)
	oPrinter:Line((nBaseRow + 224), 010, (nBaseRow + 224), 580,, cSlimLine)
	oPrinter:Line((nBaseRow + 267), 010, (nBaseRow + 267), 580,, cSlimLine)

	//Moldura: Linhas verticais
	oPrinter:Line((nBaseRow + 084), 110, (nBaseRow + 124), 110,, cSlimLine)
	oPrinter:Line((nBaseRow + 104), 147, (nBaseRow + 124), 147,, cSlimLine)
	oPrinter:Line((nBaseRow + 104), 220, (nBaseRow + 124), 220,, cSlimLine)
	oPrinter:Line((nBaseRow + 084), 240, (nBaseRow + 104), 240,, cSlimLine)
	oPrinter:Line((nBaseRow + 084), 300, (nBaseRow + 124), 300,, cSlimLine)
	oPrinter:Line((nBaseRow + 084), 330, (nBaseRow + 104), 330,, cSlimLine)
	oPrinter:Line((nBaseRow + 044), 420, (nBaseRow + 224), 420,, cSlimLine)

	//Labels
	oPrinter:Say((nBaseRow + 050), 012, 'Local de Pagamento'       	 , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 050), 422, 'Vencimento'                 , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 070), 012, 'Beneficiário'  	       	 , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 070), 422, 'Agência/Código Beneficiário', oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 090), 012, 'Data do documento'	         , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 090), 112, 'Nº do Documento'	         , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 090), 242, 'Espécie Doc.'	   	         , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 090), 302, 'Aceite'	   	   		     , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 090), 332, 'Data processamento'	     , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 090), 422, 'Nosso Número'	             , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 110), 012, 'Uso do Banco'	             , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 110), 112, 'Carteira'	                 , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 110), 149, 'Espécie Moeda'	             , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 110), 222, 'Quantidade'	             , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 110), 312, 'Assinatura'	             , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 110), 422, '(=) Valor do Documento'     , oFnHel09,,,,)

	oPrinter:Say((nBaseRow + 130), 012, 'Instruções (Todas informações deste bloqueto são de exclusiva responsabilidade do beneficiário)', oFnHel09b,,,,)

	oPrinter:Say((nBaseRow + 130), 422, '( - ) Descontos/Abatimentos', oFnHel09 ,,,,)
	oPrinter:Say((nBaseRow + 150), 422, '( - ) Outras Deduções'	     , oFnHel09 ,,,,)
	oPrinter:Say((nBaseRow + 170), 422, '( + ) Mora/Multa/Juros'	 , oFnHel09 ,,,,)
	oPrinter:Say((nBaseRow + 190), 422, '( + ) Outros Acréscimos'	 , oFnHel09 ,,,,)
	oPrinter:Say((nBaseRow + 210), 422, '( = ) Valor Cobrado'		 , oFnHel09 ,,,,)
	oPrinter:Say((nBaseRow + 233), 012, ::aData[::nPointer, 43]      , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 233), 400, 'Cliente:'                   , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 243), 400, 'CGC/CNPJ:'                  , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 253), 400, 'Documento:'                 , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 263), 012, 'Sacador/Avalista'			 , oFnHel09 ,,,,)

	oPrinter:Say((nBaseRow + 273), 400, 'Autenticação Mecânica - Recibo do ' + ::aData[::nPointer, 43], oFnHel09 ,,,,)

	//Dados
	oPrinter:Say((nBaseRow + 060), 012, allTrim(::aData[::nPointer, 4]) , oFnCou12,,,,)		//Local de pagamento
	oPrinter:Say((nBaseRow + 060), 523, dToC(::aData[::nPointer, 18])   , oFnCou12,,,,)		//Data de vencimento
	// oPrinter:Say((nBaseRow + 080), 012, allTrim(::aData[::nPointer, 12]), oFnCou12,,,,)		//Nome do beneficiário

	oPrinter:Say((nBaseRow + 072), 080, allTrim(::aData[::nPointer, 12]), oFnCou11,,,,)		//Nome do beneficiário
	oPrinter:Say((nBaseRow + 082), 080, allTrim(::aData[::nPointer, 46]) + ' '  + ;
		allTrim(::aData[::nPointer, 47]) + '  ' + ;
		allTrim(::aData[::nPointer, 48]), oFnCou11,,,,)		//Endereço do beneficiário

	oPrinter:Say((nBaseRow + 080), 450, allTrim(::aData[::nPointer, 11]), oFnHel10,,,,)		//Beneficiário
	oPrinter:Say((nBaseRow + 100), 450, allTrim(::aData[::nPointer, 34]), oFnHel10,,,,)		//Nosso número
	oPrinter:Say((nBaseRow + 100), 012, dToC(::aData[::nPointer, 19])   , oFnCou11,,,,)		//Data de emissão
	oPrinter:Say((nBaseRow + 100), 112, allTrim(::aData[::nPointer, 20]), oFnCou11,,,,)		//Número do documento
	oPrinter:Say((nBaseRow + 100), 242, allTrim(::aData[::nPointer, 13]), oFnCou11,,,,)		//Espécie
	oPrinter:Say((nBaseRow + 100), 312, 'N'					            , oFnCou11,,,,)		//Aceite
	oPrinter:Say((nBaseRow + 100), 332, dToC(dDatabase)	                , oFnCou11,,,,)		//Data de processamento
	oPrinter:Say((nBaseRow + 120), 012, ''					            , oFnCou11,,,,)		//Uso do banco
	oPrinter:Say((nBaseRow + 120), 112, allTrim(::aData[::nPointer, 22]), oFnCou11,,,,)		//Carteira
	oPrinter:Say((nBaseRow + 120), 149, 'Real'				            , oFnCou11,,,,)		//Espécie da moeda

	oPrinter:SayAlign(((nBaseRow + 120) - 9), 422, transform(::aData[::nPointer, 21], '@E 999,999,999.99'), oFnCou11, 155, 10,, 1, 1) //Valor do documento

	oPrinter:SayAlign(((nBaseRow + 140) - 9), 422, transform(::aData[::nPointer, 17], '@E 999,999,999.99'), oFnCou11, 155, 10,, 1, 1) //Valor do Desconto


	oPrinter:Say((nBaseRow + 140), 012, aInfBco[1], oFnHel10,,,,)		//Instrução bancária - Linha 1
	oPrinter:Say((nBaseRow + 150), 012, aInfBco[2], oFnHel10,,,,)		//Instrução bancária - Linha 2
	oPrinter:Say((nBaseRow + 160), 012, aInfBco[3], oFnHel10,,,,)		//Instrução bancária - Linha 3
	oPrinter:Say((nBaseRow + 170), 012, aInfBco[4], oFnHel10,,,,)		//Instrução bancária - Linha 4
	oPrinter:Say((nBaseRow + 180), 012, aInfBco[5], oFnHel10,,,,)		//Instrução bancária - Linha 5
	oPrinter:Say((nBaseRow + 190), 012, aInfBco[6], oFnHel10,,,,)		//Instrução bancária - Linha 6
	oPrinter:Say((nBaseRow + 200), 012, aInfBco[7], oFnHel10,,,,)		//Instrução bancária - Linha 7

	oPrinter:Say((nBaseRow + 233), 044, allTrim(::aData[::nPointer, 24]), oFnCou10,,,,)			//Nome do sacado
	oPrinter:Say((nBaseRow + 243), 044, allTrim(::aData[::nPointer, 25]), oFnCou10,,,,)			//Endereço do sacado
	oPrinter:Say((nBaseRow + 253), 044, allTrim(::aData[::nPointer, 26]) ;				        //Cidade/UF/CEP do sacado
	+ ' - ' + allTrim(::aData[::nPointer, 27]) ;
		+ iIf(empty(allTrim(::aData[::nPointer, 28])), '', ' - ' + allTrim(::aData[::nPointer, 28])), oFnCou10,,,,)
	oPrinter:Say((nBaseRow + 233), 445, allTrim(::aData[::nPointer, 23]), oFnCou10,,,,)			//Código do sacado
	oPrinter:Say((nBaseRow + 243), 445, allTrim(::aData[::nPointer, 30]), oFnCou10,,,,)			//ID federal do sacado CNPJ ou CPF
	oPrinter:Say((nBaseRow + 253), 445, allTrim(::aData[::nPointer, 20]), oFnCou10,,,,)			//Número do documento dados do sacado
	oPrinter:Say((nBaseRow + 263), 090, alltrim(::aData[::nPointer, 35]), oFnHel10,,,,)			//Sacador/Avalista

	//Dados do SAC - Obrigatório para o banco Caixa Econômica Federal
	oPrinter:SayAlign(((nBaseRow + 278) - 9), 010, allTrim(::aData[::nPointer, 36]), oFnHel09b, 320, 10,, 2, 1)
	oPrinter:SayAlign(((nBaseRow + 288) - 9), 010, allTrim(::aData[::nPointer, 37]), oFnHel09b, 320, 10,, 2, 1)
	oPrinter:SayAlign(((nBaseRow + 298) - 9), 010, allTrim(::aData[::nPointer, 38]), oFnHel09b, 320, 10,, 2, 1)
	oPrinter:SayAlign(((nBaseRow + 308) - 9), 010, allTrim(::aData[::nPointer, 39]), oFnHel09b, 320, 10,, 2, 1)

	//Separador
	oPrinter:Say((nBaseRow + 318), 220, 'Corte na linha pontilhada', oFnHel10,,,,)
	putDashLine((nBaseRow + 323), 010, (nBaseRow + 323), 580, 0, cSlimLine, 5, 2, oPrinter)
return


/*/{Protheus.doc} tcBoleto:PutRecCompensacao
Método para impressão do boleto bancário - Recibo da Compensação  
@author Odair Batista - TOTVS Unidade Londrina
@since 18/01/2018
@version 1.0                        
@type method
@example
oBoleto:PutRecCompensacao()
/*/
method PutRecCompensacao() class tcBoleto
	local nBaseRow := 493
	local aInfBco  := ::aData[::nPointer, 14]	//Instruções bancárias

	//Moldura: Linhas, labels e dados do top
	oPrinter:Say((nBaseRow + 010), 450, 'Ficha de Compensação', oFnHel14b,,,,)

	oPrinter:Line((nBaseRow + 024), 120, (nBaseRow + 044), 120,, cThickLine)
	oPrinter:Line((nBaseRow + 024), 170, (nBaseRow + 044), 170,, cThickLine)
	oPrinter:Line((nBaseRow + 044), 010, (nBaseRow + 044), 580,, cThickLine)

	oPrinter:SayBitmap((nBaseRow + 024), 010, ::aData[::nPointer, 03], 108, 018)

	oPrinter:Say((nBaseRow + 040), 123, allTrim(::aData[::nPointer, 1]) , oFnHel19b,,,,)		//Código do banco
	oPrinter:Say((nBaseRow + 040), 173, allTrim(::aData[::nPointer, 32]), oFnHel16b,,,,)		//Linha digitável

	//Moldura: Linhas horizontais
	oPrinter:Line((nBaseRow + 064), 010, (nBaseRow + 064), 580,, cSlimLine)
	oPrinter:Line((nBaseRow + 084), 010, (nBaseRow + 084), 580,, cSlimLine)
	oPrinter:Line((nBaseRow + 104), 010, (nBaseRow + 104), 580,, cSlimLine)
	oPrinter:Line((nBaseRow + 124), 010, (nBaseRow + 124), 580,, cSlimLine)
	oPrinter:Line((nBaseRow + 144), 420, (nBaseRow + 144), 580,, cSlimLine)
	oPrinter:Line((nBaseRow + 164), 420, (nBaseRow + 164), 580,, cSlimLine)
	oPrinter:Line((nBaseRow + 184), 420, (nBaseRow + 184), 580,, cSlimLine)
	oPrinter:Line((nBaseRow + 204), 420, (nBaseRow + 204), 580,, cSlimLine)
	oPrinter:Line((nBaseRow + 224), 010, (nBaseRow + 224), 580,, cSlimLine)
	oPrinter:Line((nBaseRow + 267), 010, (nBaseRow + 267), 580,, cSlimLine)

	//Moldura: Linhas verticais
	oPrinter:Line((nBaseRow + 084), 110, (nBaseRow + 124), 110,, cSlimLine)
	oPrinter:Line((nBaseRow + 104), 147, (nBaseRow + 124), 147,, cSlimLine)
	oPrinter:Line((nBaseRow + 104), 220, (nBaseRow + 124), 220,, cSlimLine)
	oPrinter:Line((nBaseRow + 084), 240, (nBaseRow + 104), 240,, cSlimLine)
	oPrinter:Line((nBaseRow + 084), 300, (nBaseRow + 124), 300,, cSlimLine)
	oPrinter:Line((nBaseRow + 084), 330, (nBaseRow + 104), 330,, cSlimLine)
	oPrinter:Line((nBaseRow + 044), 420, (nBaseRow + 224), 420,, cSlimLine)

	//Labels
	oPrinter:Say((nBaseRow + 050), 012, 'Local de Pagamento'       	 , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 050), 422, 'Vencimento'                 , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 070), 012, 'Beneficiário'  	       	 , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 070), 422, 'Agência/Código Beneficiário', oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 090), 012, 'Data do documento'	         , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 090), 112, 'Nº do Documento'	         , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 090), 242, 'Espécie Doc.'	   	         , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 090), 302, 'Aceite'	   	   		     , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 090), 332, 'Data processamento'	     , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 090), 422, 'Nosso Número'	             , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 110), 012, 'Uso do Banco'	             , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 110), 112, 'Carteira'	                 , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 110), 149, 'Espécie Moeda'	             , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 110), 222, 'Quantidade'	             , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 110), 312, 'Assinatura'	             , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 110), 422, '(=) Valor do Documento'     , oFnHel09,,,,)

	oPrinter:Say((nBaseRow + 130), 012, 'Instruções (Todas informações deste bloqueto são de exclusiva responsabilidade do beneficiário)', oFnHel09b,,,,)

	oPrinter:Say((nBaseRow + 130), 422, '( - ) Descontos/Abatimentos', oFnHel09 ,,,,)
	oPrinter:Say((nBaseRow + 150), 422, '( - ) Outras Deduções'	     , oFnHel09 ,,,,)
	oPrinter:Say((nBaseRow + 170), 422, '( + ) Mora/Multa/Juros'	 , oFnHel09 ,,,,)
	oPrinter:Say((nBaseRow + 190), 422, '( + ) Outros Acréscimos'	 , oFnHel09 ,,,,)
	oPrinter:Say((nBaseRow + 210), 422, '( = ) Valor Cobrado'		 , oFnHel09 ,,,,)
	oPrinter:Say((nBaseRow + 233), 012, ::aData[::nPointer, 43]      , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 233), 400, 'Cliente:'                   , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 243), 400, 'CGC/CNPJ:'                  , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 253), 400, 'Documento:'                 , oFnHel09,,,,)
	oPrinter:Say((nBaseRow + 263), 012, 'Sacador/Avalista'			 , oFnHel09 ,,,,)

	oPrinter:Say((nBaseRow + 273), 390, 'Autenticação Mecânica - Ficha de Compensação', oFnHel09 ,,,,)

	//Dados
	oPrinter:Say((nBaseRow + 060), 012, allTrim(::aData[::nPointer, 4]) , oFnCou12,,,,)		//Local de pagamento
	oPrinter:Say((nBaseRow + 060), 523, dToC(::aData[::nPointer, 18])   , oFnCou12,,,,)		//Data de vencimento
	// oPrinter:Say((nBaseRow + 080), 012, allTrim(::aData[::nPointer, 12]), oFnCou12,,,,)		//Nome do beneficiário
	oPrinter:Say((nBaseRow + 072), 080, allTrim(::aData[::nPointer, 12]), oFnCou11,,,,)		//Nome do beneficiário
	oPrinter:Say((nBaseRow + 082), 080, allTrim(::aData[::nPointer, 46]) + ' '  + ;
		allTrim(::aData[::nPointer, 47]) + '  ' + ;
		allTrim(::aData[::nPointer, 48]), oFnCou11,,,,)		//Endereço do beneficiário

	oPrinter:Say((nBaseRow + 080), 450, allTrim(::aData[::nPointer, 11]), oFnHel10,,,,)		//Beneficiário
	oPrinter:Say((nBaseRow + 100), 450, allTrim(::aData[::nPointer, 34]), oFnHel10,,,,)		//Nosso número
	oPrinter:Say((nBaseRow + 100), 012, dToC(::aData[::nPointer, 19])   , oFnCou11,,,,)		//Data de emissão
	oPrinter:Say((nBaseRow + 100), 112, allTrim(::aData[::nPointer, 20]), oFnCou11,,,,)		//Número do documento
	oPrinter:Say((nBaseRow + 100), 242, allTrim(::aData[::nPointer, 13]), oFnCou11,,,,)		//Espécie
	oPrinter:Say((nBaseRow + 100), 312, 'N'					            , oFnCou11,,,,)		//Aceite
	oPrinter:Say((nBaseRow + 100), 332, dToC(dDatabase)	                , oFnCou11,,,,)		//Data de processamento
	oPrinter:Say((nBaseRow + 120), 012, ''					            , oFnCou11,,,,)		//Uso do banco
	oPrinter:Say((nBaseRow + 120), 112, allTrim(::aData[::nPointer, 22]), oFnCou11,,,,)		//Carteira
	oPrinter:Say((nBaseRow + 120), 149, 'Real'				            , oFnCou11,,,,)		//Espécie da moeda

	oPrinter:SayAlign(((nBaseRow + 120) - 9), 422, transform(::aData[::nPointer, 21], '@E 999,999,999.99'), oFnCou11, 155, 10,, 1, 1) //VALOR DO DOCUMENTO

	oPrinter:SayAlign(((nBaseRow + 140) - 9), 422, transform(::aData[::nPointer, 17], '@E 999,999,999.99'), oFnCou11, 155, 10,, 1, 1) //Valor do DESCONTO

	oPrinter:Say((nBaseRow + 140), 012, aInfBco[1], oFnHel10,,,,)		//Instrução bancária - Linha 1
	oPrinter:Say((nBaseRow + 150), 012, aInfBco[2], oFnHel10,,,,)		//Instrução bancária - Linha 2
	oPrinter:Say((nBaseRow + 160), 012, aInfBco[3], oFnHel10,,,,)		//Instrução bancária - Linha 3
	oPrinter:Say((nBaseRow + 170), 012, aInfBco[4], oFnHel10,,,,)		//Instrução bancária - Linha 4
	oPrinter:Say((nBaseRow + 180), 012, aInfBco[5], oFnHel10,,,,)		//Instrução bancária - Linha 5
	oPrinter:Say((nBaseRow + 190), 012, aInfBco[6], oFnHel10,,,,)		//Instrução bancária - Linha 6
	oPrinter:Say((nBaseRow + 200), 012, aInfBco[7], oFnHel10,,,,)		//Instrução bancária - Linha 7

	oPrinter:Say((nBaseRow + 233), 045, allTrim(::aData[::nPointer, 24]), oFnCou10,,,,)			//Nome do sacado
	oPrinter:Say((nBaseRow + 243), 045, allTrim(::aData[::nPointer, 25]), oFnCou10,,,,)			//Endereço do sacado
	oPrinter:Say((nBaseRow + 253), 045, allTrim(::aData[::nPointer, 26]) ;				        //Cidade/UF/CEP do sacado
	+ ' - ' + allTrim(::aData[::nPointer, 27]) ;
		+ iIf(empty(allTrim(::aData[::nPointer, 28])), '', ' - ' + allTrim(::aData[::nPointer, 28])), oFnCou10,,,,)
	oPrinter:Say((nBaseRow + 233), 445, allTrim(::aData[::nPointer, 23]), oFnCou10,,,,)			//Código do sacado
	oPrinter:Say((nBaseRow + 243), 445, allTrim(::aData[::nPointer, 30]), oFnCou10,,,,)			//ID federal do sacado CNPJ ou CPF
	oPrinter:Say((nBaseRow + 253), 445, allTrim(::aData[::nPointer, 20]), oFnCou10,,,,)			//Número do documento dados do sacado
	oPrinter:Say((nBaseRow + 263), 090, alltrim(::aData[::nPointer, 35]), oFnHel10,,,,)			//Sacador/Avalista

	oPrinter:FwMsBar ;
		('INT25' ;						//Tipo do código: 'EAN13', 'EAN8', 'UPCA', 'SUP5', 'CODE128', 'INT25', 'MAT25', 'IND25', 'CODABAR', 'CODE3_9'
	, 67 ;							//Posição relativa ao topo
	, 1 ;							//Posição relativa à esquerda
	, ::aData[::nPointer, 33] ;	//Texto a ser transformado em código de barra
	, oPrinter ;					//Objeto Printer
	, .f. ;						//Se calcula o digito de controle. Defautl .T.
	, CLR_BLACK ;					//Numero da Cor, utilize a "color.ch". Default CLR_BLACK
	, .t. ;						//Se imprime na Horizontal. Default .T.
	, 0.020 ;						//Numero do Tamanho da barra. Default 0.025
	, 1.0 ;						//Numero da Altura da barra. Default 1.5
	, .f. ;						//Se imprime a linha com o código embaixo da barra. Default .T.
	, 'Arial' ;					//Nome do Fonte a ser utilizado. Defautl "Arial"
	, '' ;							//Modo do codigo de barras CO. Default ""
	, .f. ;						//Se executa o método Print() de oPrinter pela MsBar. Default .T.
	, 1 ;							//Número do índice de ajuste da largura da fonte. Default 1
	, 1 ;							//Número do índice de ajuste da altura da fonte. Default 1
	, .t.)							//Utiliza o método Cmtr2Pix() do objeto Printer.Default .T.
return


/*/{Protheus.doc} putDashLine
Função imprimir uma linha pontillhada  
@author Odair Batista - TOTVS Unidade Londrina
@since 19/01/2018
@version 1.0                        
@type function
@param nXRow   , inteiro , posição linha inicial 
@param nXCol   , inteiro , posição coluna inicial 
@param nYRow   , inteiro , posição linha final 
@param nYCol   , inteiro , posição coluna final 
@param nColor  , inteiro , Cor da linha 
@param nWidth  , caracter, Expessura da linha 
@param nStep   , inteiro , Salto do pontilhado 
@param nSpace  , inteiro , Espaçamento do pontilhado 
@param oPrinter, objeto  , Objeto fwMsPrinter() 
@example
putDashLine(010, 340, 580, 340, 0, '-2', 50, 30, oPrinter)
/*/
static function putDashLine(nXRow, nXCol, nYRow, nYCol, nColor, cWidth, nStep, nSpace, oPrinter)
	local nPos 	   := 0
	local nMaxSize := 0

	default nColor := 0
	default cWidth := '-2'
	default nStep  := 5
	default nSpace := 2

	for nPos := nXCol to nYCol step nStep
		nMaxSize := iIf((nPos + nSpace) <= nYCol, (nPos + nSpace), nYCol)

		oPrinter:Line(nXRow, nPos, nYRow, nMaxSize,, cWidth)
	next nRow
return


/*/{Protheus.doc} loadSM0
Função para efetuar a carga de dados da empresa beneficiária  
@author Odair Batista - TOTVS Unidade Londrina
@since 19/01/2018
@version 1.0                        
@type function
@return aDataSM0, array, conteúdo de dados da empresa beneficiária
@example
aDataSM0 := loadSM0()
/*/
static function loadSM0()
	local aDataSM0 := {}

	aDataSM0 := {SM0->M0_NOMECOM ; 																		//[1]Nome da Empresa
	, SM0->M0_ENDENT ; 																	//[2]Endereço
	, allTrim(SM0->M0_BAIRENT) + ", " + allTrim(SM0->M0_CIDENT) + ", " + SM0->M0_ESTENT ; 	//[3]Complemento
	, subStr(SM0->M0_CEPENT, 1, 5) + "-" + subStr(SM0->M0_CEPENT, 6, 3) ; 					//[4]CEP
	, SM0->M0_TEL ; 																		//[5]Telefones
	, subStr(SM0->M0_CGC, 1, 2) + "." + subStr(SM0->M0_CGC,3,3) + "." ; 					//[6]CGC
	+ subStr(SM0->M0_CGC, 6, 3) + "/" + subStr(SM0->M0_CGC, 9, 4) + "-" ;
		+ subStr(SM0->M0_CGC, 13, 2) ;
		, subStr(SM0->M0_INSC, 1, 3) + "." + subStr(SM0->M0_INSC, 4, 3) + "." ; 				//[7]Inscrição Estadual
	+ subStr(SM0->M0_INSC, 7, 3) + "." + subStr(SM0->M0_INSC, 10, 3)}
return(aDataSM0)
