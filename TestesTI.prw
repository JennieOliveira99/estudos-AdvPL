#include "totvs.ch"
#include "protheus.ch"
#include "TOPCONN.CH"

User Function ImpCusto()
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
    Local qtdeMax      := 0
    Local nIncluidos := 0
    Local nAlterados := 0
    Local nDuplicados := 0
    Local nErros     := 0
    Local cLinhasErro:= ""
    Local cMsg := ""
    Local cLinha      := ""
    Local cCodAux     := "" //cod do produto

    Local lExisteSZX  := .F.
    Local nCusoAntigo := 0
    Local nCustdNovo  := 0
    Local nTolerancia := 0.20
    Local nPercDif    := 0

    // Abrir uma tela para escolher o arquivo
    cDiret := tFileDialog( "CSV files (*.csv) ", 'Seleção de Arquivos', , , .F., )

    // Se o usuário fechar a tela sem escolher um arqv, a rotina é encerrada
    If Empty(cDiret)
        Alert("Nenhum arquivo selecionado.")
        Return
    EndIf

    // Leitura arqv
    FT_FUSE(cDiret)                          // Abre/carrega na memória do Protheus o arquivo indicado pelo caminho salvo
                                            // em cDiret para disponibilizar às funções FT_F (File Text)
    ProcRegua(FT_FLASTREC())                // Lê e retorna o número total de linhas do arquivo texto aberto pela função FT_FUse()
    FT_FGOTOP()                             // Posiciona no início (primeiro caractere da primeira linha) do arquivo texto aberto pela função FT_FUse()

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

        aLinha := Separa(cLinha, ";", .T.)                // Lê a linha atual e fatia usando ";"

        // Validação da primeira linha do arquivo
        IF lPrimLin
            aCampos := aLinha                           // Lê a 1° linha (Nome das colunas)

            // Conferindo se o nome de cada coluna está na ordem esperada e removendo os espaços
            If (Len(aCampos) >= 7 .AND. ;
                    (AllTrim(aCampos[1]) == "ZX_FILIAL") .AND. ;
                    (AllTrim(aCampos[2]) == "ZX_ANO") .AND. ;
                    (AllTrim(aCampos[3]) == "ZX_MES") .AND. ;
                    (AllTrim(aCampos[4]) == "ZX_GRUPO") .AND. ;
                    (AllTrim(aCampos[5]) == "ZX_CUSTD") .AND. ;
                    (AllTrim(aCampos[6]) == "ZX_CUSLIQ")) .AND. ;
                    (AllTrim(aCampos[7]) == "ZX_CUSFIC")

                lPrimLin := .F.                         // Desliga a flag de primeira linha.

                // Validação do cabeçalho (Segunda linha do arquivo)
                FT_FSKIP()                             // Pula para a próxima linha (cabeçalho)
                Loop
            Else
                Alert("Cabeçalho da tabela não foi encontrado, indique no arquivo os campos:"+ CRLF + "ZX_FILIAL;ZX_ANO;ZX_MES;ZX_GRUPO;ZX_CUSTD;ZX_CUSLIQ;ZX_CUSFIC")
                FT_FUSE() // Fecha o arquivo
                Return
            Endif
        Endif

        // Leitura dos dados a partir da terceira linha
        aDados := aLinha

        // -------- verifica se o array  tem os 11 itens esperados antes de gravá-lo no array de importação
        If Len(aDados) >= 7
            Aadd(AxSZXIMP, {AllTrim(aDados[1]), AllTrim(aDados[2]), AllTrim(aDados[3]), AllTrim(aDados[4]), AllTrim(aDados[5]), AllTrim(aDados[6]), AllTrim(aDados[7])})
        EndIf

        FT_FSKIP()                                         // Move para a próxima linha do CSV
    EndDo

    FT_FUSE() // Libera/fecha o arquivo da memória após terminar a leitura

    // --------------Grava no BD
    qtdeMax := Len(AxSZXIMP) // Guarda a quantidade total de registros lidos
    ProcRegua(qtdeMax)                                    // Inicia o processo da Regua de gravação

    Begin Transaction                                     // Abre transação com o BD 

        If qtdeMax != 0                                   // Verifica se o array não está vazio
            dbSelectArea("SZX")                          // Define a SZX como ativa
            SZX->(dbSetOrder(1))                        // Ativa o Índice 1 da SZX


            For njx := 1 to qtdeMax                     // Loop por todos os itens guardados no array

                IncProc("Analisando e gravando registro " + cValToChar(nAtual) + " de " + cValToChar(qtdeMax) + "...")

                // Verifica se os campos obrigatórios Ano, Mês e Grupo da linha atual (njx) não estão vazios.
                If (!Empty(AxSZXIMP[njx][2])) .AND. (!Empty(AxSZXIMP[njx][3])) .AND. (!Empty(AxSZXIMP[njx][4]))

                    SZX->(dbSetOrder(1)) //Posiciona a tabela SZX no índice 1

                    // Ajusta o tamanho do código do produto, remove espaços de acordo com o tamanho definido na SX3
                    cCodAux := Padr(AllTrim(AxSZXIMP[njx][4]), TamSX3("ZX_GRUPO")[1])
                    //Monta a chave de busca da SZX, concatenando Ano + Mês + Grupo, ajustado ao tamanho acordo com o tamanho definido na SX3
                    cCodBusca := Padr(AllTrim(AxSZXIMP[njx][2]), TamSX3("ZX_ANO")[1]) + Padr(AllTrim(AxSZXIMP[njx][3]), TamSX3("ZX_MES")[1]) + Padr(AllTrim(AxSZXIMP[njx][4]), TamSX3("ZX_GRUPO")[1])


                    //Validação SB1
                    dbSelectArea("SB1")
                    SB1->(dbSetOrder(4))

                    If !SB1->(DBSEEK(xFilial("SB1") + cCodAux)) //Se não encontrou o cod do prod na SB1
                        nErros++
                        cLinhasErro += "Registro " + cValToChar(njx) + " (" + AllTrim(cCodAux) + "): Grupo não encontrado na tabela SB1." + CRLF
                        dbSelectArea("SZX")
                        SZX->(dbSetOrder(1))
                        nAtual++
                        Loop
                    EndIf



                    //validação zx_cuso possui muita diferença para ZX_CUSTD


                    dbSelectArea("SZX")                          // Define a SZX como ativa
                    SZX->(dbSetOrder(1))  


                    lExisteSZX := SZX->(DBSEEK(xFilial("SZX") + cCodBusca))
                    nCusoAntigo := 0

                    If lExisteSZX
                        nCusoAntigo := SZX->ZX_CUSO

                        nCustdNovo := Val(StrTran(AxSZXIMP[njx][5], ",", "."))
                        nTolerancia := 0.20 //20% de tolerancia

                        If nCusoAntigo > 0
                        nPercDif := ((nCustdNovo - nCustAntigo)/ nCusoAntigo)

                        //Abs() pega o valor absoluto
                        If Abs(nPercDif) > nTolerancia
                        nErros++
                        cLinhasErro += "Registro " + cValToChar(njx) + " (" + AllTrim(cCodAux) + "): Divergência de custo acima da tolerância. CUSO Anterior: " + cValToChar(nCusoAntigo) + " | Novo CUSTD: " + cValToChar(nCustdNovo) + CRLF
                                        //     dbSelectArea("SZX")
                        SZX->(dbSetOrder(1))
                        nAtual++
                            Loop
                            EndIf
                        EndIf
                    EndIf

                    //validação sb2 comentada pois nao recebemos o codigo pelo csv entao nao tem como comparar
                    // dbSelectArea("SB2")
                    // SB2->(dbSetOrder(1))

                    //     If !SB2->(DBSEEK(xFilial("SB2") + cCodAux))
                    //     //If !SB2->(DBSEEK(xFilial("SB2") + Padr(AllTrim(AxSZXIMP[njx][9]), TamSX3("B2_COD")[1])))
                    //     nErros++
                    //     cLinhasErro += "Registro " + cValToChar(njx) + " (" + AllTrim(cCodAux) + "): Produto não encontrado na tabela SB2." + CRLF
                    //     dbSelectArea("SZX")
                    //     SZX->(dbSetOrder(1))
                    //     nAtual++
                    //     Loop
                    // Else
                    //     // Verifica se o custo na SB2 é negativo
                    //     If SB2->B2_VATU1 < 0
                    //         nErros++
                    //         cLinhasErro += "Registro " + cValToChar(njx) + " (" + AllTrim(cCodAux) + "): Produto possui custo negativo (B2_VATU1) na SB2." + CRLF
                    //         dbSelectArea("SZX")
                    //         SZX->(dbSetOrder(1))
                    //         nAtual++
                    //         Loop
                    //     EndIf
                   

                    //Seleciona e posiciona a SZX para verificar se o registro JÁ EXISTE na SZX
                    dbSelectArea("SZX")
                    SZX->(dbSetOrder(1))

                    If SZX->(DBSEEK(xFilial("SZX") + cCodBusca))
                        Reclock("SZX", .F.)


                        // Verifica se algum campo mudou
                        If SZX->ZX_GRUPO <> AxSZXIMP[njx][4] .OR. ;
                                SZX->ZX_CUSTD <> Val(StrTran(AxSZXIMP[njx][5], ",", ".")) .OR. ;
                                SZX->ZX_CUSLIQ <> Val(StrTran(AxSZXIMP[njx][6], ",", ".")) .OR. ;
                                SZX->ZX_CUSFIC <> Val(StrTran(AxSZXIMP[njx][7], ",", "."))

                            // Se algum campo mudou ATUALIZA
                            Reclock("SZX", .F.)

                            //SZX->ZX_FILIAL := xFilial("SZX")
                            SZX->ZX_ANO      := AxSZXIMP[njx][2]
                            SZX->ZX_MES      := AxSZXIMP[njx][3]
                            SZX->ZX_GRUPO    := AxSZXIMP[njx][4]
                            SZX->ZX_CUSTD    := Val(StrTran(AxSZXIMP[njx][5], ",", "."))
                            SZX->ZX_CUSLIQ   := Val(StrTran(AxSZXIMP[njx][6], ",", "."))
                            SZX->ZX_CUSFIC   := Val(StrTran(AxSZXIMP[njx][7], ",", "."))
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
                        SZX->ZX_CUSTD   := Val(StrTran(AxSZXIMP[njx][5], ",", "."))
                        SZX->ZX_CUSLIQ  := Val(StrTran(AxSZXIMP[njx][6], ",", "."))
                        SZX->ZX_CUSFIC  := Val(StrTran(AxSZXIMP[njx][7], ",", "."))
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
        cMsg += "Total de linhas no arquivo: " + cValToChar(qtdeMax) + CRLF
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

User Function VisuCusto()
    DbSelectArea("SZX")
    SZX->(DbSetOrder(1))
    AxCadastro("SZX", "Visualizar Custos")
Return
