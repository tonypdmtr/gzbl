
;-----------------------------------------
; MAKROS
;-----------------------------------------
bnef    macro   cim
        beq     $+3+2
        jmp     ~@~
        endm

bnzf    macro   cim
        beq     $+3+2
        jmp     ~@~
        endm

jeq     macro   cim
        bne     $+3+2
        jmp     ~@~
        endm

ldhxf   macro   par
        ldx     ~@~
        pshx
        pulh
        ldx     1+~@~
        endm

req     macro           ; Return if eq
        bne     $+2+1
        rts
        endm 

rlo     macro           ; Return if lo
        bhs     $+2+1
        rts
        endm 

rne     macro           ; Return if not eq
        beq     $+2+1
        rts
        endm 

rcc     macro           ; Return if Carry Clear
        bcs     $+2+1
        rts
        endm 



; hx = hx + a  (word)
addhxanda
        psha            ; Save A
        txa             ; X (op1 lo)
        add     1,sp    ; + (op2 lo)
        tax             ; Store to X (op1 lo)

        pshh            ; H (op1 hi)
        pula            ; ----||----
        adc     #0      ; Add with carry
        psha            ; Store to H (op1 hi)
        pulh            ; ----||----            
        ais     #1      ; Restore A (drop out)
        rts



memcopy
        sthx    mc_num
memcopy1
        ldhx    mc_src
        lda     ,x
        ldhx    mc_dest
        sta     ,x

        inc     mc_src+1
        bne     mc1
        inc     mc_src
mc1
        inc     mc_dest+1
        bne     mc2
        inc     mc_dest
mc2
        lda     mc_num+1
        sub     #1
        sta     mc_num+1
        lda     mc_num
        sbc     #0
        sta     mc_num

        ldhx    mc_num
        cphx    #0
        bne     memcopy1
        rts
