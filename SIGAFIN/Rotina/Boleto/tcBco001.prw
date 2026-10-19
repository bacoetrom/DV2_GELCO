/*
Programa.: tcBco001.prw
Tipo.....: Classe 
Autor....: Odair Batista
Data.....: 19/01/2018
Descrição: Classe especializada para impressão de boleto bancário do Banco do Brasil (001) 
Notas....: Os método da classe pai podem ser especializados na classe filho se houver necessidade 
		   de definir padrões diferentes para cada banco, como por exemplo: layout, geração de 
		   código de barras e geração de linha digitável.  
*/

#include "totvs.ch"
#include "protheus.ch"
#include "topConn.ch"
#include "rptDef.ch"
#include "fwPrintSetup.ch"

#define CRLF chr(13) + chr(10)


user function tcBco001()
return .t. 


/*/{Protheus.doc} tcBco001
Classe principal da classe tcBco001
@author Odair Batista - TOTVS Unidade Londrina
@since 19/01/2018
@version 1.0
@type class
/*/
class tcBco001 from tcBoleto
	data cClassName as string hidden
	data cBcoCor    as string hidden
	
	method New() constructor
	method ClassName()
	method Destroy(oObj)

	method SetCorrespondente(cBcoCor)
	
	method GetCorrespondente()
	
	method AddBy(rowId_SE1)
endClass               

                   
/*/{Protheus.doc} tcBco001:New
Método construtor da classe tcBco001
@author Odair Batista - TOTVS Unidade Londrina
@since 19/01/2018
@version 1.0                        
@type constructor
@example
local oBoleto := tcBco001():New()
/*/
method New() class tcBco001
	_Super:New()
	
	::cClassName := "tcBco001"
	::cBcoCor	 := ''
return

           
 /*/{Protheus.doc} tcBco001:ClassName
Método responsável por retornar o nome da classe
@author Odair Batista - TOTVS Unidade Londrina
@since 19/01/2018
@version 1.0
@type method     
@return caractere, retorna o nome da classe
/*/
method ClassName() class tcBco001
return ::cClassName


 /*/{Protheus.doc} tcBco001:Destroy
Método destrutor do objeto, responsável pela desalocação da memória
@author Odair Batista - TOTVS Unidade Londrina
@since 19/01/2018
@version 1.0
@type method     
/*/  
method Destroy(oObj as object) class tcBco001    
	freeObj(oObj)	       
return


 /*/{Protheus.doc} tcBco001:SetCorrespondente
Método para informar qual o banco correspondente
@author Odair Batista - TOTVS Unidade Londrina
@since 01/02/2018
@version 1.0
@type method
@param cBcoCor, caracter, Número do banco correspondente      
/*/  
method SetCorrespondente(cBcoCor) class tcBco001    
	::cBcoCor := cBcoCor	       
return


 /*/{Protheus.doc} tcBco001:GetCorrespondente
Método para retornar qual o banco correspondente
@author Odair Batista - TOTVS Unidade Londrina
@since 01/02/2018
@version 1.0
@type method     
/*/  
method GetCorrespondente() class tcBco001    
return(::cBcoCor)


/*/{Protheus.doc} tcBoleto:AddBy
Método para alimentar o array com dados básicos do título para emissão do boleto   
@author Odair Batista - TOTVS Unidade Londrina
@since 19/01/2018
@version 1.0                        
@type method
@param rowId_SE1, inteiro, número do registro no banco de dados (Recno) 
@example
oBoleto:AddBy(rowId_SE1)
@obs
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
[14] Instruções bancárias (array) - É levado em conta no máximo 8 linhas
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
[43] Descrição Sacado ou Pagador
[44] CNPJ do Beneficiario
[45] Numero da Parcela
/*/
method AddBy(rowId_SE1) class tcBco001
	local nRowId_SEE := 0
	local aData      := {}
	local nRowArray  := 0
	local nTamNumBco := 0
	local cConvenio  := ''
	local cCarteira  := ''
	local cNNum      := ''
	local cFree      := ''
	local cLinDigit  := ''
	local cCodBarra  := ''
	local cLinhaSE1  := ''

	_Super:AddBy(rowId_SE1)			//Executa o método da classe pai populando os dados padrões

	//Se a classe pai não carregou o título (SEE/SE1/SA1 não encontrados) não há o que especializar
	if _Super:HasErrors()
		return
	endIf

	nRowId_SEE := _Super:GetRowId()		//Obtém o Recno da tabela SEE
	aData      := _Super:GetArray()		//Obtém conteúdo carregado pela classe pai
	nRowArray  := _Super:GetRowArray()	//Obtém o número da linha no array aData

	if empty(aData) .or. nRowArray == 0
		_Super:Add('AddBy' ;
			, 'Dados do boleto não carregados!' ;
			, 'E' ;
			, 'Não foi possível carregar os dados do título com ID <' + cValToChar(rowId_SE1) + '>. (tcBco001)')
		return
	endIf

	dbSelectArea('SEE')
	SEE->(dbGoTo(nRowId_SEE))

	if SEE->(eof())
		_Super:Add('AddBy' ;
			, 'Parâmetro de Banco/Agência/Conta/Sub-Conta não encontrado!' ;
			, 'E' ;
			, 'O registro <' + cValToChar(nRowId_SEE) + '> da tabela SEE não foi encontrado. (tcBco001)')
		return
	endIf

	//INÍCIO dos tratamentos especializados para o Banco
	/*
	Composição do campo livre - Convênio de 7 posições
	==================================================
	Posição  Tamanho  Formato    Conteúdo
	-------  -------  ---------  --------
	20 a 25  06       9(6)       Zeros
	26 a 42  17       9(17)      Nosso Número: Convênio(7) + Sequencial(10), sem DV
	43 a 44  02       9(2)       Carteira
	*/

	nTamNumBco := len(SE1->E1_NUMBCO)	//SE1 posicionado pela classe pai

	//Convênio (EE_CODEMP) e carteira (EE_CODCART; se vazio, EE_TIPCART)
	cConvenio := strZero(val(subStr(allTrim(aData[nRowArray, 40]), 1, 7)), 7)
	cCarteira := allTrim(aData[nRowArray, 22])

	if empty(cCarteira)
		cCarteira := allTrim(aData[nRowArray, 41])
	endIf

	cCarteira := strZero(val(cCarteira), 2)

	//Nosso número já gravado no título (reimpressão)
	cNNum := allTrim(aData[nRowArray, 10])

	if len(cNNum) == 18		//Gravado anteriormente com DV - convênio de 7 posições não possui DV
		cNNum := subStr(cNNum, 1, 17)
	endIf

	if !empty(cNNum) .and. len(cNNum) <> 17
		_Super:Add('AddBy' ;
			, 'Nosso Número inválido!' ;
			, 'E' ;
			, 'O Nosso Número <' + cNNum + '> gravado no título com ID <' + cValToChar(rowId_SE1) ;
			+ '> não possui 17 dígitos (Convênio + Sequencial). Verifique o campo E1_NUMBCO.')
		return
	endIf

	if empty(cNNum)		//Primeira impressão do boleto - gera o nosso número
		if nTamNumBco < 17
			_Super:Add('AddBy' ;
				, 'Tamanho do campo E1_NUMBCO insuficiente!' ;
				, 'E' ;
				, 'O Nosso Número do Banco do Brasil (convênio de 7 posições) possui 17 dígitos ' ;
				+ 'e o campo E1_NUMBCO possui <' + cValToChar(nTamNumBco) + '> posições. ' ;
				+ 'Ajuste o tamanho do campo no dicionário de dados.')
			return
		endIf

		if empty(val(cConvenio))
			_Super:Add('AddBy' ;
				, 'Convênio não informado!' ;
				, 'E' ;
				, 'O código do convênio (EE_CODEMP) não foi informado no parâmetro de banco ' ;
				+ 'com ID <' + cValToChar(nRowId_SEE) + '>. (SEE)')
			return
		endIf

		//Obtem o próximo número e grava na faixa (SEE)
		cNNum := cConvenio + '000' + _Super:NextNossoNumero(7)

		if _Super:HasErrors()
			return
		endIf
	endIf

	//Preparação do campo livre
	cFree := '000000' + cNNum + cCarteira

	//Preparação do código de barras e linha digitável
	cCodBarra := _Super:CreateBarCode(cFree)		//Montagem do código de barras
	cLinDigit := _Super:CreateLine(cCodBarra)		//Montagem da linha digitável

	cLinhaSE1 := strTran(cLinDigit, '.', '')
	cLinhaSE1 := strTran(cLinhaSE1, ' ', '')

	//Grava especializações no array aData para retorno
	aData[nRowArray,  1] += '-9'
	aData[nRowArray, 10] := cNNum
	aData[nRowArray, 32] := cLinDigit
	aData[nRowArray, 33] := cCodBarra
	aData[nRowArray, 34] := cNNum
	aData[nRowArray, 49] := cLinhaSE1
	//TÉRMINO dos tratamentos especializados para o Banco

	_Super:SetArray(aData)			//Devolve conteúdo especializado para a classe pai
return
