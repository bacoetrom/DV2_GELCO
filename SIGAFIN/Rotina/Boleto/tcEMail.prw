/*****************************************************************************************************
Autor....: Odair Batista
Data.....: 13 de novembro de 2015
Descrição: Classe para tratamento de EMail
******************************************************************************************************/

#include "totvs.ch"
#include "protheus.ch"
#include "rwmake.ch"
#include "ap5mail.ch"
                                                      
user function tcEMail()
return .t. 


/*/{Protheus.doc} tcEMail
Classe principal 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0
@type class
/*/
class tcEMail from LongClassName
	data cClassName as string hidden
	
	data cUser	     as string  hidden
	data cPasswd     as string  hidden
    data cServer     as string  hidden
    data nPort 	     as integer hidden
    data cFrom       as string  hidden             
    data cTo   	     as string  hidden 
    data cCc   	     as string  hidden 
    data cBcc        as string  hidden 
    data cSubject    as string  hidden 
    data cBody       as string  hidden 
    data aAttach     as array   hidden
    data nTimeout    as integer hidden
    data lShowToLog  as boolean hidden    
    data lDebug      as boolean hidden
    data nPriority   as integer hidden    
    data nSecurity   as integer hidden    
    data nProtocol   as integer hidden
    data cServerPath as string  hidden    
    data lAuth       as boolean hidden
    data nTypeFrom   as integer hidden
    data attachOnSrv as boolean hidden
    data cLastError  as string  hidden
	
	method New() constructor
	method ClassName()
	method Destroy(oObj)
	  
	method SetUser(cUser)
	method SetPassword(cPasswd)
	method SetServer(cServer)
	method SetPort(nPort)
	method SetFrom(cFrom)
	method SetTo(cTo)
	method SetCc(cCc)
	method SetBcc(cBcc)
	method SetSubject(cSubject)
	method SetBody(cBody)
	method SetTimeOut(nTimeOut)
	method SetPriority(nPriority)
	method SetSecurity(nSecurity)
	method SetProtocol(nProtocol)
	method SetShowToLog(lShowToLog)
	method SetDebug(lDebug)
	method SetServerPath(cServerPath)
	method SetAuth(lAuth)
	method SetAttachOnServer(attachOnSrv)
	  
	method GetUser()
	method GetPassword()
	method GetServer()
	method GetPort()
	method GetFrom()
	method GetTo()
	method GetCc()
	method GetBcc()
	method GetSubject()
	method GetBody()
	method GetTimeOut()
	method GetPriority()
	method GetSecurity()
	method GetProtocol()
	method IsShowToLog()
	method IsDebug()
	method GetServerPath()
	method IsAuth()
	method IsAttachOnServer()

	method GetNumAttach()
	method GetAttach(nNumAttach)
	
	method Attach(cAttach)
	method Send()
	method GetLastError()
endClass               

                   
/*/{Protheus.doc} tcEMail:New
Método construtor da classe tcEMail
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type constructor
@example
local oTcEMail := tcEMail():New()
@type method
/*/
method New() class tcEMail
	local oUser := nil

	::cClassName := "tcEMail"	
	
	::cServer     := superGetMV("MV_E_SERV", .f., "",)	//Endereço do servidor de EMail - Pode ser parametrizado no sistema    
	::nPort       := superGetMV("MV_E_PORT", .f., 0,)    //Porta de comunicação para envio do EMail - Pode ser parametrizado no sistema
	::cUser       := superGetMV("MV_E_USER", .f., "",)   //Usuário para autenticação - Pode ser parametrizado no sistema
	::cPasswd     := superGetMV("MV_E_PASS", .f., "",)   //Senha do usuário para autenticação - Pode ser parametrizado no sistema
	::nTypeFrom   := superGetMV("MV_E_TYPE", .f., "",)	//Tipo da origem do remetente (1=Padrão, 2=Usuário, 3=Ambos)
	::cFrom       := superGetMV("MV_E_FROM", .f., "",)	//EMail do remetente padrão para envio de EMail - Pode ser parametrizado no sistema
	::cTo         := ""									//EMail do(s) destinatário(s)
	::cSubject    := ""									//Assunto
	::cBody       := ""									//Corpo da mensagem
	::cCc         := ""									//Com cópia para
	::cBcc        := ""									//Com cópia oculta para
	::aAttach     := {}									//Anexos
	::nTimeOut    := superGetMV("MV_E_TMOUT", .f., "",)  //Um minuto - Pode ser parametrizado no sistema
	::nPriority   := 0 									//Prioridade Normal
	::nSecurity   := superGetMV("MV_E_SECUR", .f., "",)	//Segurança: 0=Normal 1=SSL ou 2=TLS - Pode ser parametrizado no sistema
	::nProtocol   := superGetMV("MV_E_PROTO", .f., "",)	//Protocolo comunicação: 1=SMTP ou 2=IMAP - Pode ser parametrizado no sistema
	::lShowToLog  := .f.									//Por padrão mostra mensagens na tela
	::lDebug      := .f.									//Por padrão não mostra mensagens
	::lAuth       := superGetMV("MV_E_AUTH", .f., "",)	//Por padrão não faz autenticação - Pode ser parametrizado no sistema
	::attachOnSrv := .f.
	::cLastError  := ''

	//Forçar para pegar dados de servidor e autenticação do padrão Protheus
	::cServer   := superGetMv('MV_RELSERV', .f., '',)
	::nPort     := iIf(at(':', ::cServer) > 0, val(subStr(::cServer, (at(':', ::cServer) + 1), len(::cServer))), 587)

	//MV_RELSERV pode vir como servidor:porta - a porta já foi extraída acima
	if at(':', ::cServer) > 0
		::cServer := subStr(::cServer, 1, at(':', ::cServer) - 1)
	endIf

	::cUser     := superGetMv('MV_RELACNT', .f., '',)
	::cPasswd   := superGetMv('MV_RELPSW' , .f., '',)
	::cFrom     := superGetMv('MV_RELFROM', .f., '',)
	::lAuth     := superGetMv('MV_RELAUTH', .f., '',)
	::nProtocol := 1
	
	if superGetMv('MV_RELSSL', .f., '',)
		::nSecurity := 1
	endIf
	
	if superGetMv('MV_RELTLS', .f., '',)
		::nSecurity := 2
	endIf

	if valType(::nTypeFrom) <> 'N'
		::nTypeFrom := val(cValToChar(::nTypeFrom))
	endIf

	if ::nTypeFrom < 1 ;
		.or. ::nTypeFrom > 3

		::nTypeFrom := 1		//Padrão (MV_E_TYPE inexistente ou inválido)
	endIf

	if ::nTypeFrom <> 1 
		//INICIO: Pegar email do usuário solicitante
		oUser := tcUser():New()
		
		oUser:FindByID(__cUserID)
		
		if oUser:Available() ;
			.and. (::nTypeFrom == 2 ;
				   .or. (::nTypeFrom == 3 .and. !empty(oUser:GetEmail())))
			
			::cFrom := oUser:GetEmail()
		endIf
	
		freeObj(oUser)
		//FIM: Pegar email do usuário solicitante
	endIf
		
	if isSrvUnix()
		::cServerPath := "/spool/"								//Pasta no servidor linux para cópia de anexos
	else
		::cServerPath := "\spool\"								//Pasta no servidor microsoft para cópia de anexos
	endIf
	
	//Se a porta não foi definida em parametro do sistema será 465 por padrão
	if ::nPort == 0 ;
		.or. valType(::nPort) <> 'N'
	
		::nPort := 465
	endIf

	if empty(::nTimeOut) ;
		.or. ::nTimeOut == 0 ;
		.or. valType(::nTimeOut) <> 'N'
		 
		::nTimeOut := 60		// Um minuto
	endIf 

	if empty(::nSecurity) ;
		.or. ::nSecurity < 0 ;
		.or. ::nSecurity > 2 ;
		.or. valType(::nSecurity) <> 'N'
		 
		::nSecurity := 0		// Segurança: 0=Normal
	endIf 

	if empty(::nProtocol) ;
		.or. ::nProtocol < 1 ;
		.or. ::nProtocol > 2 ;
		.or. valType(::nProtocol) <> 'N'
		 
		::nProtocol := 1		// Protocolo comunicação: 1=SMTP
	endIf 

	if empty(::lAuth) ;
		.or. valType(::lAuth) <> 'L'
		 
		::lAuth := .f.			//Por padrão não faz autenticação
	endIf
	
	::aAttach := {}            
return

           
 /*/{Protheus.doc} tcEMail:ClassName
Método responsável por retornar o nome da classe
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0
@type method     
@return caractere, retorna o nome da classe
/*/
method ClassName() class tcEMail
return ::cClassName


 /*/{Protheus.doc} tcEMail:Destroy
Método destrutor do objeto, responsável pela desalocação da memória
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0
@type method     
/*/  
method Destroy(oObj as object) class tcEMail    
	freeObj(oObj)	       
return


/*/{Protheus.doc} tcEMail:SetUser
Método para informar o usuário para autenticação 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@param cUser, caractere, Nome do usuário para autenticação
@example
oTcEMail:SetUser("user")
/*/
method SetUser(cUser) class tcEMail
	::cUser := cUser                                              
return                                   


/*/{Protheus.doc} tcEMail:SetPassword
Método para informar a senha do usuário para autenticação 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@param cPasswd, caractere, Senha do usuário para autenticação
@example
oTcEMail:SetPassword("senha")
/*/
method SetPassword(cPasswd) class tcEMail
	::cPasswd := cPasswd                                              
return                                   


/*/{Protheus.doc} tcEMail:SetServer
Método para informar o endereço do servidor de EMail 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@param cServer, caractere, Endereço do servidor de EMail
@example
oTcEMail:SetServer("192.168.1.100")
/*/
method SetServer(cServer) class tcEMail
	::cServer := cServer                                              
return                                   


/*/{Protheus.doc} tcEMail:SetPort
Método para informar a porta para comunicação com o servidor de EMail 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@param nPort, inteiro, Porta de comunicação com o servidor de EMail
@example
oTcEMail:SetPort(465)
/*/
method SetPort(nPort) class tcEMail
	::nPort := nPort                                              
return                                   


/*/{Protheus.doc} tcEMail:SetFrom
Método para informar o EMail do remetente 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@param cFrom, caractere, EMail do remetente
@example
oTcEMail:SetFrom("usuario@servidor.com")
/*/
method SetFrom(cFrom) class tcEMail
	::cFrom := cFrom                                              
return                                   


/*/{Protheus.doc} tcEMail:SetTo
Método para informar o EMail do(s) destinatario(s) 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@param cTo, caractere, EMail do(s) destinatário(s)
@example
oTcEMail:SetTo("usuario@servidor.com") 
oTcEMail:SetTo("usuario@servidor.com;usuario2@servidor.com;usuario3@servidor.com")
/*/
method SetTo(cTo) class tcEMail
	::cTo := cTo                                              
return                                   


/*/{Protheus.doc} tcEMail:SetCc
Método para informar o EMail com cópia para destinatário(s) 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@param cCc, caractere, EMail do(s) destinatário(s)
@example
oTcEMail:SetCc("usuario@servidor.com") 
oTcEMail:SetCc("usuario@servidor.com;usuario2@servidor.com;usuario3@servidor.com")
/*/
method SetCc(cCc) class tcEMail
	::cCc := cCc                                              
return                                   


/*/{Protheus.doc} tcEMail:SetBcc
Método para informar o EMail com cópia oculta para destinatário(s) 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@param cBcc, caractere, EMail do(s) destinatário(s)
@example
oTcEMail:SetBcc("usuario@servidor.com") 
oTcEMail:SetBcc("usuario@servidor.com;usuario2@servidor.com;usuario3@servidor.com")
/*/
method SetBcc(cBcc) class tcEMail
	::cBcc := cBcc                                              
return                                   


/*/{Protheus.doc} tcEMail:SetSubject
Método para informar o assunto 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@param cSubject, caractere, assunto
@example
oTcEMail:SetSubject("assunto") 
/*/
method SetSubject(cSubject) class tcEMail
	::cSubject := cSubject                                              
return                                   


/*/{Protheus.doc} tcEMail:SetBody
Método para informar o corpo da mensagem 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@param cBody, caractere, corpo da mensagem
@example
oTcEMail:SetBody("corpo da mensagem") 
/*/
method SetBody(cBody) class tcEMail
	::cBody := cBody                                              
return                                   


/*/{Protheus.doc} tcEMail:SetTimeOut
Método para informar o tempo para tentativas  
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@param nTimeOut, inteiro, Tempo para tentativas de envio do EMail
@example
oTcEMail:SetTimeOut(60)
/*/
method SetTimeOut(nTimeOut) class tcEMail
	::nTimeOut := nTimeOut                                              
return                                   


/*/{Protheus.doc} tcEMail:SetPriority
Método para informar o número da prioridade para o EMail  
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@param nPriority, inteiro, número da prioridade
@example
oTcEMail:SetPriority(1)
/*/
method SetPriority(nPriority) class tcEMail
	::nPriority := nPriority                                              
return                                   


/*/{Protheus.doc} tcEMail:SetSecurity
Método para informar o tipo de segurança  
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@param nSecurity, inteiro, código para identificação do tipo de segurança 0=Normal / 1=SSL / 2=TLS
@example
oTcEMail:SetSecurity(1)
/*/
method SetSecurity(nSecurity) class tcEMail
	::nSecurity := nSecurity
	
	if ::nSecurity == 0
		::lAuth := .f.
	else
		::lAuth := .t.
	endIf                                              
return                                   


/*/{Protheus.doc} tcEMail:SetProtocol
Método para informar o protocolo de comunicação  
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@param nProtocol, inteiro, código para protocolo de segurança 1=SMTP / 2=IMAP
@example
oTcEMail:SetProtocol(1)
/*/
method SetProtocol(nProtocol) class tcEMail
	::nProtocol := nProtocol                                              
return                                   


/*/{Protheus.doc} tcEMail:SetShowToLog
Método para informar se apresenta mensagens no log do sistema  
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@param .t. / .f., lógico, Apresenta mensagens de erro no log do sistema
@example
oTcEMail:SetShowToLog(.f.)
/*/
method SetShowToLog(lShowToLog) class tcEMail
	::lShowToLog := lShowToLog                                              
return                                   


/*/{Protheus.doc} tcEMail:SetDebug
Método para informar se apresenta mensagens   
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@param .t. / .f., lógico, Apresenta mensagens 
@example
oTcEMail:SetDebug(.f.)
/*/
method SetDebug(lDebug) class tcEMail
	::lDebug := lDebug                                              
return                                   


/*/{Protheus.doc} tcEMail:SetServerPath
Método para informar a pasta no servidor para cópia de anexos   
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@param cServerPath, caracter, Caminho no servidor para cópia de anexos 
@example
oTcEMail:SetServerPath("\temp\")
/*/
method SetServerPath(cServerPath) class tcEMail
	//Se for informado barra normal troca para barra inversa
	if isSrvUnix()
		cServerPath := trim(strTran(cServerPath, "\", "/" ))
	else
		cServerPath := trim(strTran(cServerPath, "/", "\" ))
	endIf
		
	//Se não foi informado a barra inversa ao final do camminho, insere a barra inversa
	if isSrvUnix()
		if substr(cServerPath, len(cServerPath), 1) <> '/'
			cServerPath += '/'
		endIf
	else
		if substr(cServerPath, len(cServerPath), 1) <> '\'
			cServerPath += '\'
		endIf
	endIf

	::cServerPath := cServerPath                                              
return                                   


/*/{Protheus.doc} tcEMail:SetAuth
Método para informar se faz autenticação   
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@param .t. / .f., lógico, Faz autenticação 
@example
oTcEMail:SetAuth(.f.)
/*/
method SetAuth(lAuth) class tcEMail
	::lAuth := lAuth                                              
return                                   


/*/{Protheus.doc} tcEMail:SetAttachOnServer
Método para informar se os anexos já estão no servidor (descarta o uso do Cpy2TS para estes casos)   
@author Odair Batista - odair.batista@gmail.com
@since 16/04/2019
@version 1.0                        
@type method
@param .t. / .f., lógico, Indica que os arquivos já estão no servidor (caminho original do anexo) 
@example
oTcEMail:SetAttachOnServer(.t.)
/*/
method SetAttachOnServer(attachOnSrv) class tcEMail
	::attachOnSrv := attachOnSrv                                              
return                                   


/*/{Protheus.doc} tcEMail:GetUser
Método para retornar o usuário para autenticação 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@return cUser, caractere, Nome do usuário para autenticação
@example
oTcEMail:GetUser()
/*/
method GetUser() class tcEMail
return ::cUser                                   


/*/{Protheus.doc} tcEMail:GetPassword
Método para retornar a senha do usuário para autenticação 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@return cPasswd, caractere, Senha do usuário para autenticação
@example
oTcEMail:GetPassword()
/*/
method GetPassword() class tcEMail
return ::cPasswd                                   


/*/{Protheus.doc} tcEMail:GetServer
Método para retornar o endereço do servidor de EMail 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@return cServer, caractere, Endereço do servidor de EMail
@example
oTcEMail:GetServer()
/*/
method GetServer() class tcEMail
return ::cServer                                   


/*/{Protheus.doc} tcEMail:GetPort
Método para retornar a porta para comunicação com o servidor de EMail 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@return nPort, inteiro, Porta de comunicação com o servidor de EMail
@example
oTcEMail:GetPort()
/*/
method GetPort() class tcEMail
return ::nPort                                   


/*/{Protheus.doc} tcEMail:GetFrom
Método para retornar o EMail do remetente 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@return cFrom, caractere, EMail do remetente
@example
oTcEMail:GetFrom()
/*/
method GetFrom() class tcEMail
return ::cFrom                                   


/*/{Protheus.doc} tcEMail:GetTo
Método para retornar o EMail do(s) destinatario(s) 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@return cTo, caractere, EMail do(s) destinatário(s)
@example
oTcEMail:GetTo() 
/*/
method GetTo() class tcEMail
return ::cTo                                   


/*/{Protheus.doc} tcEMail:GetCc
Método para retornar o EMail com cópia para destinatário(s) 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@return cCc, caractere, EMail do(s) destinatário(s)
@example
oTcEMail:GetCc() 
/*/
method GetCc() class tcEMail
return ::cCc                                   


/*/{Protheus.doc} tcEMail:GetBcc
Método para retornar o EMail com cópia oculta para destinatário(s) 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@return cBcc, caractere, EMail do(s) destinatário(s)
@example
oTcEMail:GetBcc() 
/*/
method GetBcc() class tcEMail
return ::cBcc                                   


/*/{Protheus.doc} tcEMail:GetSubject
Método para retornar o assunto 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@return cSubject, caractere, assunto
@example
oTcEMail:GetSubject() 
/*/
method GetSubject() class tcEMail
return ::cSubject                                   


/*/{Protheus.doc} tcEMail:GetBody
Método para retornar o corpo da mensagem 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@return cBody, caractere, corpo da mensagem
@example
oTcEMail:GetBody() 
/*/
method GetBody() class tcEMail
return ::cBody                                   


/*/{Protheus.doc} tcEMail:GetTimeOut
Método para retornar o tempo para tentativas  
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@return nTimeOut, inteiro, Tempo para tentativas de envio do EMail
@example
oTcEMail:GetTimeOut()
/*/
method GetTimeOut() class tcEMail
return ::nTimeOut                                   


/*/{Protheus.doc} tcEMail:GetPriority
Método para retornar o número da prioridade para o EMail  
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@return nPriority, inteiro, número da prioridade
@example
oTcEMail:GetPriority()
/*/
method GetPriority() class tcEMail
return ::nPriority                                   


/*/{Protheus.doc} tcEMail:GetSecurity
Método para retornar o tipo de segurança  
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@return nSecurity, inteiro, código do tipo de segurança 0=Normal / 1=SSL / 2=TLS
@example
oTcEMail:GetSecurity()
/*/
method GetSecurity() class tcEMail
return ::nSecurity                                   


/*/{Protheus.doc} tcEMail:GetProtocol
Método para retornar o protocolo de comunicação  
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@return nProtocol, inteiro, código para protocolo de segurança 1=SMTP / 2=IMAP
@example
oTcEMail:GetProtocol(1)
/*/
method GetProtocol() class tcEMail
return ::nProtocol                                   


/*/{Protheus.doc} tcEMail:IsShowToLog
Método para retornar se apresenta mensagens no log do sistema  
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@return results, lógico, Apresenta mensagens no log do sistema?
@example
oTcEMail:IsShowToLog()
/*/
method IsShowToLog() class tcEMail
return ::lShowToLog                                   


/*/{Protheus.doc} tcEMail:IsDebug
Método para retornar se apresenta mensagens   
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@return results, lógico, Apresenta mensagens no log do sistema?
@example
oTcEMail:IsDebug()
/*/
method IsDebug() class tcEMail
return ::lDebug                                   


/*/{Protheus.doc} tcEMail:GetServerPath
Método para retornar a pasta no servidor para cópia de anexos   
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@return cServerPath, caracter, Caminho no servidor para cópia de anexos 
@example
oTcEMail:GetServerPath()
/*/
method GetServerPath() class tcEMail
return ::cServerPath                                   


/*/{Protheus.doc} tcEMail:IsAuth
Método para retornar se faz autenticação   
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@return lAuth, lógico, Faz autenticação 
@example
oTcEMail:IsAuth()
/*/
method IsAuth() class tcEMail
return ::lAuth                                   


/*/{Protheus.doc} tcEMail:IsAttachOnServer
Método para retornar a indicação que os anexos já estão no servidor   
@author Odair Batista - odair.batista@gmail.com
@since 16/04/2019
@version 1.0                        
@type method
@return attachOnSrv, lógico, Indica se os anexos estão no servidor 
@example
oTcEMail:IsAttachOnServer()
/*/
method IsAttachOnServer() class tcEMail
return ::attachOnSrv                                   


/*/{Protheus.doc} tcEMail:GetNumAttach
Método para retornar a quatidade de anexos 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@return cNumAttachs, inteiro, quantidade de anexos
@example
oTcEMail:GetNumAttach() 
/*/
method GetNumAttach() class tcEMail
return len(::aAttach)                                   


/*/{Protheus.doc} tcEMail:GetAttach
Método para retornar o anexo de número informado 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@param nNumAttach, inteiro, número do anexo (o número é a sequencia de adição do anexo)
@return aAttach, caracter, caminho do anexo de número informado
@example
oTcEMail:GetAttach(nNumAttach) 
/*/
method GetAttach(nNumAttach) class tcEMail
return ::aAttach[nNumAttach]                                   


/*/{Protheus.doc} tcEMail:Attach
Método para informar o anexo para o EMail 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@param cAttach, caractere, anexo
@example
oTcEMail:Attach("caminho do anexo") 
/*/
method Attach(cAttach) class tcEMail
	aAdd(::aAttach, cAttach)
return                                   


/*/{Protheus.doc} tcEMail:GetLastError
Retorna a descrição do último erro ocorrido no método Send()
@author pablo.regis
@since 22/10/2026
@version 1.0
@type method
@return caractere, descrição do erro (vazio se não houve erro)
/*/
method GetLastError() class tcEMail
return ::cLastError


/*/{Protheus.doc} tcEMail:Send
Método para enviar o EMail 
@author Odair Batista - odair.batista@gmail.com
@since 13/11/2015
@version 1.0                        
@type method
@return results, lógico, informa se executou com sucesso ou não
@example
oTcEMail:Send() 
/*/
method Send() class tcEMail
	local oServer    := nil
	local oMessage   := nil
	local nError     := 0
	local nAttachErr := 0
	local cAttach    := ""
	local nRow       := 0
	local fullName   := ""
	local nAttempt   := 3

	::cLastError := ''

	//Apos a conexão, cria o objeto da mensagem
	oMessage := TMailMessage():New()
	   
	//Limpa o objeto
	oMessage:Clear()
	   
	//Popula com os dados de envio
	oMessage:cDate	  := cValToChar(date())
	oMessage:cFrom    := ::cFrom
	oMessage:cTo      := ::cTo
	oMessage:cCc      := ::cCc
	oMessage:cBcc     := ::cBcc
	oMessage:cSubject := ::cSubject
	oMessage:cBody    := ::cBody
	
	//Adiciona um anexos
	for nRow := 1 to len(::aAttach)
		if ::attachOnSrv
			fullName := ::aAttach[nRow]
		else
			cpyT2S(::aAttach[nRow], ::cServerPath)
			
			//Obtem somente o nome do arquivo do path de origem e vincula ao path de destino
			if isSrvUnix()
				fullName := ::cServerPath + allTrim(substr(::aAttach[nRow], rat('/', ::aAttach[nRow]) + 1, 100))
			else
				fullName := ::cServerPath + allTrim(substr(::aAttach[nRow], rat('\', ::aAttach[nRow]) + 1, 100))
			endIf
	
			nAttachErr := iIf(file(fullName), 0, 1) 
			
			if ::lDebug
				isMailFail(::lShowToLog,, nAttachErr, "Anexo " + trim(fullName) + " copiado com sucesso para o servidor.", "Anexo " + trim(fullName) + " não foi copiado para o servidor.")	
			endIf
		endIf
		
		if nAttachErr == 0		
			nAttachErr := oMessage:AttachFile(fullName)
		
			if ::lDebug
				isMailFail(::lShowToLog,, nAttachErr, "Anexo " + trim(::aAttach[nRow]) + " adicionado com sucesso", "Não foi possível adicionar o anexo " + trim(::aAttach[nRow]))	
			endIf
		endIf

		if nAttachErr < 0
	    	nError := nAttachErr
		endIf
	next nRow

	if nError <> 0
		::cLastError := 'Falha ao anexar o arquivo ' + fullName
	endIf

	if nError == 0
		//Instancia objeto para conexão com o servidor
		oServer := tMailManager():New()
	
		//Setar segurança para conexão com o servidor
		oServer:SetUseSSL(::nSecurity == 1)
		oServer:SetUseTLS(::nSecurity == 2)
	
		//Setar timeout para conexão com o servidor
		oServer:SetSMTPTimeout(::nTimeOut)
	
		if ::nProtocol == 2
			oServer:Init(::cServer, "", ::cUser, ::cPasswd, ::nPort, 0)
		else
			oServer:Init("", ::cServer, ::cUser, ::cPasswd, 0, ::nPort)
		endIf
	
		//Inicializa objeto para conexão com o servidor
		for nRow = 1 to nAttempt		//Tentativas
			//Efetua conexão com o servidor
			if ::nProtocol == 2
				nError := oServer:IMAPConnect()
			else
				nError := oServer:SMTPConnect()
			endIf
			
			if nError == 0
				exit
			elseIf nRow < nAttempt
				sleep(1000)
			endIf 
		next nRow

		if nError <> 0
			::cLastError := 'Falha ao conectar no servidor ' + ::cServer + ':' + cValToChar(::nPort) ;
				+ ' (' + allTrim(cValToChar(oServer:GetErrorString(nError))) + ')'
		endIf
					
		if ::lDebug
			isMailFail(::lShowToLog, oServer, nError, "Servidor conectado com sucesso", "Não foi possível Conectar ao servidor")	
		endIf
		
		if ::lAuth ;
			.and. nError == 0
			
			nError := oServer:SmtpAuth(::cUser, ::cPasswd)

			if nError <> 0
				::cLastError := 'Falha na autenticação do usuário ' + ::cUser ;
					+ ' (' + allTrim(cValToChar(oServer:GetErrorString(nError))) + ')'
			endIf
					
			if ::lDebug
				isMailFail(::lShowToLog, oServer, nError, "Autenticado com sucesso", "Falha na autenticação")	
			endIf
		endIf	
			
		if nError == 0
		  	//Envia o e-mail
		  	nError := oMessage:Send(oServer)

			if nError <> 0
				::cLastError := 'Falha no envio para ' + ::cTo + ' a partir de ' + ::cFrom ;
					+ ' (' + allTrim(cValToChar(oServer:GetErrorString(nError))) + ')'
			endIf
		  	
			if ::lDebug
				isMailFail(::lShowToLog, oServer, nError, "E-Mail enviado com sucesso para " + ::cTo, "Falha ao enviar E-Mail para " + ::cTo)
			endIf

			//Se houver anexos copiados para o servidor, verifica existência e elimina
			for nRow := 1 to len(::aAttach)
				//Obtem somente o nome do arquivo do path de origem e vincula ao path de destino 
				if isSrvUnix()
					fullName := ::cServerPath + allTrim(substr(::aAttach[nRow], rat('/', ::aAttach[nRow]) + 1, 100))
				else
					fullName := ::cServerPath + allTrim(substr(::aAttach[nRow], rat('\', ::aAttach[nRow]) + 1, 100))
				endIf
		
				fErase(fullName)
			next nRow
			
			if ::nProtocol == 2
				nError := oServer:IMAPDisconnect()
			else
				nError := oServer:SMTPDisconnect()
			endIf
		
			if ::lDebug
				isMailFail(::lShowToLog, oServer, nError, "Servidor desconectado com sucesso", "Não foi possível desconectar o servidor")
			endIf
		endIf
	endIf
return (nError == 0)


/*
Função interna para tratamento de erros
*/
static function isMailFail(showToLog_, oServer_, nError_, message_, failMsg_)
	if nError_ == 0
		if showToLog_
			conout(message_)
		else
			alert(message_)
		endIf
	else
		if valType(oServer_) == "O"
			failMsg_ += " (" + trim(cValToChar(oServer_:getErrorString(nError_))) + ")"
		endIf
		
		if showToLog_
			conout(failMsg_)
		else
			alert(failMsg_)
		endIf
	endIf
return
