/*
 Programa.: tcBco422.prw
 Tipo.....: Classe 
 Autor....: Odair Batista
 Data.....: 25/01/2018
 Descrição: Classe especializada para impressão de boleto bancário do Banco do Safra (422) 
 Notas....: Os método da classe pai podem ser especializados na classe filho se houver necessidade 
 		    de definir padrões diferentes para cada banco, como por exemplo: layout, geração de 
		    código de barras e geração de linha digitável.  


 Autor....: William Campana
 Data.....: 03/08/2020
 Descrição: Classe especializada para impressão de boleto bancário do Banco do Safra (422) 
 Notas....: Alterações das mensagens no corpo do boleto conforme solicitação: 12623 
 
*/

#include "totvs.ch"
#include "protheus.ch"
#include "topConn.ch"
#include "rptDef.ch"
#include "fwPrintSetup.ch"

#define CRLF chr(13) + chr(10)


user function tcBco422()
return .t. 


/*/{Protheus.doc} tcBco422
Classe principal da classe tcBco422
@author Odair Batista - TOTVS Unidade Londrina
@since 25/01/2018
@version 1.0
@type class
/*/
class tcBco422 from tcBoleto
	data cClassName as string hidden
	data cBcoCor    as string hidden
	
	method New() constructor
	method ClassName()
	method Destroy(oObj)

	method SetCorrespondente(cBcoCor)
	
	method GetCorrespondente()
	
	method AddBy(rowId_SE1)
endClass               

                   
/*/{Protheus.doc} tcBco422:New
Método construtor da classe tcBco422
@author Odair Batista - TOTVS Unidade Londrina
@since 25/01/2018
@version 1.0                        
@type constructor
@example
local oBoleto := tcBco422():New()
/*/
method New() class tcBco422
	_Super:New()
	
	::cClassName := "tcBco422"
	::cBcoCor	 := ''
return

           
 /*/{Protheus.doc} tcBco422:ClassName
Método responsável por retornar o nome da classe
@author Odair Batista - TOTVS Unidade Londrina
@since 25/01/2018
@version 1.0
@type method     
@return caractere, retorna o nome da classe
/*/
method ClassName() class tcBco422
return ::cClassName


 /*/{Protheus.doc} tcBco422:Destroy
Método destrutor do objeto, responsável pela desalocação da memória
@author Odair Batista - TOTVS Unidade Londrina
@since 25/01/2018
@version 1.0
@type method     
/*/  
method Destroy(oObj as object) class tcBco422    
	freeObj(oObj)	       
return


 /*/{Protheus.doc} tcBco422:SetCorrespondente
Método para informar qual o banco correspondente
@author Odair Batista - TOTVS Unidade Londrina
@since 01/02/2018
@version 1.0
@type method
@param cBcoCor, caracter, Número do banco correspondente      
/*/  
method SetCorrespondente(cBcoCor) class tcBco422    
	::cBcoCor := cBcoCor	       
return


 /*/{Protheus.doc} tcBco422:GetCorrespondente
Método para retornar qual o banco correspondente
@author Odair Batista - TOTVS Unidade Londrina
@since 01/02/2018
@version 1.0
@type method     
/*/  
method GetCorrespondente() class tcBco422    
return(::cBcoCor)


/*/{Protheus.doc} tcBoleto:AddBy
Método para alimentar o array com dados básicos do título para emissão do boleto   
@author Odair Batista - TOTVS Unidade Londrina
@since 25/01/2018
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
method AddBy(rowId_SE1) class tcBco422
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
	local cDigCC     := ''
	local cFree      := ''
	local aInfBco    := {}
	
	_Super:AddBy(rowId_SE1)			    //Executa o método da classe pai populando os dados padrões

	nRowId_SEE := _Super:GetRowId()		//Obtém o Recno da tabela SEE
	aData      := _Super:GetArray()		//Obtém conteúdo carregado pela classe pai
	nRowArray  := _Super:GetRowArray()	//Obtém o número da linha no array aData

	dbSelectArea('SEE')
	SEE->(dbGoTo(nRowId_SEE))
	
	if SEE->(eof())
		return
	endIf

	//INÍCIO dos tratamentos especializados para o Banco
	if ::cBcoCor == '237'	//Padrão Bradesco
		/*
		Composição do campo livre
		=========================
		Posição  Tamanho  Formato    Conteúdo
		-------  -------  ---------  --------				
	    20 a 23  04       9(4)       Agência Beneficiária (Sem o digito verificador, completar com zeros a esquerda quando necessário)
	    24 a 25  02       9(2)       Carteira
	    26 a 36  11       9(11)      Número do Nosso Número (Sem o digito verificador)
	    37 a 43  07       9(7)       Conta do Beneficiário (Sem o digito verificador, completar com zeros a esquerda quando necessário)
	    44 a 44  01       9(1)       Zero
		*/
		
   	    // Beneficiário
//        aData[nRowArray, 12] += ' - '  + aData[nRowArray, 44]	
	
		//Composição para nosso número e campo livre
		cNumAge := strZero(val(aData[1, 6]), 4) 
		cNumCC  := strZero(val(aData[1, 8]), 7) 
			
		//Preparação do nosso número	
		cNNum    := alltrim(aData[nRowArray, 10])
		cNNumDig := subStr(cNNum, len(cNNum), 1)
		cNNum    := subStr(cNNum, 1, (len(cNNum) - 1))
			
		if empty(cNNum)		//Se ainda não foi gerado nosso número - primeira impressão do boleto
			//Obtem o prefixo para o nosso número - tipo da carteira
			cNNumPre := strZero(val(aData[nRowArray, 41]), 2)
		
			//Obtem o próximo número e grava na faixa (SEE) com a quantidade de dígitos informado
			cNNum := cNNumPre + _Super:NextNossoNumero(9)
	
			//Calculo do dígito verificador do nosso número
			cNNumDig := _Super:CalcMod11(cNNum, 2, 7, 'P')
		endIf
	
		//Geração da composição para impressão
		cNNumComp := subStr(cNNum, 1, 2) + '/' + allTrim(subStr(cNNum, 3, 9)) + '-' + cNNumDig   
	
		//Preparação do campo livre
		cFree := cNumAge + cNNum + cNumCC + '0'
		   
		aData[nRowArray, 35] := aData[nRowArray, 12]
		aData[nRowArray, 11] := aData[nRowArray, 1]
		aData[nRowArray, 12] := aData[nRowArray, 2]
		aData[nRowArray,  1] := '237-2'
		aData[nRowArray,  2] := 'BANCO BRADESCO SA'
		aData[nRowArray,  3] := 'system\tcImage\banco237.jpg'
		aData[nRowArray,  5] := '237'
		
		aInfBco    := aData[1, 14]
		//aInfBco[1] := 'ATÉ O VENCIMENTO, PREFERENCIALMENTE NO BANCO BRADESCO SA' 	
		//aInfBco[2] := 'APÓS O VENCIMENTO, SOMENTE NO BANCO BRADESCO SA'
    	aInfBco[1] := 'DEPOSITO BANCÁRIO NÃO EFETUA QUITAÇÃO DO BOLETO'
	    aInfBco[2] := 'PROTESTAR NO 6º DIA ÚTIL APÓS O VENCIMENTO'
	    aInfBco[3] := ''
	    aInfBco[4] := 'JUROS AO DIA DE R$ ' + transform((aData[1, 21] * 0.0026666), '@E 999,999.99')
	    aInfBco[5] := ''
	    aInfBco[6] := ''
	    aInfBco[7] := ''	    
		
		aData[1, 14] := aInfBco
	else		//Padrão Safra
		/*
		Composição do campo livre
		=========================
		Posição  Tamanho  Formato    Conteúdo
		-------  -------  ---------  --------				
	    20 a 20  01       9(1)       7 = Dígito do Bco Safra
	    21 a 25  05       9(5)       Agência  do  cliente
	    26 a 34  09       9(9)       Nº da conta
	    35 a 43  09       9(9)       Nosso Número
	    44 a 44  01       9(1)       2 = Cobrança registrada
		*/
		
		// Alteração Dados Especificos
		aData[nRowArray, 11] := strZero(val(allTrim(aData[nRowArray, 6])), 5) + '/' + strZero(val(allTrim(aData[nRowArray, 8]) + allTrim(aData[nRowArray, 9])), 9)
		aData[nRowArray, 43] := 'Pagador'
	
		//Composição para nosso número e campo livre
		cNumAge   := subStr(allTrim(aData[nRowArray, 6]), 1, 5)
		cNumAge   := strZero(val(cNumAge), 5) 
		cNumCC    := subStr(allTrim(aData[nRowArray, 8]), 1, 9)
		cNumCC    := strZero(val(cNumCC), 8) 
		cDigCC    := aData[nRowArray, 9]
			
		//Preparação do nosso número	
		cNNum      := alltrim(aData[nRowArray, 10])
		cNNumDig   := subStr(cNNum, len(cNNum), 1)
		cNNum      := subStr(cNNum, 1, (len(cNNum) - 1))
			
		if empty(cNNum)		//Se aWIinda não foi gerado nosso número - primeira impressão do boleto
			//Obtem o prefixo para o nosso número - vazio
			cNNumPre := ''
			
			//Obtem o próximo número e grava na faixa (SEE) com a quantidade de dígitos informado
			cNNum := cNNumPre + _Super:NextNossoNumero(8)
	
			//Calculo do dígito verificador do nosso número 
			cNNumDig := _Super:CalcMod11(cNNum, 2, 9, '')
		endIf
	
		//Geração da composição para impressão
		//cNNum     := subStr(cNNum, 2, len(cNNum))
		cNNumComp := cNNum + '-' + cNNumDig  
	
		//Preparação do campo livre
		cFree := '7' + cNumAge + cNumCC + cDigCC + cNNum + cNNumDig + '2'
		   
		aData[nRowArray,  1] += '-7'
		
		aInfBco      := aData[1, 14]
		aInfBco[1]   := 'PROTESTAR NO 6º DIA ÚTIL APÓS O VENCIMENTO'
		aInfBco[2]   := ''
		aInfBco[3]   := 'ESTE BOLETO REPRESENTA DUPLICATA CEDIDA FIDUCIARIAMENTE AO BANCO SAFRA S/A, '
		aInfBco[4]   := 'FICANDO VEDADO O PAGAMENTO DE QUALQUER OUTRA FORMA QUE NÃO ATRAVÉS DO PRESENTE BOLETO.'
		aInfBco[5]   := ''
		aInfBco[6]   := 'JUROS AO DIA DE R$ ' + transform((aData[1, 21] * 0.0026666), '@E 999,999.99')
		ainfBco[7]   := '' 
		aData[1, 14] := aInfBco
	endIf
	
	//Preparação do código de barras e linha digitável
	cCodBarra := _Super:CreateBarCode(cFree)		//Montagem do código de barras
	cLinDigit := _Super:CreateLine(cCodBarra)		//Montagem da linha digitável	

	//Grava especializações no array aData para retorno 	
	aData[nRowArray, 10] := cNNum + cNNumDig
	aData[nRowArray, 32] := cLinDigit
	aData[nRowArray, 33] := cCodBarra
	aData[nRowArray, 34] := cNNumComp
	//TÉRMINO dos tratamentos especializados para o Banco
	
	_Super:SetArray(aData)			//Devolve conteúdo especializado para a classe pai
return
