.include "m2560def.inc"

.cseg
myString1: .db "*A%%BCD$$EFG$$$$"
myString2: .db "$%()@#*%@(#*%"    ;using for isSYMBOL

ldi r16, low(RAMEND)
out SPL, r16
ldi r16, high(RAMEND)		;!!! Insert stack initialization code here !!!
out SPH, r16             

;load the string into Z
ldi ZL, low(myString1 << 1)
ldi ZH, high(myString1 << 1)
;load Function into Y

ld YL, low(isSymbol)
ld YH, high(isSymbol)

mov r20, r16    
call checkString

ldi ZL, low(myString2 << 1)
ldi ZH, high(myString2 << 1)
;load Function into Y

ld YL, low(isSymbol)
ld YH, high(isSymbol)

call checkString
