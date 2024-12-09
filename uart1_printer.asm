;	UART1 printer
; 	Richard Turnnidge 2023

; 	Reads a byte and displaye it. Simple

; ---------------------------------------------
;
;	MACROS
;
; ---------------------------------------------

	macro MOSCALL afunc
	ld a, afunc
	rst.lil $08
	endmacro

; ---------------------------------------------
;
;	INITIALISE
;
; ---------------------------------------------

	.assume adl=1						; big memory mode
	.org $40000							; load code here

	jp start_here						; jump to start of code

	.align 64							; MOS header
	.db "MOS",0,1

; ---------------------------------------------
;
;	INITIAL SETUP CODE HERE
;
; ---------------------------------------------

start_here:
										; store everything as good practice	
	push af								; pop back when we return from code later
	push bc
	push de
	push ix
	push iy


	call CLS 							; clear screen
	call openUART1						; init the UART1 serial port
	call hidecursor						; hide the cursor

	ld hl, text_data
	ld bc, end_text_data - text_data
	rst.lil $18							; print default text to screen

; ---------------------------------------------
;
;	MAIN LOOP
;
; ---------------------------------------------

MAIN_LOOP:	
	MOSCALL $08							; get IX pointer to sysvars
	ld a, (ix + 05h)					; ix+5h is 'last key pressed'
	cp 27								; is it ESC key?
	jp z, exit_here						; if so exit cleanly

	call uart1_handler					; get any new data from UART1

	ld a, (uart1_received)				; check if we got anything
	cp 0
	jr z, MAIN_LOOP						; nothing new, loop round again

								
	ld a, (uart1_buffer)				; got some new data				
	call printDec						; display it
	ld hl, LINEFEED
	call printString					; and a new line

	jp MAIN_LOOP



; ---------------------------------------------
; Adapted from Hexload source

uart1_handler:		
	DI
	PUSH	AF
	IN0	A,(REG_LSR)						; Get the line status register
	AND	UART_LSR_RDY					; Check for characters in buffer
	JR	Z, noData 						; Nothing received
			
	LD	A,1   							; we got new data
	LD	(uart1_received),a 				; so set flag for new data
	IN0	A,(REG_RBR)						; Read the character from the UART receive buffer
	LD	(uart1_buffer),A  				; store new byte of data
	POP	AF
	EI

 	;ld a, (uart1_buffer)				; check it is a control code. Exit if not
	;LD (uart1_received), A				; store it

	RET

noData:
	XOR 	A,A
	LD	(uart1_received),A				; note that nothing is available	
	POP	AF
	EI

	RET
			
uart1_buffer:		.db	1				; 64 byte receive buffer
uart1_received:		.db	1				; boolean
uart1_data:		.db	1					; final pot MidiValue received
uart1_command: 		.db 	0			; current command received

; ---------------------------------------------
;
;	UART CODE
;
; ---------------------------------------------

openUART1:
	ld ix, UART1_Struct
	MOSCALL $15							; open uart1
	ret 

; ---------------------------------------------

closeUART1:
	MOSCALL $16 						; close uart1
	ret 

; ---------------------------------------------

UART1_Struct:	
	.dl 	31250 						; baud (stored as three byte LONG)
	.db 	8 							; data bits
	.db 	1 							; stop bits
	.db 	0 							; parity bits
	.db 	0							; flow control
	.db 	0							; interrupt bits

; ---------------------------------------------
;
;	EXIT CODE CLEANLY
;
; ---------------------------------------------

exit_here:

	call closeUART1
	call CLS
										; reset all values before returning to MOS
	pop iy
	pop ix
	pop de
	pop bc
	pop af
	ld hl,0

	ret									; return to MOS here

; ---------------------------------------------
;
;	OTHER ROUTINES	
;
; ---------------------------------------------

CLS:
	ld a, 12
	rst.lil $10							; CLS
	ret 

; ---------------------------------------------

hidecursor:
	push af
	ld a, 23
	rst.lil $10
	ld a, 1
	rst.lil $10
	ld a,0
	rst.lil $10	;VDU 23,1,0
	pop af
	ret

; ---------------------------------------------
; strings used

LINEFEED:           .asciz "\r\n"

printString:                			; print zero terminated string
    ld a,(hl)
    or a
    ret z
    RST.LIL 10h
    inc hl
    jr printString

; ---------------------------------------------
;
;	DEBUG ROUTINES
;
; ---------------------------------------------
	
; print decimal value of 0 -> 255 to screen at current TAB position

printDec:               ; debug A to screen as 3 char string pos

    ld (base),a         ; save

    cp 200              ; are we under 200 ?
    jr c,_under200      ; not 200+
    sub a, 200
    ld (base),a         ; sub 200 and save

    ld a, '2'           ; 2 in ascii
    rst.lil $10         ; print out a '200' digit

    jr _under100

_under200:
    cp 100              ; are we under 100 ?
    jr c,_under100      ; not 200+
    sub a, 100
    ld (base),a         ; sub 100 and save

    ld a, '1'           ; 1 in ascii
    rst.lil $10         ; print out a '100' digit

_under100:
    ld a, (base)        ; get last 2 digits as decimal
    ld c,a              ; store numerator in C
    ld d, 10            ; D will be denominator
    call C_Div_D        ; divide C by 10 to get two parts. 
                        ; A is the remainder, C is the int of C/D

    ld b, a             ; put remainder ascii into B

    ld a, c             ; get int div
    cp 0                ; if 0 (ie, number was <10)
    jr z, _lastBut1    ; just do last digit

    add a, 48           ; add 48 to make ascii of int C/D
    rst.lil $10         ; print out 10s digit
    jr _lastDigit

_lastBut1:
    add a, 48           ; add 48 to make ascii of int C/D
    rst.lil $10         ; print out 10s digit

_lastDigit:
    ld a,b              ; get remainder back
    add a, 48           ; add 48 to remainder to convert to ascii   
    rst.lil $10         ; print out last digit

    ret 

base:   .db     0       ; used in calculations

; -----------------

C_Div_D:
;Inputs:
;     C is the numerator
;     D is the denominator
;Outputs:
;     A is the remainder
;     B is 0
;     C is the result of C/D
;     D,E,H,L are not changed
;
    ld b,8              ; B is counter = 8
    xor a               ; [loop] clear flags
    sla c               ; C = C x 2
    rla                 ; A = A x 2 + Carry
    cp d                ; compare A with Denominator
    jr c,$+4            ; if bigger go to loop
    inc c               ; inc Numerator
    sub d               ; A = A - denominator
    djnz $-8            ; go round loop
    ret                 ; done 8 times, so return
; ---------------------------------------------
	
display_A:					; debug A to screen as HEX byte pair at pos BC
	ld (debug_char), a			; store A
						; first, print 'A=' at TAB 36,0
	ld a, 31				; TAB at x,y
	rst.lil $10
	ld a, b					; x=b
	rst.lil $10
	ld a,c					; y=c
	rst.lil $10				; put tab at BC position

	ld a, (debug_char)			; get A from store, then split into two nibbles
	and 11110000b				; get higher nibble
	rra
	rra
	rra
	rra					; move across to lower nibble
	add a,48				; increase to ascii code range 0-9
	cp 58					; is A less than 10? (58+)
	jr c, nextbd1				; carry on if less
	add a, 7				; add to get 'A' char if larger than 10
nextbd1:	
	rst.lil $10				; print the A char

	ld a, (debug_char)			; get A back again
	and 00001111b				; now just get lower nibble
	add a,48				; increase to ascii code range 0-9
	cp 58					; is A less than 10 (58+)
	jp c, nextbd2				; carry on if less
	add a, 7				; add to get 'A' char if larger than 10	
nextbd2:	
	rst.lil $10				; print the A char
	
	ld a, (debug_char)
	ret					; head back

debug_char: 	.db 0

; ---------------------------------------------
;
;	TEXT AND DATA	
;
; ---------------------------------------------

text_data:

	.db 31, 0, 0, "Serial Read on UART1\r\n\r\n"


end_text_data:

; ---------------------------------------------
;
;	PORT CONSTANTS - FOR REFERENCE, NOT ALLL ARE USED
;
; ---------------------------------------------

PORT:			EQU	$D0		; UART1
				
REG_RBR:		EQU	PORT+0		; Receive buffer
REG_THR:		EQU	PORT+0		; Transmitter holding
REG_DLL:		EQU	PORT+0		; Divisor latch low
REG_IER:		EQU	PORT+1		; Interrupt enable
REG_DLH:		EQU	PORT+1		; Divisor latch high
REG_IIR:		EQU	PORT+2		; Interrupt identification
REG_FCT:		EQU	PORT+2;		; Flow control
REG_LCR:		EQU	PORT+3		; Line control
REG_MCR:		EQU	PORT+4		; Modem control
REG_LSR:		EQU	PORT+5		; Line status
REG_MSR:		EQU	PORT+6		; Modem status
REG_SCR:		EQU 	PORT+7		; Scratch
TX_WAIT:		EQU	16384 		; Count before a TX times out
UART_LSR_ERR:		EQU 	$80		; Error
UART_LSR_ETX:		EQU 	$40		; Transmit empty
UART_LSR_ETH:		EQU	$20		; Transmit holding register empty
UART_LSR_RDY:		EQU	%01		; Data ready




