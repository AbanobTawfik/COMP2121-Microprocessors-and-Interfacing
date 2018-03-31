.include "m2560def.inc"
.dseg
stringStore:
	.byte 50

.cseg
myString1: .db "AB",0,0
myString2: .db "aBCDEFGHIJKLMNOPQRSTUVWXYz",0 ,0
myString3: .db "1234567890",0,0
myString4: .db "123456789a",0,0				
ldi r16, low(RAMEND)
out SPL, r16
ldi r16, high(RAMEND)		;!!! Insert stack initialization code here !!!
out SPH, r16             

;load the string into Z
ldi ZL, low(myString1 << 1)
ldi ZH, high(myString1 << 1)
;load Function into Y
ldi YL, low(isUPPER)
ldi YH, high(isUPPER)
call checkString
mov r19, r16

ldi ZL, low(myString2 << 1)
ldi ZH, high(myString2 << 1)
;load Function into Y
ldi YL, low(isUPPER)
ldi YH, high(isUPPER)
call checkString
mov r20, r16

ldi ZL, low(myString3 << 1)
ldi ZH, high(myString3 << 1)
;load Function into Y
ldi YL, low(isDIGIT)
ldi YH, high(isDIGIT)
call checkString
mov r21, r16

ldi ZL, low(myString4 << 1)
ldi ZH, high(myString4 << 1)
;load Function into Y
ldi YL, low(isDIGIT)
ldi YH, high(isDIGIT)
mov r22, r16

checkString:
clr XL
clr XH
ldi XL, low(stringStore)
ldi XH, high(stringStore)
;epilogue, pushing values + return address onto stack
loadStringToDataMemory:
lpm r17, Z+
st X+, r17
cpi r17, 0
brne loadStringToDataMemory

clr ZL
clr ZH
mov ZL, YL
mov ZH, YH

icall
ret

isUPPER:
ldi XL, low(stringStore)
ldi XH, high(stringStore)
checkCharacters:

ld r17, X+
cpi r17, 0
breq endSuccess
;load A into r18
ldi r18, 'A'
cp r17, r18
brsh checkupperZ
rjmp endFail

checkupperZ:
ldi r18, 'Z'
cp r18, r17
brlt endFail
rjmp checkCharacters

isDigit:
ldi XL, low(stringStore)
ldi XH, high(stringStore)
;now we want to check value
checkDigit:
ld r17, X+
cpi r17, 0
breq endSuccess
;load A into r18
ldi r18, '0'
cp r17, r18
brsh checkdig2
rjmp endFail

checkdig2:
ldi r18, '9'
cp r18, r17
brlt endFail
rjmp checkDigit

endSuccess:
ldi r16, 1
;return
ldi XL, low(stringStore)
ldi XH, high(stringStore)
clr XL
clr XH
ret

endFail:
ldi r16, 0
;return
ld XL, low(stringStore)
ld XH, high(stringStore)
clr XL
clr XH

ret
