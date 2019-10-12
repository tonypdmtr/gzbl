; Clock Generator Module handler


; fBUSDES = 8MHz
; fVCLKDES = 32MHz
; fRCLK = 8MHz
; N = 4
; fVCLK = 32MHz
; E = 2
; L = 112
; fVRS = 31.987200 MHz
; fVRS - fVCLK = 12800
; (fNUM * 2^E) /2 = 142800
PLLInit
        clr     PCTL            ; turn off PLL
        bset    1,PCTL          ; E=2   (PLL_E2)
        clr     PMSH            ; N=4 (high)
        mov     #4,PMSL         ; N=4 (low)
        mov     #112,PMRS       ; L=112
        mov     #AUTOBAUD,PBWC  ; sel auto tracking mode
        bset    5,PCTL          ; turn on PLL BITNUM(PLLON)
pll1
	brclr	6,PBWC,pll1     ; while( 0==(PBWC & LOCK) )
        bset    4,PCTL          ; switch over to PLL frequency (BCS)

        rts


