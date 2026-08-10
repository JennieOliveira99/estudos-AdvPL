#include "totvs.ch"
#include "protheus.ch"
#include "TOPCONN.CH"

User Function TestesTI()
    
    // Variáveis para ler o CSV
    Local cDiret
    Local aCampos     := {}
    Local aDados      := {}
    Local aLinha      := {}
    Local AxSZ1IMP    := {} // Guarda os produtos lidos do arquivo antes de gravar no BD
    Local lcabok      := .F. // Flag para validar se o cabeçalho do arquivo está correto
    
    // Variáveis para mapear os campos
    Local lPrimLin    := .T.
    Local njx         := 1    // Guarda o índice da linha atual no loop.
    Local nAtual      := 1
    Local qtdaux      := 0

    Local nIncluidos := 0
    Local nAlterados := 0
    Local cMsg := ""

    Local cLinha      := ""
    Local cCodAux     := ""

    // Abrir uma tela para escolher o arquivo.
    cDiret := cGetFile('Arquivo CSV|*.csv| Arquivo TXT|*.txt| Arquivos XML|*.xml',; // Seleção de Arquivo: cGetFile, Armazena o caminho do arqv: cDiret   
                        'Selecao de Arquivos',;                                         // Titulo da janela
                        0,;                                                             // Filtro inicial
                        'C:\csv\',;                                                     // Pasta inicial
                        .F.,;                                                         // Modo da janela: .F. Abrir | .T. Salvar
                        GETF_LOCALHARD + GETF_NETWORKDRIVE,;                         // Permite buscar no disco local e rede
                        .T.)                                                         // Exibe o diretório do servidor de aplicação ou local.

    // Se o usuário fechar a tela sem escolher um arqv, a rotina é encerrada
    If Empty(cDiret)
        Alert("Nenhum arquivo selecionado.")
        Return
    EndIf

    // Leitura arqv
    FT_FUSE(cDiret)                                        // Prepara a biblioteca para manipular o arquivo
    ProcRegua(FT_FLASTREC())                            // Configura a régua de progresso total de linhas do arquivo
    FT_FGOTOP()                                            // Seta a primeira linha do arquivo

    While !FT_FEOF()                                    // Enquanto não for o final do arquivo
        
        IncProc('Lendo Arquivo texto...')               // Anda a barra de progresso
        
        // Limpeza dos caracteres ocultos e quebras de linha do LibreOffice
        cLinha := FT_FREADLN()
        cLinha := StrTran(cLinha, Chr(13), "")
        cLinha := StrTran(cLinha, Chr(10), "")
        cLinha := StrTran(cLinha, '"', "")
        
        // Remove marcação BOM UTF-8 se estiver na primeira linha
        If lPrimLin
            cLinha := StrTran(cLinha, Chr(239)+Chr(187)+Chr(191), "")
        EndIf

        aLinha := Separa(cLinha, ";", .T.)                // Lê a linha atual e fatia pelo delimitador ";"
        
        // Validação da primeira linha do arquivo
        IF lPrimLin                                         
            aCampos := aLinha                           // Lê a 1° linha (Nome das colunas)
            
            // Conferindo se o nome de cada coluna está na ordem esperada e removendo os espaços
            //aCampos  := Separa(FT_FREADLN(),";",.T.)  
            If (Len(aCampos) >= 5 .AND. ;
                (AllTrim(aCampos[1]) == "COD") .AND. ; 
                (AllTrim(aCampos[2]) == "DESC") .AND. ;
                (AllTrim(aCampos[3]) == "QTDE") .AND. ; 
                (AllTrim(aCampos[4]) == "DATA") .AND. ; 
                (AllTrim(aCampos[5]) == "VALOR")) 
                
                lPrimLin := .F.                         // Desliga a flag de primeira linha.
                lcabok   := .T.                      // Liga a flag de cabeçalho ok.                        
                // Validação do cabeçalho (Segunda linha do arquivo)
                lcabok   := .F.                      // Desliga a flag, pois já validou o cabeçalho
                FT_FSKIP()                             // Pula para a próxima linha (cabeçalho)    
                Loop
            Else
                Alert("Cabeçalho da tabela não foi encontrado, indique no arquivo os campos: COD;DESC;QTDE;DATA;VALOR") 
                FT_FUSE() // Fecha o arquivo
                Return
            Endif
        Endif

        // Leitura dos dados a partir da terceira linha
        aDados := aLinha                                
                                                        
        // -------- verifica se o array  tem os 5 itens esperados antes de gravá-lo no array de importação
        If Len(aDados) >= 5
            Aadd(AxSZ1IMP, {AllTrim(aDados[1]), AllTrim(aDados[2]), AllTrim(aDados[3]), AllTrim(aDados[4]), AllTrim(aDados[5])}) 
        EndIf
                                                        
        FT_FSKIP()                                         // Move para a próxima linha do CSV

    EndDo


   
    
    FT_FUSE() // Libera/fecha o arquivo da memória após terminar a leitura


    // --------------Grava no BD
    qtdaux := Len(AxSZ1IMP) // Guarda a quantidade total de registros lidos
    
    ProcRegua(qtdaux)                                    // Inicia o processo da Regua de gravação
    
    Begin Transaction                                     // Abre transação com o BD para garantir integridade
        
        If qtdaux != 0                                    // Verifica se o array não está vazio
            
            dbSelectArea("SZ1")                         // Define a SZ1 como ativa
            
            For njx := 1 to qtdaux                        // Loop por todos os itens guardados no array
                
                IncProc("Analisando e gravando registro " + cValToChar(nAtual) + " de " + cValToChar(qtdaux) + "...") 

                // Verifica se Código, Descrição e Quantidade não estão vazios
                If (!Empty(AxSZ1IMP[njx][1])) .AND. (!Empty(AxSZ1IMP[njx][2])) .AND. (!Empty(AxSZ1IMP[njx][3])) 
                    
                    SZ1->(dbSetOrder(1))                // Ativa o Índice 1 da SZ1 (Z1_COD)

                    // Ajusta o tamanho do código para o Dicionário (SX3) e evita repetição de código
                    cCodAux := Padr(AxSZ1IMP[njx][1], TamSX3("Z1_COD")[1])

                    // Busca no banco se o registro já existe (Código alinhado com o tamanho do dicionário)
                    If SZ1->(DBSEEK(cCodAux))
                        // Se ENCONTROU, trava para ALTERAÇÃO
                        Reclock("SZ1", .F.)      
                         nAlterados++       
                    Else
                        // Se NÃO ENCONTROU, trava para INCLUSÃO
                        Reclock("SZ1", .T.)
                        nIncluidos++
                    EndIf
                    
                    // Preenche os campos do banco com os dados do array
                    SZ1->Z1_FILIAL := xFilial("SZ1")                // Pega a filial corrente do sistema
                    SZ1->Z1_COD    := cCodAux                       // Código
                    SZ1->Z1_DESC   := AxSZ1IMP[njx][2]              // Descrição
                    SZ1->Z1_QTDE   := Val(StrTran(AxSZ1IMP[njx][3], ",", ".")) // Converte para Número
                    
                    // Se data no CSV como AAAAMMDD contínuo (ex: 19990313), SToD() 
                    // Se data formato "13/03/1999", CToD()
                    SZ1->Z1_DATA   := CToD(AxSZ1IMP[njx][4])        
                    
                    //SZ1->Z1_VALOR  := Val(AxSZ1IMP[njx][5])         // val() Converte para Número
                    SZ1->Z1_VALOR := Val(StrTran(AxSZ1IMP[njx][5], ",", ".")) //StrTran()substitui: a vírgula pelo ponto
                    
                    MsUnlock() // Destrava o registro e confirma a gravação na tabela
                EndIf
                
                nAtual++                                // Incrementa o contador da régua
            Next
        EndIf
        
    End Transaction
    
   // Alert("Sucesso! Processados " + cValToChar(nAtual-1) + " de " + cValToChar(qtdaux) + " registros encontrados no CSV.")
    cMsg += "Leitura do arquivo CSV finalizada!" + CRLF + CRLF
    cMsg += "Total de linhas no arquivo: " + cValToChar(qtdaux) + CRLF
    cMsg += "Novos registros inseridos: " + cValToChar(nIncluidos) + CRLF
    cMsg += "Registros atualizados: " + cValToChar(nAlterados) + CRLF

    FWAlertSuccess(cMsg, "Resultado da Importação")

Return
