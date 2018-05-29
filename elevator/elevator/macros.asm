//////////////////////////////////////
//                                  //
//    Prologue + Epilogue           //
//                                  //
//////////////////////////////////////

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
	prologue
	ldi YL, low(@0)	
	ldi YH, high(@0)
	clr temp
	st Y+, temp
	st Y, temp
	epilogue
.endmacro

////////////////////////////////////////////////
//                                            //
//    Elevator macro for convertinf floors    //
//    or adding to queue                      //
//                                            //
////////////////////////////////////////////////


; a full queue would look like
; full queue with floors 0-9 
; 0b (high bits) 0000011 (low bits) 11111111
; this macro converts level into bits eg if floor is 6
; converts 6 into 0b 00000000 01000000
.macro CONVERT_FLOOR_INTEGER
	push temp
	mov temp, @0
	; loop floor number amoutn of times
	loop:		
		dec temp
		cpi temp, 0
		brlt endloop
		; each iteration we want to left shift and rotate left the register pair
		lsl @1
		rol @2
		jmp loop

    endloop:
		pop temp
.endmacro

; passing in 2 16 bit register pairs
; 1 register pair is the current queue for the levels
; the other register pair is the floor number in bit representation we are adding
; OR is equivalent to add
.macro UPDATE_STATE_ADD
	; or the low bits with low bits 
	or @0, @1
	; or the high bits with the high bits
	or @2, @3
.endmacro

; passing in 2 16 bit register pairs
; 1 register pair is the current queue for the levels
; the other register pair is the floor number we are removing
; eor will check if the two bits are different
.macro UPDATE_STATE_REMOVE
	; exclusive or the low bits with the low bits
	eor @0, @1
	; exclusive or the high bits with the high bits
	eor @2, @3
.endmacro
