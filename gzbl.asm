;*******************************************************************************
; GZ family BootLoader (frame code, main file)
;*******************************************************************************

                    #Uses     gz60.inc            ; Load microcontroller specific register definitions

NL                  equ       10                  ; New line character (Linux)
ROUTINESINRAM       equ       $0200               ; Start of area of Flash handler routines in RAM

;*******************************************************************************
                    #RAM
;*******************************************************************************

SRSR_saved          rmb       1                   ; Saved value of SRSR register, because read clears (can only be read once)
wr_datac            rmb       1                   ; Number of data byte to be written (source for flash writer)
dump_addr           rmb       2                   ; Address variable for general purpose
address             rmb       2                   ; Address variable for flash write and erase
wr_datap            rmb       2                   ; Write data pointer
mc_src              rmb       2                   ; memcopy source address
mc_dest             rmb       2                   ; memcopy destination address
mc_num              rmb       2                   ; memcopy number of bytes to copy
p_flcr              rmb       2                   ; Address of flash control register (of Flash1 or Flash2)
p_flbpr             rmb       2                   ; Address of flash block protection register (of Flash1 or Flash2)
cs_trign            rmb       1                   ; frame checksum, and before frames number of received trigger characters
comtimer            rmb       1                   ; timeout timer for serial UART communication
nosysinfo           rmb       1                   ; Administration that 'no system software' info was already printed out (do not print it again)

wr_datat            equ       $0080               ; 128 byte write data buffer. It can contain data with any length and from any address.
data                equ       $0100               ; 128 byte buffer for flash manipulation. Always aligned to a complete page

;*******************************************************************************
                    #ROM
;*******************************************************************************

; Start of bootloader. This shall be as much as possible in last part of Flash1.
; This ensures compatibility with smaller memory variant uCs, and most space for
; system software.
; To be adjusted manually without overlap in gz60.inc
?BootloaderStart
;*******************************************************************************
; STRINGS
;*******************************************************************************

welcome             fcs       NL,'HC908GZ60 BootLoader (github.com/butyi/gzbl)',NL
sysstr              fcs       ' Application is starting.',NL
nsstr               fcs       ' Application is not found. Stay in BootLoader.',NL

;*******************************************************************************
; RUTINOK
;*******************************************************************************

                    #Uses     cgm.sub
                    #Uses     lib.sub
                    #Uses     flash.sub
                    #Uses     pcb.sub
                    #Uses     sci.sub
                    #Uses     tbm.sub
                    #Uses     term.sub

;*******************************************************************************
; MAIN rutinok
;*******************************************************************************

; Main entry point. This address shall be in Reset Vector.

Start               proc
                    sei                           ; Disable interrupts
          ;-------------------------------------- ; Init Stack
                    ldhx      #STACKTOP
                    txs
          ;-------------------------------------- ; Save reset status register, because it is cleared during read
                    lda       SRSR
                    sta       SRSR_saved
                    jsr       PLLInit             ; Clock Generator module init
          ;-------------------------------------- ; Enable CAN module
                    lda       #MSCANEN_+TMBCLKSEL_
                    sta       CONFIG2
          ;-------------------------------------- ; LVI module enable
                    lda       #LVI5OR3_
                    sta       CONFIG1
          ;--------------------------------------
          ; Flash Block protection setup
          ; Lock bootloader area on Flash1
          ; Address to lock F800h = 1111 1000 0000 0000 (comes from reset vector)
          ; These bits are needed    xxx xxxx x
          ;--------------------------------------
                    lda       Vreset              ; Load reset vector High byte
                    lsla                          ; Shift up by 1
                    ldx       Vreset+1            ; Load reset vector Low byte just for test
                    bpl       _1@@                ; Jump when plus, so MSB is zero
                    inca
_1@@                sta       FL1BPR
          ;-------------------------------------- ; Unlock the whole Frash2
                    lda       #$FF
                    sta       FL2BPR
          ;-------------------------------------- ; Clear RAM variables
                    clr       nosysinfo
                    clr       cs_trign
                    clr       dump_addr
                    clr       dump_addr+1
          ;-------------------------------------- ; LED Init
                    @ledoff
                    @ledinit
                    jsr       PCB_Init            ; PCB specific initialization (if needed)
          ;-------------------------------------- ; Copy flash handler routines into RAM
                    ldhx      #ramprog
                    sthx      mc_src
                    ldhx      #ROUTINESINRAM
                    sthx      mc_dest
                    ldhx      #::ramprog
                    jsr       memcopy
                    jsr       SCIInit             ; SCI module init
                    ldhx      #welcome
                    jsr       sciputs
                    jsr       TBMInit             ; Time related inits
                    jsr       TERM_Init           ; Terminal init on UART
;                   bra       MainTime

;*******************************************************************************
; Here starts the main loop

MainTime            proc
                    @tim                          ; Pull up timer
                    @ledon
MainLoop            jsr       TBMHandle
          ;-------------------------------------- ; wait for communication attempt on UART
                    brclr     5,SCS1,_1@@
                    bsr       serialtask
                    clr       cs_trign
                    bra       MainTime            ; loop again with pull up timer
          ;-------------------------------------- ; Check time
_1@@                tst       comtimer
                    beq       _2@@                ; If time spent, call system software
                    bra       MainLoop            ; If time not yet spent, wait further
          ;-------------------------------------- ; Call of system software
_2@@                @ledoff
          ;--------------------------------------
          ; Check Vpll vector, if here data is not $FFFF there is system software to call
          ; Do not forget: Bootloader can download standalone software, where the start address
          ; is allocated to vector Vreset. The bootloader will move start address from Vreset
          ; to Vpll, and keep bootloader start address in Vreset. Therefore system software
          ; start address will be in Vpll. If system software want to use Vpll, bad luck
          ; this bootloader cannot be used, or must be modified to use other not used vector.
          ;--------------------------------------
                    lda       Vpll
                    and       Vpll+1
                    coma
                    bne       _3@@                ; there is system software
          ;-------------------------------------- ; Here comes if there is no system software
          ;-------------------------------------- ; Print 'no sys' info only once (first time)
                    tst       nosysinfo           ; if 'no sys' info was already printed
                    bne       stayinboot          ; do not write it again
                    inc       nosysinfo           ; set flag to not print 'no sys' info again
          ;-------------------------------------- ; Print 'no sys' info
                    ldhx      #nsstr
                    jsr       sciputs
          ;-------------------------------------- ; Stay in bootloader further
                    bra       stayinboot
          ;-------------------------------------- ; There is system software, jump to there
_3@@
          ;-------------------------------------- ; Print 'is sys' info
                    ldhx      #sysstr
                    jsr       sciputs
          ;-------------------------------------- ; Load start addess of system software, and jump to there
                    lda       Vpll
                    tah
                    ldx       Vpll+1
                    jmp       ,x

;*******************************************************************************
; There is no system software. Wait 0,5s and jump to wait download attempt again

stayinboot          proc
                    mov       #15,comtimer
Loop@@              jsr       TBMHandle
                    tst       comtimer
                    bne       Loop@@
                    bra       MainTime

;*******************************************************************************
; Task to handle serial communication

serialtask          proc
Loop@@              jsr       TBMHandle
          ;-------------------------------------- ; Timeout check
                    tst       comtimer
                    @req                          ; If timeout reached, return from task
          ;-------------------------------------- ; Try to read a character
                    jsr       scigetc
                    bcc       Loop@@              ; If no character received, wait further
          ;-------------------------------------- ; If 't' arrived, terminal is needed
                    cmp       #'t'
                    jeq       Terminal
          ;-------------------------------------- ; Check for download trigger character
                    cmp       #$1C
                    bne       Loop@@              ; If no trigger character received, wait further
          ;-------------------------------------- ; If expected trigger character arrived
                    inc       cs_trign            ; Count the trigger characters
          ;-------------------------------------- ; Check number of received trigger characters
                    lda       cs_trign
                    cmp       #4                  ; shall be 4 for successful connection
                    bne       Loop@@              ; If less that 4 received only, wait further
          ;--------------------------------------
          ; Expected number of trigger characters were received,
          ; this is a valid download request.
          ; Send answer to confirm successful trigger reception (4 times $E3)
          ;--------------------------------------
                    lda       #$E3
                    jsr:4     sciputc
          ;--------------------------------------
          ; Format of serial frame:
          ; $56,$AB,lenh,lenl,addrh,addrl,d0,d1,...dn,cs
          ; Answer frame:
          ; $BA,$65,addrh,addrl,error
          ; error=0: successful
          ; error=1: cs error,
          ; error=2: address error
          ; error=3: timeout error
          ; error=4: len is zero
          ; error=5: len is too high (>128)
          ; error=6: out of page (page overflow from address with given len)
          ;
          ; frame handling: - pull up timer to 1s (at 38400 a frame is 32ms/128byte)
          ; timeout always causes read a new frame
          ; - wait for $56, if byte is different, read a new frame
          ; - wait for $AB, if byte is different, read a new frame
          ; - wait for len, save it, if wrong, read a new frame
          ; - wait for address, save it, if wrong, read a new frame
          ; - wait for data bytes, save it, and calculate checksum meantime
          ; - wait for checksum, compare it, if wrong, read a new frame
          ;--------------------------------------
Frames@@            @ledon                        ; Switch debug LED on
          ;-------------------------------------- ; Wait for first byte of frame header ($56)
                    bsr       scigetct            ; Timeout type getc
                    bcs       _1@@                ; If character received, go further
                    rts                           ; If no character received during time, return (lost communication)
          ;-------------------------------------- ; Character received, check it
_1@@                cmp       #$56
                    bne       Frames@@            ; Not the expected, wait for the next
          ;-------------------------------------- ; Wait for second byte of frame header ($AB)
                    bsr       scigetct            ; Timeout type getc
                    bcc       ?ErrCode3           ; In case of timeout: ?ErrCode3
                    cmp       #$AB                ; Character received, check it
                    bne       Frames@@            ; Not the expected, wait for the next frame
          ;-------------------------------------- ; Frame header ($56 $AB) arrived
                    clr       cs_trign            ; clear checksum variable
          ;--------------------------------------
          ; Read len high byte, not used in GZ family
          ; because page size is just 128 bytes, so it is always zero
          ;--------------------------------------
                    bsr       scigetct            ; Timeout type getc
                    bcc       ?ErrCode3           ; In case of timeout: ?ErrCode3
                    bne       ?ErrCode5           ; If 256<len (high byte is not zero): ?ErrCode5
          ;-------------------------------------- ; Read len low byte
                    bsr       scigetct            ; Timeout type getc
                    bcc       ?ErrCode3           ; In case of timeout: ?ErrCode3
                    beq       ?ErrCode4           ; If len=0: ?ErrCode4
                    cmp       #128
                    bhi       ?ErrCode5           ; If 128<len: ?ErrCode5
                    sta       wr_datac            ; Store len parameter in RAM
                    bsr       addcs               ; Add byte to checksum for later check
          ;-------------------------------------- ; Read address hi
                    bsr       scigetct            ; Timeout type getc
                    bcc       ?ErrCode3           ; In case of timeout: ?ErrCode3
                    sta       dump_addr           ; Store parameter in RAM
                    bsr       addcs               ; Add byte to checksum for later check
          ;-------------------------------------- ; Read address lo
                    bsr       scigetct            ; Timeout type getc
                    bcc       ?ErrCode3           ; In case of timeout: ?ErrCode3
                    sta       dump_addr+1         ; Store parameter in RAM
                    bsr       addcs               ; Add byte to checksum for later check
          ;--------------------------------------
          ; Read data bytes into RAM
          ; dump_addr     ; address where data to be written
          ; wr_datac      ; number of bytes to be written
          ; wr_datat      ; data buffer
          ;--------------------------------------
                    clrhx
NewData@@           bsr       scigetct            ; Timeout type getc
                    bcc       ?ErrCode3           ; In case of timeout: ?ErrCode3
                    sta       wr_datat,x          ; Store data byte in RAM buffer
                    bsr       addcs               ; Add byte to checksum for later check
                    incx                          ; increment index
                    cpx       wr_datac            ; Last data index (e.g. in case of 128 bytes -> 127)
                    blo       NewData@@           ; If not the last, read next byte
          ;-------------------------------------- ; Read checksum
                    bsr       scigetct            ; Timeout type getc
                    bcc       ?ErrCode3           ; In case of timeout: ?ErrCode3
                    cmp       cs_trign            ; Compare with calculated checksum
                    beq       wr2fls              ; If same, jump to write (write from RAM back to Flash)
                    lda       #1                  ; CS error code
?ErrCode0           bsr       answer              ; Send answer
                    bra       Frames@@            ; Wait for another frame
?ErrCode2           lda       #2                  ; Addr error
                    bra       ?ErrCode0           ; Send answer and Wait for another frame
?ErrCode4           lda       #4                  ; Len is zero
                    bra       ?ErrCode0           ; Send answer and Wait for another frame
?ErrCode5           lda       #5                  ; Len is out of range
                    bra       ?ErrCode0           ; Send answer and Wait for another frame
?ErrCode6           lda       #6                  ; Out of page boundary
                    bra       ?ErrCode0           ; Send answer and Wait for another frame
; serialtask (frames) was called by bsr. Only timeout error is what can be reason of end of serialtask. This will be done here.
?ErrCode3           lda       #3                  ; Ha timeout van, akkor rts
                    bra       answer

;*******************************************************************************

addcs               proc
                    add       cs_trign
                    sta       cs_trign
                    rts

;*******************************************************************************
; Wait a character on UART till timeout

scigetct            proc
                    @tim
Loop@@              jsr       TBMHandle
                    tst       comtimer
                    clc                           ; Clear carry bit to report timeout
                    beq       Done@@              ; Timeout handling
                    jsr       scigetc
                    bcc       Loop@@              ; If no character, wait more
Done@@              rts

;*******************************************************************************

wr2fls              proc                          ; Here RAM mirror is ready to write back into Flash
                    @ledoff
          ;--------------------------------------
          ; Check if selected page is allowed to
          ; program (Allowed: before boorloader and vectors)
          ;--------------------------------------
                    lda       dump_addr           ; Load address Hi byte allows only double pages check
                    cmp       #]?BootloaderStart  ; Compare it with high byte of start address of bootloader
                    blo       AddrOk@@            ; Lower addresses are allowed to program
                    coma                          ; Negate to check $FF value, what is also allowed because of interrupt vectors
                    beq       AddrOk@@            ; $FF addresses are allowed to program because of interrupt vectors
                    bra       ?ErrCode2           ; Wrong address, not allowed dor bootloader to override itself
          ;--------------------------------------
          ; Check if requested number of data bytes
          ; from start address is still inside the page
          ;--------------------------------------
AddrOk@@            lda       dump_addr+1         ; Load address low byte
                    and       #$7F                ; Mask out page counter bits
                    deca
                    add       wr_datac            ; Add number of bytes
                    bmi       ?ErrCode6           ; If out of page boundary, addition result will be $80 or larger, so negative
                    jsr       write               ; Write page
          ;-------------------------------------- ; Ack with zero error code
                    clra
                    bra       ?ErrCode0

;*******************************************************************************
; Send answer frame 'BA 65 HH LL ER' back to host PC (A contains the error code)

answer              proc
                    psha                          ; Save error code from A
                    lda       #$BA
                    jsr       sciputc
                    lda       #$65
                    jsr       sciputc
                    lda       dump_addr           ; Hi byte
                    jsr       sciputc
                    lda       dump_addr+1         ; Lo byte
                    jsr       sciputc
                    pula                          ; Resore error code into A
                    jmp       sciputc

;*******************************************************************************
; Bootloader version and build date, in format to be easy to read in S19 and hex memory dump
;-------------------------------------------------------------------------------

                    org       BL_VER_DATE
                    db        0                   ; version
                    db        ${:year/100}        ; build date
                    db        ${:year\100}
                    db        ${:month}
                    db        ${:date}
                    db        ${:hour}
                    db        ${:min}
                    db        ${:sec}

;*******************************************************************************
; Serial number (16 byte reserved, I prefer bootloader download date in bcd format)
; Can be set here and compile, but my downloader (Host PC application) updates
; this field with the time of loading automatic. By this way there will never be
; two HW with same serial number.
;-------------------------------------------------------------------------------

                    org       SERIAL_NUMBER
                    db        $00,$20,$19,$10,$05,$22,$39,$35

;*******************************************************************************
                    #VECTORS
;*******************************************************************************
                    org       Vreset
                    dw        Start

                    #Hint     ...................................................................................................... {1957(f4)} bytes, RAM: {21(f5)}, CRC: $41C6
