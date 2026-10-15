/*
Programa.: tcBco756.prw
Tipo.....: Classe 
Autor....: William Campana
Data.....: 10/09/2020
Descrição: Classe especializada para impressão de boleto bancário do Banco Sicoob (756) 
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


user function tcBco756()
return .t. 


/*/{Protheus.doc} tcBco756
Classe principal da classe tcBco246
@author William Campana
@since 10/09/2020
@version 1.0
@type class
/*/
class tcBco756 from tcBoleto
	data cClassName as string hidden
	data cBcoCor    as string hidden
	
	method New() constructor
	method ClassName()
	method Destroy(oObj)

	method SetCorrespondente(cBcoCor)
	
	method GetCorrespondente()
	
	method AddBy(rowId_SE1)
	
    method CreateBarCode(cFree)
    method CalcMod11(cCode)
	
endClass               

                   
/*/{Protheus.doc} tcBco756:New
Método construtor da classe tcBco756
@author William Campana
@since 10/09/2020
@version 1.0                        
@type constructor
@example
local oBoleto := tcBco756():New()
/*/
method New() class tcBco756
	_Super:New()
	
	::cClassName := "tcBco756"
	::cBcoCor	 := ''
return

           
 /*/{Protheus.doc} tcBco756:ClassName
Método responsável por retornar o nome da classe
@author William Campana
@since 10/09/2020
@version 1.0
@type method     
@return caractere, retorna o nome da classe
/*/
method ClassName() class tcBco756
return ::cClassName


 /*/{Protheus.doc} tcBco756:Destroy
Método destrutor do objeto, responsável pela desalocação da memória
@author William Campana
@since 10/09/2020
@version 1.0
@type method     
/*/  
method Destroy(oObj as object) class tcBco756    
	freeObj(oObj)	       
return


 /*/{Protheus.doc} tcBco756:SetCorrespondente
Método para informar qual o banco correspondente
@author William Campana
@since 10/09/2020
@version 1.0
@type method
@param cBcoCor, caracter, Número do banco correspondente      
/*/  
method SetCorrespondente(cBcoCor) class tcBco756
	::cBcoCor := cBcoCor	       
return


 /*/{Protheus.doc} tcBco756:GetCorrespondente
Método para retornar qual o banco correspondente
@author William Campana
@since 10/09/2020
@version 1.0
@type method     
/*/  
method GetCorrespondente() class tcBco756    
return(::cBcoCor)


/*/{Protheus.doc} tcBoleto:AddBy
Método para alimentar o array com dados básicos do título para emissão do boleto   
@author William Campana
@since 10/09/2020
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
method AddBy(rowId_SE1) class tcBco756
	local nRowId_SEE  := 0
	local cNNumPre    := ''
	local cNNum       := ''
	local cNNumDig    := ''
	local cNNumComp   := ''
	local cLinDigit   := ''
	local cCodBarra   := ''
	local cNumAge     := ''
	local cNumCC      := ''
	local cTpCart     := ''
	local cCodCart    := ''
	local cFree       := ''

	private nRowArray := 0
	private aData     := {}
	
	_Super:AddBy(rowId_SE1)			//Executa o método da classe pai populando os dados padrões

	nRowId_SEE := _Super:GetRowId()		//Obtém o Recno da tabela SEE
	aData      := _Super:GetArray()		//Obtém conteúdo carregado pela classe pai
	nRowArray  := _Super:GetRowArray()	//Obtém o número da linha no array aData

	dbSelectArea('SEE')
	SEE->(dbGoTo(nRowId_SEE))
	
	if SEE->(eof())
		return
	endIf

	//INÍCIO dos tratamentos especializados para o Banco
	/*
	Composição do campo livre
	=========================
	Posição  Tamanho  Formato    Conteúdo
	-------  -------  ---------  --------				
    20 a 30  11       9(11)      Convênio(4) + Nosso Número(7), sem DV
    31 a 34  04       9(4)       Número da Agência de Relacionamento, sem DV
    35 a 42  08       9(8)       Conta Corrente de Relacionamento, sem DV
    43 a 44  02       9(2)       Tipo de Carteira/Modalidade de Cobrança
	*/
	
	//Composição para nosso número e campo livre
	cNumAge  := strZero(val(aData[1, 6]), 4) 
	cNumCC   := strZero(val(aData[1, 8]), 8) 
	cTpCart  := strZero(val(aData[1, 41]), 2)
	cCodCart := allTrim(aData[1, 22])
		
	//Preparação do nosso número	
	cNNum    := alltrim(aData[nRowArray, 10])
	cNNumDig := subStr(cNNum, len(cNNum), 1)
	cNNum    := subStr(cNNum, 1, (len(cNNum) - 1))
		
	if empty(cNNum)		//Se ainda não foi gerado nosso número - primeira impressão do boleto
		//Obtem o prefixo para o nosso número - número do convênio
		cNNumPre := strZero(val(aData[nRowArray, 6]), 4) + strZero(val(aData[nRowArray, 40]), 10) 
	
		//Obtem o próximo número e grava na faixa (SEE) com a quantidade de dígitos informado
		cNNum := _Super:NextNossoNumero(7)

		//Calculo do dígito verificador do nosso número
		cNNumDig := ::CalcMod11(cNNumPre + cNNum)
	endIf

	//Geração da composição para impressão
	cNNumComp := cNNum + '-' + cNNumDig  

	//Preparação do campo livre
	cFree := cCodCart + cNumAge + cTpCart + strZero(val(aData[nRowArray, 40]), 7) + cNNum + cNNumDig + aData[nRowArray, 45]      

	//Preparação do código de barras e linha digitável
	cCodBarra := ::CreateBarCode(cFree)		        //Montagem do código de barras

	cLinDigit := _Super:CreateLine(cCodBarra)		//Montagem da linha digitável	

	//Grava especializações no array aData para retorno 	
	aData[nRowArray,  1] += '-0'
	aData[nRowArray, 10] := cNNum + cNNumDig
	aData[nRowArray, 11] := cNumAge + ' / ' + subStr(strZero(val(aData[nRowArray, 40]), 7), 1, 6) + '-' + subStr(strZero(val(aData[nRowArray, 40]), 7), 7, 1)
	aData[nRowArray, 12] := 'HYDRONORTH S/A - 01.618.551/0001-86'	  
	aData[nRowArray, 32] := cLinDigit
	aData[nRowArray, 33] := cCodBarra
	aData[nRowArray, 34] := cNNumComp
	//TÉRMINO dos tratamentos especializados para o Banco
	
	_Super:SetArray(aData)			//Devolve conteúdo especializado para a classe pai
return


/*/{Protheus.doc} tcBco756:CalcMod11
Método para calcular o dígito verificador   
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
method CalcMod11(cCode) class tcBco756
    local nAccum   := 0
    local nResto   := 0
    local nPosicao := 0
    local nNumero  := ''
    local cFactor  := '319731973197319731973'
    local cDigit   := ''
    
	for nPosicao := len(cCode) to 1 step -1
        nNumero  := subStr(cCode, nPosicao, 1)
        nAccum   += (val(nNumero) * val(subStr(cFactor, nPosicao, 1)))
	next nPosicao

    nResto = round(mod(nAccum, 11), 0)

    if nResto > 1 
       nResto := (11 - nResto)
    else 
       nResto := 0
	endIf
	
    cDigit := cValToChar(nResto)
return(cDigit)  



/*/{Protheus.doc} CreateBarCode
Método para geração do código de barras  
Retirado da Classe Pai devido a Diferenca no calculo do Digito Verificador.
@author William Campana
@since 11/09/2020
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
/*/
method CreateBarCode(cFree) class tcBco756
	local cFatorVcto := strZero(((aData[nRowArray, 18] - cToD('03/07/2000')) + 1000), 4)
	local cCodBco    := strZero(val(aData[nRowArray, 1]), 3)
	local cValor     := strZero((aData[nRowArray, 21] * 100), 10)
	local cBarCode   := cCodBco + '9' + cFatorVcto + cValor + cFree
	
	//Acrescenta dígito ao código de barras
	cBarCode := subStr(cBarCode, 1, 4) ;
				+ _Super:CalcMod11(cBarCode, 2, 9, 'DAC-BarCode') ;
				+ subStr(cBarCode, 5, 44)
return(cBarCode)              

