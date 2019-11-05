; Time Base Module handler

;-----------------------------------------
; MAKROS
;-----------------------------------------
tim     macro 
        mov     #30,comtimer 		; 32.768 ms * 30 ~= 1s
        endm


TBMInit
	; TMBCLKSEL is set to 1, so longer timings will be active
	; Divider 262144 needs TBR2-TBR0 = 010b with TMBCLKSEL=1.
	;   this will result 32.768ms timing with with 8MHz CGMXCLK
        mov     #TBON_+TBR1_,TBCR    ; switch on and set TBR1_
        clr     comtimer
        rts


;Scheduled decrement of timer and longtimer
TBMHandle
        sta     COPCTL
        brclr   7,TBCR,TBMH_v
        
        ;Here is the time!
        tst     comtimer
        beq     TBMH_1
        dec     comtimer
TBMH_1
        ;Clear timer flag
        bset    3,TBCR
TBMH_v
        rts

