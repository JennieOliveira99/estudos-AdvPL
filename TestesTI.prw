#include "totvs.ch"
#include "protheus.ch"
#include "TOPCONN.CH"

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
    Local nErros     := 0
    Local cLinhasErro:= ""
    Local cMsg := ""

    Local cLinha      := ""
    Local cCodAux     := ""

    // Captura do ambiente original (compatível com versões antigas)
    Local cEmpAnt := GetMV("EMPRESA") // GetMv busca e retorna o valor de um parâmetro cadastrado na SX6 parametros
    Local cFilAnt := GetMV("FILIAL")
    // Empresas a serem processadas
    Local aEmpresas := {"01", "03"}
    Local cEmpAtual := ""
    Local i := 0

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
                    (AllTrim(aCampos[5]) == "VALOR"))

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
        If Len(aDados) >= 5
            Aadd(AxZF1IMP, {AllTrim(aDados[1]), AllTrim(aDados[2]), AllTrim(aDados[3]), AllTrim(aDados[4]), AllTrim(aDados[5])})
        EndIf

        FT_FSKIP()                                         // Move para a próxima linha do CSV

    EndDo

    FT_FUSE() // Libera/fecha o arquivo da memória após terminar a leitura

    // --------------Grava no BD
    qtdaux := Len(AxZF1IMP) // Guarda a quantidade total de registros lidos

    // Régua ajustada para processar duas vezes (empresa 01 e 03)
    ProcRegua(qtdaux * 2)   //loop será executado duas vezes (empresas 01 e 03)

    Begin Transaction                                     // Abre transação com o BD para garantir integridade

        If qtdaux != 0                                    // Verifica se o array não está vazio

//Loop que atribui a empresa atual à variável cEmpAtual,
// e chama RpcSetEnv para trocar o ambiente para essa empresa, mantendo a filial original
            For i := 1 to Len(aEmpresas)                 // Loop por todas as empresas definidas no array
                cEmpAtual := aEmpresas[i]

                // Define o ambiente para a empresa atual (mantém a filial original)
                RpcSetEnv(cEmpAtual, cFilAnt)

                dbSelectArea("ZF1")                         // Define a ZF1 como ativa
                ZF1->(dbSetOrder(1))                // Ativa o Índice 1 da ZF1 (ZF1_COD)

                For njx := 1 to qtdaux                        // Loop por todos os itens guardados no array
                    IncProc("Analisando e gravando registro " + cValToChar(nAtual) + " de " + cValToChar(qtdaux) + "...")

                    // Verifica se os campos não estão vazios
                    If (!Empty(AxZF1IMP[njx][1])) .AND. (!Empty(AxZF1IMP[njx][2])) .AND. (!Empty(AxZF1IMP[njx][3])) .AND. (!Empty(CToD(AxZF1IMP[njx][4]))) .AND. (!Empty(AxZF1IMP[njx][5]))
                        ZF1->(dbSetOrder(1))

                        // Ajusta o tamanho do código para o Dicionário (SX3) e evita repetição de código
                        cCodAux := Padr(AllTrim(AxZF1IMP[njx][1]), TamSX3("ZF1_COD")[1])

                        //valida se existe na tabela SB1 e SB2 o produto que está sendo importado, caso não exista, interrompe o processo
                        // dbSelectArea("SB1")
                        // SB1->(dbSetOrder(1)) // Filial + Codigo
                        // If !SB1->(DBSEEK(xFilial("SB1") + cCodAux))
                        //     Alert("Produto " + cCodAux + " não cadastrado na tabela SB1. Processo interrompido.")
                        //     DisarmTransaction()
                        //     Return
                        // EndIf

                        // dbSelectArea("SB2")
                        // SB2->(dbSetOrder(1)) // Filial + Codigo + Local
                        // If !SB2->(DBSEEK(xFilial("SB2") + cCodAux))
                        //     Alert("Produto " + cCodAux + " não encontrado na tabela SB2. Processo interrompido.")
                        //     DisarmTransaction()
                        //     Return
                        // Else
                        // //     // Verifica se o custo na SB2 é negativo
                        //     If SB2->B2_VATU1 <= 0 //B2_QATU - saldo atual, B2_VATU1 - valor atual,
                        //         Alert("Produto " + cCodAux + " possui custo negativo (B2_VATU1) na SB2. Processo interrompido.")
                        //       //  DisarmTransaction()
                        //         //Return
                        //     EndIf
                        // EndIf

                        // Busca no banco se o registro já existe
                        //If ZF1->(DBSEEK(cCodAux))
                        //If ZF1->(DBSEEK(xFilial("ZF1") + cCodAux))
                        //  If ZF1->(DBSEEK(xFilial("ZF1") + AllTrim(AxZF1IMP[njx][1]), TamSX3("ZF1_COD")[1]))
                        // Se ENCONTROU, trava para ALTERAÇÃO

                        //Seleciona e posiciona a ZF1 para verificar se o registro JÁ EXISTE na ZF1
                        dbSelectArea("ZF1")
                        ZF1->(dbSetOrder(1))// ZF1_FILIAL + ZF1_COD
                        If ZF1->(DBSEEK(xFilial("ZF1") + cCodAux)) //Passando COD e filial
                            Reclock("ZF1", .F.)
                            nAlterados++
                        Else
                            // Se NÃO ENCONTROU, trava para INCLUSÃO
                            Reclock("ZF1", .T.)
                            nIncluidos++
                        EndIf

                        // Preenche os campos do banco com os dados do array
                        ZF1->ZF1_FILIAL := xFilial("ZF1")                // Pega a filial corrente do sistema
                        ZF1->ZF1_COD    := cCodAux                       // Código
                        ZF1->ZF1_DESC   := AxZF1IMP[njx][2]              // Descrição
                        ZF1->ZF1_QTDE   := Val(StrTran(AxZF1IMP[njx][3], ",", ".")) // Converte para Número
                        ZF1->ZF1_DATA   := CToD(AxZF1IMP[njx][4])
                        ZF1->ZF1_VALOR := Val(StrTran(AxZF1IMP[njx][5], ",", ".")) //StrTran()substitui: a vírgula pelo ponto

                        MsUnlock() // Destrava o registro e confirma a gravação na tabela

                    Else
                        nErros++ //Incrementa contador de erros e guarda a linha com erro para exibir no final do processo
                        cLinhasErro += "Registro " + cValToChar(njx)+ ": "

                        If !Empty(AxZF1IMP[njx][1])
                            cLinhasErro +=  (AxZF1IMP[njx][1])  + " "
                        EndIf

                        // Validação detalhada para identificar qual campo está vazio ou inválido
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

                        cLinhasErro += CRLF
                    EndIf
                    nAtual++
                Next

            Next // Fim do For (empresas)

        EndIf

    End Transaction

    // Restaura o ambiente original
    RpcSetEnv(cEmpAnt, cFilAnt)

    If nErros == 0
        // Monta mensagem de Sucesso (nenhum erro encontrado)
        cMsg += "Leitura do arquivo CSV finalizada!" + CRLF + CRLF
        cMsg += "Total de linhas no arquivo: " + cValToChar(qtdaux) + CRLF
        cMsg += "Novos registros inseridos: " + cValToChar(nIncluidos) + CRLF
        cMsg += "Registros atualizados: " + cValToChar(nAlterados) + CRLF

        FWAlertSuccess(cMsg, "Resultado da Importação")
    Else
        // Monta mensagem de Erro / Inconsistência
        cMsg += "Leitura do arquivo CSV finalizada!" + CRLF + CRLF
        cMsg += "Linhas não inseridas (erros): " + cValToChar(nErros) + CRLF

        cMsg += CRLF + "As seguintes linhas não foram inseridas, verifique: " + CRLF
        cMsg += cLinhasErro + CRLF

        cMsg += "Novos registros inseridos: " + cValToChar(nIncluidos) + CRLF
        cMsg += "Registros atualizados: " + cValToChar(nAlterados) + CRLF

        FWAlertWarning(cMsg, "Resultado da Importação (Aviso)")
    EndIf

Return
