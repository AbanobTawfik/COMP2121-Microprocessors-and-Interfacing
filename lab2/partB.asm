.include "m2560def.inc"

.cseg
rjmp start

validstring:
.db "abcdABCDzZ",0
invalidstring:
.db "74(*&Q#$^}{:?<>",0

start:
;initialised stack here
ldi r16, low(RAMEND)
out SPL, r16
ldi r16, high(RAMEND)		;!!! Insert stack initialization code here !!!
out SPH, r16             

ldi ZL, low(validstring << 1)
ldi ZH, high(validstring << 1)
call checkalpha
mov r20, r16
; r20 should be 1
ldi ZL, low(invalidstring << 1)
ldi ZH, high(invalidstring << 1)
call checkalpha
mov r21, r16
; r21 should be 0




halt:
rjmp halt

checkalpha:
;(if((r17>'A' && r17 <'Z') || (r17 > 'a' && r17 < 'z')
push ZL
push ZH
push r17
push r18
push r0   ;return address
checkCharacters:
lpm r17, Z+
cpi r17, 0	;check if character is end of string if not keep looping
breq endOfFunctionSuccess
;load A into r18
ldi r18, 'A'
; if  < A that means its not even in range of character 
cp r17, r18
;if >= A we want to check if <=Z
brsh checkupperz
;if <A do this
rjmp endOfFunctionFail

checkupperz:
ldi r18, 'Z'
;compare our Z with our letter
cp r18, r17
;if our letter >Z we want to check if its an uppercase letter then
brlt checkiflowercaseinstead
;otherwise its >=A <=Z its a uppercase character check next
rjmp checkCharacters

checkiflowercaseinstead:
;check if its >=a
ldi r18, 'a'
cp r17, r18
;if its >=a check if its <=z
brsh checklowerz
;otherwise its not a letter if its not >=a but >=z
rjmp endOfFunctionFail

checklowerz:
;check if the character is <=z 
ldi r18, 'z'
cp r18,r17
;if its >z then its a symbol of a sort or special character  
brlt endOfFunctionFail
;otherwise jump to next character to checl
rjmp checkCharacters

endOfFunctionSuccess:
;load success into r16 -> 1
;return values from stack esp return address r0 to ret to next call
ldi r16, 1
pop r0
pop r18
pop r17
pop ZH
pop ZL
ret
endOfFunctionFail:
;load fail into r16 -> 0
;return values from stack esp return address r0 to ret to next call
ldi r16, 0
pop r0
pop r18
pop r17
pop ZH
pop ZL
ret


