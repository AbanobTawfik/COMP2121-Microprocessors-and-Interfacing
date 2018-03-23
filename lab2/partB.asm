.include "m2560def.inc"
;defining upper case limits
.equ A = 65
.equ Z = 90
;defining lower case limits
.equ a = 97
.equ z = 122

.cseg
rjmp start

validstring:
.db "abcdABCD", 0
invalidstring:
.db "74(*&Q#$^}{:?<>", 0

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


push ZL
push ZH
push r16
push r17
push r18

halt:
rjmp halt

checkalpha:
;(if((r17>'A' && r17 <'Z') || (r17 > 'a' && r17 < 'z')

checkCharacters:
lpm r17, Z+
cpi r17, 0	;check if character is end of string if not keep looping
beq endOfFunctionSuccess
;load A into r18
ldi r18, A
; if >A go to second check 
cp r17, r18
brlt checkupperz
ldi r18, a
cp r17, r18
brlt checklowerz
rjmp checkCharacters

checkupperz:
ldi r18, Z
cp r18, r17
brlt checkCharacters
rjmp endOfFunctionFail

checklowerz:
ldi r18, z
cp r18, r17
brlt checkCharacters
rjmp endOfFunctionFail

endOfFunctionSuccess:
;load success into r16 -> 1
;return
ldi r16, 1
pop r18
pop r17
pop r16
pop ZH
pop ZL
ret
endOfFunctionFail:
;load fail into r16 -> 0
;return
ldi r16, 0
pop r18
pop r17
pop r16
pop ZH
pop ZL
ret


