#include "totvs.ch"
#include "protheus.ch"
#include "TOPCONN.CH"


User Function TelaCSV()
    Local aArea := FWGetArea()
    Local oBrowse
    Private aRotina := {}
    Private cCadastro := "Importação de Registros CSV"

    //Definição do Menu
    aRotina := MenuDef()

    //Instanciando o Browse
    oBrowse := FWMBrowse() :New()
    oBrowse:SetAlias("ZF1")
    oBrowse:SetDescription(cCadastro)
    oBrowse:DisableDetails()

    //Add legendas
    oBrowse:AddLegend("ZF1->ZF1_STATUS == 'A'", "GREEN" , "Ativo")
    oBrowse:AddLegend("ZF1->ZF1_STATUS == 'I'", "RED"   , "Inativo")
    oBrowse:AddLegend("ZF1->ZF1_STATUS == 'D'", "YELLOW", "Desativado")

    // Seleciona a área e índice padrão
    DbSelectArea("ZF1")
    ZF1->(DbSetOrder(1))

    // Ativa o Browse
    oBrowse:Activate()
    FWRestArea(aArea)
Return Nil
Static Function MenuDef()
    Local aRotina := {}

    //Adicionando opcoes do menu
    aAdd(aRotina, {"Pesquisar", "AXPESQUI", 0, 1})
    aAdd(aRotina, {"Visualizar", "AXVISUAL", 0, 2})
    aAdd(aRotina, {"Incluir", "AXINCLUI", 0, 3})
    aAdd(aRotina, {"Alterar", "AXALTERA", 0, 4})
    aAdd(aRotina, {"Excluir", "AXDELETA", 0, 5})
    aAdd(aRotina, {"Importar CSV", "U_ImpCSV", 0, 6})


Return aRotina

User Function ImpCSV()

    // Variáveis para ler o CSV
    Local cDiret
    Local aCampos     := {}
    Local aDados      := {}
    Local aLinha      := {}
    Local AxZF1IMP    := {} // Guarda os produtos lidos do arquivo antes de gravar no BD

    // Variáveis para mapear os campos
    Local lPrimLin    := .T.
    Local njx         := 1    // Guarda o índice da linha atual no loop.
    Local nAtual      := 1
    Local qtdaux      := 0

    Local nIncluidos := 0
    Local nAlterados := 0
    Local nDuplicados := 0
    Local nErros     := 0
    Local cLinhasErro:= ""
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
            If (Len(aCampos) >= 5 .AND. ;
                    (AllTrim(aCampos[1]) == "COD") .AND. ;
                    (AllTrim(aCampos[2]) == "DESC") .AND. ;
                    (AllTrim(aCampos[3]) == "QTDE") .AND. ;
                    (AllTrim(aCampos[4]) == "DATA") .AND. ;
                    (AllTrim(aCampos[5]) == "VALOR")) .AND. ;
                    (AllTrim(aCampos[6]) == "STATUS")
                lPrimLin := .F.                         // Desliga a flag de primeira linha.
                // Validação do cabeçalho (Segunda linha do arquivo)
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
        If Len(aDados) >= 6
            Aadd(AxZF1IMP, {AllTrim(aDados[1]), AllTrim(aDados[2]), AllTrim(aDados[3]), AllTrim(aDados[4]), AllTrim(aDados[5]), AllTrim(aDados[6])})
        EndIf

        FT_FSKIP()                                         // Move para a próxima linha do CSV

    EndDo

    FT_FUSE() // Libera/fecha o arquivo da memória após terminar a leitura

    // --------------Grava no BD
    qtdaux := Len(AxZF1IMP) // Guarda a quantidade total de registros lidos

    ProcRegua(qtdaux)                                    // Inicia o processo da Regua de gravação
    Begin Transaction                                     // Abre transação com o BD para garantir integridade

        If qtdaux != 0                                    // Verifica se o array não está vazio

            dbSelectArea("ZF1")                         // Define a ZF1 como ativa
            ZF1->(dbSetOrder(1))                // Ativa o Índice 1 da ZF1 (ZF1_COD)

            For njx := 1 to qtdaux                        // Loop por todos os itens guardados no array
                IncProc("Analisando e gravando registro " + cValToChar(nAtual) + " de " + cValToChar(qtdaux) + "...")

                // Verifica se os campos não estão vazios
                If (!Empty(AxZF1IMP[njx][1])) .AND. (!Empty(AxZF1IMP[njx][2])) .AND. (!Empty(AxZF1IMP[njx][3])) .AND. (!Empty(CToD(AxZF1IMP[njx][4]))) .AND. (!Empty(AxZF1IMP[njx][5])) .AND. (!Empty(AxZF1IMP[njx][6]))
                    ZF1->(dbSetOrder(1))

                    // Ajusta o tamanho do código para o Dicionário (SX3) e evita repetição de código
                    cCodAux := Padr(AllTrim(AxZF1IMP[njx][1]), TamSX3("ZF1_COD")[1])
                    cCodBusca := AllTrim(AxZF1IMP[njx][1])

                    dbSelectArea("SB1")
                    SB1->(dbSetOrder(1))
                    If !SB1->(DBSEEK(xFilial("SB1") + cCodAux))
                        // If !SB1->(DBSEEK(xFilial("SB1") + Padr(AllTrim(AxZF1IMP[njx][1]), TamSX3("B1_COD")[1])))
                        nErros++
                        cLinhasErro += "Registro " + cValToChar(njx) + " (" + AllTrim(cCodAux) + "): Produto não cadastrado na tabela SB1." + CRLF
                        dbSelectArea("ZF1")
                        ZF1->(dbSetOrder(1))
                        nAtual++
                        Loop
                    EndIf


                    dbSelectArea("SB2")
                    SB2->(dbSetOrder(1))
                    //If !SB2->(DBSEEK(xFilial("SB2") + cCodAux))
                    If !SB2->(DBSEEK(xFilial("SB2") + Padr(AllTrim(AxZF1IMP[njx][1]), TamSX3("B2_COD")[1])))
                        nErros++
                        cLinhasErro += "Registro " + cValToChar(njx) + " (" + AllTrim(cCodAux) + "): Produto não encontrado na tabela SB2." + CRLF
                        dbSelectArea("ZF1")
                        ZF1->(dbSetOrder(1))
                        nAtual++
                        Loop
                    Else
                        // Verifica se o custo na SB2 é negativo
                        If SB2->B2_VATU1 < 0
                            nErros++
                            cLinhasErro += "Registro " + cValToChar(njx) + " (" + AllTrim(cCodAux) + "): Produto possui custo negativo (B2_VATU1) na SB2." + CRLF
                            dbSelectArea("ZF1")
                            ZF1->(dbSetOrder(1))
                            nAtual++
                            Loop
                        EndIf
                    EndIf

                    //Seleciona e posiciona a ZF1 para verificar se o registro JÁ EXISTE na ZF1
                    dbSelectArea("ZF1")
                    ZF1->(dbSetOrder(1))

                    If ZF1->(DBSEEK(xFilial("ZF1") + cCodAux))
                        Reclock("ZF1", .F.)

                        // Verifica se algum campo mudou
                        If ZF1->ZF1_DESC <> AxZF1IMP[njx][2] .OR. ;
                                ZF1->ZF1_QTDE <> Val(StrTran(AxZF1IMP[njx][3], ",", ".")) .OR. ;
                                ZF1->ZF1_DATA <> CToD(AxZF1IMP[njx][4]) .OR. ;
                                ZF1->ZF1_VALOR <> Val(StrTran(AxZF1IMP[njx][5], ",", ".")) .OR. ;
                                ZF1->ZF1_STATUS <> AxZF1IMP[njx][6]

                            // Se algum campo mudou ATUALIZA
                            Reclock("ZF1", .F.)
                            //ZF1->ZF1_FILIAL := xFilial("ZF1")
                            ZF1->ZF1_COD     := cCodAux
                            ZF1->ZF1_DESC   := AxZF1IMP[njx][2]              // Descrição
                            ZF1->ZF1_QTDE   := Val(StrTran(AxZF1IMP[njx][3], ",", ".")) // Converte para Número
                            ZF1->ZF1_DATA   := CToD(AxZF1IMP[njx][4])
                            ZF1->ZF1_VALOR := Val(StrTran(AxZF1IMP[njx][5], ",", ".")) //StrTran()substitui: a vírgula pelo ponto
                            ZF1->ZF1_STATUS := AxZF1IMP[njx][6]
                            MsUnlock() // Destrava o registro e confirma a gravação na tabela
                            nAlterados++

                        Else
                            // Registro idêntico -> NÃO grava, apenas contabiliza como duplicado
                            nDuplicados++
                        EndIf

                    Else
                        // Se NÃO ENCONTROU -> INCLUI
                        Reclock("ZF1", .T.)

                        ZF1->ZF1_FILIAL := xFilial("ZF1")
                        ZF1->ZF1_COD    := cCodAux
                        ZF1->ZF1_DESC   := AxZF1IMP[njx][2]
                        ZF1->ZF1_QTDE   := Val(StrTran(AxZF1IMP[njx][3], ",", "."))
                        ZF1->ZF1_DATA   := CToD(AxZF1IMP[njx][4])
                        ZF1->ZF1_VALOR  := Val(StrTran(AxZF1IMP[njx][5], ",", "."))
                        ZF1->ZF1_STATUS := AxZF1IMP[njx][6]
                        MsUnlock()

                        nIncluidos++
                    EndIf

                Else

                    nErros++
                    cLinhasErro += "Registro " + cValToChar(njx) + ": "

                    If !Empty(AxZF1IMP[njx][1])
                        cLinhasErro += (AxZF1IMP[njx][1]) + " "
                    EndIf
                    // Validação para identificar qual campo está vazio ou inválido

                    If Empty(AxZF1IMP[njx][1])
                        cLinhasErro += "Código não informado "
                    EndIf

                    If Empty(AxZF1IMP[njx][2])
                        cLinhasErro += "Descrição não informada "
                    EndIf
                    If Empty(AxZF1IMP[njx][3])
                        cLinhasErro += "Quantidade não informada "
                    EndIf
                    If Empty(CToD(AxZF1IMP[njx][4]))
                        cLinhasErro += "Data inválida ou não informada "
                    EndIf
                    If Empty(AxZF1IMP[njx][5])
                        cLinhasErro += "Valor não informado "
                    EndIf
                    If Empty(AxZF1IMP[njx][6])
                        cLinhasErro += "Status não informado "
                    EndIf
                    cLinhasErro += CRLF
                EndIf
                nAtual++
            Next
        EndIf

    End Transaction

    If nErros == 0
        cMsg += "Leitura do arquivo CSV finalizada!" + CRLF + CRLF
        cMsg += "Total de linhas no arquivo: " + cValToChar(qtdaux) + CRLF
        cMsg += "Novos registros inseridos: " + cValToChar(nIncluidos) + CRLF
        cMsg += "Registros atualizados: " + cValToChar(nAlterados) + CRLF
        cMsg += "Registros duplicados (não inseridos): " + cValToChar(nDuplicados) + CRLF

        FWAlertSuccess(cMsg, "Resultado da Importação")
    Else
        cMsg += "Leitura do arquivo CSV finalizada!" + CRLF + CRLF
        cMsg += "Linhas não inseridas (erros): " + cValToChar(nErros) + CRLF

        cMsg += CRLF + "As seguintes linhas não foram inseridas, verifique: " + CRLF
        cMsg += cLinhasErro + CRLF

        cMsg += "Novos registros inseridos: " + cValToChar(nIncluidos) + CRLF
        cMsg += "Registros atualizados: " + cValToChar(nAlterados) + CRLF
        cMsg += "Registros duplicados (não inseridos): " + cValToChar(nDuplicados) + CRLF
        FWAlertWarning(cMsg, "Resultado da Importação (Aviso)")
    EndIf

Return

User Function VisuCSV()

    DbSelectArea("ZF1")
    ZF1->(DbSetOrder(1))

    AxCadastro("ZF1", "Cadastro dos Registros Importados")
Return
