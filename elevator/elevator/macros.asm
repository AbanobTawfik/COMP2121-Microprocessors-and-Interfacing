
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//																																						 //
//													helpful macros																						 //
//																																						 //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

.macro prologue
	in r16, SREG
	push r16
	push r17
	push r18
	push r19
	push r20
	push r21
	push r22
	push r23
	push r24
	push r25
	push XL
	push XH
	push YL
	push YH
	push ZL
	push ZH
.endmacro

.macro epilogue
	pop ZH
	pop ZL
	pop YH
	pop YL
	pop XH
	pop XL
	pop r25
	pop r24
	pop r23
	pop r22
	pop r21
	pop r20
	pop r19
	pop r18
	pop r17
	pop r16
	out SREG, r16
.endmacro

.macro clear
	ldi YL, low(@0)	
	ldi YH, high(@0)
	clr temp
	st Y+, temp		;we clear the two bytes located where the label @a0 is by loading in a clear byte
	st Y, temp

.endmacro

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//																																						 //
//													elevator queue macros																				 //
//																																						 //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


//a full queue would look like
//full queue with floors 0-9 
//0b (high bits) 0000011 (low bits) 11111111

;this macro converts level into bits eg if floor is 6
//converts 6 into 0b 00000000 01000000
.macro CONVERT_FLOOR_INTEGER
	prologue
	lds temp, @0
	;add 1 to temp since floor 0 is 0b0000000000000001
	inc temp
	loop:
		cpi temp, 0
		brlo endloop
		dec temp
		lsl @1
		rol @2
		jmp loop

    endloop:
		epilogue
.endmacro

; passing in 2 16 bit register pairs
; 1 register pair is the current queue for the levels
; the other register pair is the floor number we are adding
.macro UPDATE_STATE_ADD
	prologue
	; or the low bits with low bits 
	or @0, @1
	; or the high bits with the high bits
	or @2, @3
	; clear the level bits
	epilogue
.endmacro

; passing in 2 16 bit register pairs
; 1 register pair is the current queue for the levels
; the other register pair is the floor number we are removing
.macro UPDATE_STATE_REMOVE
	prologue
	; exclusive or the low bits with the low bits
	eor @0, @1
	; exclusive or the high bits with the high bits
	eor @2, @3
	; clear the level bits
	clear @0:@2
	epilogue
.endmacro
