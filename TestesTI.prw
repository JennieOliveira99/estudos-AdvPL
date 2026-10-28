#include "totvs.ch"
#include "protheus.ch"
#include "TOPCONN.CH"

Static aErrosImp := {}

User Function ImpCusto()
    // Variáveis para ler o CSV
    Local cDiret
    Local aCampos     := {}
    Local aLinha      := {}
    Local AxSZXIMP    := {} // Guarda os produtos lidos do arquivo antes de gravar no BD

    // Variáveis de controle
    Local lPrimLin    := .T.
    Local njx         := 1    // Índice da linha atual no loop
    Local nAtual      := 1
    Local qtdeMax     := 0
    Local nIncluidos  := 0
    Local nAlterados  := 0
    Local nDuplicados := 0
    Local nErros      := 0
    Local cLinhasErro := ""
    Local cMotivo     := ""
    Local cMsg        := ""
    Local cLinha      := ""
    Local cCodAux     := ""   // Código do grupo/produto
    Local cCodBusca   := ""   // Chave de busca: Ano + Mês + Grupo

    // Valores numéricos da linha atual (convertidos do CSV)
    Local nCustd      := 0
    Local nCusLiq     := 0
    Local nCusFic     := 0

    // Validação de divergência de custo
    Local lExisteSZX  := .F.
    Local nCustoAnt   := 0
    Local nTolerancia := 0.20 // 20% de tolerância
    Local nPercDif    := 0

    // Limpa os erros de importações anteriores
    aErrosImp := {}

    // Abrir uma tela para escolher o arquivo
    cDiret := tFileDialog( "CSV files (*.csv) ", 'Seleção de Arquivos', , , .F., )

    // Se o usuário fechar a tela sem escolher um arquivo, a rotina é encerrada
    If Empty(cDiret)
        Alert("Nenhum arquivo selecionado.")
        Return
    EndIf

    // Leitura do arquivo
    FT_FUSE(cDiret)
    ProcRegua(FT_FLASTREC())                // Total de linhas do arquivo
    FT_FGOTOP()                             // Posiciona no início do arquivo

    While !FT_FEOF()
        IncProc('Lendo Arquivo texto...')

        // Limpeza dos caracteres ocultos e quebras de linha
        cLinha := FT_FREADLN()
        cLinha := StrTran(cLinha, Chr(13), "")
        cLinha := StrTran(cLinha, Chr(10), "")
        cLinha := StrTran(cLinha, '"', "")

        // Remove marcação BOM UTF-8 se estiver na primeira linha
        If lPrimLin
            cLinha := StrTran(cLinha, Chr(239)+Chr(187)+Chr(191), "")
        EndIf

        aLinha := Separa(cLinha, ";", .T.)  // Fatia a linha usando ";"

        // Validação do cabeçalho (primeira linha do arquivo)
        If lPrimLin
            aCampos := aLinha

            // Confere se o nome de cada coluna está na ordem esperada
            If Len(aCampos) >= 7 .AND. ;
                    AllTrim(aCampos[1]) == "ZX_FILIAL" .AND. ;
                    AllTrim(aCampos[2]) == "ZX_ANO"    .AND. ;
                    AllTrim(aCampos[3]) == "ZX_MES"    .AND. ;
                    AllTrim(aCampos[4]) == "ZX_GRUPO"  .AND. ;
                    AllTrim(aCampos[5]) == "ZX_CUSTD"  .AND. ;
                    AllTrim(aCampos[6]) == "ZX_CUSLIQ" .AND. ;
                    AllTrim(aCampos[7]) == "ZX_CUSFIC"

                lPrimLin := .F.     // Desliga a flag de primeira linha
                FT_FSKIP()
                Loop
            Else
                Alert("Cabeçalho da tabela não foi encontrado, indique no arquivo os campos:" + CRLF + "ZX_FILIAL;ZX_ANO;ZX_MES;ZX_GRUPO;ZX_CUSTD;ZX_CUSLIQ;ZX_CUSFIC")
                FT_FUSE() // Fecha o arquivo
                Return
            EndIf
        EndIf

        // Verifica se a linha tem os 7 itens esperados antes de guardar no array de importação
        If Len(aLinha) >= 7
            Aadd(AxSZXIMP, {AllTrim(aLinha[1]), AllTrim(aLinha[2]), AllTrim(aLinha[3]), AllTrim(aLinha[4]), AllTrim(aLinha[5]), AllTrim(aLinha[6]), AllTrim(aLinha[7])})
        EndIf

        FT_FSKIP()  // Próxima linha do CSV
    EndDo

    FT_FUSE() // Fecha o arquivo após terminar a leitura

    // -------------- Grava no BD
    qtdeMax := Len(AxSZXIMP)
    ProcRegua(qtdeMax)

    Begin Transaction

        If qtdeMax != 0
            dbSelectArea("SZX")
            SZX->(dbSetOrder(1))

            For njx := 1 to qtdeMax

                IncProc("Analisando e gravando registro " + cValToChar(nAtual) + " de " + cValToChar(qtdeMax) + "...")

                // Verifica se os campos obrigatórios Ano, Mês e Grupo não estão vazios
                If !Empty(AxSZXIMP[njx][2]) .AND. !Empty(AxSZXIMP[njx][3]) .AND. !Empty(AxSZXIMP[njx][4])

                    // Validação numérica
                    If !IsNumeric(AxSZXIMP[njx][2]) .OR. ;
                            !IsNumeric(AxSZXIMP[njx][3]) .OR. ;
                            !IsNumDot(StrTran(AxSZXIMP[njx][5], ",", ".")) .OR. ;
                            !IsNumDot(StrTran(AxSZXIMP[njx][6], ",", ".")) .OR. ;
                            !IsNumDot(StrTran(AxSZXIMP[njx][7], ",", "."))

                        nErros++
                        cMotivo := ""
                        cLinhasErro += "Registro " + cValToChar(njx) + " (" + AllTrim(AxSZXIMP[njx][4]) + "): "

                        If !IsNumeric(AxSZXIMP[njx][2])
                            cMotivo += "Ano inválido [" + AxSZXIMP[njx][2] + "] "
                        EndIf
                        If !IsNumeric(AxSZXIMP[njx][3])
                            cMotivo += "Mês inválido [" + AxSZXIMP[njx][3] + "] "
                        EndIf
                        If !IsNumDot(StrTran(AxSZXIMP[njx][5], ",", "."))
                            cMotivo += "ZX_CUSTD inválido [" + AxSZXIMP[njx][5] + "] "
                        EndIf
                        If !IsNumDot(StrTran(AxSZXIMP[njx][6], ",", "."))
                            cMotivo += "ZX_CUSLIQ inválido [" + AxSZXIMP[njx][6] + "] "
                        EndIf
                        If !IsNumDot(StrTran(AxSZXIMP[njx][7], ",", "."))
                            cMotivo += "ZX_CUSFIC inválido [" + AxSZXIMP[njx][7] + "] "
                        EndIf

                        cLinhasErro += cMotivo + CRLF

                        aAdd(aErrosImp, { ;
                            AxSZXIMP[njx][2],; // Ano
                            AxSZXIMP[njx][3],; // Mês
                            AxSZXIMP[njx][4],; // Grupo
                            AxSZXIMP[njx][5],; // Custo Padrão
                            AxSZXIMP[njx][6],; // Custo Líquido
                            AxSZXIMP[njx][7],; // Custo Fictício
                            AllTrim(cMotivo) })

                        nAtual++
                        Loop
                    EndIf

                    // Converte os custos do CSV para número (troca vírgula por ponto)
                    nCustd  := Val(StrTran(AxSZXIMP[njx][5], ",", "."))
                    nCusLiq := Val(StrTran(AxSZXIMP[njx][6], ",", "."))
                    nCusFic := Val(StrTran(AxSZXIMP[njx][7], ",", "."))

                    // Ajusta o código do grupo ao tamanho definido na SX3
                    cCodAux := Padr(AllTrim(AxSZXIMP[njx][4]), TamSX3("ZX_GRUPO")[1])

                    // Chave de busca da SZX: Ano + Mês + Grupo
                    cCodBusca := Padr(AllTrim(AxSZXIMP[njx][2]), TamSX3("ZX_ANO")[1]) + ;
                                 Padr(AllTrim(AxSZXIMP[njx][3]), TamSX3("ZX_MES")[1]) + ;
                                 cCodAux

                    // Validação SB1: o grupo precisa existir
                    dbSelectArea("SB1")
                    SB1->(dbSetOrder(4))

                    If !SB1->(DBSEEK(xFilial("SB1") + cCodAux))
                        nErros++
                        cLinhasErro += "Registro " + cValToChar(njx) + " (" + AllTrim(cCodAux) + "): Grupo não encontrado na tabela SB1." + CRLF

                        aAdd(aErrosImp, { ;
                            AxSZXIMP[njx][2],; // Ano
                            AxSZXIMP[njx][3],; // Mês
                            AxSZXIMP[njx][4],; // Grupo
                            AxSZXIMP[njx][5],; // Custo Padrão
                            AxSZXIMP[njx][6],; // Custo Líquido
                            AxSZXIMP[njx][7],; // Custo Fictício
                            "Grupo não encontrado na tabela SB1" })

                        nAtual++
                        Loop
                    EndIf

                    // Volta para a SZX e verifica se o registro já existe
                    dbSelectArea("SZX")
                    SZX->(dbSetOrder(1))
                    lExisteSZX := SZX->(DBSEEK(xFilial("SZX") + cCodBusca))

                    // Validação: novo CUSTD não pode divergir mais que 20% do CUSO atual
                    If lExisteSZX
                        nCustoAnt := SZX->ZX_CUSO

                        If nCustoAnt > 0
                            nPercDif := (nCustd - nCustoAnt) / nCustoAnt

                            If Abs(nPercDif) > nTolerancia
                                nErros++
                                cLinhasErro += "Registro " + cValToChar(njx) + " (" + AllTrim(cCodAux) + "): Divergência de custo acima da tolerância. CUSO Anterior: " + cValToChar(nCustoAnt) + " | Novo CUSTD: " + cValToChar(nCustd) + CRLF

                                aAdd(aErrosImp, { ;
                                    AxSZXIMP[njx][2],; // Ano
                                    AxSZXIMP[njx][3],; // Mês
                                    AxSZXIMP[njx][4],; // Grupo
                                    AxSZXIMP[njx][5],; // Custo Padrão
                                    AxSZXIMP[njx][6],; // Custo Líquido
                                    AxSZXIMP[njx][7],; // Custo Fictício
                                    "Divergência de custo acima da tolerância. CUSO Anterior: " + cValToChar(nCustoAnt) + " | Novo CUSTD: " + cValToChar(nCustd) })

                                nAtual++
                                Loop
                            EndIf
                        EndIf
                    EndIf

                    // ------------------ Gravação ------------------
                    If lExisteSZX
                        // Só grava se algum custo mudou
                        If SZX->ZX_CUSTD  <> nCustd  .OR. ;
                           SZX->ZX_CUSLIQ <> nCusLiq .OR. ;
                           SZX->ZX_CUSFIC <> nCusFic

                            Reclock("SZX", .F.)
                            SZX->ZX_CUSTD  := nCustd
                            SZX->ZX_CUSLIQ := nCusLiq
                            SZX->ZX_CUSFIC := nCusFic
                            MsUnlock()
                            nAlterados++
                        Else
                            // Registro idêntico: não grava, contabiliza como duplicado
                            nDuplicados++
                        EndIf
                    Else
                        // Não encontrou: inclui
                        Reclock("SZX", .T.)
                        SZX->ZX_FILIAL  := xFilial("SZX")
                        SZX->ZX_ANO     := AxSZXIMP[njx][2]
                        SZX->ZX_MES     := AxSZXIMP[njx][3]
                        SZX->ZX_GRUPO   := AxSZXIMP[njx][4]
                        SZX->ZX_CUSTD   := nCustd
                        SZX->ZX_CUSLIQ  := nCusLiq
                        SZX->ZX_CUSFIC  := nCusFic
                        SZX->ZX_DESC    := ""
                        SZX->ZX_PRODUTO := ""
                        SZX->ZX_CUSO    := 0
                        SZX->ZX_CUSCALC := 0
                        MsUnlock()
                        nIncluidos++
                    EndIf

                Else
                    // Campos obrigatórios vazios
                    nErros++
                    cMotivo := ""
                    cLinhasErro += "Registro " + cValToChar(njx) + ": "

                    If !Empty(AxSZXIMP[njx][4])
                        cLinhasErro += AxSZXIMP[njx][4] + " "
                    EndIf

                    If Empty(AxSZXIMP[njx][2])
                        cMotivo += "Ano não informado "
                    EndIf

                    If Empty(AxSZXIMP[njx][3])
                        cMotivo += "Mês não informado "
                    EndIf

                    If Empty(AxSZXIMP[njx][4])
                        cMotivo += "Grupo não informado "
                    EndIf

                    cLinhasErro += cMotivo + CRLF

                    aAdd(aErrosImp, { ;
                        AxSZXIMP[njx][2],; // Ano
                        AxSZXIMP[njx][3],; // Mês
                        AxSZXIMP[njx][4],; // Grupo
                        AxSZXIMP[njx][5],; // Custo Padrão
                        AxSZXIMP[njx][6],; // Custo Líquido
                        AxSZXIMP[njx][7],; // Custo Fictício
                        AllTrim(cMotivo) })
                EndIf

                nAtual++
            Next
        EndIf
    End Transaction

    If nErros == 0
        cMsg += "Total de linhas no arquivo: " + cValToChar(qtdeMax) + CRLF
        cMsg += "Novos registros inseridos: " + cValToChar(nIncluidos) + CRLF
        cMsg += "Registros atualizados: " + cValToChar(nAlterados) + CRLF
        cMsg += "Registros duplicados (não inseridos): " + cValToChar(nDuplicados) + CRLF
        FWAlertSuccess(cMsg, "Resultado da Importação")
    Else
        cMsg += "Linhas não inseridas (erros): " + cValToChar(nErros) + CRLF
        cMsg += cLinhasErro + CRLF
        cMsg += "Novos registros inseridos: " + cValToChar(nIncluidos) + CRLF
        cMsg += "Registros atualizados: " + cValToChar(nAlterados) + CRLF
        cMsg += "Registros duplicados (não inseridos): " + cValToChar(nDuplicados) + CRLF
        FWAlertWarning(cMsg, "Resultado da Importação")

        U_ErrosCusto()
    EndIf
Return


User Function ErrosCusto()

    Local oFWMsExcel
    Local nX
    Local cNomeArq := "Erros_Importacao_Custos.xml"
    Local cArqSrv  := "\system\" + cNomeArq

    // Se a importação não gerou nenhum erro, não há o que exportar
    If Len(aErrosImp) == 0
        MsgAlert("Nenhum erro encontrado na importação.")
        Return
    EndIf

    oFWMsExcel := FWMsExcel():New()     // Cria o Excel em memória 

    // Cria a aba (planilha) com o nome que aparece na parte de baixo do Excel
    oFWMsExcel:AddWorkSheet("Custos Não Importados")

    // Cria uma tabela dentro da aba
    oFWMsExcel:AddTable("Custos Não Importados","Importacao")

    // Define as colunas da tabela
    oFWMsExcel:AddColumn("Custos Não Importados","Importacao","Ano",1,1)
    oFWMsExcel:AddColumn("Custos Não Importados","Importacao","Mês",1,1)
    oFWMsExcel:AddColumn("Custos Não Importados","Importacao","Grupo",1,1)
    oFWMsExcel:AddColumn("Custos Não Importados","Importacao","Custo Padrão (ZX_CUSTD)",1,1)
    oFWMsExcel:AddColumn("Custos Não Importados","Importacao","Custo Líquido (ZX_CUSLIQ)",1,1)
    oFWMsExcel:AddColumn("Custos Não Importados","Importacao","Custo Fictício (ZX_CUSFIC)",1,1)
    oFWMsExcel:AddColumn("Custos Não Importados","Importacao","Motivo",1,1)

    // Adiciona uma linha na planilha para cada registro não importado
    For nX := 1 To Len(aErrosImp)
        oFWMsExcel:AddRow("Custos Não Importados", "Importacao", aErrosImp[nX])
    Next

    oFWMsExcel:Activate()
    oFWMsExcel:GetXMLFile(cArqSrv)          // grava no servidor

    CpyS2T(cArqSrv, GetTempPath())          // envia para a máquina do usuário

    FErase(cArqSrv)                         // remove o arquivo temporário do servidor

Return

User Function VisuCusto()
    DbSelectArea("SZX")
    SZX->(DbSetOrder(1))
    AxCadastro("SZX", "Visualizar Custos")
Return
