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
	local cNNumPre   := ''
	local cNNum      := ''
	local cNNumDig   := ''
	local cNNumComp  := ''
	local cLinDigit  := ''
	local cCodBarra  := ''
	local cNumAge    := ''
	local cNumCC     := ''
	local cTpCart    := ''
	local cFree      := ''
	local cLinhaSE1  := ''
	
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
	cNumAge := strZero(val(aData[1, 6]), 4) 
	cNumCC  := strZero(val(aData[1, 8]), 8) 
	cTpCart := strZero(val(aData[1, 41]), 2) 
		
	//Preparação do nosso número	
	If alltrim(aData[nRowArray, 1]) == "001" //Victor Ramon
		cNNum    := alltrim(aData[nRowArray, 10])
		cNrNs    := alltrim(aData[nRowArray, 10])		
		cNNumDig := subStr(cNNum, len(cNNum), 1)
		//cNNum    := subStr(cNNum, 1, (len(cNNum) - 1))	
	Else
		cNNum    := alltrim(aData[nRowArray, 10])
		cNNumDig := subStr(cNNum, len(cNNum), 1)
		cNNum    := subStr(cNNum, 1, (len(cNNum) - 1))
	EndIf
		
	if empty(cNNum)		//Se ainda não foi gerado nosso número - primeira impressão do boleto
		//Obtem o úmero do convênio BANCO DO BRASIL
		If alltrim(aData[nRowArray, 1]) == "001" //Victor Ramon
			cNNumPre := strZero(val(subStr(aData[nRowArray, 40], 1, 7)), 7)
		Else
			cNNumPre := strZero(val(subStr(aData[nRowArray, 40], 1, 4)), 4)
		EndIf
	
		//Obtem o próximo número e grava na faixa (SEE) com a quantidade de dígitos informado
		If alltrim(aData[nRowArray, 1]) == "001" //Victor Ramon
			cNNum := cNNumPre + "000" +_Super:NextNossoNumero(7) 
		Else
			cNNum := cNNumPre + _Super:NextNossoNumero(7) 
		EndIf

		//Calculo do dígito verificador do nosso número
		cNNumDig := _Super:CalcMod11(cNNum, 2, 9, 'X')
	endIf

	//Geração da composição para impressão
	cNNumComp := cNNum //+ '-' + cNNumDig  

	If empty(cNrNs)// Primeira passada ainda não tem nosso numero gravado na SE1 por isso pego após gerar
		cNrNs := cNNum //+ cNNumDig 
	EndIf

	//Preparação do campo livre
	If alltrim(aData[nRowArray, 1]) == "001" //Victor Ramon
	   cFree := "000000" + cNrNs + cTpCart   
	  //cFree := "000000" + cNNum + cNumAge + cNumCC + cTpCart    
	Else
	   cFree := cNNum + cNumAge + cNumCC + cTpCart   
	EndIf	

	//Preparação do código de barras e linha digitável
	cCodBarra := _Super:CreateBarCode(cFree)		//Montagem do código de barras
    if alltrim(aData[nRowArray, 1]) == "001" //Victor Ramon
	    //cCodbr    := SUBSTR( cCodBarra,1,42) + "17" + SUBSTR( cCodBarra,45,5)
		cLinDigit := _Super:CreateLine(cCodBarra)		//Montagem da linha digitável	
	else
	    cLinDigit := _Super:CreateLine(cCodBarra)		//Montagem da linha digitável	
	endIf	
	
	
	cLinhaSE1 := StrTran(cLinDigit,'.','')
	cLinhaSE1 := StrTran(cLinhaSE1,' ','')

	//Grava especializações no array aData para retorno 	
	aData[nRowArray,  1] += '-9'
	aData[nRowArray, 10] := cNNum + cNNumDig
	aData[nRowArray, 32] := cLinDigit
	aData[nRowArray, 33] := cCodBarra
	aData[nRowArray, 34] := cNNumComp
	aData[nRowArray, 49] := cLinhaSE1
	//TÉRMINO dos tratamentos especializados para o Banco
	
	_Super:SetArray(aData)			//Devolve conteúdo especializado para a classe pai
return
