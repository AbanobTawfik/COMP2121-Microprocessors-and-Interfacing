;
; AssemblerApplication7.asm
;
; Created: 18/04/2018 4:29:07 PM
; Author : Abs Tawfik
;


; Replace with your application code
.include "m2560def.inc"

start:
;configure all 8 pins 0b 1111 1111 , 1 = output, 0 = input 
   out DDRC, 0xFF
;load the pattern into register 0xe5 ---> 0b 1110 0101 so the 1's represent on lights, 0's off lights 
   ldi r16, 0xE5
;output the pattern from the port
   out PORTC, r16

halt:
	rjmp halt
