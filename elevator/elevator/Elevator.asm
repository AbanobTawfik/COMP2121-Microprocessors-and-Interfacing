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
        .byte 2
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
    lds temp, canClose
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

PB1_ON_PRESS:
;  PROLOGUE
    prologue     
    lds temp, canClose
    cpi temp, 0
    breq pb1Epilogue
    ldi temp, 1
    sts closing, temp

    ;this button will enter 1 so we load our pattern << to move the bit up (aka multiply by 2) and then add  1 to the end 

pb1Epilogue:
    ;epilogue
    epilogue
    reti    
PB0_ON_PRESS:
;  PROLOGUE
    prologue
    lds temp, canOpen
    cpi temp, 0
    breq pb0Epilogue
    ldi temp, 1
    sts opening, temp

pb0Epilogue:
    ;epilogue
    epilogue
    reti    

Timer0OVF:
;storing onto the stack the values we want to preserve and conflict registers
;  PROLOGUE
    prologue
    ;button debouncing ~100 ms since 7812 = 1 second, 25 ms = 7812/1000 * 100 
;if the buttons status is on we want to start counter to reset it
    lds temp, emergency
    cpi temp, 1
    breq strobePattern
    jmp strobeSkip
strobePattern:
    lds r26, strobeTimer
    lds r27, strobeTimer+1
    adiw r27:r26, 1
    cpi r26, low(100)   ;on off ever 1/4s
    ldi temp, high(100)
    cpc temp, r27
    brne strobeSkip                ;after debouncy has been set to enable debounce statuses
    ;now we want to load the value of temporary counter into the register pair r25/r24
    
    lds temp, strobeOn
    cpi temp, 0
    breq showStrobe
    jmp offStrobe
showStrobe:
    ldi temp, 0b00000010
    out portA, temp
    ldi temp, 1
    sts strobeOn, temp
    jmp finishStrobe
offStrobe:
    ldi temp, 0b00000000
    out portA, temp
    ldi temp, 0
    sts strobeOn, temp
finishStrobe:
    clear strobeTimer
    clr r26
    clr r27

strobeSkip:
    sts strobeTimer, r26        ;update the value of the temporary counter
    sts strobeTimer+1, r27
    lds r24, tempCounter
    lds r25, tempCounter+1
    adiw r25:r24, 1            ;increment the register pair
    cpi r24, low(7812)        ;check if the register pair (r25:r24) = 7812
    ldi temp, high(7812)
    cpc r25, temp
    breq isSecond            ;if the register pair are not 7812, a second hasnt passed so we jump to NotSecond which will increase counter by 1
    jmp notSecond
isSecond:
    clear tempCounter
    ldi r24, 0
    sts tempCounter, r24
    sts tempCounter+1, r24
    lds temp1, secondCounter
    inc temp1                    ;increment the amount of seconds passed
    sts secondCounter, temp1
    lds temp, emergencyshown
    cpi temp, 1
    breq showEmergency2
    jmp skipEmergencyDisplay
showEmergency2:
    PRINT_EMERGENCY
    lds temp, emergency
    cpi temp, 0
    breq reset_emergency
    jmp afterprint
reset_emergency:
    ldi temp, 0
    sts emergencyShown, temp
    jmp afterPrint
skipEmergencyDisplay:
    lds temp, currentFloor
    sts currentFloor, temp
    PRINT_FLOOR temp
    ;now we want our elevator to move if there is stuff in queue, if not we just want to exit so
AfterPrint:
    lds r24, floor_queue
    lds r25, floor_queue+1        ;checking if the queue is empty
    cpi r24, 0
    brne somethinginQueue
    cpi r25, 0
    brne somethinginQueue            ;if nothing is in the queue we just want to return!
    jmp nothinginQueue
somethinginQueue:
    ;otherwise we want to check the current queue and see which direction we are travelling in
    ;if there is stuff on the queue now we want to know which direction the lift will travel in
    ;we want to compare the CURRENT FLOOR to the queue in a way to check if it is moving up or down with the current 
    ;the movement of the elevator is simple
    ;it will move up all the way till it reaches the top floor
    ;then move down all the way till it reaches thw lowest floor, taking floors off the queue on its way
    ;to check if we are at the top, we can simply just check if the current floor in bits
    ;is higher than the entire queue, since 0b11111110 < 0b00000001
    ;now to check if we are at the bottom we simply want to subtract 1 from the queue
    ;and AND, if the result is = 0 -> no floors below move up
    ;otherwise continue in direction
    lds temp, currentFloor
    ;now we want to convert current floor into bit representation
    ldi XL, 1
    ldi XH, 0 
    CONVERT_FLOOR_INTEGER temp, XL, XH
    ;queue is in r24:r25 we want a copy of it for our subtraction
    lds temp1, floor_Queue
    lds temp2, floor_Queue + 1
    cp temp1, XL
    cpc temp2, XH
    brne checkk
    rcall open_door
    jmp TimerEpilogue
checkk:
    lds temp, currentFloor
    ;now we want to convert current floor into bit representation
    ldi XL, 1
    ldi XH, 0 
    CONVERT_FLOOR_INTEGER temp, XL, XH
    ;queue is in r24:r25 we want a copy of it for our subtraction
    lds temp1, floor_Queue
    lds temp2, floor_Queue + 1
    and temp1, XL
    and temp2, XH
    cpi temp1, 0
    ldi temp, 0
    cpc temp2, temp
    breq checkk2
    rcall open_door
    jmp TimerEpilogue
checkk2:
    lds temp, currentFloor
    ;now we want to convert current floor into bit representation
    ldi XL, 1
    ldi XH, 0 
    CONVERT_FLOOR_INTEGER temp, XL, XH
    ;queue is in r24:r25 we want a copy of it for our subtraction
    lds temp1, floor_Queue
    lds temp2, floor_Queue + 1
    cp temp1, XL
    cpc temp2, XH
    brlo moveDown
    ;now the second check to change direction
    lds temp, currentFloor
    ;now we want to convert current floor into bit representation
    ldi XL, 1
    ldi XH, 0 
    CONVERT_FLOOR_INTEGER temp, XL, XH
    ;queue is in r24:r25 we want a copy of it for our subtraction
    lds temp1, floor_Queue
    lds temp2, floor_Queue + 1
    sbiw XH:XL, 1
    and XL, temp1
    and XH, temp2
    cpi XL, 0
    ldi temp, 0
    cpc XH, temp
    ;if its = 0 that means direction is up as there are no lower floors
    brne anotherSkip
    jmp moveUp
anotherSkip:
    jmp continue

moveDown:
    ;set direction to be down so down == trye
    ldi temp, 1
    sts down, temp
    jmp continue
moveUp:
    ;set direction to be up so down == false
    ldi temp, 0
    sts down, temp
    jmp continue

continue:
    lds temp, down
    cpi temp, 1
    breq continueDown
    ;otherwise move up
    jmp continueUp
continueDown:
    ldi temp1, MOVING_DOWN
    out portC, temp1
    ;move up the floors checking if a floor is in the queue
    ;first check if the CURRENT FLOOR IS ON QUEUE
    ;IF IT IS call the open door function
    ;return from open if called
    ;delay for 2s between floors.
    ;increment current floor by 1
    lds temp, currentFloor
    ;now we want to convert current floor into bit representation
    ldi XL, 1
    ldi XH, 0 
    CONVERT_FLOOR_INTEGER temp, XL, XH
    ;queue is in r24:r25 we want a copy of it for our subtraction
    lds temp1, floor_Queue
    lds temp2, floor_Queue + 1
    and temp1, XL
    and temp2, XH
    cpi temp1, 0
    ldi temp, 0
    cpc temp2, temp
    breq ignoredown
    ;in here we will update the queue by removing the current floor
    rcall OPEN_DOOR
ignoredown:
    ;after regardless of return we sleep for 2s
    lds temp, secondCounter
    cpi temp, 2
    breq anotherskipp
    jmp timerEpilogue
anotherskipp:
    ldi temp, 0
    sts secondCounter, temp
    lds temp, currentFloor
    dec temp
    sts currentFloor, temp
    ;do_lcd_data_in_register temp
    jmp timerEpilogue
continueUp:
    ldi temp1, MOVING_UP
    out portC, temp1
    ;move up the floors checking if a floor is in the queue
    ;first check if the CURRENT FLOOR IS ON QUEUE
    ;IF IT IS call the open door function
    ;return from open if called
    ;delay for 2s between floors.
    ;increment current floor by 1
    lds temp, currentFloor
    ;now we want to convert current floor into bit representation
    ldi XL, 1
    ldi XH, 0 
    CONVERT_FLOOR_INTEGER temp, XL, XH
    ;queue is in r24:r25 we want a copy of it for our subtraction
    lds temp1, floor_Queue
    lds temp2, floor_Queue + 1
    and temp1, XL
    and temp2, XH
    cpi temp1, 0
    ldi temp, 0
    cpc temp2, temp
    breq ignoreup
    ;in here we will update the queue by removing the current floor
    rcall OPEN_DOOR
ignoreup:
    ;after regardless of return we sleep for 2s
    ;after regardless of return we sleep for 2s
    lds temp, secondCounter
    cpi temp, 2
    breq anotherskippr
    jmp timerEpilogue
anotherskippr:
    ldi temp, 0
    sts secondCounter, temp
    lds temp, currentFloor    
    inc temp
    sts currentFloor, temp
    ;do_lcd_data_in_register temp
    jmp timerEpilogue    
NotSecond:
    sts TempCounter, r24        ;update the value of the temporary counter
    sts TempCounter+1, r25    
    jmp TimerEpilogue

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
    lds temp, currentFloor
    sts opening, temp1
    sts canOpen, temp1
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
