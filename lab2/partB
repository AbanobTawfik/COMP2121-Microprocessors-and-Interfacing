.include "m2560def.inc"

;definitions
.def lengthret = r16
.def lengthtmp = r17
.def stringret = r18
.def tempreg = r19
.def singlecharacter = r20

.set NEXT_STRING = 0x0000
.macro defstring ; str
	.set T = PC				; save current position in program memory
	.dw NEXT_STRING	<< 1	; write out address of next list node
	.set NEXT_STRING = T	; update NEXT_STRING to point to this node

	.if strlen(@0) & 1		; odd length + null byte
		.db @0, 0
	.else					; even length + null byte, add padding byte
		.db @0, 0, 0
	.endif
.endmacro

.cseg
	defstring "1"			;length 1
	defstring "12"			;length 2
	defstring "123"			;length 3
	defstring "1234"		;length 4
	defstring "4321"		;length 4
	defstring "321"			;length 3


	;our rules should state that our return shud be 1234 and strlen of 4
	;now we want to initialise our Z pointer to our NEXT_STRING which has all these in a linked list
	;we also want to initalise our stack

	ldi tempreg, low(RAMEND)
	out SPL, tempreg
	ldi tempreg, high(RAMEND)
	out SPH, tempreg

	;now we want to store in our Z pointer our NEXT_STRING linked list
	
	ldi ZL, low(NEXT_STRING<<1)
	ldi ZH, high(NEXT_STRING<<1)
	ldi lengthret, 0

	rcall recsearch		   ;call our recurisve search for longest string

	rjmp printstring

recsearch:
	;epilogue, want to push values into stack for our function call and our return value onto stack too ^_^ return in Z, length in r16
	;each call to this recursive search initalises a new stack frame hence why our epilogue is here rather than before function call
	;allows each call to deal with its own values
	push XH
	push XL
	push YH			;pushing all the pointer registers into stack (r26-r31)
	push YL		
	push ZH
	push ZL
									
	push stringret
	push tempreg								;pushing our registers for our recursive calls into our stack 
	push lengthtmp

	;check if our current Z value is null
	cpi ZL, 0
	ldi tempreg, 0
	cpc ZH, tempreg 							;comparing the higher value of Z with remainderto NULL (if ZL == 0 it would ignore this
	brne keepsearching 							;instruction and skip to the tempreg current = ZH	
	rjmp endSearch								;if the input == NULL return NULL (ZL ZH NULL r16 0 as asked)

keepsearching:
	push ZH
	push ZL										;store the old addresses of z onto the stack to allow us to compare

	lpm YL, Z+
	lpm YH, Z 									;we are using Y to hold the next value of Z temporarily as a means of comparison between
												;the current node and the next node in the list (sort of like bubble sort)
	
	subi ZL, 1									;Z-								
	ldi tempreg, 0								;move Z back (since we basically doing z = z->next now z = z->prev)
	cpc ZH, tempreg								
	;IF z->NEXT AKA Y = NULL
	cpi YL, 0
	ldi tempreg, 0								;checking if our Y value (next node in the list is null if it is skip )
	cpc YH, tempreg
	breq getLength
	;ELSE
	movw ZL, YL									;store z->Next into Z
	push tempreg
	rcall recsearch								;recursively call the search function with new args
	pop tempreg
	movw YL, ZL									;now we want our old values from the stack
	in XL, SPL
	in XH, SPH									;initialising X with our stack pointer, using this to retrieve 
	ldi tempreg, 1
	add XL, tempreg
	ldi tempreg, 0
	adc XH, tempreg
	ld ZL, X+									;old value of Z loaded from stack
	ld ZH, X	


getLength:										;function to get length of string
	ldi lengthtmp, 0
	ldi tempreg, 2
	add ZL, tempreg								;Z repositioned to start of new string getting length of
	ldi tempreg, 0
	adc ZH, tempreg
lengthloop:
	lpm tempreg, Z+
	cpi tempreg, 0								;loop through string till 0 reached
	breq comparewitholdlength					;when entire length acquired go to compare function
	inc lengthtmp
	rjmp lengthloop							

comparewitholdlength:
	cp lengthret, lengthtmp		;(lengthtmp - length) if >=0 skip else perform override
	brsh elsee					;branch if the new length >= old_length (skip unless strictly higher)
								;if the length of the check is BIGGER UPDATE OUR RETURN LENGTH
	mov lengthret, lengthtmp
	pop ZL						;override the old values for return
	pop ZH						;store our updated return values
	rjmp endSearch

elsee:
	;if the old length stored is larger than the current length want to compare with
	movw ZL, YL					;this is skip instruction (move into our Z the Y which is z->next)
	pop tempreg					;pop off stack
	pop tempreg					;pop off the staack


endSearch:
	;prologue (clearing stack popping all values including return addresses
	;returns our values from the stack 
	pop lengthtmp
	pop tempreg
	pop stringret
	pop ZL
	pop ZH
	pop YL
	pop YH
	pop XL
	pop XH
	ret									;unwind the recursion hehe
	
printstring:
	lpm singlecharacter, Z+
	cpi singlecharacter, 0
	breq end
	rjmp printstring
end:
	rjmp end
