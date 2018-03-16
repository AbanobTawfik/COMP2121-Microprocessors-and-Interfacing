.include "m2560def.inc"

.def prev = r18			;to store previous for comparison
.def curr = r16			;to keep track of current array value
.def next = r19			;to store next for comparison
.def swapp = r20		;this stores 1 of the values as a temporary required for swapping
.def size = r17			;loop counter

.dseg 
resultArray:
	.byte 7		;start code at starf of SRAM

.cseg
sortingArray:
	.db 7,4,5,1,6,3,2


ldi ZL, low(sortingArray<<1)			;storing our Y pointer at start of SRAM
ldi ZH, high(sortingArray<<1)
;putting array into memory SRAM

ldi YL, low(resultArray)
ldi YH, high(resultArray)

moveIntoMemory:
	lpm curr, Z+
	st Y+, curr
	cpi curr, 0
	brne moveIntoMemory

ldi YL, low(resultArray)
ldi YH, high(resultArray)
ldi curr, 0				;current index	= 0
ldi size, 6				;size of array = 6

;sorting loop 
;1. it goes through the check it checks the previous value with the next value
;2. if the previous value is BIGGER than the next value for example ur pair is 7 4
;3. then swap it so it becomes 4 7
;4. otherwise you iterate through the array and dont swap (u dont swap  1 7, ud move to next pair)
;5. repeat till you lock a value in last position of array
;6. reduce the overall scan size by 1 (size of array is scan size initially)
;7. now repeat this until the scan size is 0 (can add check if nswaps = 0 but idk how)
;8. added a little check to see if it was sorted by loading out my array into r16-r22

bubblesort:
	ld prev, y+			;load the previous value into y+1
	ld next, y			;load the next value into y
	cp next, prev		;compares the value of next and previous
	brlo bubbleswap		;if the prev>next swap them (bubble sort algorithm)
	rjmp bubbleswapalgorithm ;else skip

	bubbleswap:
	mov swapp, next		; sets temporary = next
	st y, prev			; sets the next = previous
	st -y, swapp			; sets the previous = temporary;
	adiw r28, 1			; goes to next value
	rjmp bubbleswapalgorithm

bubbleswapalgorithm:
	inc curr
	cp curr, size			;incrementing the index of our sort, if the index is less than the size of the array sort, 
	brlo bubblesort

	dec size			;1 less element to sort 
	cpi size, 0			;checks if anymore elements left to compare, if so continue if no more aka = 0 end program
	breq checksorted
	ldi curr, 0
	ldi YL, low(resultArray)
    ldi YH, high(resultArray)	;now we go through the whole array again to check if its all sorted, so reset counter and reset our Y pointer and repeat sort till condition met no element to sort
	rjmp bubblesort



checksorted:
ldi YL, low(resultArray)
ldi YH, high(resultArray)
	ld r16, y+
	ld r17, y+
	ld r18, y+
	ld r19, y+
	ld r20, y+
	ld r21, y+
	ld r22, y+
	ld r23, y+

halt:
	rjmp halt
