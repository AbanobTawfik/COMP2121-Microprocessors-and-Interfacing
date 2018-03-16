.include "m2560def.inc"
; this program will add two arrays and store the result in arrayret
.dseg

arrayret: .byte 5
.cseg
    .def a1 = r16
	.def a2 = r17
	.def a3 = r18
	.def a4 = r19
	.def a5 = r20

	.def b1 = r21
	.def b2 = r22
	.def b3 = r23
	.def b4 = r24
	.def b5 = r25


	ldi a1, 1
	ldi a2, 2
	ldi a3, 3
	ldi a4, 4
	ldi a5, 5

	ldi b5, 1
	ldi b4, 2
	ldi b3, 3
	ldi b2, 4
	ldi b1, 5

addition:
	add a1, b1
	add a2, b2
	add a3, b3
	add a4, b4
	add a5, b5

returnarray:
	ldi XL, low(arrayret)
	ldi XH, high(arrayret)
	st X+, a1
	st X+, a2
	st X+, a3
	st X+, a4
	st x+, a5

halt:
	rjmp halt
