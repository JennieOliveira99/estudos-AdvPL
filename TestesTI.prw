#include "Protheus.ch"
#include "Totvs.ch"
/*/
Rotina de execu√ß√£o de testes
@author Jennyfer Alvim
/*/
User Function TestesTI()

//Declarando variavel tipo Caractere
Local cNomeCliente := "Jennyfer"
//Declarando variaver tipo Numerico
Local nValorTotal := 155.50
//Declarando variavel do tipo LÛgico
Local lAtivo := .T.
//Declarando variavel do tipo Data
Local dHoje := Date()

MsgInfo("Exibindo cNomeCliente do tipo: "+ ValType(cNomeCliente))
MsgInfo("Vari·vel nValorTotal È do tipo: " + ValType(nValorTotal))
MsgInfo("Vari·vel lAtivo È do tipo: " + ValType(lAtivo))
MsgInfo("Vari·vel dHoje È do tipo: " + ValType(dHoje))

return
