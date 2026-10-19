/*
Programa.: tcBco637.prw
Tipo.....: Classe 
Autor....: William Campana
Data.....: 12/11/2018
Descrição: Classe especializada para impressão de boleto bancário do Banco do Sofisa (637) 
Notas....: Os método da classe pai podem ser especializados na classe filho se houver necessidade 
		   de definir padrões diferentes para cada banco, como por exemplo: layout, geração de 
		   código de barras e geração de linha digitável.  
		   O boleto deverá sair como se fosse o Banco Itau.
*/

#include "totvs.ch"
#include "protheus.ch"
#include "topConn.ch"
#include "rptDef.ch"
#include "fwPrintSetup.ch"

#define CRLF chr(13) + chr(10)


user function tcBco637()
return .t.


/*/{Protheus.doc} tcBco637
Classe principal da classe tcBco637
@author William Campana
@since 12/11/2018
@version 1.0
@type class
/*/
	class tcBco637 from tcBoleto
		data cClassName as string hidden
		data cBcoCor    as string hidden

		method New() constructor
		method ClassName()
		method Destroy(oObj)

		method SetCorrespondente(cBcoCor)

		method GetCorrespondente()

		method AddBy(rowId_SE1)

		//method CalcMod11(cCode, nInitFactor, nLimitFactor, cChrCode)

		//method CreateBarCode(cFree)
		//method CreateLine(cBarCode)
	endClass


/*/{Protheus.doc} tcBco637:New
Método construtor da classe tcBco637
@author William Campana
@since 12/11/2018
@version 1.0                        
@type constructor
@example
local oBoleto := tcBco637():New()
/*/
method New() class tcBco637
	_Super:New()

	::cClassName := "tcBco637"
	::cBcoCor	 := ''
return


 /*/{Protheus.doc} tcBco637:ClassName
	Método responsável por retornar o nome da classe
	@author William Campana
	@since 12/11/2018
	@version 1.0
	@type method
	@return caractere, retorna o nome da classe
/*/
method ClassName() class tcBco637
return ::cClassName


 /*/{Protheus.doc} tcBco033:Destroy
	Método destrutor do objeto, responsável pela desalocação da memória
	@author William Campana
	@since 12/11/2018
	@version 1.0
	@type method
/*/  
method Destroy(oObj as object) class tcBco637
	freeObj(oObj)
return


 /*/{Protheus.doc} tcBco637:SetCorrespondente
	Método para informar qual o banco correspondente
	@author William Campana
	@since 01/02/2018
	@version 1.0
	@type method
	@param cBcoCor, caracter, Número do banco correspondente
/*/  
method SetCorrespondente(cBcoCor) class tcBco637
	::cBcoCor := cBcoCor
return


 /*/{Protheus.doc} tcBco637:GetCorrespondente
	Método para retornar qual o banco correspondente
	@author William Campana
	@since 01/02/2018
	@version 1.0
	@type method
/*/  
method GetCorrespondente() class tcBco637
return(::cBcoCor)


/*/{Protheus.doc} tcBoleto:AddBy
Método para alimentar o array com dados básicos do título para emissão do boleto   
@author William Campana
@since 12/11/2018
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
method AddBy(rowId_SE1) class tcBco637
	local nRowId_SEE   := 0
	local cNNumPre     := ''
	local cNNum        := ''
	local cNNumDig     := ''
	local cNNumComp    := ''
	local cLinDigit    := ''
	local cCodBarra    := ''
	local cNumAge      := ''
	local cNumCC       := ''
	local cNumCart     := ''
	local cFree        := ''
	local cNumCCDig  := ''

	private nRowArray  := 0
	private aData      := {}

	_Super:AddBy(rowId_SE1)			//Executa o método da classe pai populando os dados padrões

	nRowId_SEE := _Super:GetRowId()		//Obtém o Recno da tabela SEE
	aData      := _Super:GetArray()		//Obtém conteúdo carregado pela classe pai
	nRowArray  := _Super:GetRowArray()	//Obtém o número da linha no array aData

	// Banco Sofisa - Calcular tudo como se fosse Santander.

	dbSelectArea('SEE')
	SEE->(dbGoTo(nRowId_SEE))

	if SEE->(eof())
		return
	endIf

	//INÍCIO dos tratamentos especializados para o Banco
	aData[nRowArray,  1] := '341'
	aData[nRowArray, 11] := '02205-3'
	aData[nRowArray, 22] := '109'

	/*
	Composição do campo livre
	=========================
	Posição  Tamanho  Formato    Conteúdo
	
	-------  -------  ---------  --------				
    20 a 20  01       9(1)       9 = Dígito do Bco Santander
    21 a 27  07       9(7)       Código do Cedente
    28 a 40  13       9(13)      Nosso Número com dígito
    41 a 41  01       9(1)       IOF – Seguradoras - Demais clientes = zero
    42 a 44  03       9(3)       (101- Cobrança simples c/ Reg, 102- Cobrança simples s/ Reg)
	*/

	//Composição para nosso número e campo livre
	cNumAge   := strZero(val(aData[1, 6]), 4) 
	cNumCC    := strZero(val(aData[1, 9]), 9)
	cNumCCDig := strZero(val(aData[1, 9]), 1) 
	cNumCart  := strZero(val(aData[1, 22]), 3)	//Carteira

	//Preparação do nosso número
	cNNum    := alltrim(aData[nRowArray, 10])
	cNNumDig := subStr(cNNum, len(cNNum), 1)
	cNNum    := subStr(cNNum, 1, (len(cNNum) - 1))

	if empty(cNNum)		//Se ainda não foi gerado nosso número - primeira impressão do boleto
		//Obtem o prefixo para o nosso número - fixo 00000
		cNNumPre := cNumAge + cNumCC + cNumCart

		//Obtem o próximo número e grava na faixa (SEE) com a quantidade de dígitos informado
		cNNum := cNNumPre + _Super:NextNossoNumero(12)

		//Calculo do dígito verificador do nosso número
		//cNNumDig := _Super:CalcMod11(cNNum, 2, 9, '')
		cNNumDig := _Super:CalcMod10(cNNum)
	endIf


//Geração da composição para impressão
	cNNumComp := cNumCart + '/' + allTrim(subStr(cNNum, 13, 8)) + '-' + cNNumDig

	//Preparação do campo livre
	cFree := cNumCart + allTrim(subStr(cNNum, 13, 8)) + cNNumDig + cNumAge + cNumCC + cNumCCDig + '000'

	//Preparação do código de barras e linha digitável
	cCodBarra := _Super:CreateBarCode(cFree)		//Montagem do código de barras
	cLinDigit := _Super:CreateLine(cCodBarra)		//Montagem da linha digitável

	//Grava especializações no array aData para retorno
	//aData[nRowArray,  1] += '-7'
	//aData[nRowArray, 10] := cNNum + cNNumDig
	//aData[nRowArray, 32] := cLinDigit
	//aData[nRowArray, 33] := cCodBarra
	//aData[nRowArray, 34] := cNNumComp
	//TÉRMINO dos tratamentos especializados para o Banco


	//Grava especializações no array aData para retorno
	aData[nRowArray,  1] += '-7'
	aData[nRowArray,  4] := 'PAGAR PREFERENCIALMENTE NO BANCO SANTANDER'
	aData[nRowArray, 10] := cNNum + cNNumDig
	aData[nRowArray, 11] := '1248/02205-3'
	aData[nRowArray, 12] := 'BANCO SOFISA S/A - 60.889.128/0001-80'
	aData[nRowArray, 32] := cLinDigit
	aData[nRowArray, 33] := cCodBarra
	aData[nRowArray, 34] := cNNumComp
	aData[nRowArray, 35] := 'HYDRONORTH S/A - 01.618.551/0001-86'
	//TÉRMINO dos tratamentos especializados para o Banco

	_Super:SetArray(aData)			//Devolve conteúdo especializado para a classe pai
return


/*/{Protheus.doc} CalcMod11
Método para calcular o digito verificador baseado em módulo 11  
@author William Campana
@since 12/11/2018
@version 1.0                        
@type method
@param  cCode 	    , caracter, Código para calculo do dígito
@param  nInitFactor , inteiro , Número initial do fator de multiplicação
@param  nLimitFactor, inteiro , Número limite do fator de multiplicação
@param  cChrCode    , caracter, Carater para composição de dígito
@return cDigit		, caractet, Dígito verificador do calculo de módulo 10
@example
CalcMod11(cCode, 2, 9, '')
/
method CalcMod11(cCode, nInitFactor, nLimitFactor, cChrCode) class tcBco637
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

	if cChrCode <> 'DAC-BarCode'
		if (nResto <= 1)
			nResto := 0
		elseIf (nResto = 10)
			nResto := 1
		endIf
	endIf

	if nResto > 1
		nResto := (11 - nResto)
	endIf

	cDigit := cValToChar(nResto)
return(cDigit)

*/
/*/{Protheus.doc} CreateBarCode
Método para geração do código de barras  
Retirado da Classe Pai devido a Diferenca no calculo do Digito Verificador.
@author William Campana
@since 13/11/2018
@version 1.0                        
@type method
@param  cFree   , caracter, Campo Livre
@return cBarCode, caracter, Código de barras
@example
cBarCode := CreateBarCode(cDigCode)
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
/
method CreateBarCode(cFree) class tcBco637
	local cFatorVcto := strZero((aData[nRowArray, 18] - cToD('07/10/1997')), 4)
	local cCodBco    := strZero(val(aData[nRowArray, 1]), 3)
	local cValor     := strZero((aData[nRowArray, 21] * 100), 10)
	local cBarCode   := cCodBco + '9' + cFatorVcto + cValor + cFree

	//Acrescenta dígito ao código de barras
	cBarCode := subStr(cBarCode, 1, 4) ;
		+ _Super:CalcMod11(cBarCode, 2, 9, 'DAC-BarCode') ;
		+ subStr(cBarCode, 5, 44)
return(cBarCode)

*/
/*/{Protheus.doc} CreateLine
Método para geração da linha digitável  
@author William Campana
@since 13/11/2018
@version 1.0                        
@type method
@param  cBarCode  , caracter, Código de barras
@return cDigitLine, caracter, Linha digitável gerada
@example
cLinhaDigitavel := CreateLine(cBarCode)
/
method CreateLine(cBarCode) class tcBco637
	cDigitLine := ""
	cCodeCut   := ""

	//Campo 1
	cCodeCut   := subStr(cBarCode, 1, 3) + subStr(cBarCode, 4, 1) + '9' + subStr(cBarCode, 21, 4)
	cDigitLine := subStr(cBarCode, 1, 3) + subStr(cBarCode, 4, 1) + '9' + subStr(cBarCode, 21, 4) ;
		+ '.' + _Super:CalcMod10(cCodeCut) + space(1)

	//Campo 2
	cCodeCut   := subStr(cBarCode, 25, 3) +  subStr(cBarCode, 28, 7)
	cDigitLine += cCodeCut + '.' + _Super:CalcMod10(cCodeCut) + space(1)

	//Campo 3
	cCodeCut   := subStr(cBarCode, 35, 6) + '0' + subStr(cBarCode, 42, 3)
	cDigitLine += cCodeCut + '.' + _Super:CalcMod10(cCodeCut) + space(1)

	//Campo 4
	cDigitLine += subStr(cBarCode, 5, 1) + space(1)

	//Campo 5
	cDigitLine += subStr(cBarCode, 6, 4) + subStr(cBarCode, 10, 10)
return(cDigitLine)
*/
