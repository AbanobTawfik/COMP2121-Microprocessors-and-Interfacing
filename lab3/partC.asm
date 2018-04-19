;Part C – Dynamic Pattern (4 Marks)
;Use the two push buttons to enter a binary pattern, and then display it on the LEDs. The left button
;(PB1) will enter a 1, and the right button (PB0) will enter a 0. When 8 bits have been collected, they
;should be displayed on the green LEDs 3 times, with each flash lasting one second and all LEDs
;turned off for one second after each flash. The bits should be displayed in the order they were
;entered, with the first one on the top LED.
;You must use timer0 to generate an interrupt to control the display speed, and falling-edge external
;interrupts 0 and 1 to detect the button pushes. It must be possible to enter a new pattern while the
;last one is still displaying, although you may assume that no more than one pattern will be entered
;while the last one is displaying.
;The buttons must be software debounced, so that one button press reliably generates only a single
;bit in the pattern. You should implement debouncing by ignoring spurious interrupts, not by
;disabling interrupts or busy-waiting.
.dseg
patternState:
	.byte 1				;single 8 byte pattern to show
queuedPattern:
	.byte 1				;single 8 byte pattern which is entered while current is displayed
.secondCounter
	.byte 1

.tempCounter
	.byte 1

;this will clear a word in memory at the address the label was located
.macro clear
	ldi YL, low(@0)	
	ldi YH, high(@0)
	clr temp
	st Y+, temp		;we clear the two bytes located where the label @a0 is by loading in a clear byte
	st Y, temp
.endmacro
