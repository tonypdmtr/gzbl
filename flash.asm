; Flash memory handler


; -----------------------------------------------------------------------------
; Start of code to be executed from RAM  
; -----------------------------------------------------------------------------
ramprog
        ; Set ERASE bit and clear MASS bit
        ldhx    p_flcr
        lda     #$02
        sta     ,x

        ; Read block protect register
        ldhx    p_flbpr
        lda     ,x

        ; Write something to memory pointed by address
        ldhx    address
        sta     ,x

        ; Wait t_NVS (10 us)
        ldx     #2
        bsr     wait

        ; Set HVEN bit
        ldhx    p_flcr
        lda     #$0A            ;$08|$02
        sta     ,x

        ; Wait t_ERASE (1 ms for page erase = 200*5us) 
        ldx     #200 
        bsr     wait

        ; Clear ERASE bit
        ldhx    p_flcr
        lda     #$08
        sta     ,x

        ; Wait t_NVH  (5 us)
        ldx     #1
        bsr     wait

        ; Clear HVEN bit
        ldhx    p_flcr
        clra
        sta     ,x

        ; Wait t_RCV  (1 us)
        ldx     #1
        bsr     wait

        bra     nextrow


; Delay routine. Parameter is X in 5us.
wait 
        ; Summa 40 cycle = 5 us with 8Mhz fbus
        div              	; 7 cycle (A <- (H:A)/(X); H <- Remainder; X not changed)
        div
        div
        div
        div
        dbnzx   wait            ; 3 cycle
        rts 


nextrow
        ; Set the PGM bit in the FLASH control register (FLxCR).
        ldhx    p_flcr
        lda     #$01
        sta     ,x

        ; Read the FLASH block protect register.
        ldhx    p_flbpr
        lda     ,x

        ; Write to any FLASH address within the row address range desired with any data.
        ldhx    address
        sta     ,x

        ; Wait for a time, t_NVS (10 us)
        ldx     #2
        bsr     wait

        ; Set the HVEN bit.
        ldhx    p_flcr
        lda     #$09
        sta     ,x

        ; Wait for a time, t_PGS. (5 us)
        ldx     #1
        bsr     wait

ciklus
        ; Write one data byte to a FLASH address to be programmed.
        lda     address+1
        and     #$7F
        tax
        clrh
        lda     data,x          ; Load data[x]
        ldhx    address
        sta     ,x              ; Store to target flash address

        ; Wait for a time, t_PROG. (40 us)
        ldx     #8
        bsr     wait

        ; Next byte
        inc     address+1       ; Increase only low byte
        lda     address+1
        and     #$3F
        bne     ciklus

        ; Clear the PGM bit.
        ldhx    p_flcr
        lda     #$08
        sta     ,x

        ; Wait for a time, t_NVH. (5us)
        ldx     #1
        bsr     wait

        ; Clear the HVEN bit.
        ldhx    p_flcr
        clra
        sta     ,x

        ; Wait for a time, t_RCV.
        ldx     #1
        bsr     wait

        ; Jump back to next row
        lda     address+1
        deca
        and     #$40
        beq     nextrow

        ;Jump back from RAM to Flash
        rts     

ramprogend
; -----------------------------------------------------------------------------
; End of code to be executed from RAM  
; -----------------------------------------------------------------------------





;Ez egetti le a 1-128 bajt-os can vagy soros frame-et
; Bemenetei
;dump_addr     ; pontos cim, ahova kell egetni
;wr_datac      ; 1 irasi adatok szama (forras az egetonek!)
;wr_datat      ; 8 irasi adat tomb (forras az egetonek!)
; Kimenetei
;data          ebben van az egetendo 128 bajt
;address       a 128 bajtos lap kezdocime (also 7 bit mindig 0)
write
        ; Allign address to start of page
        ldhx    dump_addr
        txa
        and     #$80
        tax
        sthx    address

        ; Copy current data from Flash to RAM buffer
        ;ldhx    address       not needed, HX is still contains address 
        sthx    mc_src
        ldhx    #data
        sthx    mc_dest
        ldhx    #128
        jsr     memcopy

        ; Put in the new data bytes
        ldhx    #wr_datat
        sthx    mc_src

        ldhx    #data
        lda     dump_addr+1     ; Offset inside a page
        and     #$7F
        jsr     addhxanda
        sthx    mc_dest
        
        ldx     wr_datac
        clrh
        jsr     memcopy

        ; Check if page is the last
        ldhx    address
        cphx    #$FF80
        bne     notlast

        ; If this is the last page
        ; Copy content of Vreset to Vpll
        lda     data+$FE-$80    ; hi
        sta     data+$F8-$80    ;( $FFF8 & $7F )
        lda     data+$FF-$80    ;lo
        sta     data+$F9-$80    ;( $FFF8 & $7F )+1
        ; Fill up Vreset with start address of bootloader
        lda     #entry>8        ;HIGH(entry)
        sta     data+$7E        ;hi
        lda     #~entry>8       ;LOW(entry)
        sta     data+$7F        ;lo

        ; Last page starts from this address
        ldhx    #$FFCC          
        sthx    address

notlast        
        ; Write 128 bytes long page
        bra     writepage

; Page erase: write $FF to every byte on page
erasepage
        ; Fill up buffer with data $FF-el
        clrh
        ldx     #128
        lda     #$FF
lt_cikl
        sta     data-1,x
        dbnzx   lt_cikl

        ; Allign address to start of page
        ldhx    dump_addr
        txa
        and     #$80
        tax
        sthx    address

; Write 128 bytes long page
writepage
        ; Switch off watchdog
        bset    COPD_,CONFIG1

        ; Select registers for the requested flash area
        lda     address         ; High
        bmi     area1           ; Jump if negative, in this case address is between 8000-FFFF, this is FL1
        ldhx    #FL2CR
        sthx    p_flcr
        ldhx    #FL2BPR
        sthx    p_flbpr
        bra	area_end
area1
        ldhx    #FL1CR
        sthx    p_flcr
        ldhx    #FL1BPR
        sthx    p_flbpr
area_end
        ; Now jump up to RAM for erase/write and after come back to here
        jsr     ROUTINESINRAM

        ; Switch on watchdog
        bclr    COPD_,CONFIG1

        ; Resore address to original value
        lda     address+1
        eor     #$80
        sta     address+1

        rts
        
