.include "m2560def.inc"

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
;epilogue, pushing values + return address onto stack
push ZL
push ZH
push YL
push YH
push r0

ret

;call the function stored in the Y pointer still has parameter Z unchanged
;now we have return restore stack to original state and return


isUPPER:
;now we want to check value
checkCharacters:
lpm r17, z+
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
;now we want to check value
checkDigit:
lpm r17, z+
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
;restore the stack
pop r0
pop YH
pop YL
pop ZH
pop ZL
ret

endFail:
ldi r16, 0
;restore stack
pop r0
pop YH
pop YL
pop ZH
pop ZL
ret
