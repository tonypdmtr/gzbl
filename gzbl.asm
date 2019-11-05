; GZ family BootLoader (frame code, main file)

#include "gz60.inc"             ; Load microcontroller specific register definitions

NL              equ     $0A     ; New line character (Linux)
ROUTINESINRAM   equ     $0200	; Start of area of Flash handler routines in RAM


#RAM

SRSR_saved      ds      1       ; Saved value of SRSR register, because read clears (can only be read once)
wr_datac        ds      1  	; Number of data byte to be written (source for flash writer)
dump_addr       ds      2  	; Address variable for general purpose
address         ds      2  	; Address variable for flash write and erase
wr_datap        ds      2  	; Write data pointer
mc_src          ds      2  	; memcopy source address
mc_dest         ds      2  	; memcopy destination address
mc_num          ds      2  	; memcopy number of bytes to copy
p_flcr          ds      2       ; Address of flash control register (of Flash1 or Flash2)
p_flbpr         ds      2       ; Address of flash block protection register (of Flash1 or Flash2)
cs_trign        ds      1  	; frame checksum, and before frames number of received trigger characters
comtimer        ds      1       ; timeout timer for serial UART communication
nosysinfo       ds      1       ; Administration that "no system software" info was already printed out (do not print it again)

wr_datat        equ     $0080  	; 128 byte write data buffer. It can contain data with any length and from any address.
data            equ     $0100  	; 128 byte buffer for flash manipulation. Always alligned to a complete page
stack_top       equ     $043F  	; 64 byte stack reserved for bootloader


#ROM
;Start of bootloader. This shall be as much as possible in last part of Flash1.
; This ensures compatibility with smaller memory variant uCs, and most space for system software.
; To be adjusted manually without overlap in gz60.inc.

bl_start_addr
;-----------------------------------------
; STRINGS
;-----------------------------------------
welcome fcs     NL,'HC908GZ60 BootLoader (github.com/butyi/gzbl)',NL
sysstr  fcs     " Application is starting.",NL
nsstr   fcs     " Application is not found. Stay in BootLoader.",NL

;-----------------------------------------
;RUTINOK
;-----------------------------------------

#include "cgm.sub"
#include "lib.sub"
#include "flash.sub"
#include "pcb.sub"
#include "sci.sub"
#include "tbm.sub"
#include "term.sub"

;-----------------------------------------
; MAIN rutinok
;-----------------------------------------


; Main entry point. This address shall be in Reset Vector.
entry

	; Disable interrupts
        sei

	; Init Stack
        ldhx    #stack_top
        txs

	; Save reset status register, because it is cleared during read
        lda     SRSR
        sta     SRSR_saved

	; Clock Generator module init
        jsr     PLLInit

	; Enable CAN module
        lda     #MSCANEN_+TMBCLKSEL_
        sta     CONFIG2

	; LVI module enable
        lda     #LVI5OR3_
        sta     CONFIG1

	; Flash Block protection setup
        ;  Lock bootloader area on Flash1
        ;  Address to lock F800h = 1111 1000 0000 0000 (comes from reset vector)
        ;  These bits are needed    xxx xxxx x
        lda     Vreset          ; Load reset vector High byte
        lsla                    ; Shift up by 1
        ldx     Vreset+1        ; Load reset vector Low byte just for test
        bpl     bp_1            ; Jump when plus, so MSB is zero
        inca
bp_1
        sta     FL1BPR

        ; Unlock the whole Frash2
        lda     #$FF
        sta     FL2BPR

	; Clear RAM variables
        clr     nosysinfo
        clr     cs_trign
        clr     dump_addr
        clr     dump_addr+1

	; LED Init
        @LEDOFF
        @LEDINIT

	; PCB specific initialization (if needed)
        jsr     PCB_Init

	; Copy flash handler routines into RAM
        ldhx    #ramprog
        sthx    mc_src
        ldhx    #ROUTINESINRAM
        sthx    mc_dest
        ldhx    #ramprogend-ramprog
        jsr     memcopy

	; SCI module init
        jsr     SCIInit
        ldhx    #welcome
        jsr     sciputs

	; Time related inits
        jsr     TBMInit

	; Terminal init on UART
        jsr     TERM_Init



; -----------------------------------------------------------------------------------------
; Here start the main loop
; -----------------------------------------------------------------------------------------
main_time

        @tim			; Pull up timer
        @LEDON
main_loop
        jsr     TBMHandle

        ; wait for communication attempt on UART
        brclr   5,SCS1,sci_nothing
        bsr     serialtask
        clr     cs_trign
        bra     main_time       ;loop again with pull up timer
sci_nothing

        ; Check time
        tst     comtimer
        beq     system          ;If time spent, call system software
        bra     main_loop       ;If time not yet spent, wait further


; Call of system software
system

        @LEDOFF

        ; Check Vpll vector, if here data is not $FFFF there is system software to call
        ;  Do not forget: Bootloader can download standalone software, where the start address
        ;  is allocated to vector Vreset. The bootloader will move start address from Vreset
        ;  to Vpll, and keep bootloader start address in Vreset. Therefore system software
        ;  start address will be in Vpll. If system software want to use Vpll, bad luck
        ;  this bootloader cannot be used, or must be modified to use other not used vector.
        lda     Vpll
        and     Vpll+1
        coma
        bne     issys		;there is system software

; Here comes if there is no system software
nosys
        ; Print "no sys" info only once (first time)
        tst     nosysinfo	; if "no sys" info was already printed
        bne     stayinboot	; do not write it again
        inc     nosysinfo	; set flag to not print "no sys" info again

        ; Print "no sys" info
        ldhx    #nsstr
        jsr     sciputs

        ; Stay in bootloader further
        bra     stayinboot

; There is system software, jump to there
issys
	; Print "is sys" info
        ldhx    #sysstr
        jsr     sciputs

	; Load start addess of system software, and jump to there
        lda     Vpll
        psha
        pulh
        ldx     Vpll+1
        jmp     ,x

; There is no system software. Wait 0,5s and jump to wait download attempt again
stayinboot
        mov     #15,comtimer
delay_c
        jsr     TBMHandle
        tst     comtimer
        bne     delay_c

        bra     main_time

; Task to handle serial communication
serialtask
        jsr     TBMHandle

        ; Timeout check
        tst     comtimer
        @req			; If timeout reached, return from task

        ; Try to read a character
        jsr     scigetc
        bcc     serialtask      ; If no character received, wait further

        ; If 't' arrived, terminal is needed
        cmp     #'t'
        @jeq    terminal

        ; Check for download trigger character
        cmp     #$1C
        bne     serialtask      ; If no trigger character received, wait further
        ; If expected trigger character arrived
        inc     cs_trign        ; Count the trigger characters

        ; Check number of received trigger characters
        lda     cs_trign
        cmp     #4		; shall be 4 for successfull connection
        bne     serialtask      ; If less that 4 received only, wait further

        ; Expected number of trigger characters were received,
        ;  this is a valid download request.

        ; Send answer to confirm successfull trigger reception (4 times $E3)
        lda     #$E3
        jsr     sciputc
        jsr     sciputc
        jsr     sciputc
        jsr     sciputc


; -----------------------------------------------------------------------
; Format of serial frame:
; $56,$AB,lenh,lenl,addrh,addrl,d0,d1,...dn,cs
; Answer frame:
; $BA,$65,addrh,addrl,error
;  error=0: successfull
;  error=1: cs error,
;  error=2: address error
;  error=3: timeout error
;  error=4: len is zero
;  error=5: len is too high (>128)
;  error=6: out of page (page overflow from address with given len)
;
; frame handling: - pull up timer to 1s (at 38400 a frame is 32ms/128byte)
;                   timeout always causes read a new frame
;                 - wait for $56, if byte is different, read a new frame
;                 - wait for $AB, if byte is different, read a new frame
;                 - wait for len, save it, if wrong, read a new frame
;                 - wait for address, save it, if wrong, read a new frame
;                 - wait for data bytes, save it, and calculate checksum meantime
;                 - wait for checksum, compare it, if wrong, read a new frame
;
; -----------------------------------------------------------------------
frames
        ; Switch debug LED on
        @LEDON

        ; Wait for first byte of frame header ($56)
        bsr     scigetct	; Timeout type getc
        bcs     sf_arrived      ; If character received, go further
        rts                     ; If no character received during time, return (lost communication)
sf_arrived

        ; Character received, check it
        cmp     #$56
        bne     frames		; Not the expected, wait for the next

        ; Wait for second byte of frame header ($AB)
        bsr     scigetct	; Timeout type getc
        bcc     errcode3        ; In case of timeout: errcode3
        cmp     #$AB		; Character received, check it
        bne     frames          ; Not the expected, wait for the next frame

        ; Frame header ($56 $AB) arrived
        clr     cs_trign     	; clear checksum variable

        ; Read len high byte, not used in GZ falily because page size is just 128 bytes, so it is always zero
        bsr     scigetct	; Timeout type getc
        bcc     errcode3        ; In case of timeout: errcode3
        bne     errcode5        ; If 256<len (high byte is not zero): errcode5

        ; Read len low byte
        bsr     scigetct	; Timeout type getc
        bcc     errcode3        ; In case of timeout: errcode3
        beq     errcode4        ; If len=0: errcode4
        cmp     #128
        bhi     errcode5        ; If 128<len: errcode5
        sta     wr_datac	; Store len parameter in RAM
        bsr     addcs		; Add byte to checksum for later check

        ; Read address hi
        bsr     scigetct	; Timeout type getc
        bcc     errcode3        ; In case of timeout: errcode3
        sta     dump_addr       ; Store parameter in RAM
        bsr     addcs		; Add byte to checksum for later check

        ; Read address lo
        bsr     scigetct	; Timeout type getc
        bcc     errcode3        ; In case of timeout: errcode3
        sta     dump_addr+1     ; Store parameter in RAM
        bsr     addcs		; Add byte to checksum for later check

        ; Read data bytes into RAM
        ;dump_addr     ; address where data to be written
        ;wr_datac      ; number of bytes to be written
        ;wr_datat      ; data buffer
        clrx
        clrh
newdata
        bsr     scigetct	; Timeout type getc
        bcc     errcode3        ; In case of timeout: errcode3
        sta     wr_datat,x      ; Store data byte in RAM buffer
        bsr     addcs           ; Add byte to checksum for later check
        incx                    ; increment index
        cpx     wr_datac        ; Last data index (e.g. in case of 128 bytes -> 127)
        blo     newdata         ; If not the last, read next byte

        ; Read checksum
        bsr     scigetct	; Timeout type getc
        bcc     errcode3        ; In case of timeout: errcode3
        cmp     cs_trign	; Compare with calculated checksum
        beq     wr2fls          ; If same, jump to write (write from RAM back to Flash)
errcode1
        lda     #1              ; CS error code
errcode0
        bsr     answer		; Send answer
        bra     frames		; Wait for another frame
errcode2
        lda     #2              ; Addr error
        bra     errcode0	; Send answer and Wait for another frame
errcode4
        lda     #4              ; Len is zero
        bra     errcode0	; Send answer and Wait for another frame
errcode5
        lda     #5              ; Len is out of range
        bra     errcode0	; Send answer and Wait for another frame
errcode6
        lda     #6              ; Out of page boundary
        bra     errcode0	; Send answer and Wait for another frame

; serialtask (frames) was called by bsr. Only timeout error is what can be reason of end of serialtask. This will be done here.
errcode3
        lda     #3              ;Ha timeout van, akkor rts
        bsr     answer
        rts

addcs   add     cs_trign
        sta     cs_trign
        rts

; Wait a character on UART till timeout
scigetct
        @tim
scigetctc
        jsr     TBMHandle
        tst     comtimer
        beq     scigetcto       ; Timeout handling
        jsr     scigetc
        bcc     scigetctc       ; If no character, wait more
        rts                     ; Character received
scigetcto                       ; Timeout handling
        clc                     ; Clear carry bit to report timeout
        rts

wr2fls	; Here RAM mirror is ready to write back into Flash.
        @LEDOFF

        ; Check if selected page is allowed to program (Allowed: before boorloader and vectors)
        lda     dump_addr       ; Load address Hi byte allows only double pages check
        cmp     #bl_start_addr>8 ; Compare it with high byte of start address of bootloader
        blo     addr_ok         ; Lower addresses are allowed to program
        coma                    ; Negate to check $FF value, what is also allowed because of interrupt vectors
        beq     addr_ok         ; $FF addresses are allowed to program because of interrupt vectors
        bra     errcode2        ; Wrong address, not allowed dor bootloader to override itself

addr_ok
        ; Check if requested number of data bytes from start address is still inside the page
        lda     dump_addr+1     ; Load address low byte
        and     #$7F		; Mask out page counter bits
        deca
        add     wr_datac	; Add number of bytes
        bmi     errcode6        ; If out of page boundary, addition result will be $80 or larger, so negative

        ; Write page
        jsr     write

        ; Ack with zero error code
        clra
        bra     errcode0


; Send answer frame "BA 65 HH LL ER" back to host PC (A contains the error code)
answer
        psha			; Save error code from A
        lda     #$BA
        jsr     sciputc
        lda     #$65
        jsr     sciputc
        lda     dump_addr       ; Hi byte
        jsr     sciputc
        lda     dump_addr+1     ; Lo byte
        jsr     sciputc
        pula                    ; Resore error code into A
        jsr     sciputc
        rts


bl_end_addr     equ     $

; Bootloader version and build date, in format to be easy to read in S19 and hex memory dump
        org     BL_VER_DATE
        db      0		; version
        db      ${:year/100}    ; build date
        db      ${:year-2000}
        db      ${:month}
        db      ${:date}
        db      ${:hour}
        db      ${:min}
        db      ${:sec}

; Serial number (16 byte reserved, I prefer bootloader download date in bcd format)
;  Can be set here and compile, but my downloader (Host PC application) updates
;  this field with the time of loading automatic. By this way there will never be
;  two HW with same serial number.
        org     SERIAL_NUMBER
        db      $00,$20,$19,$10,$05,$22,$39,$35


        org     Vreset
        dw      entry

