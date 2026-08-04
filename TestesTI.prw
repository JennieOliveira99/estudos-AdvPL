#include "totvs.ch"
#include "protheus.ch"
#include "TOPCONN.CH"

User Function TestesTI()
	
	// Variáveis para ler o CSV
	Local cDiret
	Local aCampos 	:= {}
	Local aDados	:= {}
	Local aLinha 	:= {}
	Local AxSZ1IMP  := {} // Guarda os produtos lidos do arquivo antes de gravar no BD
	Local lcabok    := .F.
	
	// Variáveis para mapear os campos
	Local lPrimLin 	:= .T.
	Local njx      	:= 1	// Guarda o índice da linha atual no loop.
	Local nAtual 	:= 1
	Local qtdaux 	:= 0


	// Abrir uma tela para escolher o arquivo.
	cDiret := cGetFile('Arquivo CSV|*.csv| Arquivo TXT|*.txt| Arquivos XML|*.xml',; // Máscara e extensão dos arqv
						'Selecao de Arquivos',;										// Titulo da janela
						0,;															// Filtro inicial
						'C:\csv\',;													// Pasta inicial
						.F.,;														// Modo da janela: .F. Abrir | .T. Salvar
						GETF_LOCALHARD + GETF_NETWORKDRIVE,;						// Permite buscar no disco local e rede
						.T.)														// Exibe o diretório do servidor de aplicação ou local.

	// Se o usuário cancelar a seleção do arquivo, encerra a rotina
	If Empty(cDiret)
		Alert("Nenhum arquivo selecionado.")
		Return
	EndIf

	// --- LEITURA DO ARQUIVO ---
	FT_FUSE(cDiret)										// Prepara a biblioteca para manipular o arquivo
	ProcRegua(FT_FLASTREC())                            // Configura a régua de progresso total de linhas do arquivo
	FT_FGOTOP()											// Seta a primeira linha do arquivo

	While !FT_FEOF()									// Enquanto não for o final do arquivo
		
		IncProc('Lendo Arquivo texto...')               // Anda a barra de progresso
		aLinha := Separa(FT_FREADLN(), ";", .T.)		// Lê a linha atual e fatia pelo delimitador ";"
			                                            
		// Validação da primeira linha do arquivo
		IF lPrimLin										
			IF Alltrim(aLinha[1]) == "SZ1"				
				lPrimLin := .F.							// Desliga a flag de primeira linha.
				lcabok   := .T. 						// Liga a flag de cabeçalho ok.						
				FT_FSKIP()								// Pula para a próxima linha (cabeçalho)	
			Else
				Alert("Corrija a importacao para tabela SZ1. Primeira linha deve conter 'SZ1'.")
				FT_FUSE() // Fecha o arquivo
				Return
			Endif
		Endif

		// Validação do cabeçalho (Segunda linha do arquivo)
		If lcabok										
			aCampos  := Separa(FT_FREADLN(), ";", .T.)	// Lê a segunda linha (Nome das colunas)
														
			// Conferindo se o nome de cada coluna está na ordem esperada
			If ((Alltrim(aCampos[1]) == "COD") .AND. ; 
				(Alltrim(aCampos[2]) == "DESC") .AND. ;
				(Alltrim(aCampos[3]) == "QTDE") .AND. ; 
				(Alltrim(aCampos[4]) == "DATA") .AND. ; 
				(Alltrim(aCampos[5]) == "VALOR")) 
				
				lcabok := .F. 							// Desliga a flag, pois já validou o cabeçalho
				FT_FSKIP() 								// Pula para a próxima linha (agora sim, os dados)
			Else
				Alert("Cabeçalho da tabela não foi encontrado, indique no arquivo os campos: COD;DESC;QTDE;DATA;VALOR") 
				FT_FUSE() // Fecha o arquivo
				Return
			Endif
		Endif

		// Leitura dos dados a partir da terceira linha
		aDados := Separa(FT_FREADLN(), ";", .T.)			
														
		// Adiciona uma nova linha no array geral com os 5 dados fatiados
		Aadd(AxSZ1IMP, {aDados[1], aDados[2], aDados[3], aDados[4], aDados[5]}) 
														
		FT_FSKIP()										// Move para a próxima linha do CSV

	EndDo
	
	FT_FUSE() // Libera/fecha o arquivo da memória após terminar a leitura


	// --- GRAVAÇÃO NO BANCO DE DADOS ---
	qtdaux := Len(AxSZ1IMP) // Guarda a quantidade total de registros lidos
	
	ProcRegua(qtdaux)									// Inicia o processo da Regua de gravação
	
	Begin Transaction 									// Abre transação com o BD para garantir integridade
		
		If qtdaux != 0 							        // Verifica se o array não está vazio
			
			dbSelectArea("SZ1") 						// Aponta para a tabela SZ1
			
			For njx := 1 to qtdaux				        // Loop por todos os itens guardados no array
				
				IncProc("Analisando e gravando registro " + cValToChar(nAtual) + " de " + cValToChar(qtdaux) + "...") 

				// Verifica se Código, Descrição e Quantidade não estão vazios
				If (!Empty(AxSZ1IMP[njx][1])) .AND. (!Empty(AxSZ1IMP[njx][2])) .AND. (!Empty(AxSZ1IMP[njx][3])) 
					
					SZ1->(dbSetOrder(1))				// Ativa o Índice 1 da SZ1 (Geralmente Z1_FILIAL + Z1_COD)
					
					// Busca no banco se o registro já existe (Filial + Código alinhado com o tamanho do dicionário)
					If SZ1->(DBSEEK(xFilial("SZ1") + Padr(AxSZ1IMP[njx][1], TamSX3("Z1_COD")[1])))
						// Se ENCONTROU, trava para ALTERAÇÃO
						Reclock("SZ1", .F.) 			
					Else
						// Se NÃO ENCONTROU, trava para INCLUSÃO
						Reclock("SZ1", .T.)
					EndIf
					
					// Preenche os campos do banco com os dados do array
					SZ1->Z1_FILIAL := xFilial("SZ1")				// Pega a filial corrente do sistema
					SZ1->Z1_COD    := AxSZ1IMP[njx][1]              // Código
					SZ1->Z1_DESC   := AxSZ1IMP[njx][2]              // Descrição
					SZ1->Z1_QTDE   := Val(AxSZ1IMP[njx][3])         // Converte para Número
					
					// Atenção: SToD exige a data no CSV como AAAAMMDD contínuo (ex: 20231025).
					// Se o seu CSV tiver formato "25/10/2023", troque SToD() por CToD()
					SZ1->Z1_DATA   := SToD(AxSZ1IMP[njx][4])        
					
					SZ1->Z1_VALOR  := Val(AxSZ1IMP[njx][5])         // Converte para Número
					
					MsUnlock() // Destrava o registro e confirma a gravação na tabela
				EndIf
				
				nAtual++								// Incrementa o contador da régua
			Next
		EndIf
		
	End Transaction
	
	Alert("Sucesso! Processados " + cValToChar(nAtual-1) + " de " + cValToChar(qtdaux) + " registros encontrados no CSV.")

Return
