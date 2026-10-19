/*
Programa.: tcBco084.prw
Tipo.....: Classe 
Autor....: william.campana
Data.....: 14/07/2022
Descrição: Classe especializada para impressão de boleto bancário do Banco Uniprime (084)
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


user function tcBco084()
return .t. 


/*/{Protheus.doc} tcBco084
Classe principal da classe tcBco084
@author william.campana
@since 14/07/2022
@version 1.0
@type class
/*/
class tcBco084 from tcBoleto
	data cClassName as string hidden
	data cBcoCor    as string hidden
	
	method New() constructor
	method ClassName()
	method Destroy(oObj)
	
	method SetCorrespondente(cBcoCor)
	
	method GetCorrespondente()
	method CalcMod11U(cCode, nInitFactor, nLimitFactor, cChrCode)
	method AddBy(rowId_SE1)
endClass               

                   
/*/{Protheus.doc} tcBco084:New
Método construtor da classe tcBco084
@author william.campana
@since 14/07/2022
@version 1.0                        
@type constructor
@example
local oBoleto := tcBco084():New()
/*/
method New() class tcBco084
	_Super:New()
	
	::cClassName := "tcBco084"
	::cBcoCor	 := ''
return

           
 /*/{Protheus.doc} tcBco084:ClassName
Método responsável por retornar o nome da classe
@author william.campana
@since 14/07/2022
@version 1.0
@type method     
@return caractere, retorna o nome da classe
/*/
method ClassName() class tcBco084
return ::cClassName


 /*/{Protheus.doc} tcBco084:Destroy
Método destrutor do objeto, responsável pela desalocação da memória
@author william.campana
@since 14/07/2022
@version 1.0
@type method     
/*/  
method Destroy(oObj as object) class tcBco084    
	freeObj(oObj)	       
return


 /*/{Protheus.doc} tcBco084:SetCorrespondente
Método para informar qual o banco correspondente
@author william.campana
@since 14/07/2022
@version 1.0
@type method
@param cBcoCor, caracter, Número do banco correspondente      
/*/  
method SetCorrespondente(cBcoCor) class tcBco084    
	::cBcoCor := cBcoCor	       
return


 /*/{Protheus.doc} tcBco084:GetCorrespondente
Método para retornar qual o banco correspondente
@author william.campana
@since 14/07/2022
@version 1.0
@type method     
/*/  
method GetCorrespondente() class tcBco084    
return(::cBcoCor)


/*/{Protheus.doc} tcBoleto:AddBy
Método para alimentar o array com dados básicos do título para emissão do boleto   
@author william.campana
@since 14/07/2022
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
method AddBy(rowId_SE1) class tcBco084
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
	local cNumCart   := ''
	local cFree      := ''
	
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
			, 'Não foi possível carregar os dados do título com ID <' + cValToChar(rowId_SE1) + '>. (tcBco084)')
		return
	endIf

	dbSelectArea('SEE')
	SEE->(dbGoTo(nRowId_SEE))
	
	if SEE->(eof())
		_Super:Add('AddBy' ;
			, 'Parâmetro de Banco/Agência/Conta/Sub-Conta não encontrado!' ;
			, 'E' ;
			, 'O registro <' + cValToChar(nRowId_SEE) + '> da tabela SEE não foi encontrado. (tcBco084)')
		return
	endIf

	//INÍCIO dos tratamentos especializados para o Banco
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

	//Composição para nosso número e campo livre
	cNumAge  := strZero(val(aData[nRowArray, 6]), 4) 
	cNumCC   := strZero(val(aData[nRowArray, 8]), 7) 
	cNumCart := strZero(val(aData[nRowArray, 22]), 2) 
		
	//Preparação do nosso número	
	cNNum    := alltrim(aData[nRowArray, 10])
	cNNumDig := subStr(cNNum, len(cNNum), 1)
	cNNum    := subStr(cNNum, 1, (len(cNNum) - 1))
		
	if empty(cNNum)		//Se ainda não foi gerado nosso número - primeira impressão do boleto
		//Obtem o prefixo para o nosso número - tipo da carteira
		cNNumPre := strZero(val(aData[nRowArray, 22]), 2)
	
		//Obtem o próximo número e grava na faixa (SEE) com a quantidade de dígitos informado
		cNNum := cNNumPre + _Super:NextNossoNumero(11)

		//Calculo do dígito verificador do nosso número
		cNNumDig := ::CalcMod11U(cNNum, 2, 7, 'P')
	endIf

	//Geração da composição para impressão
	cNNumComp := subStr(cNNum, 1, 2) + '/' + allTrim(subStr(cNNum, 3, 11)) + '-' + cNNumDig   

	//Preparação do campo livre
	cFree := cNumAge + cNumCart + substr(cNNum, 3, 11) + cNumCC + '0'

	//Preparação do código de barras e linha digitável
	cCodBarra := _Super:CreateBarCode(cFree)		//Montagem do código de barras
	cLinDigit := _Super:CreateLine(cCodBarra)		//Montagem da linha digitável	

	//Grava especializações no array aData para retorno 	
	aData[nRowArray,  1] += '-1'
	aData[nRowArray, 10] := cNNum + cNNumDig
	aData[nRowArray, 11] := allTrim(aData[nRowArray, 6]) + '-' + aData[nRowArray, 7] + '/' + cNumCC + '-' + aData[nRowArray, 9]
	aData[nRowArray, 06] := "01.618.551/0001-86"
	aData[nRowArray, 12] := "HYDRONORTH S/A - " + aData[nRowArray, 06]
	aData[nRowArray, 20] := getFrmtBco(rowId_SE1)
	aData[nRowArray, 32] := cLinDigit
	aData[nRowArray, 33] := cCodBarra
	aData[nRowArray, 34] := cNNumComp
	aData[nRowArray, 43] := "Pagador"
	aData[nRowArray, 46] := "ROD MELLO PEIXOTO, 159"
   
	//TÉRMINO dos tratamentos especializados para o Banco
	

	//O nosso número precisa caber no campo do título, senão é truncado ao gravar
	if len(allTrim(aData[nRowArray, 10])) > len(SE1->E1_NUMBCO)
		_Super:Add('AddBy' ;
			, 'Tamanho do campo E1_NUMBCO insuficiente!' ;
			, 'E' ;
			, 'O Nosso Número <' + allTrim(aData[nRowArray, 10]) + '> possui <' ;
			+ cValToChar(len(allTrim(aData[nRowArray, 10]))) + '> posições e o campo E1_NUMBCO possui <' ;
			+ cValToChar(len(SE1->E1_NUMBCO)) + '>. Ajuste o tamanho do campo no dicionário de dados.')
		return
	endIf
	_Super:SetArray(aData)			//Devolve conteúdo especializado para a classe pai
return



/*/{Protheus.doc} CalcMod11U
Método para calcular o dídigito verificador baseado em módulo 11  
@author william.campana
@since 14/07/2022
@version 1.0                        
@type method
@param  cCode 	    , caracter, Código para calculo do dígito
@param  nInitFactor , inteiro , Número initial do fator de multiplicação
@param  nLimitFactor, inteiro , Número limite do fator de multiplicação
@param  cChrCode    , caracter, Carater para composição de dígito
@return cDigit		, caractet, Dígito verificador do calculo de módulo 11
@example
::CalcMod11U(cCode, 2, 7, '')
/*/
method CalcMod11U(cCode, nInitFactor, nLimitFactor, cChrCode) class tcBco084
    local nAccum   := 0
    local nResto   := 0
    local nPosicao := 0
    local nNumero  := ''
    local nFactor  := 0
    local cDigit   := ''
    
	default nInitFactor  := 2
	default nLimitFactor := 7

    if nInitFactor < 2 
       nInitFactor := 2
	endIf
	
    if nLimitFactor > 7
       nLimitFactor := 7
	endIf
	
	nFactor := nInitFactor
	
	for nPosicao := len(cCode) to 1 step -1
        nNumero  := subStr(cCode, nPosicao, 1)
        nAccum   += (val(nNumero) * nFactor)
        nFactor  := iIf(nFactor < nLimitFactor, (nFactor + 1), nInitFactor)
	next nPosicao

   nResto := round(mod(nAccum, 11), 0)

   if (nResto == 0)
      cDigit := "0"
   elseIf (nResto == 1)
      cDigit := cChrCode
   else
      cDigit := cValToChar(11 - nResto)
   endIf

return(cDigit) 


/*/{Protheus.doc} getFrmtBco
Formatar numero do documento conforme orientação do banco
@type function
@version  1.0
@author william.campana
@since 19/07/2022
@param rowID_SE1, numeric, recno do registro SE1
@return character, conteudo formatado
/*/
static function getFrmtBco(rowID_SE1)
   local cReturn as character
   local aAreaSE1 as array
   
   aAreaSE1 := fwGetArea("SE1")

   dbSelectArea("SE1")
   SE1->(dbGoTo(rowID_SE1))

   cReturn := right(SE1->E1_NUM, 7) + "/" + right(SE1->E1_PARCELA, 2)

   fwRestArea(aAreaSE1)

return (cReturn)
