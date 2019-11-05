; Terminal service on UART

;-----------------------------------------
; MAKROS
;-----------------------------------------
putspace macro 
        lda     #' '
        jsr     sciputc
        endm 

putn    macro 
        lda     #$0A    ;'\n'
        jsr     sciputc
        endm 

puta    macro 
        jsr     sciputb
        @putspace
        endm 

putk    macro   kar
        lda     #~@~
        jsr     sciputc
        endm 

puthx   macro
        pshh
        pula
        jsr     sciputb
        txa
        jsr     sciputb
        @putspace
        endm 


;-----------------------------------------
; STRINGS
;-----------------------------------------
startstrt
        db      " Push T button for terminal!"
        db      $0A
        db      0


termstr 
        db      "Serial terminal. Push ? to help!"
        db      $0A
        db      0
warn1str
        db      $0A
        db      'Warning! Last byte was half byte.'
        db      $0A
        db      0
err1str
        db      $0A
        db      'Error! Data are outside of page.'
        db      $0A
        db      0
err2str
        db      $0A
        db      'Error! Too high address.'
        db      $0A
        db      0
helpstr 
        db      $0A
        db      'x : exit from terminal.'
        db      $0A
        db      'r : Reset MCU.'
        db      $0A
        db      'dAAAA : Dump from address AAAAh (Default 0000h).'
        db      $0A
        db      'n : Next (Dump).'
        db      $0A
        db      'b : Back (Dump).'
        db      $0A
        db      'a : Again (Dump).'
        db      $0A
        db      'hAAAA11223344 [ENTER] : Hexa write from address AAAAh,'
        db      $0A
        db      'tAAAAwww.butyi.hu [ENTER] : Text write from address AAAAh,'
        db      $0A
        db      'eAAAA : Erase page from address AAAAh (128 bytes).'
        db      $0A
        db      0

TERM_Init
        ldhx    #startstrt
        jsr     sciputs 
        rts

egetkey
        ;loop when waiting for a terminal character
        jsr     TBMHandle
        
        ;Toggle LED
        @LEDNEG

        ; Check if timeout elapsed (user didn't do anything in the last 8s)
        tst     comtimer
        bne     egk_nto         ; Jump through on timeout handling
        ; Timeout handling: Simulate pushed 'x' button to leave terminal
        lda     #'x'
        bra     egk_enter
egk_nto ;No timeout
        
        jsr     scigetc		; Check character from useer
        bcc     egetkey		; No character arrived, wait further
        mov     #250,comtimer   ; Character arrived, pull up 8s timer

        ; Change Linux ENTER key to Windows ENTER key
        cmp     #$0A            ; Linux ENTER
        bne     egk_enter
        lda     #$0D            ; Windows ENTER
egk_enter        
        jsr     sciputc		; Echo back the pushed key
        tsta			; Set CCR to be able to use conditional branches after return
        rts


;Serial terminal
term_help
        ldhx    #helpstr
        jsr     sciputs 
        bra     term_cikl

terminal
        clr     cs_trign		; Reset pending connection attempt
        ldhx    #termstr
        jsr     sciputs
        mov     #250,comtimer		; 32ms * 250 ~= 8s
term_cikl       
        bsr     egetkey
        cmp     #'x'
        beq     term_exit
        cmp     #'r'
        beq     term_reset
        cmp     #'d'
        beq     term_dump
        cmp     #'n'
        beq     term_dump_n
        cmp     #'a'
        beq     term_dump_a
        cmp     #'b'
        beq     term_dump_b
        cmp     #'?'
        beq     term_help
        cmp     #'t'
        @jeq    term_text
        cmp     #'h'
        @jeq    term_hexa
        cmp     #'e'
        @jeq    term_erase

        
        bra     term_cikl

term_exit
        @putn
        rts

term_reset                      ;proci reset
        bra     term_reset

term_dump_b
        ldhx    dump_addr
        pshh
        pula
        deca
        psha
        pulh
        sthx    dump_addr
term_dump_a
        ldhx    dump_addr
        pshh
        pula
        deca
        psha
        pulh
        sthx    dump_addr
        bra     term_dump_n
term_dump
        jsr     getdumpaddr
term_dump_n                     ;continue
        ldhx    dump_addr
        bsr     dump8lines
        @putn
        bsr     dump8lines
        @putn
        sthx    dump_addr
        bra     term_cikl


dump8lines
        lda     #8
td_c1
        psha
        bsr     dumpline
        pula
        dbnza   td_c1
        rts

dumphn                  	; Dump Hexa n-times
	psha
        lda     ,x
        jsr     sciputb
        aix     #1
        pula
        dbnza	dumphn
        rts

dumpline
        @putn
        pshh
        pula    
        jsr     sciputb
        txa
        jsr     sciputb
        lda     #':'
        jsr     sciputc
        @putspace
        lda	#4
        bsr     dumphn
        @putspace
        lda	#4
        bsr     dumphn
        @putspace
        @putspace
        lda	#4
        bsr     dumphn
        @putspace
        lda	#4
        bsr     dumphn
        
        @putspace
        lda     #'|'
        jsr     sciputc
        @putspace

        aix     #-16
        lda	#8
        bsr     dumpan
        @putspace
        lda	#8
        bsr     dumpan
        rts

dumpan                   ;Dump ascii n-times
        psha
        lda     ,x
	; If character is not displayable, print dot
        cmp     #$20
        blo     pr_dot
        cmp     #$7F
        bhi	pr_dot
        bra     pr_ch
pr_dot
        lda     #'.'
pr_ch
        jsr     sciputc
        aix     #1

        pula
        dbnza   dumpan
        rts

term_common
        clr     wr_datac        ; Clear length of write
        ldhx    #wr_datat       ; Copy buffer address
        sthx    wr_datap        ;  to pointer variable
        jsr     getdumpaddr     ; Read address from user
        rts

; Text write into flash
term_text
        bsr     term_common     ; Call common part of terminal write
        bsr     gettextdata     ; Read text data from user
        bra     term_comm_end   ; Jump to write

; Hexa data write into flash
term_hexa
        bsr     term_common     ; Call common part of terminal write
        bsr     gethexadata     ; Read hexa data from user

        ; Check if complete byte are given (in hexa mode one character is just 4 bits)
        lda     wr_datac
        and     #1
        beq     term_comm_end   ; If even, no problem
        ; If odd, print a warning
        ldhx    #warn1str
        jsr     sciputs

term_comm_end
        ; Check if is there any data to be written
        tst     wr_datac
        @jeq    term_cikl       ; If no, jump back to main menu

        ; Check if data to be written is still inside the page. if $80 < ((cim & $7f) + len) then too long
        lda     dump_addr+1     ; Low byte of address
        and     #$7F
        deca
        add     wr_datac
        bpl     term_in_page    ; If positive, so sign bit is zero, then still inside the page
        
        ; Error message about too long data
        ldhx    #err1str
        jsr     sciputs
        jmp     term_cikl
        
term_in_page
        ; Check that all addresses to be written is lower that bootloader area
        ldhx    dump_addr
        lda     wr_datac
        jsr     addhxanda
        cphx    #entry
        blo     term_addr_good

        ; Write attemp to not allowed area, error message is reported
        ldhx    #err2str
        jsr     sciputs
        jmp     term_cikl       ; Back to main menu
        
term_addr_good      
        ; Write data into flash
        jsr     write
        
        ; Dump from begin of 256 byte long page 
        clr     dump_addr+1

        ; Print dump to verify write was successfull  
        jmp     term_dump_n

; Erase page from terminal
term_erase
        ; Read address
        bsr     getdumpaddr
        
        ; Erase flash page
        jsr     erasepage

        ; Print dump to verify erase was successfull  
        jmp     term_dump_n

; Read hexa bytes from user till ENTER key
gethexadata
        ; Check if data is not too long
        lda     wr_datac
        cmp     #128
        @req
        
        jsr     egetkey         ; Read a character from user
        cmp     #$0d            ; Windows enter
        @req
        bsr     convtoval       ; Convert character to 4 bits binary value
        nsa                     ; Shift up by 4 bits
        psha                    ; Save high nibble
        jsr     egetkey         ; Read a character from user
        cmp     #$0d            ; Windows enter
        @req
        bsr     convtoval       ; Convert character to 4 bits binary value
        ldhx    wr_datap        ; Load buffer pointer as index
        ora     1,sp            ; Binary or with high nibble
        sta     ,x              ; Write character to buffer
        ais     #1              ; Drop out high nibble from stack

        bsr     getdata_next
        bra     gethexadata

; Read string from user till ENTER key
gettextdata
        ; Check if data is not too long
        lda     wr_datac
        cmp     #128
        @req
        
        jsr     egetkey         ; Read a character from user
        cmp     #$0d            ; Windows enter
        @req
        ldhx    wr_datap        ; Load buffer pointer as index
        sta     ,x              ; Write character to buffer

        bsr     getdata_next
        bra     gettextdata

getdata_next
        ; Increase length
        inc     wr_datac        
        
        ; Increase pointer
        ldhx    wr_datap
        aix     #1
        sthx    wr_datap
        
        rts

; Convert character to 4 bits binary value
convtoval
        sub     #48
        bmi     ctv_0
        cmp     #10
        blo     ctv_x
        sub     #7
        bmi     ctv_0
        cmp     #10
        blo     ctv_0
        cmp     #16
        blo     ctv_x
        sub     #32
        bmi     ctv_0
        cmp     #10
        blo     ctv_0
        cmp     #16
        blo     ctv_x
ctv_0
        clra
ctv_x
        and     #$0F
        rts

getdumpaddr
        jsr     egetkey
        bsr     convtoval       ; Convert character to 4 bits binary value
        nsa
        sta     dump_addr

        jsr     egetkey
        bsr     convtoval       ; Convert character to 4 bits binary value
        ora     dump_addr
        sta     dump_addr

        jsr     egetkey
        bsr     convtoval       ; Convert character to 4 bits binary value
        nsa
        sta     dump_addr+1

        jsr     egetkey
        bsr     convtoval       ; Convert character to 4 bits binary value
        ora     dump_addr+1
        sta     dump_addr+1
        rts





