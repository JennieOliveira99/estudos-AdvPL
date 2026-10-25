#include "totvs.ch"
#include "protheus.ch"
#include "TOPCONN.CH"

// User Function ImpCusto()
//     Local aArea := FWGetArea()
//     Local oBrowse

//     Private aRotina := {}
//     Private cCadastro := "Importação de Registros CSV"

//     //Definição do Menu
//     aRotina := MenuDef()

//     //Instanciando o Browse
//     oBrowse := FWMBrowse() :New()
//     oBrowse:SetAlias("SZX")
//     oBrowse:SetDescription(cCadastro)

//     // Seleciona a área e índice padrão
//     DbSelectArea("SZX")
//     SZX->(DbSetOrder(1))

//     // Ativa o Browse
//     oBrowse:Activate()

//     FWRestArea(aArea)
// Return

// //Adiciona Legenda
// User Function AXLEGENDA()
//     Local aLegenda := {}

//     aAdd(aLegenda, {"BR_VERDE",    "Ativo"})
//     aAdd(aLegenda, {"BR_VERMELHO", "Inativo"})
//     aAdd(aLegenda, {"BR_PINK",     "Inválido"})

//     BrwLegenda("Legenda", "Legenda dos Registros", aLegenda)
// Return

// Static Function MenuDef()
//     Local aRotina := {}

//     //Adicionando opcoes do menu
//     aAdd(aRotina, {"Pesquisar", "AXPESQUI", 0, 1})
//     aAdd(aRotina, {"Visualizar", "AXVISUAL", 0, 2})
//     aAdd(aRotina, {"Incluir", "AXINCLUI", 0, 3})
//     aAdd(aRotina, {"Alterar", "AXALTERA", 0, 4})
//     aAdd(aRotina, {"Excluir", "AXDELETA", 0, 5})
//     aAdd(aRotina, {"Importar CSV", "U_ImpCSV", 0, 6})
//     aAdd(aRotina, {"Legenda", "U_AXLEGENDA", 0, 7}) // U_ para chamar user function
// Return aRotina

User Function ImpCSV()
    // Variáveis para ler o CSV
    Local cDiret
    Local aCampos     := {}
    Local aDados      := {}
    Local aLinha      := {}
    Local AxSZXIMP    := {} // Guarda os produtos lidos do arquivo antes de gravar no BD

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
    // cDiret := cGetFile('Arquivo CSV|*.csv| Arquivo TXT|*.txt| Arquivos XML|*.xml',; // Seleção de Arquivo: cGetFile, Armazena o caminho do arqv: cDiret
    //     'Selecao de Arquivos',;                                         // Titulo da janela
    //     0,;                                                             // Filtro inicial
    //     'C:\csv\',;                                                     // Pasta inicial
    //     .F.,;                                                         // Modo da janela: .F. Abrir | .T. Salvar
    //     GETF_LOCALHARD + GETF_NETWORKDRIVE,;                         // Permite buscar no disco local e rede
    //     .T.)                                                         // Exibe o diretório do servidor de aplicação ou local.

 cDiret := tFileDialog( "CSV files (*.csv) ", 'Seleção de Arquivos', , , .F., ) 
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
            If (Len(aCampos) >= 11 .AND. ;
                    (AllTrim(aCampos[1]) == "ZX_FILIAL") .AND. ;
                    (AllTrim(aCampos[2]) == "ZX_ANO") .AND. ;
                    (AllTrim(aCampos[3]) == "ZX_MES") .AND. ;
                    (AllTrim(aCampos[4]) == "ZX_GRUPO") .AND. ;
                    (AllTrim(aCampos[5]) == "ZX_DESC") .AND. ;
                    (AllTrim(aCampos[6]) == "ZX_CUSO") .AND. ;
                    (AllTrim(aCampos[7]) == "ZX_CUSTD") .AND. ;
                    (AllTrim(aCampos[8]) == "ZX_CUSCALC") .AND. ;
                    (AllTrim(aCampos[9]) == "ZX_PRODUTO") .AND. ;
                    (AllTrim(aCampos[10]) == "ZX_CUSLIQ")) .AND. ;
                    (AllTrim(aCampos[11]) == "ZX_CUSFIC")

                lPrimLin := .F.                         // Desliga a flag de primeira linha.

                // Validação do cabeçalho (Segunda linha do arquivo)
                FT_FSKIP()                             // Pula para a próxima linha (cabeçalho)
                Loop
            Else
                Alert("Cabeçalho da tabela não foi encontrado, indique no arquivo os campos: ZX_FILIAL;ZX_ANO;ZX_MES;ZX_GRUPO;ZX_DESC;ZX_CUSO;ZX_CUSTD;ZX_CUSCALC;ZX_PRODUTO;ZX_CUSLIQ;ZX_CUSFIC")
                FT_FUSE() // Fecha o arquivo
                Return
            Endif
        Endif

        // Leitura dos dados a partir da terceira linha
        aDados := aLinha

        // -------- verifica se o array  tem os 11 itens esperados antes de gravá-lo no array de importação
        If Len(aDados) >= 11
            Aadd(AxSZXIMP, {AllTrim(aDados[1]), AllTrim(aDados[2]), AllTrim(aDados[3]), AllTrim(aDados[4]), AllTrim(aDados[5]), AllTrim(aDados[6]), AllTrim(aDados[7]), AllTrim(aDados[8]), AllTrim(aDados[9]), AllTrim(aDados[10]), AllTrim(aDados[11])})
        EndIf

        FT_FSKIP()                                         // Move para a próxima linha do CSV
    EndDo

    FT_FUSE() // Libera/fecha o arquivo da memória após terminar a leitura

    // --------------Grava no BD
    qtdaux := Len(AxSZXIMP) // Guarda a quantidade total de registros lidos
    ProcRegua(qtdaux)                                    // Inicia o processo da Regua de gravação

    Begin Transaction                                     // Abre transação com o BD para garantir integridade

        If qtdaux != 0                                    // Verifica se o array não está vazio
            dbSelectArea("SZX")                         // Define a SZX como ativa
            SZX->(dbSetOrder(1))                // Ativa o Índice 1 da SZX

            For njx := 1 to qtdaux                        // Loop por todos os itens guardados no array

                IncProc("Analisando e gravando registro " + cValToChar(nAtual) + " de " + cValToChar(qtdaux) + "...")

                // Verifica se os campos não estão vazios
                If (!Empty(AxSZXIMP[njx][2])) .AND. (!Empty(AxSZXIMP[njx][3])) .AND. (!Empty(AxSZXIMP[njx][4]))

                    SZX->(dbSetOrder(1))

                    // Ajusta o tamanho do código para o Dicionário (SX3) e evita repetição de código
                    cCodAux := Padr(AllTrim(AxSZXIMP[njx][9]), TamSX3("ZX_PRODUTO")[1])
                    cCodBusca := Padr(AllTrim(AxSZXIMP[njx][2]), TamSX3("ZX_ANO")[1]) + Padr(AllTrim(AxSZXIMP[njx][3]), TamSX3("ZX_MES")[1]) + Padr(AllTrim(AxSZXIMP[njx][4]), TamSX3("ZX_GRUPO")[1])

                    dbSelectArea("SB1")
                    SB1->(dbSetOrder(1))

                    If !SB1->(DBSEEK(xFilial("SB1") + cCodAux))
                        // If !SB1->(DBSEEK(xFilial("SB1") + Padr(AllTrim(AxSZXIMP[njx][9]), TamSX3("B1_COD")[1])))
                        nErros++
                        cLinhasErro += "Registro " + cValToChar(njx) + " (" + AllTrim(cCodAux) + "): Produto não cadastrado na tabela SB1." + CRLF
                        dbSelectArea("SZX")
                        SZX->(dbSetOrder(1))
                        nAtual++
                        Loop
                    EndIf

                    dbSelectArea("SB2")
                    SB2->(dbSetOrder(1))

                    //If !SB2->(DBSEEK(xFilial("SB2") + cCodAux))
                    If !SB2->(DBSEEK(xFilial("SB2") + Padr(AllTrim(AxSZXIMP[njx][9]), TamSX3("B2_COD")[1])))
                        nErros++
                        cLinhasErro += "Registro " + cValToChar(njx) + " (" + AllTrim(cCodAux) + "): Produto não encontrado na tabela SB2." + CRLF
                        dbSelectArea("SZX")
                        SZX->(dbSetOrder(1))
                        nAtual++
                        Loop
                    Else
                        // Verifica se o custo na SB2 é negativo
                        If SB2->B2_VATU1 < 0
                            nErros++
                            cLinhasErro += "Registro " + cValToChar(njx) + " (" + AllTrim(cCodAux) + "): Produto possui custo negativo (B2_VATU1) na SB2." + CRLF
                            dbSelectArea("SZX")
                            SZX->(dbSetOrder(1))
                            nAtual++
                            Loop
                        EndIf
                    EndIf

                    //Seleciona e posiciona a SZX para verificar se o registro JÁ EXISTE na SZX
                    dbSelectArea("SZX")
                    SZX->(dbSetOrder(1))

                    If SZX->(DBSEEK(xFilial("SZX") + cCodBusca))
                        Reclock("SZX", .F.)

                        // Verifica se algum campo mudou
                        If SZX->ZX_DESC <> AxSZXIMP[njx][5] .OR. ;
                                SZX->ZX_CUSO <> Val(StrTran(AxSZXIMP[njx][6], ",", ".")) .OR. ;
                               SZX->ZX_CUSTD <> Val(StrTran(AxSZXIMP[njx][7], ",", ".")) .OR. ;
                                SZX->ZX_CUSCALC <> Val(StrTran(AxSZXIMP[njx][8], ",", ".")) .OR. ;
                                SZX->ZX_PRODUTO <> AxSZXIMP[njx][9] .OR. ;
                                SZX->ZX_CUSLIQ <> Val(StrTran(AxSZXIMP[njx][10], ",", ".")) .OR. ;
                                SZX->ZX_CUSFIC <> Val(StrTran(AxSZXIMP[njx][11], ",", "."))

                            // Se algum campo mudou ATUALIZA
                            Reclock("SZX", .F.)
                            //SZX->ZX_FILIAL := xFilial("SZX")
                            SZX->ZX_ANO      := AxSZXIMP[njx][2]
                            SZX->ZX_MES      := AxSZXIMP[njx][3]
                            SZX->ZX_GRUPO    := AxSZXIMP[njx][4]
                            SZX->ZX_DESC     := AxSZXIMP[njx][5]              // Descrição
                            SZX->ZX_CUSO     := Val(StrTran(AxSZXIMP[njx][6], ",", ".")) // Converte para Número
                            SZX->ZX_CUSTD    := Val(StrTran(AxSZXIMP[njx][7], ",", "."))
                            SZX->ZX_CUSCALC  := Val(StrTran(AxSZXIMP[njx][8], ",", ".")) //StrTran()substitui: a vírgula pelo ponto
                            SZX->ZX_PRODUTO  := AxSZXIMP[njx][9]
                            SZX->ZX_CUSLIQ   := Val(StrTran(AxSZXIMP[njx][10], ",", "."))
                            SZX->ZX_CUSFIC   := Val(StrTran(AxSZXIMP[njx][11], ",", "."))
                            MsUnlock() // Destrava o registro e confirma a gravação na tabela

                            nAlterados++
                        Else
                            // Registro idêntico -> NÃO grava, apenas contabiliza como duplicado
                            nDuplicados++
                        EndIf
                    Else
                        // Se NÃO ENCONTROU -> INCLUI
                        Reclock("SZX", .T.)
                        SZX->ZX_FILIAL  := xFilial("SZX")
                        SZX->ZX_ANO     := AxSZXIMP[njx][2]
                        SZX->ZX_MES     := AxSZXIMP[njx][3]
                        SZX->ZX_GRUPO   := AxSZXIMP[njx][4]
                        SZX->ZX_DESC    := AxSZXIMP[njx][5]
                        SZX->ZX_CUSO    := Val(StrTran(AxSZXIMP[njx][6], ",", "."))
                        SZX->ZX_CUSTD   := Val(StrTran(AxSZXIMP[njx][7], ",", "."))
                        SZX->ZX_CUSCALC := Val(StrTran(AxSZXIMP[njx][8], ",", "."))
                        SZX->ZX_PRODUTO := AxSZXIMP[njx][9]
                        SZX->ZX_CUSLIQ  := Val(StrTran(AxSZXIMP[njx][10], ",", "."))
                        SZX->ZX_CUSFIC  := Val(StrTran(AxSZXIMP[njx][11], ",", "."))
                        MsUnlock()

                        nIncluidos++
                    EndIf
                Else
                    nErros++
                    cLinhasErro += "Registro " + cValToChar(njx) + ": "

                    If !Empty(AxSZXIMP[njx][4])
                        cLinhasErro += (AxSZXIMP[njx][4]) + " "
                    EndIf

                    // Validação para identificar qual campo está vazio ou inválido
                    If Empty(AxSZXIMP[njx][2])
                        cLinhasErro += "Ano não informado "
                    EndIf

                    If Empty(AxSZXIMP[njx][3])
                        cLinhasErro += "Mês não informado "
                    EndIf

                    If Empty(AxSZXIMP[njx][4])
                        cLinhasErro += "Grupo não informado "
                    EndIf

                    cLinhasErro += CRLF
                EndIf

                nAtual++
            Next
        EndIf
    End Transaction

    If nErros == 0
       // cMsg += "Leitura do arquivo CSV finalizada!" + CRLF + CRLF
        cMsg += "Total de linhas no arquivo: " + cValToChar(qtdaux) + CRLF
        cMsg += "Novos registros inseridos: " + cValToChar(nIncluidos) + CRLF
        cMsg += "Registros atualizados: " + cValToChar(nAlterados) + CRLF
        cMsg += "Registros duplicados (não inseridos): " + cValToChar(nDuplicados) + CRLF
        FWAlertSuccess(cMsg, "Resultado da Importação")
    Else
       // cMsg += "Leitura do arquivo CSV finalizada!" + CRLF + CRLF
        cMsg += "Linhas não inseridas (erros): " + cValToChar(nErros) + CRLF
      //  cMsg += CRLF + "As seguintes linhas não foram inseridas, verifique: " + CRLF
        cMsg += cLinhasErro + CRLF
        cMsg += "Novos registros inseridos: " + cValToChar(nIncluidos) + CRLF
        cMsg += "Registros atualizados: " + cValToChar(nAlterados) + CRLF
        cMsg += "Registros duplicados (não inseridos): " + cValToChar(nDuplicados) + CRLF
        FWAlertWarning(cMsg, "Resultado da Importação (Aviso)")
    EndIf
Return

User Function VisuCSV()
    DbSelectArea("SZX")
    SZX->(DbSetOrder(1))
    AxCadastro("SZX", "Cadastro dos Registros Importados")
Return
