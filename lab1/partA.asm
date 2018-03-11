.include "m2560def.inc"
; this program will add two integers together 


.def a_low = r16
.def a_high = r17
.def b_low = r18
.def b_high = r19
.def result_low = r20
.def result_high = r21
.def remainder = r22
partAAddition:
	clr r16
	clr r17
	clr r18
	clr r19
	clr r20
	clr r21

	ldi remainder, 0
	ldi a_low, high(640)		;the high takes lower bits
	ldi a_high, low(640)		;the low takes the higher bits 0xAA00 is 40960, high is the AA low is the 00
	ldi b_low, high(511)
	ldi b_high, low(511)

	mov result_low, a_low
	mov result_high, a_high
	add result_low, b_low
	add result_high, b_high
	adc result_low, remainder

halt:
	rjmp halt

	