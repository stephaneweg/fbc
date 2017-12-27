'' examples/manual/switches/option-byval.bas
''
'' NOTICE: This file is part of the FreeBASIC Compiler package and can't
''         be included in other distributions without authorization.
''
'' See Also: https://www.freebasic.net/wiki/wikka.php?wakka=KeyPgOptionbyval
'' --------

'' compile with the "-lang fblite" compiler switch

#lang "fblite"

Sub TestDefaultByref( a As Integer )
  '' change the value
  a = a * 2
End Sub

Option ByVal

Sub TestDefaultByval( a As Integer )
  a = a * 2
End Sub

Dim a As Integer = 1

Print "a = "; a
TestDefaultByref( a )
Print "After TestDefaultByref : a = "; a
Print

Print "a = "; a
TestDefaultByval( a )
Print "After TestDefaultByval : a = "; a
Print
