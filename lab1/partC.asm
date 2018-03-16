.include "m2560def.inc"
.equ ending = 0								; end of string is null or 0
.equ lowertouppercase=32					; (will be -32 as lowercase have higher ascii values
.def letter = r16							; a register for pointing to a letter expecting 0x74 as r16 first

.dseg
arrayFinal:
	.byte 20

.cseg
myword: 
	.db "thiswordshudbeup1_2",0				;making sure to pad so no misallignment Cx
   ldi ZL, low(myword<<1)   
   ldi ZH, high(myword<<1)					;loading into the X - pointer the string above me ^^^^

   ldi YL, low(arrayFinal)	
   ldi YH, high(arrayFinal)						;loading the pointer of Y into SRAM 0x200 is start of sram

moveIntoMemory:
   lpm letter, Z+							;loading our letters into program memori dont be dumb like me use the z pointer
   st Y+, letter							;now storing that letter into the SRAM
   cpi letter, ending
   brne moveIntoMemory						;check if we copied the entire word into sram if we havent then go back to copy function


   ;now we want our beloved y pointer to the start of our SRAM which will have our word
   ldi YL, low(arrayFinal)   
   ldi YH, high(arrayFinal)						;pointing Y to start of arrayFinal (contains stored array of ints)


makeUpper:
	ld letter, Y							;now that our string is loaded into sram, convert char by char
	cpi letter, ending						;check if we are at the end of the string
	breq halt								;if its the end end the whole thing done
	cpi letter, 97							;want to check if its a lowercase letter now a = 97 z = 123
	brlo nextcharr							;if its not lowercase next char
	ldi r20, 123
	cp r20, letter							;check if its passed the end letter z = 123
	brlo nextcharr							;skip dat shieee
	
	subi letter, lowertouppercase

nextcharr:
	st Y+, letter
	rjmp makeUpper

   halt:
	rjmp halt
