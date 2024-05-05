; ICE REVOLUTION
; BIOS PATCHING REWRITE
; KILLER CUT
; V1-V10
; RGB FIX
; PSX1 imports screen pos fix
; $270 FREE NOW

;INCLUDE "define.inc"
 
TRANSISTOR EQU	1

DEVICE	SX28AC, OSCHS2, TURBO, OPTIONX, PROTECT
;IRC_CAL	IRC_SLOW
ID 'ICEREV'
FREQ	50_000_000

EPROM_OE	equ 	ra.0		;R
BIOS_CS		equ	rb.1		;W   1 = no access to rom , 0 = access to rom
RST_BTN		equ 	rb.2		;RST 1 = normal , 0 = reset
IO_EJECT	equ 	rb.3		;Z , 1 = tray open , 0 = tray closed

DVD_CNT_CLK	equ 	ra.1		;A from flip flop
FFCLR		equ	ra.3		;flip flop clr



COUNT1		equ	$8
COUNT2		equ	$9
COUNT3		equ	$A
COUNT4		equ	$B
VAR_FLAG	equ	$C
VAR_PSX_DATA	equ	$D
;FLAG		equ	$E
;FLAG1		equ	$F
PS2_ID1		equ	$10
PS2_ID2		equ	$11
PS2_ID3		equ	$12
WAKE_UP		equ	$13		;for power down operation
VAR_TEMP	equ	$14


EJ_FLAG		equ	$E.0		;bit 0 used by eject routine
SOFT_RST	equ	$E.1		;soft reset flag for disk patch 
PSX_FLAG	equ	$E.2		;psx mode flag		
V10_FLAG	equ	$E.3		
E_FLAG		equ	$E.4		
A_FLAG		equ	$E.5		
I_FLAG		equ	$E.6
SCEX_FLAG	equ	$E.7		;

V12_FLAG	equ	$F.0
V12L_FLAG	equ	$F.1
X_FLAG		equ	$F.3
DEV_FLAG	equ	$F.4
;MOVIE_FLAG	equ	$F.5

				
BIOS_DATA	equ	rc
CDDVD_DATA	equ	rb

IO_SCEX		equ 	ra.2
;TST		equ	ra.2 		;only for test mode !!!  

;****** Reset of the chip ********************************
org $0
INTERRUPT
;goes to sleep and wait for reset release ( 1 ) or tray close (0) ...
	mode	$0F
	mov	!rc,#$FF		;to be sure ports are input ...
	mov	!rb,#$FF
	mov	!ra,#$FF
	mov	m, #00Ah		;set up edge register
	mov	!rb, #%00001000		;RB3 wait for LOW ( = 1 ),RB2 wait for hi ( =0 ) 
	mov	m, #009h		;clear all wakeup pending bits
	clr	w			;  
	mov	!rb,w			;
	mov	m, #00Bh		;enable wakeup...
	mov	!rb, #%11110011		;... on RB3 ( eject ) & RB2 (reset) 
	mode	#0Fh			;
	sleep
					
INIT_CHIP				;here from stby & wake up...
	mode	$0D			;TTL/CMOS mode...
	mov	!rb,#%11110111		;set IO_EJECT input as cmos ( level '1' > 2.5V ) work better with noise ...
	mode	$0F			;port mode 
	mov	!ra,#$07		;port mode : all input
;	mov	!ra,#%00000011		;only for test mode !!!
	mov	!rb,#$FF
	mov	!rc,#$FF
	mov 	!option,#%11000111	;rtcc enabled,no int,incr.on clock, prescaler (bit 2,1,0).
;	clrb	TST			;only for test mode !!!


;read power down register
	clr	FSR
	mov 	m, #$09 		;read power down register 
	clr	W 			;clear W
	mov 	!RB, W			;exchange registers = read pending bits
	mov	WAKE_UP,W		;save wake up status ...
	mode	#$0F			;need 'cause removed from patch disk for speed !
	
;execute correct startup...
	jb 	STATUS.3,POWER_UP		;0 = power up from sleep , 1= power up from Power ON (STBY)
	jb	WAKE_UP.2,RESET0
;	jb	WAKE_UP.3,CDDVD_EJECTED
	jb	IO_EJECT,CDDVD_EJECTED
	jb	WAKE_UP.1,@IS_XCDVDMANX		;xcdvdman reload check
	jmp	@SLEEP_MODE			;to be sure 

;power up from STBY
POWER_UP
	clr	$E			;reset all used flag    
	clr	$F			;reset all used flag
	jmp	START

;---------------------------------------------------------
;Delay routine using RTCC 
;---------------------------------------------------------
DELAY100m			;Precise delay routine using RTCC 
	mov COUNT1,#100        	;delay = 100 millisec.
l_del   	
IFDEF	MODE54  	
	mov RTCC,#45		;load  timer=45 for 54M
ELSE
	mov RTCC,#61		;load  timer=61,delay = (256-61)*256*0.02 micros.= 1000 micros.	
ENDIF	
l_del1	
	mov w,RTCC		;wait for timer= 0 ... (don't use TEST RTCC)
	jnz l_del1		;
	djnz COUNT1 , l_del	;
	retp			;

;----------------------------------------------------------
;setup interrupt routine
;----------------------------------------------------------
SET_INTRPT
	mov	m, #00Ah			;set up edge register
	mov	!rb, #%00000110			;RB1 & RB2 wait for low, RB3 for high 
	mov	m, #009h			;clear all wakeup pending bits
	clr	w				;  
	mov	!rb,w				;
	mov	m, #00Bh			;enable interrupt ...
	mov	!rb, #%11110011			;... on RB3 ( eject ) & RB2 ( reset )
	mode	#00Fh				;
	retp

;----------------------------------------------------------
;SCEX_HI
;----------------------------------------------------------
SCEX_HI
	setb	IO_SCEX
	mov	w, #59
	mov	COUNT3, w
label_0038
IFDEF	MODE54
	mov	w, #229
ELSE	
	mov	w, #212
ENDIF	
	mov	COUNT2, w
	not	ra
label_003B
	mov	w, #3
	mov	COUNT1, w
label_003D
	decsz	COUNT1
	jmp	label_003D
	decsz	COUNT2
	jmp	label_003B
	decsz	COUNT3
	jmp	label_0038
	ret

;----------------------------------------------------------
;SCEX_LO
;----------------------------------------------------------
SCEX_LO
	clrb	IO_SCEX
	mov	w, #59
	mov	COUNT3, w
label_0047
IFDEF	MODE54
	mov	w, #229
ELSE	
	mov	w, #212
ENDIF	
	mov	COUNT2, w
	jb	BIOS_CS,label_004B
	setb	SCEX_FLAG		;bios cs occurred 
label_004B
	mov	w, #3
	mov	COUNT1, w
label_004D
	decsz	COUNT1
	jmp	label_004D
	decsz	COUNT2
	jmp	label_004B
	decsz	COUNT3
	jmp	label_0047
	ret

;----------------------------------------------------------
;SCEX_TBL
;----------------------------------------------------------
SCEX_TBL				; SCEA, SCEI, SCEE
	add	pc, w
	retw	'S'			; $53
	retw	'C'			; $43
	retw	'E'			; $45
	retw	'A'			; $41
	retw	'S'			; $53
	retw	'C'			; $43
	retw	'E'			; $45
	retw	'I'			; $49
	retw	'S'			; $53
	retw	'C'			; $43
	retw	'E'			; $45
	retw	'E'			; $45

;send scex signal
SEND_SCEX
	jb	A_FLAG,:us
	jb	E_FLAG,:uk
	jmp	:jap
:us
	clr	COUNT4				; COUNT4 = offset = $10
	jmp	label_0071
:uk
	mov	COUNT4, #$08			; SCEE
	jmp	label_0071
:jap
	mov	COUNT4, #$04			; SCEI

label_0071
	mov	w, #$0B
	mov	!ra, w

	mov	VAR_TEMP,#$04			; VAR_TEMP count bytes = $C
	
label_0076
	mov	w, COUNT4
	call	SCEX_TBL			;
	mov	VAR_PSX_DATA, w
	not	VAR_PSX_DATA

	mov	WAKE_UP,#$08			; WAKE_UP as bitecount = $E

	call	SCEX_LO				;
	call	SCEX_LO				;proc_0044
	call	SCEX_HI				;
label_007F
	rr	VAR_PSX_DATA
	snc
	jmp	label_0085
	sc
	call	SCEX_LO				;
	jmp	label_0086
label_0085
	call	SCEX_HI				;
label_0086
	djnz	WAKE_UP,label_007F
	inc	COUNT4
	djnz	VAR_TEMP,label_0076
	clrb	IO_SCEX				;
	mov	COUNT4,#$16
label_008E
	call	SCEX_LO				;
	djnz	COUNT4,label_008E
	mov	!ra,#$0F
	ret

;----------------------------------------------------------
;wait for bios oe low (page 0)
;----------------------------------------------------------
wait_bios_oe_low_p0
	jb	EPROM_OE,$
IFDEF	MODE54	
	nop
ENDIF
	ret

; start of CODE
; ### read regional/bios version data ###
; PS2_ID1 = x1 :- holds a numeric value (function unknown), this can have the value '2', '5', or '6'
; PS2_ID0 = x2 :- holds the region of the BIOS, this can have the value 'A' / 'J' or 'E'.
; PS2_ID2 = x3 :- seems to hold the year of the bios, '0', '1' or '2'.
START  
start_l0
	; wait for "S201"
	;        0123456789AB
	; Read "PS20??0?C200?
	jb	EPROM_OE,start_l0		; next byte / wait for bios OE low
	nop
	cjne	BIOS_DATA, #'P',start_l0	; is byte0 = 'P'
	call	wait_bios_oe_low_p0		; next byte
	cjne	BIOS_DATA, #'S',start_l0	; is byte1 = 'S'
	call	wait_bios_oe_low_p0		; next byte
	cjne	BIOS_DATA, #'2',start_l0	; is byte2 = '2'
	call	wait_bios_oe_low_p0		; next byte
	cjne	BIOS_DATA, #'0',start_l0	; is byte3 = '0'
	call	wait_bios_oe_low_p0		; next byte
	jnb	EPROM_OE,$			; skip byte  '1' for V1-V11, '2' for V12
	call	wait_bios_oe_low_p0		; next byte	
	mov	PS2_ID1,BIOS_DATA		; byte4 = BIOS VER  2, 5, 6, 7(V9!)

start_l1
	jb	EPROM_OE,start_l1		; wait for bios OE low(next byte)
	nop
	cjne	BIOS_DATA, #'0',start_l1	; is byte5 = '0'
	call	wait_bios_oe_low_p0		; next byte
	mov	PS2_ID3,BIOS_DATA		; byte6 = Region  A(USA) E(UK) J(JAP)

start_l2
	jb	EPROM_OE,start_l2		; wait for bios OE low(next byte)
	nop
	cjne	BIOS_DATA, #'0',start_l2	; is byte9 = '0'
	call	wait_bios_oe_low_p0		; next byte
	cjne	BIOS_DATA, #'0',start_l2	; is byteA = '0'
	call	wait_bios_oe_low_p0		; next byte
	mov	PS2_ID2,BIOS_DATA		; byteB = BIOS Year  0(2k), 1(2k1), 2(2k2),3(2k3) 

	cje	PS2_ID3, #'A',:us
	cje	PS2_ID3, #'E',:uk
	cje	PS2_ID3, #'R',:uk		;Russian PS2 use UK region table :)
	cje	PS2_ID3, #'C',:uk	
	jmp	:jap				;default to jap for 'J' and 'H' machines

:us
	setb	A_FLAG
	jmp	:next_r
:uk
	setb	E_FLAG
	jmp	:next_r	
:jap
	setb	I_FLAG
:next_r    
	jb	RST_BTN,RESET0		;enter ps2 mode


AUTO_P	
	setb	PSX_FLAG			;enter psx mode
;	setb	MOVIE_FLAG			;enter psx mode	
	
;DVD movie : GREEN fix + MACROVISION off
KERNEL_PATCH
	cje	PS2_ID1,#'0',kernel_v910	;V12 use V910 kernel :)
	cje	PS2_ID1,#'7',kernel_V910	;select KERNEL TYPE V9 or V10
	cje	PS2_ID1,#'9',kernel_V910

;V1-8 kernels: sync 1E006334 then 2410 

	mov	COUNT1,#50
:loop0
	jb	EPROM_OE, $			;
	nop
	cjne	BIOS_DATA, #$1E, :loop0	
	call	wait_bios_oe_low_p0	
	cjne	BIOS_DATA, #$00, :loop0	
	call	wait_bios_oe_low_p0	
	cjne	BIOS_DATA, #$63, :loop0	
	call	wait_bios_oe_low_p0	
	cjne	BIOS_DATA, #$34, :loop0	

:loop0a
	jb	EPROM_OE, $		; next byte / wait for bios OE low
	nop
	cjne	BIOS_DATA, #$24, :loop0a
	call	wait_bios_oe_low_p0	
	cjne	BIOS_DATA, #$10, :loop0a
	
:loopko1	
	jnb	EPROM_OE, $    	
	jb	EPROM_OE, $    
	djnz	COUNT1,:loopko1 		

	mov	BIOS_DATA, #$00
	mode	#$0F

IFDEF	MODE54
	jb	EPROM_OE, $			; wait for bios OE low(next byte)
	jnb	EPROM_OE, $			; wait for bios OE HI
ELSE
	call	wait_bios_oe_low_p0
ENDIF

	mov	!BIOS_DATA, #$00		;port rc =out
	
	call	wait_bios_oe_low_p0
	mov	BIOS_DATA, #$00			;send 00,00,00,00
	call	wait_bios_oe_low_p0
	mov	BIOS_DATA, #$00
	jnb	EPROM_OE, $    	
	mov	!BIOS_DATA, #$FF

	jmp	TEST_RESET			;exit KERNEL PATCH	


; V9/V10/V12 kernels

kernel_V910

Kstart_l0
	jb	EPROM_OE,Kstart_l0		; patch 25 10 43 00 to 00 00 00 00 	
	nop
	cjne	BIOS_DATA, #$DC,Kstart_l0
	jnb	EPROM_OE,$
	jb	EPROM_OE,$
	cjne	BIOS_DATA, #$24,Kstart_l0
	jnb	EPROM_OE,$
	jb	EPROM_OE,$
	cjne	BIOS_DATA, #$10,Kstart_l0
	jnb	EPROM_OE,$
	jb	EPROM_OE,$
	cjne	BIOS_DATA, #$45,Kstart_l0	
	mov	BIOS_DATA, #$00				
	mode	#$0F
	mov	!BIOS_DATA, #$00		;port rc =out

IFDEF	MODE54
	jb	EPROM_OE, $			; wait for bios OE low(next byte)
	jnb	EPROM_OE, $			; wait for bios OE HI
ELSE
	call	wait_bios_oe_low_p0
ENDIF

	mov	BIOS_DATA, #$00			;send 00,00,00,00
	call	wait_bios_oe_low_p0
	mov	BIOS_DATA, #$00
	call	wait_bios_oe_low_p0
	mov	BIOS_DATA, #$00
	call	wait_bios_oe_low_p0
	mov	!BIOS_DATA, #$FF


;**************************************************************************************************
;New mode select for PSX/DEV mode :
;Check RESET for about 4 sec ( 2 =initial delay + 2 from this routine )
;if exit before then enter PSX mode , else wait for reset release and wait again for 
;10 sec. If RESET is pressed again within 10 sec. then enter DEV mode else 
;definitively SLEEP chip for all media that no need patch ( VIDEO , MUSIC , ORIGINALS ).
;**************************************************************************************************
TEST_RESET
	mov	count2,#10			;test RESET for about 2.0 sec 
test_l1
	call	DELAY100m									
	jb	RST_BTN,RESET_DOWN
	djnz	count2,test_l1
	jnb	RST_BTN,$			;wait RESET release
 	mov	count2,#5			;debounce RESET for about 0.5 sec 
test_l2
	call	DELAY100m
	djnz	count2,test_l2
	mov	count2,#100			;test RESET again for about 10.0 sec.
test_l3 
	call	DELAY100m
	jnb	RST_BTN,@DEVMODE		;resetted ...enter DEV mode
	djnz	count2,test_l3
	sleep					;...sleep chip , can't wake up without put PS2 into stby

RESET0
	clr	FSR
	clrb	PSX_FLAG
;	clrb	MOVIE_FLAG
RESET_DOWN
;	clr	FSR				;
	jb	DEV_FLAG,@DEVMODE		;reenter dev mode if rest in dev mode
	setb	SOFT_RST			;soft reset may need more than 1 disk patch  he he he ....
	clrb	EJ_FLAG	
	setb	X_FLAG				;first XMAN patch flag
	clrb	V12L_FLAG			;clear V12 logo flag patch
;	clrb	V10_FLAG
;	clrb	V12_FLAG	
	jmp	@PS2_PATCH			;PS2 osd patch or PS1DRV init... (based on psx_flag status)


;---------------------------------------------------------------------
;PS2 : continue patch after  OSDSYS & wait for disk ready...
;---------------------------------------------------------------------
PS2_PATCH2
	clr	FSR
	jnb	PSX_FLAG,@XMAN

;EJECTED0
;	clr	FSR
	jnb	PSX_FLAG,CDDVD_EJECTED
;:el0
;	jnb	RST_BTN,RESET0		;reset ?
;	jb	IO_EJECT,:el0		;wait for tray closed...
;	call	SET_INTRPT	
;	jmp	PSX_PATCH					
CDDVD_EJECTED					;here from eject
	jnb	RST_BTN,RESET0		;reset ?
	jb	IO_EJECT,CDDVD_EJECTED		;wait for tray closed...

;wait for bios cs inactive ( fix for  5 bit bus and cd boot )
DELAY1s					;Precise delay routine using RTCC 
	mov	COUNT2,#5
ld_del0
	mov	COUNT1,#100        	;delay = 100 millisec.
ld_del   	
IFDEF	MODE54
	mov 	RTCC,#45		;load  timer=45 for 54 M
ELSE	
	mov 	RTCC,#59		;load  timer=61,delay = (256-61)*256*0.02 micros.= 1000 micros.
ENDIF	
ld_del1
	jnb	BIOS_CS,DELAY1s		;wait again 500msec if bios cs active
	jnb	RST_BTN,RESET0		;new reset check here ...	
	jb	IO_EJECT,CDDVD_EJECTED	;
	mov 	w,RTCC			;wait for timer= 0 ... (don't use TEST RTCC)
	jnz 	ld_del1			;
	djnz 	COUNT1,ld_del		;
	djnz	COUNT2,ld_del0

	call	SET_INTRPT		;better here ....
	
	clr	FSR
	
	jb	DEV_FLAG,@MEDIA_PATCH	;patch media for DEVMODE
	;jb	PSX_FLAG,PSX_PATCH	;enter psx mode ...

	mov	COUNT4,#2		;# of ps2logo patch for PS2 V7
	cje	PS2_ID2, #'2', MEPATCH	;year 2002 for V7
	mov	COUNT4,#1
MEPATCH	
	jmp	@MEDIA_PATCH		;patch ps2 CD/DVD

;-------------------------------------------------------------------------
;NEW NEW NEW patch psx game... and some protected too 
;-------------------------------------------------------------------------

PSX_PATCH
	clr	FSR
	clrb	SCEX_FLAG
	mov	VAR_FLAG,#255		;autosend correct # of SCEX (max value help bad optics) ;)
psx_ptc_l0
	call	SEND_SCEX
	jb	SCEX_FLAG,DRVPTC
	djnz	VAR_FLAG,psx_ptc_l0	; loop sending SCEX
	jmp	@SLEEP_MODE
DRVPTC
	jb	EJ_FLAG,psx_ptc_l0	;send all scex after bios patch then sleep
	mov	COUNT4,#2		;# of PS1DRV patch for PS2 V7
	cje	PS2_ID2,#'2',DRV
	mov	COUNT4,#1
DRV      
	jb	A_FLAG,@LOGO
	jb	I_FLAG,@LOGO
	
	jmp	@PSX1DRV		;exec psxdrv patch + logo1 + set EJect flag and ret to PSX_PATCH

org	$200					;page 1
;----------------------------------------------------------
;wait bios oe low in page 1
;----------------------------------------------------------
wait_bios_oe_low_p1
	jb	EPROM_OE,$
IFDEF	MODE54	
	nop
ENDIF
	ret  

;---------------------------------------------------------
; NEW BIOS PATCH ROUT
;---------------------------------------------------------
PATCH		                
IFDEF	MODE54
	jnb	EPROM_OE, $	
ENDIF
:loop0
	mov	BIOS_DATA,INDF
	inc	FSR     
	or	FSR,#%00010000
	jb	EPROM_OE, $	
	djnz	COUNT2,:loop0
	jnb	EPROM_OE, $
	mov	!BIOS_DATA, #$FF
	clr	FSR			;moved here !
	retp

;----------------------------------------------------------
;Patch PS2 game...
;----------------------------------------------------------
LOAD_OSDSYS
	add	pc,w
;V134
	retw	$23
	retw	$80
	retw	$AC
	retw	$0C
	retw	$00
	retw	$00
	retw	$00 
;VX
	retw	$24	;7
	retw	$10
	retw	$3C
	retw	$E4 
	retw	$24
	retw	$80
	retw	$AC
	retw	$E4
	retw	$22
	retw	$90
	retw	$AC
	retw	$84
	retw	$BC

	mov	COUNT3,#63 ; #### ber
	jmp	LOAD_END
	
;V9	
	retw	$24	;23
	retw	$10
	retw	$3C
	retw	$74
	retw	$2A
	retw	$80
	retw	$AC
	retw	$74
	retw	$28
	retw	$90
	retw	$AC
	retw	$BC
	retw	$D3
	
	mov	COUNT3,#63
	jmp	LOAD_END

	retw	$24	; 39  +8 = 47
	retw	$10 
	retw	$3C
	retw	$E4 
	retw	$2C 
	retw	$80 
	retw	$AC
	retw	$F4
	retw	$2A 
	retw	$90 
	retw	$AC

	jb	V12_FLAG,:v12
	mov	COUNT3,#54	; 54 + 8 = 62
	retw	$A4
	retw	$EC 
	mov	COUNT3,#63	; 63 + 8 = 71
	jmp	LOAD_END
:v12
	mov	COUNT3,#61	; 61 +8 = 69
	retw	$0C
	retw	$F9 


LOAD_END
	retw	$91 	; 63    + 8  = 71
	retw	$34
	retw	$00 
	retw	$00    
	retw	$30 
	retw	$AE
	retw	$0C 
	retw	$00 
	retw	$00 
	retw	$00

LOAD_PSX1D
;	retw	$3C 	; 71       + 8 = 79
	retw	$C7 	;73
	retw	$02
	retw	$34 
	retw	$19 
	retw	$19 
	retw	$E2
	retw	$BA 
	retw	$11 
	retw	$19 
	retw	$E2	
	retw	$BA		

PS2_PATCH
;load osdsys data patch for PS2 mode or ps1drv data patch for PSX mode 
	clr	FSR
	jnb	PSX_FLAG,:set_psx2	;ps2 mode selected , skip 
	mov	COUNT1,#11 		;psx mode : # of patch bytes      
	mov	w,#73			;ps1drv data offset here ...
	jmp	:loopxx	

:set_psx2
;ps2 mode data offset 
	clr	FSR
	cje	PS2_ID1, #'1', :set_V1
	cje	PS2_ID1, #'2', :set_V3
	cje	PS2_ID1, #'5', :set_V4
	jmp	:set_Vx				; V7/8/9/10

:set_V1
	mov	BIOS_DATA,#$C0
	mov	COUNT3,#$B0
	mov	COUNT4,#$74	
	jmp	:set_P
:set_V3
	mov	BIOS_DATA,#$D8
	mov	COUNT3,#$40
	mov	COUNT4,#$7A
	jmp	:set_P	
:set_V4
	mov	COUNT3,#$60
	mov	COUNT4,#$7D
	mov	BIOS_DATA,#$0C

:set_P
       	mov	COUNT1,#7
	mov	COUNT2,w       	
       	clr	w
	jmp	:loopxx       	
:set_Vx
	mov	BIOS_DATA,#$02
	mov	COUNT1,#23      
	mov	COUNT2,w

	cje	PS2_ID1, #'7', :set_V9
	cje	PS2_ID1, #'9', :set_V10
	cje	PS2_ID1, #'0', :set_V12	
	
	mov	COUNT3,#$30
	mov	COUNT4,#$7D
	
	mov	w,#7		; V5678
	jmp	:loopxx
:set_V9           
	mov	COUNT3,#$04
	mov	COUNT4,#$94
	mov	w,#23
	jmp	:loopxx	
:set_V10                
	setb	V10_FLAG
	mov	COUNT3,#$64
	mov	COUNT4,#$9E
	mov	w,#39
	jmp	:loopxx	
:set_V12
	setb	V10_FLAG
	setb	V12_FLAG
	mov	COUNT3,#$7C
	mov	COUNT4,#$A9
	mov	w,#39      
	
:loopxx

	jb	DEV_FLAG,SETUPDEV
	mov	COUNT3,w
	mov	FSR,#$15
:loop
	mov	w,COUNT3     
	call	LOAD_OSDSYS
	mov	INDF,w
	inc	FSR     
	or	FSR,#%00010000
	inc	COUNT3	
	djnz	COUNT1,:loop

	clr	FSR
	
	jb	PSX_FLAG,@CDDVD_EJECTED	;PS2_PATCH2		;exit osd patch if psx mode selected ...

:loop0
	; OSDSYS Wait for 60 00 04 08 ... fixed for V10 :)
	jb	EPROM_OE, :loop0		; wait for OE = LOW
;	nop
	cjne	BIOS_DATA, #060h, :loop0	; is byte1 = #060h
	jnb	EPROM_OE,$
	jb	EPROM_OE,$
;	nop	
	cjne	BIOS_DATA, #000h, :loop0	; is byte2 = #000h
	jnb	EPROM_OE,$
	jb	EPROM_OE,$
;	nop	
	cjne	BIOS_DATA, #004h, :loop0	; is byte3 = #004h
	jnb	EPROM_OE,$
	jb	EPROM_OE,$
;	nop	
	cjne	BIOS_DATA, #008h, :loop0	; is byte4 = #008h

;	jb	DEV_FLAG,BIOS_OSDSYS
	mov	FSR,#$15
	
;-----------------------------------------------------------
; Patch data for bios OSDSYS 
;-----------------------------------------------------------
BIOS_OSDSYS
:loop1
	jb	EPROM_OE, $			; next byte(OE low..)
;	nop	
	cjne	BIOS_DATA, #007h, :loop1	;

:loop66	jb	EPROM_OE, $			; next byte / wait for bios OE low
;	nop
	cjne	BIOS_DATA, #003h, :loop66	; is byte1 = #03h
	jnb	EPROM_OE, $
	jb	EPROM_OE, $
;	nop	
	cjne	BIOS_DATA, #024h, :loop66	; is byte2 = #24h
	jnb	EPROM_OE, $
	mov	!BIOS_DATA, w
	
	jb	EPROM_OE, $			; wait for bios OE low(next byte)
	call	@PATCH
	jb	DEV_FLAG,@MODLOAD1
	jb	V12L_FLAG,@PS2_PS2LOGO:back		;logo patch for V12
	jmp	@PS2_PATCH2			;end of osd patch

SETUPDEV
	mov	FSR,#$1C
	mov	INDF,COUNT3
	inc	FSR
	mov	INDF,COUNT4
	clr	FSR	

	mov	BIOS_DATA,#$04
	mov	COUNT2,#119

	jmp	@PS2_PATCH:loop0		

;----------------------------------------------------------
;XCDVDMAN routine
;---------------------------------------------------------- 

IS_XCDVDMANX
	call	@SET_INTRPT

IS_XCDVDMAN
	jb	DEV_FLAG,@MODLOAD	

	mov	COUNT4, #100			; 30-35 sec wait for BIOS 
:loop4	mov	COUNT3, #0FFh
:loop3	mov	COUNT2, #0FFh
:loop2	mov	COUNT1, #0FFh
:loopx  jnb	BIOS_CS,:loop1		
	djnz	COUNT1, :loopx
	djnz	COUNT2, :loop2
	djnz	COUNT3, :loop3	
	djnz	COUNT4, :loop4
	jmp	SLEEP_MODE			; no xcdvdman reload ...


:loop0  
	jb	BIOS_CS,:loopx
:loop1	cjne	BIOS_DATA, #$A2, :loop0		;sync A2 93 23 for V1-V10
	call	wait_bios_oe_low_p1
	cjne	BIOS_DATA, #$93, :loop0		; is byte2 = #093h
	call	wait_bios_oe_low_p1
	cjne	BIOS_DATA, #$34, :loop0		; is byte3 = #034h

XCDVDMAN

	clr	FSR
	mov	COUNT2,#7
	mov	BIOS_DATA, #$08				;send 08

xcdvdman1_l0a                                            
	jb	EPROM_OE,xcdvdman1_l0a			;27 18 00 A3 (A3)
;	nop						;
	cjne	BIOS_DATA, #027h, xcdvdman1_l0a		;
	call	wait_bios_oe_low_p1
	cjne	BIOS_DATA, #018h, xcdvdman1_l0a		;
	call	wait_bios_oe_low_p1
	cjne	BIOS_DATA, #00h, xcdvdman1_l0a		;
	call	wait_bios_oe_low_p1
	cjne	BIOS_DATA, #0A3h, xcdvdman1_l0a		;


; patch it
; Addr 00006A28 export 0x23(Cd Check) kill it
; 00006A28: 08 00 E0 03  jr ra
; 00006A2C: 00 00 00 00  nop

	jb	X_FLAG,again			;first XMAN executed !

xcdvdman1_next
	mov	FSR,#$15

xcdvdman1_l1
	jb	EPROM_OE,$
	nop	
	cjne	BIOS_DATA,#$27,xcdvdman1_l1
	jnb	EPROM_OE, $	
	mov	!BIOS_DATA, w  

	jb	EPROM_OE,$			;wait bios LOW
	call	@PATCH				;


;	jb	DEV_FLAG,@MODLOAD1

	jnb	EJ_FLAG,@CDDVD_EJECTED		;jump to EJECTED if no EJ_FLAG = first xman patch for originals
	jmp	IS_XCDVDMAN			;? da verificare !!!
again
	clrb	X_FLAG
	jmp	IS_XCDVDMAN			;patch cddvdman & xcdvdman


;TO SLEEP ... , PERHARPS TO DREAM ...
;SLEEP0
;	clrb	PSX_FLAG
SLEEP_MODE
	mov	m, #00Ah			;set up edge register
	mov	!rb, #%00000110			;RB3 wait for HI ( = 0 ),RB2 wait for low (=1)						
	mov	m, #009h			;clear all wakeup pending bits
	clr	w				;  
	mov	!rb,w				;
	mov	m, #00Bh			;enable wakeup...
	jb	PSX_FLAG,no_bios_wake
;	jb	MOVIE_FLAG,no_bios_wake	
	mov	!rb, #%11110001			;... on RB3 ( EJECT ),RB2 (reset) & RB1 (bios cs) 
	sleep
no_bios_wake
	mov	!rb, #%11110011			;... on RB3 ( EJECT ),RB2 (reset) 
	sleep	
	


org $400
wait_bios_oe_low_p4
	jb	EPROM_OE,$
	ret

LOAD_PS2LOGO
	add	PC, w
LOAD_XMAN
	retw	$00 
	retw	$E0	
	retw	$03
	retw	$00 
	retw	$00
	retw	$00
	retw	$00 

PS2_LOGOV12

	retw	$08	; 27 ;1C
	retw	$11
	retw	$3C
	retw	$C1
	retw	$00
	retw	$31
	retw	$36
	retw	$18
	retw	$16
	retw	$91
	retw	$AC	

	retw	$0C		
	retw	$00
	retw	$00
	retw	$00
	 
LOGO2
	retw	$00	;22
	retw	$00	 ; 37h  3C
	retw	$00
	retw	$00
	retw	$20
	retw	$38
	retw	$11
	retw	$00
	retw	$00
	retw	$60
	retw	$03
	retw	$24
	retw	$00
	retw	$00
	retw	$E2
	retw	$90
	retw	$00
	retw	$00
	retw	$E4
	retw	$90
	retw	$FF
	retw	$FF
	retw	$63
	retw	$24
	retw	$26
	retw	$20
	retw	$82
	retw	$00
	retw	$00
	retw	$00
	retw	$E4
	retw	$A0
	retw	$FB
	retw	$FF
	retw	$61
	retw	$04
	retw	$01
	retw	$00
	retw	$E7
	retw	$24	;42	;61
	
	mov	COUNT3,#73			
	jb	V10_FLAG,LOADV10A
	mov	COUNT3,#68
	
	retw	$D0	;49	; 68
	retw	$80

	mov	COUNT3,#75
	jmp	LOADL1

;V10	
LOADV10A

	retw	$50	; 50	;73
	retw	$81
LOADL1	
	retw	$80	; 75
	retw	$AF
	retw	$2E
	retw	$01
	retw	$22
	retw	$92
	retw	$2F
	retw	$01
	retw	$23
	retw	$92
	retw	$26
	retw	$10
	retw	$43
	retw	$00
	retw	$1A
	retw	$00
	retw	$03
	retw	$24
	retw	$03
	retw	$00
	retw	$43
	retw	$14
	retw	$01
	retw	$00
	retw	$07
	retw	$24	;81 ; 100

	mov	COUNT3,#127			
	jb	V10_FLAG,LOADV10B
	mov	COUNT3,#107	
	
	retw	$BD	;88 ;107
	retw	$05
	retw	$04
	retw	$08
	retw	$CC
	retw	$80
	retw	$87
	retw	$AF
	retw	$00
	retw	$00
	retw	$07
	retw	$24
	retw	$BD 
	retw	$05
	retw	$04
	retw	$08
	retw	$CC
	retw	$80
	retw	$87
	retw	$AF	; 107 ;126

;V10
LOADV10B
	retw	$AF	; 108 ;127
	retw	$05
	retw	$04
	retw	$08
	retw	$4C
	retw	$81
	retw	$87
	retw	$AF
	retw	$00
	retw	$00
	retw	$07
	retw	$24
	retw	$AF
	retw	$05
	retw	$04
	retw	$08
	retw	$4C
	retw	$81
	retw	$87
	retw	$AF	;146

V12END
	retw	$AF	;147
	retw	$05
	retw	$04		
	retw	$08	;150
XMAN
	mov	COUNT1,#114
	mov	COUNT2,w
        clr	w
 
PS2_PS2LOGO

:loopa
	mov	COUNT3,w
	mov	FSR,#$15
:loop
	mov	w,COUNT3     
	call	LOAD_PS2LOGO
	mov	INDF,w
	inc	FSR     
	or	FSR,#%00010000
	inc	COUNT3	
	djnz	COUNT1,:loop


	clr	FSR
	jb	X_FLAG,@IS_XCDVDMAN

:loopz
	clr	FSR
;load regs with v12 logo sync
	mov	COUNT2,#107			;V12 logo lenght
	mov	VAR_TEMP,#008h			;V12 sync data
	mov	VAR_FLAG,#0E0h
	mov	WAKE_UP, #09Dh
	mov	BIOS_DATA,#$40			;V12 bios preload
	jb	V12_FLAG,:loop00x
;load regs with v10 sync
	mov	VAR_TEMP,#0AFh			;V10 sync data
	mov	VAR_FLAG,#006h
	mov	WAKE_UP, #008h
	mov	BIOS_DATA, #$00			;V1-V10 bios preload
	jb	V10_FLAG,:patchlogo2
;load regs with v1-v9 sync
	mov	VAR_FLAG,#01Eh			;V1-V9 sync data 

:patchlogo2
;do not use COUNT2, COUNT4 
;free var : VAR_TEMP , VAR_FLAG , WAKE_UP , COUNT1 , COUNT3
	mov	COUNT2,#87			;V1-V10 logo lenght

:loop4	mov	VAR_PSX_DATA, #050h		;need correct value here ( FFh = too HI , 01h too LO) !!!
:loop3	mov	COUNT3, #0FFh			;value ok
:loop2	mov	COUNT1, #0FFh			;value ok
:loopx  jnb	BIOS_CS,:loop1x		
	djnz	COUNT1, :loopx
	djnz	COUNT3, :loop2
	djnz	VAR_PSX_DATA,:loop3

;AUTORESET 	
;NEW!!! future board design using a 2N7002 mosfet
IFDEF	TRANSISTOR				;transistor onchip 2N7002 
	mode	#00Bh				;disable interrupt , need !!! ...
	mov	!rb, #%11111111			;
	mode	#00Fh			
	mov	CDDVD_DATA,#$00			;reset by transistor on chip , no need F to mboard
	mov	w, #%11111011			;'0' = output ! = RESET MACHINE 
	mov	!CDDVD_DATA, w
	call	@DELAY100m
	mov	!CDDVD_DATA, #$FF
ELSE						;F wire on mboard 
	mov	CDDVD_DATA,#$00
	mov	w, #%11111110			;'0' = output ! = RESET MACHINE ... use F now
	mov	!CDDVD_DATA, w
	call	@DELAY100m			;
	mov	!CDDVD_DATA, #$FF
ENDIF
	setb	PSX_FLAG
	jmp	@AUTO_P

	
;sync for all versions using regs :))
:loop00x  
	jb	BIOS_CS,:loopx
:loop1x	cjne	BIOS_DATA,VAR_TEMP, :loop00x	;
	jnb	EPROM_OE,$
	jb	EPROM_OE,$	
	cjne	BIOS_DATA,VAR_FLAG, :loop00x	;
	jnb	EPROM_OE,$
	jb	EPROM_OE,$
	cjne	BIOS_DATA,WAKE_UP , :loop00x	;

	jb	V12_FLAG,:logo12
	mov	FSR,#$3C

:loop1			
	jb	EPROM_OE,$			; wait for OE = LOW
	nop
	cjne	BIOS_DATA, #00Ch, :loop1	; is last byte = #00Ch
	jnb	EPROM_OE, $
	mov	!BIOS_DATA, w
	jb	EPROM_OE, $ 	
	call	@PATCH
	djnz	COUNT4,:patchlogo2		;patch logo 2 times for V7 only !
:back
	setb	EJ_FLAG
	jmp	@IS_XCDVDMAN

;V12 logo sync
:logo12
	mov	FSR,#$1C	;27
	setb	V12L_FLAG
	jmp	@BIOS_OSDSYS	

;psx1 driver patch ...
PSX1DRV
V7DRV
	mov	BIOS_DATA,#$3C
	mov	COUNT2,#11
	mov	FSR,#$15
	
;10 01 00 43 30
psx1drv_l0
	jb	EPROM_OE,$	
	cjne	BIOS_DATA, #$11,psx1drv_l0
	call	wait_bios_oe_low_p4	
	cjne	BIOS_DATA, #$11,psx1drv_l0
	call	wait_bios_oe_low_p4	
	cjne	BIOS_DATA, #$00,psx1drv_l0
	call	wait_bios_oe_low_p4	
	cjne	BIOS_DATA, #$09,psx1drv_l0

psx1drv_l0a
	jb	EPROM_OE,$	
	nop
	cjne	BIOS_DATA, #$30,psx1drv_l0a	; 3C C7 34 19 19 E2 B2 19 E2 BA
	jnb	EPROM_OE, $	
	mov	!BIOS_DATA, w
	jb	EPROM_OE, $			; wait for bios OE low(next byte)
	call	@PATCH
	djnz	COUNT4,V7DRV	

LOGO
	mov	COUNT1,#52			;byte to skip
	mov	COUNT3,#24
	mov	COUNT4,w	

logo_l1						;match FDFF8514
	jb	EPROM_OE,$	
	cjne	BIOS_DATA, #$FD,logo_l1	
	jnb	EPROM_OE,$
	jb	EPROM_OE,$		
	cjne	BIOS_DATA, #$FF,logo_l1			
	jnb	EPROM_OE,$
	jb	EPROM_OE,$
	cjne	BIOS_DATA, #$85,logo_l1			
	jnb	EPROM_OE,$
	jb	EPROM_OE,$
	cjne	BIOS_DATA, #$14,logo_l1
 
logo_skip
	jnb	EPROM_OE, $    	
	jb	EPROM_OE, $    
	djnz	COUNT1,logo_skip    

	mov	BIOS_DATA,#$03
	jnb	EPROM_OE, $
	mov	!BIOS_DATA,#$00
	call	wait_bios_oe_low_p4
	mov	BIOS_DATA,#$80    
	call	wait_bios_oe_low_p4
	mov	BIOS_DATA,#$04
	call	wait_bios_oe_low_p4
	mov	BIOS_DATA,#$3C
	call	wait_bios_oe_low_p4
	mov	!BIOS_DATA, #$FF
	
logo_skip2	
	jnb	EPROM_OE, $    	
	jb	EPROM_OE, $    
	djnz	COUNT3,logo_skip2

	mov	BIOS_DATA,#$00
	jnb	EPROM_OE, $
	mov	!BIOS_DATA,#$00
	call	wait_bios_oe_low_p4
	mov	BIOS_DATA,#$00
	call	wait_bios_oe_low_p4
	mov	BIOS_DATA,#$00
	call	wait_bios_oe_low_p4
	mov	BIOS_DATA,#$00
	call	wait_bios_oe_low_p4			
	mov	!BIOS_DATA, #$FF

logo_skip3	
	jnb	EPROM_OE, $    	
	jb	EPROM_OE, $    
	djnz	COUNT4,logo_skip3

	mov	BIOS_DATA,#$88
	jnb	EPROM_OE, $
	mov	!BIOS_DATA,#$00	
	call	wait_bios_oe_low_p4
	mov	BIOS_DATA,#$02
	call	wait_bios_oe_low_p4
	mov	BIOS_DATA,#$80
	call	wait_bios_oe_low_p4
	mov	BIOS_DATA,#$A4
	call	wait_bios_oe_low_p4			
	mov	!BIOS_DATA, #$FF 

;	clr	FSR
	setb	EJ_FLAG
	jmp	@PSX_PATCH	

org $600

wait_bios_oe_low_p3
	jb	EPROM_OE,$
IFDEF	MODE54	
	nop
ENDIF
	ret

LOAD_DEVMODE
	add	pc,w

;	retw	$04
	retw	$08
	retw	$10
	retw	$3C
	retw	$72  
	retw	$00
	retw	$11	;10	
	retw	$36	;11

	retw	$00	; adress
	retw	$00	; 

	retw	$92	;
	retw	$34
	retw	$00
	retw	$00
	retw	$51
	retw	$AE	;20
	retw	$0C
	retw	$00
	retw	$00
	retw	$00	;20

	retw	$03  
	retw	$00
	retw	$05	;10	
	retw	$24	 
	retw	$10	;1B
	retw	$00	;1B
	retw	$04
	retw	$3C
	retw	$F0
	retw	$01
	retw	$84
	retw	$34
	retw	$10
	retw	$00
	retw	$06
	retw	$3C
	retw	$E4
	retw	$01
	retw	$C6
	retw	$34	 
	retw	$06	;20
	retw	$00
	retw	$03
	retw	$24
	retw	$0C
	retw	$00
	retw	$00
	retw	$00

	retw	$FB
	retw	$01
	retw	$10	;30
	retw	$00
	retw	$0B
	retw	$02
	retw	$10
	retw	$00
	retw	$19
	retw	$02
	retw	$10
	retw	$00	
	
	retw	$6D	;40
	retw	$6F
	retw	$64
	retw	$75
	retw	$6C
	retw	$65
	retw	$6C	 
	retw	$6F
	retw	$61
	retw	$64
	retw	$00	;50
	
	retw	$2D
	retw	$6D
	retw	$20
	retw	$72
	retw	$6F	 
	retw	$6D
	retw	$30
	retw	$3A
	retw	$53
	retw	$49	;60
	retw	$4F
	retw	$32
	retw	$4D
	retw	$41
	retw	$4E
	retw	$00
	
	retw	$2D	 
	retw	$6D
	retw	$20	;70
	retw	$72
	retw	$6F
	retw	$6D
	retw	$30
	retw	$3A
	retw	$4D
	retw	$43
	retw	$4D
	retw	$41
	retw	$4E	;80
	retw	$00

	retw	$6D
	retw	$63
	retw	$30
	retw	$3A
	retw	$2F
	retw	$42   	
	retw	$4F	
	retw	$4F     
	retw	$54     	;90
	retw	$2F 	
	retw	$42	
	retw	$4F     
	retw	$4F     
	retw	$54     
	retw	$2E
	retw	$45
	retw	$4C
	retw	$46
	retw	$00		;100

DEVMODE

	clrb	PSX_FLAG  
;	clrb	X_FLAG
	setb	SOFT_RST
	setb	EJ_FLAG				; skip logo patch after media for DEVMODE
	setb	DEV_FLAG			;set DEVMODE flags...
;	setb	MODL_FLAG			;...

       	mov	COUNT1,#119
;	mov	COUNT2,w	

:next	
	clr	w
:loopxx
	mov	COUNT3,w
	mov	FSR,#$15
:loop
	mov	w,COUNT3     
	call	LOAD_DEVMODE
	mov	INDF,w
	inc	FSR     
	or	FSR,#%00010000
	inc	COUNT3	
	djnz	COUNT1,:loop
	
	jmp	@PS2_PATCH:set_psx2


	
;------------------------
;skip # of cddvd bytes
;------------------------
CDDVDSKIP_P8
	jb	DVD_CNT_CLK,$
	clrb	FFCLR
	nop
	setb	FFCLR
	djnz	COUNT1,CDDVDSKIP_P8
	ret	

PACKIT_BYTE			; move B to F
	add	pc,w
;A version patch 

	retw	$3B
	retw	$A0
	retw	$33
	retw	$28
	retw	$20
	retw	$FF
	retw	$04
	retw	$41							

;E version patch
	
	retw	$44
	retw	$FD
	retw	$13
	retw	$2B
	retw	$61
	retw	$22
	retw	$13
	retw	$31							
	
;I version patch 
	retw	$8C
	retw	$B0
	retw	$03
	retw	$3A
	retw	$31
	retw	$33
	retw	$19
	retw	$91							

;-----------------------------------------------------------------------------------------------------
;Patch DVD
;This ruotine will authenticate DVD to PS2 and is executed a certain number ( variable ?)  of times...
;boots dvd-r , dvd-rw on V9 :)
;-----------------------------------------------------------------------------------------------------
MEDIA_PATCH
	clr FSR
	setb	FFCLR
;execute first patch for V12 only ...
	cje	PS2_ID1,#'0',dvd_patch		;patch DVD media for V12
;skip first patch for V1-V8....
	cjae	PS2_ID1,#'7',dvd_patch		;patch DVD media for V9-10

;V1-V8 version... fix for HDD operations ( bios activity )
HDD_FIX
	mov	COUNT1,#4
:l0
	mov	W,#$90	
	jb	DVD_CNT_CLK,$		;wait sync byte FF FF FF FF
	clrb	FFCLR
	nop
	setb	FFCLR
	and	W,CDDVD_DATA
	mov	VAR_TEMP,w
	cjne 	VAR_TEMP,#$90,HDD_FIX
	djnz	COUNT1,:l0
	jmp	CDDVD_PATCH_V1

dvd_patch 
	mov	COUNT1, #15			;skip 16 byte for V9-10-12 dvd patch ,15 is a fix !!!

dvd_patch1
	mov	W,#$B0
	jb	DVD_CNT_CLK,$			;wait sync byte 
	clrb	FFCLR
	and	W,CDDVD_DATA
	mov	VAR_TEMP,w
	setb	FFCLR
	cjne 	VAR_TEMP,#$A0,dvd_patch1	;FA-FC

media_l1
	mov	w,#$B0		
	jb	DVD_CNT_CLK,$			;wait sync byte
	clrb	FFCLR
	and	W,CDDVD_DATA
	mov	VAR_TEMP,w
	setb	FFCLR
	cje 	VAR_TEMP,#$B0,media_l2		;FF	
	cjne	VAR_TEMP,#$00,dvd_patch1	;00

media_l2
	mov	w,#$B0	
	jb	DVD_CNT_CLK,$			;wait sync byte
	clrb	FFCLR
	and	W,CDDVD_DATA
	mov	VAR_TEMP,w
	setb	FFCLR     
	cje 	VAR_TEMP,#$B0,CDDVD_PATCH		;FF	
	cjne	VAR_TEMP,#$A0,dvd_patch1	;FC

	jb	PSX_FLAG,@SLEEP_MODE		;sleep for DVD media loaded in PSX mode
	call	CDDVDSKIP_P8

dvd_patch2
;Patch bus first time	
;only F,G bit need patch :)
;patch to	0X 0X 0X 0X 
;dvdr game  is 	0F 25 0F 25
;dvdrom game is 02 01 02 01
;dvd-rw game is 0F 32 0F 32
;dvd9 video is  02 01 02 01
	mov	w, #$00				;patch bus first time !			
	mov	CDDVD_DATA, w	
	mov	w, #%00011111			;mechacon bus: IHGBXXXF ; '0' = output !

	jb	DVD_CNT_CLK,$			;patch 4 bytes
	clrb	FFCLR				;this is byte #1
	mov	!CDDVD_DATA, w
	setb	FFCLR				;

	mov	COUNT1, #5			;skip 5 bytes , FIX for 15 bytes skip (see above ...)
	call	CDDVDSKIP_P8
	mov	!CDDVD_DATA,#$FF

CDDVD_PATCH

	jb	PSX_FLAG,@PSX_PATCH

CDDVD_PATCH_V1

;wait for mecha FA-FF-FF-01-00-00-01 then patch to 81
dvd_l1
	jnb	BIOS_CS,exit_patch
	jb	DVD_CNT_CLK,dvd_l1		;wait sync byte FA FF FF ...
	clrb	FFCLR
	nop
	setb	FFCLR
	snb	RB.7
	snb	RB.4
	jmp	dvd_l1	

dvd_l2
	jb	DVD_CNT_CLK,dvd_l2		;wait sync byte
	clrb	FFCLR
	nop
	setb	FFCLR
	snb	RB.7
	sb	RB.4
	jmp	dvd_l1	

dvd_l3
	jb	DVD_CNT_CLK,dvd_l3			;wait sync byte
	clrb	FFCLR
	nop
	setb	FFCLR
	snb	RB.7
	sb	RB.4
	jmp	dvd_l1	

dvd_l4
	jb	DVD_CNT_CLK,dvd_l4			;wait sync byte
	clrb	FFCLR
	nop
	setb	FFCLR
	sb	RB.7
	snb	RB.4
	jmp	dvd_l1	
	
dvd_l5
	jb	DVD_CNT_CLK,dvd_l5			;wait sync byte
	clrb	FFCLR
	nop
	setb	FFCLR
	sb	RB.7
	sb	RB.4
	jmp	CDDVD_PATCH	
	
dvd_l6
	jb	DVD_CNT_CLK,dvd_l6			;wait sync byte
	clrb	FFCLR
	nop
	setb	FFCLR
	sb	RB.7
	sb	RB.4
	jmp	CDDVD_PATCH
		
dvd_l7
	jb	DVD_CNT_CLK,dvd_l7			;wait sync byte
	clrb	FFCLR
	nop
	setb	FFCLR
	sb	RB.7
	snb	RB.4
	jmp	CDDVD_PATCH
	jb	PSX_FLAG,@SLEEP_MODE	;V1-V8: sleep for DVD media loaded in PSX mode		

dvd_c1
	mov	w, #$90				;NEW 1 time 1 BYTE patch !!!!!!!!!
	mov	CDDVD_DATA, w
	mov	w, #%01101111			

	jb	DVD_CNT_CLK,$			
	clrb	FFCLR				
	mov	!CDDVD_DATA, w	
	setb	FFCLR

	jb	DVD_CNT_CLK,$
	clrb	FFCLR
	mov	!CDDVD_DATA,#$FF
	setb	FFCLR

;prepare patch region , here for speed !!! No move!!!	
	jb	A_FLAG,:reg_usa		;
	jb	E_FLAG,:reg_uk		;

	mov	w,#16				;JAP
	jmp	reg_ptc
:reg_uk	mov	w,#8				;EURO
	jmp	reg_ptc
:reg_usa
	clr	w				;USA
reg_ptc
	mov	COUNT2, w			; save offset...
	mov	COUNT3, #8			;region patch : # of bytes to patch
	mov	CDDVD_DATA, #$FF		;!!!!!!!!!!!!!	critical	

WAIT_DISK
wait_dvd_lx
	mov	COUNT1, #$03			;skip 6 byte (FA,FF,FF,FA,FF,FF) 
wait_dvd_l0
	jb	DVD_CNT_CLK,$
	clrb	FFCLR
	nop
	setb	FFCLR	
	snb	RB.7
	snb	RB.4
	jmp	wait_dvd_lx

	jb	DVD_CNT_CLK,$
	clrb	FFCLR
	nop
	setb	FFCLR	
	snb	RB.7
	sb	RB.4
	jmp	wait_dvd_lx

	jb	DVD_CNT_CLK,$
	clrb	FFCLR
	nop
	setb	FFCLR	
	snb	RB.7
	sb	RB.4
	jmp	wait_dvd_lx

	djnz	COUNT1,wait_dvd_l0
;	call	CDDVDSKIP_P8

;patch region ...
	mov	w, #%00001111			; '0' = output
	mov	!CDDVD_DATA, w			;port = out
reg_l1
	mov	w, COUNT2 
	call	PACKIT_BYTE

	jb	DVD_CNT_CLK,$			;wait for low
	mov	CDDVD_DATA, w			;patch bus !
	clrb	FFCLR
	mov	VAR_TEMP,w
	mov	w,<>VAR_TEMP	
	setb	FFCLR

	jb	DVD_CNT_CLK,$			;wait for low
	mov	CDDVD_DATA, w			;patch bus !
	clrb	FFCLR
	inc	COUNT2
	setb	FFCLR	
	
	djnz	COUNT3,reg_l1
	jb	DVD_CNT_CLK,$			;wait for low
	mov	!CDDVD_DATA,#$FF

	jb	SOFT_RST,CDDVD_PATCH_V1		;loop on patch for soft reset fix !
exit_patch
	clrb	SOFT_RST			;clear soft reset bit when exit disk patch ...
	jb	EJ_FLAG,@IS_XCDVDMAN		;routine was called from eject...no logo patch required...
	jmp	@PS2_PS2LOGO:loopz
;	jmp	@AUTODETECT

;Modload repatch...
MODLOAD1
	call	@SET_INTRPT
MODLOAD
	mov	COUNT4, #100			; 30-35 sec wait for BIOS 
:loop4	mov	COUNT3, #0FFh
:loop3	mov	COUNT2, #0FFh
:loop2	mov	COUNT1, #0FFh
:loopx  jnb	BIOS_CS,:loop1		
	djnz	COUNT1, :loopx
	djnz	COUNT2, :loop2
	djnz	COUNT3, :loop3	
	djnz	COUNT4, :loop4
	jmp	@SLEEP_MODE			; no xcdvdman reload ...

:loop0  
	jb	BIOS_CS,:loopx
:loop1	cjne	BIOS_DATA, #$43, :loop0		;sync A2 93 23 for V1-V10
	call	wait_bios_oe_low_p3
	cjne	BIOS_DATA, #$14, :loop0		; is byte2 = #093h
	call	wait_bios_oe_low_p3
	cjne	BIOS_DATA, #$74, :loop0		; is byte3 = #034h

:modl1
	jb	EPROM_OE,$	
	cjne	BIOS_DATA, #$D0,:modl1
	jnb	EPROM_OE,$
	jb	EPROM_OE,$
	cjne	BIOS_DATA, #$FF,:modl1
	jnb	EPROM_OE,$
	jb	EPROM_OE,$
	cjne	BIOS_DATA, #$42,:modl1
	mov	BIOS_DATA, #$34				
	mov	!BIOS_DATA, #$00			
	call	wait_bios_oe_low_p3
	mov	!BIOS_DATA, #$FF
	jmp	MODLOAD			

org $7FF							
	jmp	INIT_CHIP			;reset vector
END