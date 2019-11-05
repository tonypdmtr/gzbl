; Serial Communication interface


;-----------------------------------------
; STRINGS
;-----------------------------------------
hexakars        
        db      '0123456789ABCDEF'


;-----------------------------------------
; FUNCTIONS
;-----------------------------------------
; Initialize SCI controller
SCIInit
        clr     SCC3

        ;57600
        mov     #SCBR_PD_1+SCBR_BD_1,SCBR
        mov     #$26,SCPSC  	; PDS(1)+PSSB(6)

        mov     #ENSCI_,SCC1
        mov     #TE_+RE_,SCC2
        rts

; Prints a byte in hexa format from A.
sciputb
        pshh                    ; Save registers
        pshx
        psha
        nsa                     ; First upper 4 bits
        and     #$F
        tax
        clrh
        lda     hexakars,x
        bsr     sciputc
        lda     1,sp            ; Next lower 4 bits
        and     #$F
        tax
        clrh
        lda     hexakars,x
        bsr     sciputc
        pula                    ; Restore registers
        pulx
        pulh
        rts

; Tries to read character from SCI. Carry bit shows if there is received character in A or not.
scigetc
        brclr   5,SCS1,gc_nothing ; SCRF = 1 ?
        lda     SCDR
        sec                     ; RX info in carry bit
        rts
gc_nothing
        clc
        rts

; Prints a string. String address is in H:X.
sciputs
        lda     ,x
        beq     scips_v
        bsr     sciputc
        aix     #1
        bra     sciputs
scips_v
        rts


; Prints a character from A.
sciputc
        bsr     TBMHandle
        brclr   7,SCS1,sciputc  ; wait to send out the previous character
        sta     SCDR            ; also SCTE is cleared here
        rts


