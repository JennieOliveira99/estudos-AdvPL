// #include "totvs.ch"
#include "protheus.ch"
#include "TOPCONN.CH"

user function TestesTI()	// U_uReadExc()
//ximpSZ1
	//Variaveis para ler o CSV
	local cDiret
	local aCampos 	:= {}
	local aDados	:= {}
	local aLinha 	:= {}
	Local AxSZ1IMP   := {}
	//Variaveis para mapear os campos
	//Local lincount  := 1
	Local lPrimLin := .T.
	Local NJX      := 1
	Local nProc		:= 0
	Local nAtual := 0
	local qtdaux := 0
//	Local cCodUse	:= RetCodUsr()
	// Local cNomeUs	:= Alltrim(UsrRetName(cCodUse))
	// Local cFullNo	:= Alltrim(UsrFullName(cCodUse))
	// Local cData  	:= SubStr(cValToChar(FWTimeStamp(2)),1,10)
	// Local cHora  	:= SubStr(cValToChar(FWTimeStamp(2)),12,8)
	// Local cLog   	:= ''
	// Local cId		:= ''
	// Local cRotina	:= FunName()

//
	//Abrir uma tela para escolher o arquivo.
	cDiret := cGetFile('Arquivo CSV|*.csv| Arquivo TXT|*.txt| Arquivos XML|*.xml',; //Máscara e extensão dos arqv que o usuário poderá visualizar.
	'Selecao de Arquivos',;											//cTitulo da janela pop-up.
	0,;																//nMascpadrao Filtro inicial padrão selecionado na lista.
	'C:\csv\',;														//cDirinicial Pasta inicial em que o navegador de arquivos abrirá.
	.F.,;															//lSalvar Modo da janela: .F.  botão de Abrir | .T. botão de Salvar).
	GETF_LOCALHARD + GETF_NETWORKDRIVE,;							//nOpcoes Permite buscar arqv no disco local e em pastas mapeadas de rede.
	.T.)															//Exibe o diretório do servidor de aplicação ou local.

//O caminho final do arqv escolhido pelo usuário é retornado e gravado dentro da variável cDiret

//Leitura do arquivo
	FT_FUSE(cDiret)										//Disponibiliza as funcoes FT_F para o arquivo. Abre o arquivo localizado no caminho guardado na variável cDiret e avisa o Protheus: 
														//"Prepara a biblioteca FT_F pra manipular esse arquivo"
	ProcRegua(FT_FLASTREC())                            //FT_FLASTREC() conta o número total de linhas do arquivo. | ProcRegua(...) pega esse número total e configura a régua do Protheus. 
														//Exemplo: se o arquivo tem 100 linhas, a régua sabe que 100 linhas equivalem a 100% da barra de progresso.
	FT_FGOTOP()											//Seta a primeira linha do arquivo

	While !FT_FEOF()									//While enquanto nao for o final do arquivo (End Of File)
		IncProc('Lendo Arquivo texto...')               //A cada volta do While, anda 1 "passinho" na barra de progresso da tela e mostra essa mensagem.
		//		cLinha := FT_FREADLN()					//Le a linha atual e coloca ela na cLinha
		aLinha := Separa(FT_FREADLN(),";",.T.)			//FT_FREADLN(): Lê a linha onde o ponteiro ta e devolve o texto inteiro dessa linha como uma única string | 
			                                            //Separa(): Pega esse texto inteiro e o "fatia" onde tiver o delimitador ponto e vírgula (;), transformando-o num Array (vetor) de pedaços. | 
//validação da primeira linha do arquivo
		IF lPrimLin										//Testa se a flag lPrimLin está verdadeira (ela começa .T.). Isso garante que este bloco só vai rodar na primeira linha do arquivo.
			IF alltrim(aLinha[1]) == "SZ1"				//pega o primeiro pedaço que a função Separa() fatiou | alltrim(...) tira qualquer espaço em branco das pontas (caso esteja "SZ1 " ou "  SZ1").
				lPrimLin := .F.							//"Desliga" a flag de primeira linha. Nas próximas voltas do While, o sistema pula esse bloco IF lPrimLin.
				lcabok   := .T. 						//"Liga" a flag de cabeçalho ok. Isso vai permitir que o sistema entre no próximo bloco IF lcabok.							
				FT_FSKIP()								//Pula para a próxima linha do arquivo. Isso é necessário porque a primeira linha do arquivo é só o cabeçalho, não tem dados.	
			Else
				Alert("Corrija a importacao para tabela SZ1")
				Return
			Endif
		Endif



		If lcabok										//se a flag do cabeçalho está autorizada (o bloco anterior confirmou que o arquivo começa com sz1)
			aCampos  := Separa(FT_FREADLN(),";",.T.)	//Caso seja a primeira, seta no vetor aCampos[], separando os campos por ;
														//FT_FREADLN(): Lê a segunda linha do arquivo (que contém "COD;DESC;QTD;DATA;VALOR").
														//Separa(..., ";", .T.): Fatia essa linha e gera o vetor aCampos
			//Conferindo se o nome de cada coluna da segunda linha está escrito exatamente na ordem esperada
				iF ((aCampos[1] == "COD") .AND. ; //carac
					(aCampos[2] == "DESC") .AND. ;// carac
					(aCampos[3] == "QTDE") .AND. ; //num
                    (aCampos[4] == "DATA") .AND. ; //data
					(aCampos[5] == "VALOR")) //num
				lcabok := .F. 							//Desliga a flag de verificação do cabeçalho. Isso impede que este bloco If lcabok rode novamente quando o loop ler a linha 3 (dados dos produtos)
				FT_FSKIP() //Pula para a próxima linha do arquivo. Isso é necessário porque a segunda linha do arquivo é só o cabeçalho, não tem dados.		
			else
				Alert("Cabecalho da tabela não foi encontrado, campos Descrição | Quantidade | Data | Valor")
				return
			endif
		endif

		adados := Separa(FT_FREADLN(),";",.T.)

		aadd(AXSZ1IMP,{adados[1],adados[2],adados[3],adados[4],adados[5]})

		FT_FSKIP()

	EndDo

	qtdaux := Len(AXSZ1IMP)
	//Count To nProc
	ProcRegua(qtdaux)															//Inicia o processo da Regua de processo
	Begin Transaction
		If Len(AXSZ1IMP) != 0
			dbselectarea("SZ1")
			For njx := 1 to len(AXSZ1IMP)
				IncProc("Analisando registro " + cValToChar(nAtual) + " de " + cValToChar(nProc) + "...")

				IF (!alltrim(AXSZ1IMP[njx][1]) == "") .AND. (!alltrim(AXSZ1IMP[njx][2]) == "") .AND. (!alltrim(AXSZ1IMP[njx][3]) == "")
					SZ1->(dbSetOrder(8))
					if SZ1->(DBSEEK(XFILIAL("SZ1")+Padr(AXSZ1IMP[njx][1],TamSX3("SZ1_CODPRO" )[1])+Padr(AXSZ1IMP[njx][2],TamSX3("SZ1_CODMON" )[1])))
						Reclock("SZ1",.F.) /// .t. GERA, .F. ALTERA
						SZ1->Z1_FILIAL := "01"
						SZ1->Z1_COD := AXSZ1IMP[njx][1]
						SZ1->SZ1_PRCVEN := AXSZ1IMP[njx][2]
						SZ1->SZ1_PRCVENB := (AXSZ1IMP[njx][2] * 0.7)
						Msunlock()
					ENDIF
				ENDIF
				nAtual++
			next
		EndIf
	End Transaction
	Alert("Importados " + cValToChar(njx) + " de " + cValToChar(qtdaux) + " registros" )
return
