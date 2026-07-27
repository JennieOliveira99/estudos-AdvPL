#include "totvs.ch"
#include "protheus.ch"
#include "TOPCONN.CH"

user function ximpSZ1()	// U_uReadExc()

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
	//Abre uma tela para escolher o arquivo.
	cDiret := cGetFile('Arquivo CSV|*.csv| Arquivo TXT|*.txt| Arquivos XML|*.xml',; 	//cMascara
	'Selecao de Arquivos',;											//cTitulo
	0,;																//nMascpadrao
	'C:\csv\',;														//cDirinicial
	.F.,;															//lSalvar
	GETF_LOCALHARD + GETF_NETWORKDRIVE,;							//nOpcoes
	.T.)

	FT_FUSE(cDiret)										//Disponibiliza as funcoes FT_F para o arquivo.
	ProcRegua(FT_FLASTREC())
	FT_FGOTOP()											//Seta a primeira linha do arquivo

	While !FT_FEOF()									//While enquanto nao for o final do arquivo
		IncProc('Lendo Arquivo texto...')
		//		cLinha := FT_FREADLN()							//Le a linha atual e coloca ela na cLinha
		aLinha := Separa(FT_FREADLN(),";",.T.)
		IF lPrimLin
			IF alltrim(aLinha[1]) == "SZ1"
				lPrimLin := .F.
				lcabok   := .T.
				FT_FSKIP()
			Else
				Alert("Corrija a importacao para tabela SZ1")
				Return
			Endif
		Endif

		If lcabok
			aCampos  := Separa(FT_FREADLN(),";",.T.)			//Caso seja a primeira, seta no vetor aCampos[], separando os campos por ;
				iF ((aCampos[1] == "COD") .AND. ; //carac
					(aCampos[2] == "DESC") .AND. ;// carac
					(aCampos[3] == "QTD") .AND. ; //num
                    (aCampos[3] == "DATA") .AND. ; //data
					(aCampos[4] == "VALOR")) //num
				lcabok := .F.
				FT_FSKIP()
			else
				Alert("Cabecalho da tabela não foi encontrado, campos PECA | PRECO | MONTADORA")
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
		If Len(AXSG1IMP) != 0
			dbselectarea("SZ1")
			For njx := 1 to len(AXSZ1IMP)
				IncProc("Analisando registro " + cValToChar(nAtual) + " de " + cValToChar(nProc) + "...")

				IF (!alltrim(AXSZ1IMP[njx][1]) == "") .AND. (!alltrim(AXSZ1IMP[njx][2]) == "") .AND. (!alltrim(AXSZ1IMP[njx][3]) == "")
					SZ1->(dbSetOrder(8))
					if SZ1->(DBSEEK(XFILIAL("SZ1")+Padr(AXSZ1IMP[njx][1],TamSX3("SZ1_CODPRO" )[1])+Padr(AXSG1IMP[njx][2],TamSX3("SZ1_CODMON" )[1])))
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
