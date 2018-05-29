/////////////////////////////////////////
//   COMP2121 Project Lift Simulator   //
//   UNSW Semester 1 2018              //
//   Written By Abanob Tawfik          //
//   15/05/2018 - 30/05/2018           //
//   z5075490                          //
/////////////////////////////////////////

.include "m2560def.inc"
.include "macros.asm"
//////////////////////////////////////
//                                  //
//        THESE ARE MACROS USES     //
//                                  //
//////////////////////////////////////
.macro do_lcd_data
    ldi r16, @0
    rcall lcd_data
    rcall lcd_wait
.endmacro
; macro will be for initial loading of LCD
.macro initalise_LCD
    do_lcd_command 0b00111000                        ; 2x5x7
    rcall sleep_5ms
    do_lcd_command 0b00111000                        ; 2x5x7
    rcall sleep_1ms
    do_lcd_command 0b00111000                        ; 2x5x7
    do_lcd_command 0b00111000                        ; 2x5x7
    do_lcd_command 0b00001000                        ; display off?
    do_lcd_command 0b00000001                        ; clear display
    do_lcd_command 0b00000110                        ; increment, no display shift
    do_lcd_command 0b00001110                        ; Cursor on, bar, no blink
    do_lcd_data ' '
    do_lcd_data ' '
    do_lcd_data ' '
    do_lcd_data ' '
    do_lcd_data ' '
    do_lcd_data 'L'
    do_lcd_data 'i'
    do_lcd_data 'f'
    do_lcd_data 't'
    do_lcd_command 0b0011000000                       ; address of second line on lcd
    do_lcd_data 'f'
    do_lcd_data 'l'
    do_lcd_data 'o'
    do_lcd_data 'o'
    do_lcd_data 'r'
    do_lcd_data ':'
    do_lcd_data ' '
    do_lcd_data '0'
.endmacro
; macro for showing the current state of lift which floor it is in
.macro PRINT_FLOOR
     do_lcd_command 0b00000001                        ; clear display
     do_lcd_command 0b00000110                        ; increment, no display shift
     do_lcd_command 0b00001110                        ; Cursor on, bar, no blink
     do_lcd_data ' '
     do_lcd_data ' '
     do_lcd_data ' '
     do_lcd_data ' '
     do_lcd_data ' '
     do_lcd_data 'L'
     do_lcd_data 'i'
     do_lcd_data 'f'
     do_lcd_data 't'
     do_lcd_command 0b0011000000                      ; address of second line on lcd
     do_lcd_data 'f'
     do_lcd_data 'l'
     do_lcd_data 'o'
     do_lcd_data 'o'
     do_lcd_data 'r'
     do_lcd_data ':'
     do_lcd_data ' '
     mov r16, @0
     subi r16, -'0'
     rcall lcd_data
     rcall lcd_wait
.endmacro
.macro do_lcd_command
    ldi r16, @0
    rcall lcd_command
    rcall lcd_wait
.endmacro
; macro will display the value inside a register
.macro do_lcd_data_in_register
    mov r16, @0
    rcall lcd_data
    rcall lcd_wait
.endmacro
; This macro will display the emergency message
.macro PRINT_EMERGENCY
    prologue
    do_lcd_command 0b00000001                         ; clear display
    do_lcd_command 0b10000000                         ; address of first line on lcd
    do_lcd_data 'E'
    do_lcd_data 'm'
    do_lcd_data 'e'
    do_lcd_data 'r'
    do_lcd_data 'g'
    do_lcd_data 'e'
    do_lcd_data 'n'
    do_lcd_data 'c'
    do_lcd_data 'y'
    do_lcd_command 0b0011000000
    do_lcd_data 'c'
    do_lcd_data 'a'
    do_lcd_data 'l'
    do_lcd_data 'l'
    do_lcd_data ':'
    do_lcd_data ' '
    do_lcd_data '0'
    do_lcd_data '0'
    do_lcd_data '0'
    epilogue
.endmacro
//////////////////////////////////////
//                                  //
//      Main + Initalising ports    //
//                                  //
//////////////////////////////////////
; register naming
.def row = r16                                        ; current row number
.def col = r17                                        ; current column number
.def rmask = r18                                      ; mask for current row during scan
.def cmask = r19                                      ; mask for current column during scan
.def temp1 = r20
.def temp2 = r21
.def topRow = r22
.def bottomRow = r23
.def numberSize = r24
.def temp = r25
; variable naming
.equ PORTLDIR = 0xF0                                  ; PL7-4: output, PL3-0, input 
.equ INITCOLMASK = 0xEF                               ; 0b1110 1111 scan from the rightmost column,
.equ INITROWMASK = 0x01                               ; 0b0000 0001 scan from the top row
.equ ROWMASK = 0x0F    
; LED PATTERNS
.equ DOOR_OPEN = 0xC3                                 ; door open is 0b11000011 supposed to look like open space for door 0 = space in middle, 1 = metal
.equ DOOR_CLOSED = 0xE7                               ; door closed is 0b11101111 the 0 in middle is the gap for door 0 = space, 1 = metal
.equ MOVING_UP = 0xF0                                 ; door moving up 0b11110000 upper half of the LCD lit up to show direction UP 
.equ MOVING_DOWN = 0x0F                               ; door moving down 0b00001111 lower half of the LCD lit up to show direction down
; Labels in Data Memory
.dseg
    debounceValue:                                    ; this will check if a key has been pressed on key pad
        .byte 1
    lastPressed:                                      ; this will also be used for keypad debouncing
        .byte 1
    secondCounter:                                    ; this will be used to keep track of seconds passed
        .byte 1
    tempCounter:                                      ; used as counter to check for seconds
        .byte 2
    strobeTimer:                                      ; timer for strobe flash (n times per second)
        .byte 1
    opening:                                          ; will be used to check if the open button was pressed
        .byte 1
    closing:                                          ; will be used to check if the close button was pressed
        .byte 1
    currentFloor:                                     ; will be used to hold the current floor
        .byte 1
    floor_Queue:                                      ; THE MAIN QUEUE FOR THE ELEVATOR
        .byte 2
    emergency:                                        ; will be used as a flag for emergency protocol
        .byte 1
    down:                                             ; used to check direction of elevator movement
        .byte 1
    timeOfClose:                                      ; will be used to check when the close button was pressed so we can add a one second delay to close door
        .byte 1
    alreadyClosing:                                   ; used to for further check if the close button was pressed and it is already closing
        .byte 1
    canClose:                                         ; used to check if the elevator is in a state where it can be closed (door just finished opening)
        .byte 1
    emergencyShown:                                   ; used as a flag to check when the first time emergency is shown so can see floors on way down to 0
        .byte 1
    strobeOn:                                         ; check if strobe light is on/off
        .byte 1
    canOpen:                                          ; check if the elevator is in a state where it can be opened, i.e no floors in queue/not moving
        .byte 1
    doorSequence:                                     ; will be used to check if we have stopped at a floor
	    .byte 1
.cseg
.org 0
    jmp RESET
.org INT0addr                                         ; INT0addr is the address of EXT_INT0
    jmp PB0_ON_PRESS
.org INT1addr                                         ; INT1addr is the address of EXT_INT1
    jmp PB1_ON_PRESS
.org OVF0addr
    jmp Timer0OVF                                     ; this will be handler for timer overflow
; RESET will contain all initalisation for the board
RESET:
    ; initialising the stack
    ldi r16, low(RAMEND)
    out SPL, r16
    ldi r16, high(RAMEND)
    out SPH, r16
    ldi temp, 0
    sts strobeOn, temp                                ; clear the label for strobe on
    ser r16
    out DDRF, r16                                     ; set port F to be output
    out DDRA, r16                                     ; set port A to be output
    clr r16
    out PORTF, r16                                    ; outputting 0 into port F and port A
    out PORTA, r16
    ; clear the label for the debounce flags
    sts lastPressed, r16                            
    sts debounceValue, r16
    ; initalising output and input for the keypad
    ldi temp1, PORTLDIR                               ; PA7:4/PA3:0, out/in
    sts DDRL, temp1
    ser temp1                                         ; PORTC is output
    out DDRC, temp1
    ldi temp, (1 << ISC11) | (1 << ISC01)             ; Interrupt 0 and Interrupt 1 will trigger on falling edges external interrupt
    sts EICRA, temp                                   ; setting the external control to trigger for INT0 and INT1 (EICRA handles INT0 - INT3)
    ; now we want to enable int0 and int1
    in temp, EIMSK
    ori temp, (1 <<INT0) | (1 << INT1)
    out EIMSK, temp
    ; now we want to setup Timer 0
    ldi temp, 1    
    ldi temp, 0b00000000
    out TCCR0A, temp
    ldi temp, 0b00000100
    out TCCR0B, temp                                  ; prescalining = 8
    ldi temp, 1<<TOIE0                                ; 128 microseconds
    sts TIMSK0, temp                                  ; T/C0 interrupt enable
    sei                                               ; enable interrupts
    ; initialising the elevator Queue and starting floor
    ldi temp, 0    
    sts lastPressed, temp                             ; Debouncing for KeyPad
    ; clear the queue and initialise floor to be 0
    clear floor_Queue
    clear strobeTimer
    ldi temp, 0
    sts currentFloor, temp
    ; initialising emergency to be off
    sts emergency, temp
    sts emergencyshown, temp
    ; display on LCD 
    initalise_LCD
    ; setup motor for output and LCD backlight and LCD Display for output 
    ldi temp1, 0xff
    out DDRE, temp1                                   ; put port E to be output
    ; set backlight for lcd 
    ldi temp1, 0xFF
    out portE, temp1
    ldi temp1, 0                                      ; motor is intiailly OFF
    sts OCR3BL, temp1                                 ; low of voltage supplied to motor -> 0
    sts OCR3BH, temp1                                 ; high of voltage supplied to motor -> 0
    ldi temp1, (1 << CS30)                            ; set the Timer3 to Phase Correct PWM mode
    sts TCCR3B, temp1
    ldi temp1, (1<< WGM30)|(1<<COM3B1)
    sts TCCR3A, temp1
    jmp main
; scans through the rows and columns
; if no key is pressed i.e full scan debounce value = 0 means last press = 0, aka no inputs
; if a convert is performed i.e detection will set debounce flag which means key pressed so flag for ispressed is set
; since it jumps to main instead of the held down which resets the debounce flag, it means that the flag is never reset
; this is because it will continously detect input there from the user because the PIN value will not be 0 
; so until a full scan is done where nothing is detected (letting go of the key scanning through all columns false)
; it will not reset flag i.e will not take new input till user lifts finger
; when lifts finger, scans through fully and resets the flag 
; debounce timer of 15ms to make sure multiple inputs arent proccessed and pull up resistors are set with the delay
heldDown:
    ldi temp1, 0
    sts debounceValue, temp1                          ; reset the secondary debounce flag
main:
    ldi cmask, INITCOLMASK                            ; initial column mask
    clr col                                           ; initial column index = 0
colloop:
    cpi col, 4
    breq heldDown                                     ; If all columns are scanned unsuccessfully -> no input -> reset debounce value  
    ; PORT H -> L CAN ONLY USE STS AND LDS DO NOT SUPPORT OUT AND IN
    sts PORTL, cmask                                  ; Otherwise, scan the next column.
    ldi temp1, 0xFF                                   ; Slowing down the scan operation.
delay:
    dec temp1                                         ; will be set up as pull-up resistors
    brne delay
    call sleep_1ms    
    lds temp1, debouncevalue                          ; if the debounce value is not set means no key was pressed skip 
    cpi temp1, 0
    breq skip
    ldi temp1, 1                                      ; load value 1 into last pressed the primary debounce flag 
    sts lastPressed, temp1
    jmp skip2
skip:
    ldi temp1, 0
    sts lastPressed, temp1                            ; otherwise no key pressed -> load 0 into the debounce flag
skip2:
    ; we want to load our current cmask (column index) into temp1
    ; then we want to and it with the ROWMASK 0x0F to check if any rows in the column are low (low means pressed)
    ; if we and them together, and get 0xf, that means we have no rows input (so we want to go to next column)
    lds temp1, PINL                                   ; Read PORTL where keypad is connected to
    andi temp1, ROWMASK                               ; Get the keypad output value
    cpi temp1, 0xF                                    ; Check if any row is low
    breq nextcol                                      ; if no rows are low i.e all 1111 for the rows we want to go to next column
    ; if a row is low means there was input
    ldi rmask, INITROWMASK                            ; Initialize for row check
    clr row  
rowloop:
    cpi row, 4                                        ; if all the rows are scanned we want to go to the next column since no more rows to check in that column
    breq nextcol
    ; now we are checking if the key in the column and row index has been pressed
    ; temp1 will have our low rows from previous and. if we and the low rows with the rowmask we currently have
    ; if result = 0 -> we have a low row key pressed -> convert
    ; otherwise we want to keep scanning through the rows
    mov temp2, temp1
    and temp2, rmask                                  ; check un-masked bit (i.e the row column index is LOW -> KEY PRESSED)
    breq convert                                      ; if bit is clear, the key is pressed
    inc row                                           ; else move to the next row (keep scanning)
    lsl rmask                                         ; want to increment the row to scan
    jmp rowloop
; incrementing the current column to scan
nextcol:                                   
    lsl cmask                                         ; left shit the column mask
    inc col                                           ; increase column value
    jmp colloop                                       ; go to the next column
convert:
    ldi temp1, 1                                      ; if a key was scanned we want to store 1 into the debounce secondary flag
    sts debounceValue, temp1
    lds temp1, lastPressed                            ; check if the primary debounce flag is = 0
    cpi temp1, 0
    brne mainjmp                                      ; return to main if primary debounce is not = 0 
    cpi col, 3                                        ; If the pressed key is in col.3 (column 3 has the letters)
    breq mainjmp                                      ; we have a letter DO NOT HANDLE -> MAIN
    ; If the key is not in col3 and
    cpi row, 3                                        ; If the key is in row3, (row 3 -> symbols) bottom row of keypad
    breq symboljmp                                    ; we have a star or 0
    mov temp1, row                                    ; Otherwise we have a number in 1-9
    lsl temp1                                         ; this will multiply temp1 by 2 
    add temp1, row                                    ; now we have 2temp1 + temp 1 = 3temp1
    add temp1, col                                    ; temp1 = row*3 + col
    subi temp1, -1                                    ; Add the value of  ‘1’ since we aren't starting at 0
    jmp addToQueue                                    ; now we want to add the floor to the queue
mainjmp:                                              ; only way to avoid the relative branch out of reach
    jmp main
symboljmp:
    jmp symbols
symbols:
    cpi col, 0                                        ; Check if we have a star
    breq starjmp                                      ; if so do jump to star handler
    cpi col, 1                                        ; now check if we have a zero which is a unique case
    breq zerojmp                                      ; if it is we store 0 onto the queue
    jmp main                                          ; otherwise so we do not handle -> MAIN
; avoiding relative branch errors
starjmp:                  
    jmp star
zerojmp:
    jmp zero
; this will be used to add floors to the elevator Queue
addToQueue:
    lds temp, emergency                               ; if the emergency flag is on
    cpi temp, 1                                       ; we want to return to main as we don't handle requests on emergency
    brne justAdd
    jmp main
; otherwise we add it to the queue again more labels to avoid relative branch out of reach error
justAdd:
    ldi XL, 1                                         ; we want to load into a register pair 0b0000000000000001
    ldi XH, 0 
    CONVERT_FLOOR_INTEGER temp1, XL, XH               ; now we want to convert the floor into a bit representation
	                                                  ; this is done by left shifting and rotating that floor number amount of times
    lds ZL, floor_Queue                               ; now we want to load the current Queue into a register pair  
    lds ZH, floor_Queue + 1    
    UPDATE_STATE_ADD ZL,XL,ZH,XH                      ; now we want to add the scanned floor by orring the bit representation with the queue 
    sts floor_Queue, ZL                               ; update the queue in memory
    sts floor_Queue+1,ZH
    jmp main                                          ; return to main to repeat the sequence
; in the case of zero we want to directly store floor 0 onto the queue
zero:                                                 
    ldi temp1, 0                                      ; set scanned floor to be = 0 and add it to the queue
    jmp addtoQueue
; in the case the emergency was pressed we want to begin the emergency protocol
star:
    ; first we want to check if the flag is set on/off to know how to toggle
    lds temp, emergency
    cpi temp, 0
    breq emergency_ON                                 ; if the current emergency flag is off we want to set it to be ON jump to that procedure
    ; otherwise we want to turn emergency off
    ldi temp, 0                                       ; store 0 into the emergency flag
    sts emergency, temp
    ldi temp, 0b00000000                              ; store 0 into the strobe light output to make sure it is off
    out portA, temp
    ldi temp, 0                                       ; reset the LED state to show elevator is now taking requests
    out portC, temp
    jmp main                                          ; return to main
; procedure for toggling emergency on
emergency_ON:
    ; want to set emergency flag
    ldi temp, 1
    sts emergency, temp
	; now we want to check if the door is currently open	 
    lds temp, doorSequence
    cpi temp, 0
    breq nothingToRemove                              ; if the door is OPEN it canClose -> FORCE IT CLOSED  
	rcall forceClose                                  ; this will force the door to shut
nothingToRemove:
	; forcing motor off regardless incase door is opening causes a weird bug
    ldi temp1, 0
    sts OCR3BL, temp1
    sts OCR3BH, temp1
    ldi temp, 0                                       ; clearing the current Queue
    sts floor_Queue, temp
    sts floor_Queue + 1, temp 
    ldi temp, 0                                       ; loading floor 0 into Queue to move down to 0 simply
    ldi XL, 1
    ldi XH, 0 
    CONVERT_FLOOR_INTEGER temp, XL, XH                ; converting floor 0 into bit representation
    lds ZL, floor_Queue                                    
    lds ZH, floor_Queue + 1                            
    UPDATE_STATE_ADD ZL,XL,ZH,XH                      ; add floor 0 to the empty Queue 
    sts floor_Queue, ZL                               ; update the state of the Queue
    sts floor_Queue+1,ZH
    jmp main                                          ; return
//////////////////////////////////////
//                                  //
//      Interrupt Handlers + LCD    //
//                                  //
//////////////////////////////////////
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4
.macro lcd_set
    sbi PORTA, @0
.endmacro
.macro lcd_clr
    cbi PORTA, @0
.endmacro
; Send a command to the LCD (r16)
lcd_command:
    out PORTF, r16
    rcall sleep_1ms
    lcd_set LCD_E
    rcall sleep_1ms
    lcd_clr LCD_E
    rcall sleep_1ms
    ret
lcd_data:
    out PORTF, r16
    lcd_set LCD_RS
    rcall sleep_1ms
    lcd_set LCD_E
    rcall sleep_1ms
    lcd_clr LCD_E
    rcall sleep_1ms
    lcd_clr LCD_RS
    ret
lcd_wait:
    push r16
    clr r16
    out DDRF, r16
    out PORTF, r16
    lcd_set LCD_RW
lcd_wait_loop:
    rcall sleep_1ms
    lcd_set LCD_E
    rcall sleep_1ms
    in r16, PINF
    lcd_clr LCD_E
    sbrc r16, 7
    rjmp lcd_wait_loop
    lcd_clr LCD_RW
    ser r16
    out DDRF, r16
    pop r16
    ret
//////////////////////////////////////
//                                  //
//    Hard coded delays (sleep)     //
//                                  //
//////////////////////////////////////
.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead
sleep_1ms:
    push r24
    push r25
    ldi r25, high(DELAY_1MS)
    ldi r24, low(DELAY_1MS)
delayloop_1ms:
    sbiw r25:r24, 1
    brne delayloop_1ms
    pop r25
    pop r24
    ret
sleep_5ms:
    rcall sleep_1ms
    rcall sleep_1ms
    rcall sleep_1ms
    rcall sleep_1ms
    rcall sleep_1ms
    ret
sleep_15ms:
    rcall sleep_5ms
    rcall sleep_5ms
    rcall sleep_5ms
    ret
sleep_100ms:
    rcall sleep_15ms
    rcall sleep_15ms
    rcall sleep_15ms
    rcall sleep_15ms
    rcall sleep_15ms
    rcall sleep_15ms
    rcall sleep_5ms
    rcall sleep_5ms
    ret
sleep_1s:
    rcall sleep_100ms
    rcall sleep_100ms
    rcall sleep_100ms
    rcall sleep_100ms
    rcall sleep_100ms
    rcall sleep_100ms
    rcall sleep_100ms
    rcall sleep_100ms
    rcall sleep_100ms
    rcall sleep_100ms
    ret
//////////////////////////////////////////
//                                      //
//    These are interrupt handlers      //
//                                      //
//////////////////////////////////////////

; close button
PB1_ON_PRESS:
    prologue     
    lds temp, canClose                                ; If the elevator cannot close (door not open)
    cpi temp, 0
    breq pb1Epilogue                                  ; return do nothing
    ldi temp, 1                                       ; otherwise set the flag to close
    sts closing, temp                                 
pb1Epilogue:
    epilogue
    reti 
; open button for when door is closing, when held down we will check pinD itself
PB0_ON_PRESS:
    prologue
    lds temp, canOpen                                 ; if the elevator (door) is not closing
    cpi temp, 0
    breq pb0Epilogue                                  ; return do nothing
    ldi temp, 1
    sts opening, temp                                 ; othweise we set the flag to reopen
pb0Epilogue:
    epilogue
    reti    
; this interrupt handler will be the main handler for all lift movement and stops etc.
Timer0OVF:
    prologue
    lds temp, emergency                               ; if the emergency is on we want to go to strobe pattern 
    cpi temp, 1
    breq strobePattern
    jmp strobeSkip                                    ; otherwise skip strobe light display
strobePattern:
    lds r26, strobeTimer
    subi r26, -1
    cpi r26, 100                                      ; every 1/4s we want to toggle the strobe light
    brne strobeSkip
    lds temp, strobeOn                                ; if the strobe is off 
    cpi temp, 0
    breq showStrobe                                   ; we want to turn it ON
    jmp offStrobe                                     ; otherwise turn the strobe off
showStrobe:
    ldi temp, 0b00000010                              ; this is the correct pin address in port A for only the strobe light
    out portA, temp                                   ; out to portA the strobe light ON
    ldi temp, 1                                       
    sts strobeOn, temp                                ; set flag on for the strobe light
    jmp finishStrobe
offStrobe:
    ldi temp, 0b00000000                              ; load 0 into port A 
    out portA, temp                                   ; turns off the strobe light
    ldi temp, 0
    sts strobeOn, temp                                ; set flag off for the strobe light
finishStrobe:
    clear strobeTimer                                 ; reset the strobe timer
    clr r26
    clr r27
strobeSkip:
    sts strobeTimer, r26                              ; update the value of the strobe timer if the 100 hasn't been mett
    lds r24, tempCounter
    lds r25, tempCounter+1                            ; load the value of the timer
    adiw r25:r24, 1                                   ; increment the register pair
    cpi r24, low(7812)                                ; check if the register pair (r25:r24) = 7812 -> 1 second
    ldi temp, high(7812)
    cpc r25, temp
    breq isSecond                                     ; if the register pair are 7812, we want to go to the protocol if a second has passed
    jmp notSecond                                     ; otherwise we want to update the timer counter and return
isSecond:
    clear tempCounter
    ldi r24, 0
    sts tempCounter, r24                              ; reset timer counter
    sts tempCounter+1, r24
    lds temp1, secondCounter
    inc temp1                                         ; increment the amount of seconds passed
    sts secondCounter, temp1
    lds temp, emergencyshown                          ; if the emergency has been shown we want to display the emergency
    cpi temp, 1
    breq showEmergency2
    jmp skipEmergencyDisplay                          ; otherwise continue normal procedure
showEmergency2:
    PRINT_EMERGENCY                                   ; display emergency message on LCD
    lds temp, emergency                               ; now we want to check if the emergency button has pressed off
    cpi temp, 0
    breq reset_emergency                              ; if so we want to turn off the emergency shown flag and resume normal procedure
    jmp afterprint                                    ; otherwise skip over and resume (since queue empty it will just reti)
reset_emergency:
    ldi temp, 0
    sts emergencyShown, temp                          ; resets the emergency shown flag
    jmp afterPrint
skipEmergencyDisplay:
    lds temp, currentFloor
    sts currentFloor, temp
    PRINT_FLOOR temp
    ; now we want our elevator to move if there is stuff in queue, if not we just want to exit so
AfterPrint:
    lds r24, floor_queue
    lds r25, floor_queue+1                            ; checking if the either half queue has something because if any half has something there is something in queue
    cpi r24, 0
    brne somethinginQueue                             ; if lower part of queue is not empty -> we want to move to our protocol
    cpi r25, 0
    brne somethinginQueue                             ; if higher part of queue is not empty -> we want to move our protocol
    jmp nothinginQueue                                ; otherwise we want to jump to our handler for nothing in queue
somethinginQueue:
    ; if there is stuff on the queue now we want to know which direction the lift will travel in
    ; we want to compare the CURRENT FLOOR to the queue in a way to check if it has reached the highest/lowest floor
    ; the movement of the elevator is simple
    ; it will move up all the way till it reaches the top floor

    ; then move down all the way till it reaches thw lowest floor, taking floors off the queue on its way
    ; i was inspired to do this by attempting my java implementation where i had a queue of booleans size 9
	; and each index showed a floor, and i would check if the current floor is the maximum floor and continue up
	; and check if current floor is min floor and continue down
	; to check if we are at the max floor, we can simply just check if the current floor in bits is higher than all the other floors
	; if there is a floor above, the queue will have a higher value
	; if we are on floor 3 and our queue is floor 1 2 3 -> 0b111
	; since floor 3 has value 8 and floor 1 and 2 together have value 7
	; floor 3 is higher than the remaining queue itself 
	; so we will set the direction to move down
    ; 0b01111111 < 0b10000000

	; to check if we are at the minimum floor we want to check if there are any floors below the current floor
    ; to do this we can subtract 1 from the current floor so if we are on floor 3 0b100 -> 0b011
	; then we check if there are any floors in 0b110 by anding the queue with the 0b011
	; if the result is 0 that means there are no lower floors
	; if floor 1 was still in the queue our result would be 0b001 not 0 so that means there is a lower floor
	; we will continue in one direction until either of these conditions are met which will swap the directions

    lds temp, currentFloor                            ; now we want to convert current floor into bit representation
    ldi XL, 1
    ldi XH, 0 
    CONVERT_FLOOR_INTEGER temp, XL, XH                ; using our macro to convert the floor into bit and store into XL:XH
    lds temp1, floor_Queue
    lds temp2, floor_Queue + 1                        ; load the current queue into temp1:temp2
    cp temp1, XL
    cpc temp2, XH                                     ; now we want to compare the current floor to the Queue  
    brne checkk                                       ; if the current floor is not equal to the queue we go to the check mentioned above
    rcall open_door                                   ; otherwise open the door since the queue == current floor 
    jmp TimerEpilogue                                 ; return from interrupt
; main check mentioned above
checkk:
    lds temp, currentFloor                            ; converting current floor into bit representation
    ldi XL, 1
    ldi XH, 0 
    CONVERT_FLOOR_INTEGER temp, XL, XH
    lds temp1, floor_Queue
    lds temp2, floor_Queue + 1                        ; load the floor queue into temp1:temp2    
    and temp1, XL
    and temp2, XH                                     ; now we want to and the queue with the current floor
    cpi temp1, 0                                      ; compare the result to 0
    ldi temp, 0
    cpc temp2, temp
    breq checkk2                                      ; if the result is not 0 that means we are currently on a floor in the queue 
    rcall open_door                                   ; open the door
    jmp TimerEpilogue                                 ; return from interrupt
; check for direction of movement
checkk2:
    ; check movement down
    lds temp, currentFloor                            ; converting current floor into bit representation
    ldi XL, 1
    ldi XH, 0 
    CONVERT_FLOOR_INTEGER temp, XL, XH                        
    lds temp1, floor_Queue                            ; now we want to load the queue into a register pair 
    lds temp2, floor_Queue + 1
    cp temp1, XL                                      ; now we want to compare the current queue with the current floor
    cpc temp2, XH
    brlo moveDown                                     ; if the queue is SMALLER THAN THE CURRENT FLOOR SET DIRECTION TO DOWN
	; check movement up
    lds temp, currentFloor                            ; convert current floor into bits
    ldi XL, 1
    ldi XH, 0 
    CONVERT_FLOOR_INTEGER temp, XL, XH
    lds temp1, floor_Queue                            ; load current floro into register pair
    lds temp2, floor_Queue + 1
    sbiw XH:XL, 1                                     ; subtract 1 from current floor so 0b100 -> 0b011 as in above
    and XL, temp1                                     ; now we want to and the current floor - 1 with the queue
    and XH, temp2
    cpi XL, 0
    ldi temp, 0                                       ; if the result is = 0 that means we are at lowest floor 
    cpc XH, temp
    brne anotherSkip                                  ; if it is not = 0 that means there are more floors below eg if floor 1 anded we would get 1 not 0
	; to avoid relative branch out of reach
    jmp moveUp                                        ; if its = 0 set direction to up
; jump to move in the same direction
anotherSkip:
    jmp continue                                      ; continues moving in the direction stored in the DOWN flag 
moveDown:
    ldi temp, 1
    sts down, temp                                    ; store true in the down flag so elevator will move downwards
    jmp continue
moveUp:
    ldi temp, 0
    sts down, temp                                    ; store false in the down flag so elevator will move upwards
    jmp continue
; this will move the elevator in the direction stored in down, 1-> down 0-> up
continue:
    lds temp, down
    cpi temp, 1                                       ; if direction stored in the down flag == 1
    breq continueDown                                 ; continue downwards
    jmp continueUp                                    ; else move up
; move down the floors checking if a floor is in the queue
; first check if the CURRENT FLOOR IS ON QUEUE
; IF IT IS call the open door function
; the floor will be removed from queue in the open door function
; return from open if called
; delay for 2s between floors.
; decrement current floor by 1
continueDown:
    ldi temp1, MOVING_DOWN
    out portC, temp1                                  ; output to the LED down pattern, lower half of LED lit up
    lds temp, currentFloor                            ; convert the current floor into bit representation
    ldi XL, 1
    ldi XH, 0 
    CONVERT_FLOOR_INTEGER temp, XL, XH
    lds temp1, floor_Queue
    lds temp2, floor_Queue + 1                        ; now we want to check if the current floor while moving down is on the queue
    and temp1, XL
    and temp2, XH                                     ; to do this and the floor with the queue
    cpi temp1, 0
    ldi temp, 0
    cpc temp2, temp
    breq ignoredown                                   ; if result = 0 that means the floor isn't on queue (result should be the current floor if it is)
                                                      ; so ignore the open door call and continue
    rcall OPEN_DOOR                                   ; otherwise we open the door 
ignoredown:
    lds temp, secondCounter                           ; whether we open or close the door we will wait for 2 seconds so
    cpi temp, 2                                       ; check if the second counter has 2 inside of it
    breq anotherskipp                                 ; if its = 2 that means we can continue to the next floor below
    jmp timerEpilogue                                 ; otherwise return from interrupt
; seriously relative branch out of reach is so stupid
anotherskipp:
    ldi temp, 0                                       ; reset the counter for number of seconds stored so it can constantly perform the ignoredown label correctly
    sts secondCounter, temp
    lds temp, currentFloor                            ; decrement the current floor by 1 since we are moving down
    dec temp
    sts currentFloor, temp                            ; store the decremented current floor into the label
    jmp timerEpilogue                                 ; return from interrupt handler
; move up the floors checking if a floor is in the queue
; first check if the CURRENT FLOOR IS ON QUEUE
; IF IT IS call the open door function
; return from open if called
; delay for 2s between floors.
; increment current floor by 1
continueUp:
    ldi temp1, MOVING_UP                              ; output to the LED's the moving up pattern (top half of LED is lit up)  
    out portC, temp1
    lds temp, currentFloor                            ; converting the current floor into the bit representation
    ldi XL, 1
    ldi XH, 0 
    CONVERT_FLOOR_INTEGER temp, XL, XH
    lds temp1, floor_Queue
    lds temp2, floor_Queue + 1                        ; now we want to load the queue so we can check if the current floor is on the queue
    and temp1, XL
    and temp2, XH                                     ; and the queue with the current floor
    cpi temp1, 0
    ldi temp, 0
    cpc temp2, temp                                   ; check if the result is 0 (i.e not on queue) if it was result would be the current floor in bits
    breq ignoreup                                     ; if result is equal to 0 we skip over and go to the ignore up label don't open the door
    rcall OPEN_DOOR                                   ; otherwise we will open door (this will remove current floor from queue)
ignoreup:
    lds temp, secondCounter                           ; whether we open the door or not we still want to delay 2s between floors
    cpi temp, 2
    breq anotherskippr                                ; if the amount of seconds passed is 2 we want to go to the label which will update the current floor
    jmp timerEpilogue                                 ; otherwise return from the interrupt handler
anotherskippr:
    ldi temp, 0                                       ; reset the amount of seconds passed so we can keep performing continue up
    sts secondCounter, temp
    lds temp, currentFloor                            ; increment the current floor by 1
    inc temp
    sts currentFloor, temp                            ; store the incremented current floor into the label
    jmp timerEpilogue                                 ; return from the interrupt handler
NotSecond:
    sts TempCounter, r24                              ;update the value of the temporary counter
    sts TempCounter+1, r25    
    jmp TimerEpilogue
; if nothing is in the queue we have to also account for if open button (PB1) is pressed
nothinginQueue:
    ldi temp1, 0
    sts secondCounter, temp1
    ldi temp1, 1
    sts canOpen, temp1
    lds temp1, opening
    cpi temp1, 1
    breq addCurrToQueue
    jmp timerEpilogue
addCurrToQueue:
    ldi temp1, 0
    sts opening, temp1
    lds temp1, currentFloor
    ldi XL, 1
    ldi XH, 0 
    CONVERT_FLOOR_INTEGER temp1, XL, XH
    lds ZL, floor_Queue
    lds ZH, floor_Queue + 1    
    UPDATE_STATE_ADD ZL,XL,ZH,XH
    sts floor_Queue, ZL
    sts floor_Queue+1,ZH
timerEpilogue:
    epilogue
    reti

OPEN_DOOR:
    prologue
	ldi temp, 1
	sts doorSequence, temp
    lds temp, secondCounter
    cpi temp, 3
    brsh skipOpen
    ldi temp1, 0xff
    ;initialise voltage to max
    sts OCR3BL, temp1
    sts OCR3BH, temp1
    ldi temp1, DOOR_CLOSED
    out portC, temp1
    jmp TimerEpilogue
skipOpen:
    ldi temp1, DOOR_OPEN
    out portC, temp1    
    ldi temp1, 1
    sts canClose, temp1
    ;motor spins for 1s then off
    ldi temp1, 0
    ;initialise voltage to max
    sts OCR3BL, temp1
    sts OCR3BH, temp1
    lds temp, closing
    cpi temp, 1
    breq startClosing
    lds temp, secondCounter
    cpi temp, 7
    brsh startClosingcheck
    jmp TimerEpilogue
startclosingcheck:
    ;first we want to check for port D if the button is pushed down (open) if it is we want to not allow it to move on
    in temp, pinD
    ldi temp1, 0b0000001
    and temp1, temp
    cpi temp1, 0
    breq stayopen
    jmp startClosing
stayopen:
    ldi temp, 7
    sts secondCounter, temp
    jmp TimerEpilogue
startClosing:
    ldi temp1, 1
    sts canOpen, temp1
    lds temp, opening
    cpi temp, 1
    breq startReopening
    jmp skipReopening
startReopening:
    ldi temp, 4
    sts secondCounter, temp
    ldi temp, 0
    sts opening, temp
    epilogue
    ret
skipReopening:
    ldi temp1, DOOR_CLOSED
    out portC, temp1
    ;turn motor on to signal door closing for 1s
    ldi temp1, 0xff
    ;initialise voltage to max
    sts OCR3BL, temp1
    sts OCR3BH, temp1
    lds temp, closing
    cpi temp, 1
    breq closecheck
    jmp skipovercheck
closecheck:
    lds temp, alreadyClosing
    cpi temp, 1
    breq closeWithMotor
    lds temp, secondCounter
    inc temp
    sts timeOfClose, temp
    lds temp, secondCounter
    sts secondCounter, temp
    jmp closeWithMotor
skipovercheck:
    lds temp, secondCounter
    cpi temp, 9
    brsh closed
    jmp TimerEpilogue
closeWithMotor:
    ldi temp1, 1
    sts alreadyClosing, temp1
    ldi temp1, 0xff
    ;initialise voltage to max
    sts OCR3BL, temp1
    sts OCR3BH, temp1
    lds temp1, timeOfClose
    lds temp2, secondCounter
    cp temp2, temp1
    brsh closed
    jmp TimerEpilogue    
closed:
    ldi temp1, 0
    ;turn motor off and return
    ;initialise voltage to max
    sts OCR3BL, temp1
    sts OCR3BH, temp1
    sts secondCounter, temp1
    sts closing, temp1
    sts timeOfClose, temp1
    sts alreadyClosing, temp1
    sts canClose, temp1
    sts opening, temp1
    sts canOpen, temp1
	sts doorSequence, temp1
    lds temp, currentFloor
    ;now we want to convert current floor into bit representation
    ldi XL, 1
    ldi XH, 0 
    CONVERT_FLOOR_INTEGER temp, XL, XH
    lds ZL, floor_Queue
    lds ZH, floor_Queue + 1    
    eor ZL,XL 
    eor ZH,XH
    sts floor_Queue, ZL
    sts floor_Queue+1,ZH
    lds temp, emergency
    cpi temp, 1
    breq showDisplay
    jmp skipDisplay
showDisplay:
	lds temp, CurrentFloor
	cpi temp, 0
	breq cont
	epilogue
	ret
cont:
    ldi temp, 1
    sts emergencyshown, temp
    ldi temp, 0xff
    out portC, temp
    PRINT_EMERGENCY
    epilogue
    ret
skipDisplay:
    epilogue
    ret

forceClose:
    prologue
    ldi temp1, 0xff
    sts OCR3BL, temp1
    sts OCR3BH, temp1    
    rcall sleep_1s
    rcall sleep_1s
    ldi temp1, DOOR_CLOSED
    out portC, temp1
    ldi temp1, 0
    ;turn motor off and return
    ;initialise voltage to max
    sts OCR3BL, temp1
    sts OCR3BH, temp1
    sts secondCounter, temp1
    sts closing, temp1
    sts timeOfClose, temp1
    sts alreadyClosing, temp1
    sts canClose, temp1
    sts opening, temp1
    sts canOpen, temp1
	sts doorSequence, temp1    
	lds temp, currentFloor

    ;now we want to convert current floor into bit representation
    ldi XL, 1
    ldi XH, 0 
    CONVERT_FLOOR_INTEGER temp, XL, XH
    lds ZL, floor_Queue
    lds ZH, floor_Queue + 1    
    eor ZL,XL 
    eor ZH,XH
    sts floor_Queue, ZL
    sts floor_Queue+1,ZH
    epilogue
    ret
