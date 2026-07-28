#include "totvs.ch"
#include "protheus.ch"
#include "TOPCONN.CH"

user function TestesTI()	// U_uReadExc()
//ximpSZ1
	//Variaveis para ler o CSV
	local cDiret
	local aCampos 	:= {}
	local aDados	:= {}
	local aLinha 	:= {}
	local  AxSZ1IMP   := {}
	local lcabok    := .F.
	//Variaveis para mapear os campos
	//Local lincount  := 1
	Local lPrimLin := .T.
	Local njx      := 1
	Local nProc		:= 0
	Local nAtual := 1
	local qtdaux := 0


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
				Alert("Cabeçalho da tabela não foi encontrado, indique no arquivo os campos Descrição | Quantidade | Data | Valor") // caiu aqui
				return
			endif
		endif

		adados := Separa(FT_FREADLN(),";",.T.)			//lê a linha corrente de dados
														//Separa(..., ";", .T.) fatia a string nos pontos e vírgulas e joga na variável adados
		aadd(AXSZ1IMP,{adados[1],adados[2],adados[3],adados[4],adados[5]}) //adiciona um novo elemento/linha ao final de um Array
														//{adados[1], ...}: Cria uma sub-lista com os 5 valores da linha atual e insere dentro do vetor AXSZ1IMP
														//O array AXSZ1IMP agora guarda todos os produtos carregados do arquivo antes de fazer a gravação oficial no BD
		FT_FSKIP()										//Move o ponteiro do arquivo para a próxima linha (linha de baixo) do CSV

	EndDo

	
//qtdaux := ...: Armazena a quantidade total de registros lidos na variável
	qtdaux := Len(AXSZ1IMP) //Len() conta quantos elementos/linhas existem dentro do array AXSZ1IMP
	//Count To nProc
	ProcRegua(qtdaux)									//Inicia o processo da Regua de processo
	Begin Transaction 									//Abre um bloco de Transação com o BD. Se ocorrer algum erro crítico dentro desse bloco, o BD pode fazer um Rollback
		If Len(AXSZ1IMP) != 0 							//Verifica se o array tem pelo menos 1 registro. Se estiver vazio, ele pula todo o processo.
			dbselectarea("SZ1") 						//Abre/aponta o ponteiro de trabalho do Protheus para a tabela SZ1
			For njx := 1 to len(AXSZ1IMP)				//Cria um loop que vai iterar do registro 1 até o último item do array AXSZ1IMP. A variável njx guarda o índice da linha atual.
				IncProc("Analisando registro " + cValToChar(nAtual) + " de " + cValToChar(nProc) + "...") //cValToChar(...): Converte valores numéricos para texto (string), permitindo concatenar mensagens.

				IF (!alltrim(AXSZ1IMP[njx][1]) == "") .AND. (!alltrim(AXSZ1IMP[njx][2]) == "") .AND. (!alltrim(AXSZ1IMP[njx][3]) == "") //XSZ1IMP[njx][1]: Acessa a coluna 1 da linha njx dentro do array.
					SZ1->(dbSetOrder(8))				//Ativa o Índice 8 da tabela SZ1 na dicionário do Protheus. Os índices determinam a ordem e os campos pelos quais a busca será feita.
					if SZ1->(DBSEEK(XFILIAL("SZ1")+Padr(AXSZ1IMP[njx][1],TamSX3("SZ1_CODPRO" )[1])+Padr(AXSZ1IMP[njx][2],TamSX3("SZ1_CODMON" )[1])))
					//DbSeek(...): Faz uma busca rápida no banco de dados usando o índice ativo.
					//xFilial("SZ1"): Retorna o código da filial corrente do usuário (ex: "01").
					//TamSX3("SZ1_CODPRO")[1]: Retorna o tamanho exato do campo no Protheus (ex: 15 caracteres).
					//Padr(..., tamanho): Preenche o texto com espaços à direita até completar o tamanho do campo no banco (vital para o DbSeek funcionar).
						Reclock("SZ1",.F.) /// .t. GERA, .F. ALTERA | função responsável por travar o registro na tabela para gravação.			
						SZ1->Z1_FILIAL := xFilial("SZ1")				// Pega a filial corrente do sistema
						SZ1->Z1_COD   := AXSZ1IMP[njx][1]
						SZ1->Z1_DESC  := AXSZ1IMP[njx][2]
						SZ1->Z1_QTDE   := Val(AXSZ1IMP[njx][3])           // Converte o texto da Qtd para Número
						SZ1->Z1_DATA  := SToD(AXSZ1IMP[njx][4])          // Converte texto (AAAAMMDD) para Data (String To Date)
						SZ1->Z1_VALOR := Val(AXSZ1IMP[njx][5])           // Converte o texto do Valor para Número
						Msunlock() // Destrava o registro e confirma a gravacao
					ENDIF
				ENDIF
				nAtual++								//Toda vez que o código passa por essa linha dentro do laço For ... Next, o valor contido na variável nAtual aumenta em 1 unidade
			next
		EndIf
	End Transaction
	Alert("Importados " + cValToChar(njx) + " de " + cValToChar(qtdaux) + " registros" )
return
