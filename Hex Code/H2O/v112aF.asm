; ICE REVOLUTION
; BIOS PATCHING REWRITE
; KILLER CUT
; V1-V12
; RGB FIX
; PSX1 imports screen pos fix
; $270 FREE NOW

;INCLUDE "define.inc"
 

DEVICE	SX28AC, OSCHS2, TURBO, OPTIONX 
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
VAR_PSX_SC	equ	$C
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
PSX_FLAG	equ	$E.2		
V10_FLAG	equ	$E.3		
E_FLAG		equ	$E.4		
A_FLAG		equ	$E.5		
I_FLAG		equ	$E.6
L_FLAG		equ	$E.7		; logo set

V12_FLAG	equ	$F.0
V12L_FLAG	equ	$F.1
X_FLAG		equ	$F.2
				
BIOS_DATA	equ	rc
CDDVD_DATA	equ	rb

IO_SCEX		equ 	ra.2   

BIOS_WAIT_OE_LO MACRO					; only used by mBIOS_SEND!!
	IF ($ & $E00) == $600				; PAGE8 600-7FF	!!!!!!!!! changed for debug
call wait_bios_oe_low_p3
	ELSE
		IF ($ & $E00) == $400			; PAGE4 400-5FF
			call wait_bios_oe_low_p2
		ELSE
			IF ($ & $E00) == $200		; PAGE2 200-3FF
				call wait_bios_oe_low_p1
			ELSE				; PAGE1 000-1FF
				call wait_bios_oe_low_p0
			ENDIF
		ENDIF
	ENDIF
ENDM

mBIOS_SEND MACRO
	REPT \0
		mov BIOS_DATA, \%
		BIOS_WAIT_OE_LO
	ENDR
ENDM

; RRETW Repeat retw
mRRETW MACRO
	REPT \0
		retw \%
	ENDR
ENDM


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
;	mov	!ra,#%11111110		;set IO_EJECT input as cmos ( level '1' > 2.5V ) work better with noise ...	
;	MODE 	$0E 			;Set Mode for Pull-Up Resistor configuration
;	MOV 	!rb,#%11111110 		;1 = normal , 0 = pull-up, mecha 'F' = 1 when read	
	mode	$0F			;port mode 
	mov	!ra,#$07		;port mode : all input
;	mov	!ra,#%00000011		;only for test mode !!!
	mov	!rb,#$FF
	mov	!rc,#$FF
	mov 	!option,#%11000111	;rtcc enabled,no int,incr.on clock, prescaler (bit 2,1,0).
;	clrb	TST


;read power down register
	clr	FSR
	mov 	m, #$09 		;read power down register 
	clr	W 			;clear W
	mov 	!RB, W			;exchange registers = read pending bits
	mov	WAKE_UP,W		;save wake up status ...
	mode	#$0F			;need 'cause removed from patch disk for speed !
	
;execute correct startup...
	jb 	STATUS.3,POWER_UP		;0 = power up from sleep , 1= power up from Power ON (STBY)
	jb	WAKE_UP.2,RESET_DOWN
;	jb	WAKE_UP.3,CDDVD_EJECTED
	jb	IO_EJECT,CDDVD_EJECTED
	jb	WAKE_UP.1,@IS_XCDVDMANX		;xcdvdman reload check
	jmp	@SLEEP_MODE			;to be sure 

;power up from STBY
POWER_UP
	clr	$E			;reset all used flag    
	clr	$F			;reset all used flag    	
	setb	L_FLAG
	setb	X_FLAG	
	jmp	START

;---------------------------------------------------------
;Delay routine using RTCC 
;---------------------------------------------------------
DELAY100m			;Precise delay routine using RTCC 
	mov COUNT1,#100        	;delay = 100 millisec.
l_del   	
IFDEF	MODE54  	
	mov RTCC,#45		;load  timer = 61	,delay = (256-61)*256*0.02 micros.= 1000 micros. / 45 for 54M
ELSE
	mov RTCC,#61		;load  timer = 61	,delay = (256-61)*256*0.02 micros.= 1000 micros. / 45 for 54M	
ENDIF	
l_del1	
	mov w,RTCC		;wait for timer= 0 ... (don't use TEST RTCC)
	jnz l_del1		;
	djnz COUNT1 , l_del	;
	ret			;

;----------------------------------------------------------
;setup interrupt routine
;----------------------------------------------------------
SET_INTRPT
	mov	m, #00Ah			;set up edge register
	mov	!rb, #%00000100			;RB3 & RB2 wait  for low
	mov	m, #009h			;clear all wakeup pending bits
	clr	w				;  
	mov	!rb,w				;
	mov	m, #00Bh			;enable interrupt ...
	mov	!rb, #%11110011			;... on RB3 ( eject ) & RB2 ( reset )
	mode	#00Fh				;
	ret

;----------------------------------------------------------
;
;----------------------------------------------------------
proc_0035
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
;
;----------------------------------------------------------
proc_0044
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
;	jnb	RST_BTN,PSX_PATCH		; check reset
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
;
;----------------------------------------------------------
proc_0054				; SCEA, SCEI, SCEE
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

SEND_SCEX
	jb	A_FLAG,:us
	jb	E_FLAG,:uk
	jmp	:jap
:us
	clr	COUNT4				; COUNT4 = offset = $10
	jmp	label_0071
:uk
	mov	COUNT4, #$08				; SCEE
	jmp	label_0071
:jap
	mov	COUNT4, #$04				; SCEI

label_0071
	mode	#$0F
	mov	w, #$0B
	mov	!ra, w

	mov	VAR_TEMP,#$04			; VAR_TEMP count bytes = $C
	
label_0076
	mov	w, COUNT4
	call	proc_0054
	mov	VAR_PSX_DATA, w
	not	VAR_PSX_DATA

	mov	WAKE_UP,#$08			; WAKE_UP as bitecount = $E

	call	proc_0044
	call	proc_0044
	call	proc_0035
label_007F
	rr	VAR_PSX_DATA
	snc
	jmp	label_0085
	sc
	call	proc_0044
	jmp	label_0086
label_0085
	call	proc_0035
label_0086
	decsz	WAKE_UP
	jmp	label_007F
	inc	COUNT4
	decsz	VAR_TEMP
	jmp	label_0076

	clrb	ra.2

	mov	COUNT4,#$16

label_008E
	call	proc_0044
	decsz	COUNT4
	jmp	label_008E
	mode	#$0F
	mov	w, #$0F
	mov	!ra, w
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

LOAD_EXPLOID_v1
	add	pc,w

Ex_v1
	retw	$4C	
	retw	$11	
	retw	$24	
	retw	$E8	
	retw	$23	
	retw	$91	
	retw	$A4	
	retw	$C8	
	retw	$EB	
	retw	$11	
	retw	$24	
	retw	$B0	
	retw	$74           
	retw	$91	  
	retw	$A4	
	retw	$04	
	retw	$3C	
	retw	$11	
	retw	$3C	
	retw	$29	
	retw	$00	
	retw	$31	
	retw	$36	  
	retw	$D4       
	retw	$23
	retw	$91        
	retw	$AC
	retw	$91	
	retw	$24
	retw	$11
	retw	$3C 	   
	retw	$38        
	retw	$4E
	retw	$31
	retw	$36
	retw	$D8
	retw	$23	
	retw	$91        
	retw	$AC
	retw	$29 
	retw	$00
	retw	$11
	retw	$3C
	retw	$3F         
	retw	$4E	
	retw	$20           
	retw	$A2

; start of CODE
; ### read regional/bios version data ###
; PS2_ID1 = x1 :- holds a numeric value (function unknown), this can have the value '2', '5', or '6'
; PS2_ID0 = x2 :- holds the region of the BIOS, this can have the value 'A' / 'J' or 'E'.
; PS2_ID2 = x3 :- seems to hold the year of the bios, '0', '1' or '2'.
START        

start_l0
	; wait for "S201"
	;        0123456789AB
	; Read "PS201?0?C200?
	jb	EPROM_OE,start_l0		; next byte / wait for bios OE low
	nop
	cjne	BIOS_DATA, #'P',start_l0	; is byte0 = 'S'	, v8 fix
	call	wait_bios_oe_low_p0		; next byte
	cjne	BIOS_DATA, #'S',start_l0	; is byte1 = '2'
	call	wait_bios_oe_low_p0		; next byte
	cjne	BIOS_DATA, #'2',start_l0	; is byte2 = '0'
	call	wait_bios_oe_low_p0		; next byte
	cjne	BIOS_DATA, #'0',start_l0	; is byte3 = '1'
	call	wait_bios_oe_low_p0		; next byte
	jnb	EPROM_OE,$
	call	wait_bios_oe_low_p0		; next byte	
	mov	PS2_ID1,BIOS_DATA		; byte4 = BIOS VER  2, 5, 6, 7(V9!)

start_l1
	jb	EPROM_OE,start_l1		; wait for bios OE low(next byte)
;	nop
	cjne	BIOS_DATA, #'0',start_l1	; is byte5 = '0'
	call	wait_bios_oe_low_p0		; next byte
	mov	PS2_ID3,BIOS_DATA		; byte6 = Region  A(USA) E(UK) J(JAP)

start_l2
	jb	EPROM_OE,start_l2		; wait for bios OE low(next byte)
;	nop
	cjne	BIOS_DATA, #'0',start_l2	; is byte9 = '0'
	call	wait_bios_oe_low_p0		; next byte
	cjne	BIOS_DATA, #'0',start_l2	; is byteA = '0'
	call	wait_bios_oe_low_p0		; next byte
	mov	PS2_ID2,BIOS_DATA		; byteB = BIOS Year  0(2k), 1(2k1), 2(2k2),3(2k3) 

	cje	PS2_ID3, #'A',:us
	cje	PS2_ID3, #'E',:uk
	cje	PS2_ID3, #'R',:uk
	cje	PS2_ID3, #'I',:jap

:us
	setb	A_FLAG
	jmp	:next_r
:uk
	setb	E_FLAG
	jmp	:next_r	
:jap
	setb	I_FLAG
:next_r    

	jb	RST_BTN,RESET_DOWN

	setb	PSX_FLAG
	jb	L_FLAG,@EXPLOIT			; FIRST TIME LONG REST = EXPLOIT		
	
;IFDEF GMFIX

;DVD movie : GREEN fix + MACROVISION off
KERNEL_PATCH

	cje	PS2_ID1, #'7', kernel_V910
	cje	PS2_ID1, #'9', kernel_V910
	cje	PS2_ID1, #'0', kernel_V910

;V1-8 kernels

	mov	COUNT1,#50
:loop0
	jb	EPROM_OE, $			; next byte / wait for bios OE low
	nop
	cjne	BIOS_DATA, #$1E, :loop0	; is byte0 = 'S'	; v8 fix
	call	wait_bios_oe_low_p0	
	cjne	BIOS_DATA, #$00, :loop0	; is byte0 = 'S'	; v8 fix
	call	wait_bios_oe_low_p0	
	cjne	BIOS_DATA, #$63, :loop0	; is byte0 = 'S'	; v8 fix
	call	wait_bios_oe_low_p0	
	cjne	BIOS_DATA, #$34, :loop0	; is byte1 = '2'

:loop0a
	jb	EPROM_OE, $			; next byte / wait for bios OE low
	nop
	cjne	BIOS_DATA, #$24, :loop0a	; is byte0 = 'S'	; v8 fix
	call	wait_bios_oe_low_p0	
	cjne	BIOS_DATA, #$10, :loop0a	; is byte0 = 'S'	; v8 fix
	
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

	mov	!BIOS_DATA, #$00			;port rc =out
	
	call	wait_bios_oe_low_p0
	mov	BIOS_DATA, #$00				;send 00,00,00,00
	call	wait_bios_oe_low_p0
	mov	BIOS_DATA, #$00
	jnb	EPROM_OE, $    	
	mov	!BIOS_DATA, #$FF


	jmp	@PS2_PATCH


; V9/10 kernels

kernel_V910

Kstart_l0
	jb	EPROM_OE,Kstart_l0		; patch 25 10 43 00 to 00 00 00 00 	
	nop
	cjne	BIOS_DATA, #$DC,Kstart_l0
;	call	wait_bios_oe_low_p0	
	jnb	EPROM_OE,$
	jb	EPROM_OE,$
	cjne	BIOS_DATA, #$24,Kstart_l0
;	call	wait_bios_oe_low_p0	
	jnb	EPROM_OE,$
	jb	EPROM_OE,$
	cjne	BIOS_DATA, #$10,Kstart_l0
;	call	wait_bios_oe_low_p0	
	jnb	EPROM_OE,$
	jb	EPROM_OE,$
	cjne	BIOS_DATA, #$45,Kstart_l0	
	mov	BIOS_DATA, #$00				;
	mode	#$0F
	mov	!BIOS_DATA, #$00			;port rc =out

IFDEF	MODE54
	jb	EPROM_OE, $			; wait for bios OE low(next byte)
	jnb	EPROM_OE, $			; wait for bios OE HI
ELSE
	call	wait_bios_oe_low_p0
ENDIF

	mov	BIOS_DATA, #$00				;send 00,00,00,00
	call	wait_bios_oe_low_p0
	mov	BIOS_DATA, #$00
	call	wait_bios_oe_low_p0
	mov	BIOS_DATA, #$00
	call	wait_bios_oe_low_p0
;	mode	#$0F
	mov	!BIOS_DATA, #$FF

PSX_MODE
	jmp	@PS2_PATCH


TEST_RESET 
	mov	count2,#20			;test reset for about 2.0 sec 
test_loop
	call	DELAY100m									
	jb	RST_BTN,CDDVD_EJECTED
	djnz	count2,test_loop
	sleep
						;...sleep chip , can't wake up without put PS2 into stby
RESET_DOWN
	clr	FSR
	clrb	EJ_FLAG				;reset eject flag	
	clrb	L_FLAG				;clear EXPLOIT
	clrb	V12L_FLAG	
	setb	X_FLAG	
	jb	PSX_FLAG,KERNEL_PATCH		;PS2_PATCH2
	jmp	@PS2_PATCH			;enter PS2 mode...


;---------------------------------------------------------------------
;PS2 : continue patch after  OSDSYS & wait for disk ready...
;---------------------------------------------------------------------
PS2_PATCH2
	clr	FSR
	setb	SOFT_RST			;soft reset may need more than 1 disk patch  he he he ....
	clrb	EJ_FLAG		
	jnb	PSX_FLAG,@XMAN
					
CDDVD_EJECTED					;here from eject
	jnb	RST_BTN,RESET_DOWN		;reset ?
	jb	IO_EJECT,CDDVD_EJECTED		;wait for tray closed...
;	call	SET_INTRPT			;moved !!!


;wait for bios cs inactive ( fix for  5 bit bus and cd boot )
DELAY1s					;Precise delay routine using RTCC 
	mov	COUNT2,#5
ld_del0
	mov	COUNT1,#100        	;delay = 100 millisec.
ld_del   	
IFDEF	MODE54
	mov 	RTCC,#45		;load  timer = 61 ,delay = (256-61)*256*0.02 micros.= 1000 micros. /45 for 54 M
ELSE	
	mov 	RTCC,#61		;load  timer = 61 ,delay = (256-61)*256*0.02 micros.= 1000 micros. /45 for 54 M
ENDIF	
ld_del1
	jnb	BIOS_CS,DELAY1s		;wait again 500msec if bios cs active
	jnb	RST_BTN,RESET_DOWN	;new reset check here ...	
	mov 	w,RTCC			;wait for timer= 0 ... (don't use TEST RTCC)
	jnz 	ld_del1			;
	djnz 	COUNT1,ld_del		;
	djnz	COUNT2,ld_del0

	call	SET_INTRPT			;better here ....

	mov	COUNT4,#2
	cje	PS2_ID2, #'2', MEPATCH
	mov	COUNT4,#1
MEPATCH	
;	jmp	@CDDVD_PATCH_PS2_CD
	jmp	@MEDIA_PATCH

;-------------------------------------------------------------------------
;patch psx game...
;-------------------------------------------------------------------------

PSX_PATCH
	jb	EJ_FLAG,psx_not_ejected
	mov	VAR_PSX_SC,#16			;send 35 SCEX ( need !)

psx_ptc_l0
	call	SEND_SCEX
	djnz	VAR_PSX_SC,psx_ptc_l0		; loop sending SCEX

	jnb	E_FLAG,psx_not_ejected

	mov	COUNT4,#2
	cje	PS2_ID2, #'2', DRV
	mov	COUNT4,#1
DRV      
	jmp	@PSX1DRV
	clr	FSR

psx_not_ejected					;here for load with boot disk / AR (for example ...)
	setb	EJ_FLAG
	mov	VAR_PSX_SC,#255			;send # SCEX 

psx_ptc_l3
	call	SEND_SCEX
	djnz	VAR_PSX_SC,psx_ptc_l3
	jmp	@SLEEP_MODE			;enter sleep from psx... 
	
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
;	nop
:loop0
	mov	BIOS_DATA,INDF
	inc	FSR     
	or	FSR,#%00010000
	jb	EPROM_OE, $	
	djnz	COUNT2,:loop0
	jnb	EPROM_OE, $
	mov	!BIOS_DATA, #$FF
	retp

;----------------------------------------------------------
;XCDVDMAN routine
;---------------------------------------------------------- 

IS_XCDVDMANX
	mov	m, #00Ah			;set up edge register
	mov	!rb, #%00000110			;RB3 & RB2 wait for low
	mov	m, #009h			;clear all wakeup pending bits
	clr	w				;  
	mov	!rb,w				;
	mov	m, #00Bh			;enable interrupt ...
	mov	!rb, #%11110011			;... on RB3 ( eject ) & RB2 ( reset )
	mode	#00Fh				;

IS_XCDVDMAN
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
:loop1	cjne	BIOS_DATA, #0A2h, :loop0	; is byte1 = #0A2h
	call	wait_bios_oe_low_p1
	cjne	BIOS_DATA, #093h, :loop0	; is byte2 = #093h
	call	wait_bios_oe_low_p1
	cjne	BIOS_DATA, #034h, :loop0	; is byte3 = #023h


XCDVDMAN

	clr	FSR
	mov	COUNT2,#7
	mov	BIOS_DATA, #$08				;send 08
	
xcdvdman1_l0a                                            
	jb	EPROM_OE,xcdvdman1_l0a			;
	nop						;
	cjne	BIOS_DATA, #027h, xcdvdman1_l0a	; is byte1 = #0A2h
	call	wait_bios_oe_low_p1
	cjne	BIOS_DATA, #018h, xcdvdman1_l0a	; is byte2 = #093h
	call	wait_bios_oe_low_p1
	cjne	BIOS_DATA, #00h, xcdvdman1_l0a	; is byte3 = #023h 34 for V12 fix
	call	wait_bios_oe_low_p1
	cjne	BIOS_DATA, #0A3h, xcdvdman1_l0a	; is byte2 = #093h

; patch it
; Addr 00006A28 export 0x23(Cd Check) kill it
; 00006A28: 08 00 E0 03  jr ra
; 00006A2C: 00 00 00 00  nop

xcdvdman1_next
	mov	FSR,#$15
;	jb	V12L_FLAG,X_12	
;xcdvdman1_l1
;	jb	EPROM_OE,$
;	nop	
;	cjne	BIOS_DATA,#$27,xcdvdman1_l1

;	jnb	EPROM_OE,$ 			
;	mov	!BIOS_DATA, w	

;	jb	EPROM_OE, $
	
;	call	@PATCH
;	jmp	x_end

X_12
	jb	EPROM_OE,$
	nop	
	cjne	BIOS_DATA,#$27,X_12

	jnb	EPROM_OE,$ 			;<<-- XMAN FIX FOR V12 !!!   	
	mov	!BIOS_DATA, w	
	jnb	EPROM_OE,$	
	jb	EPROM_OE, $
	
	call	@PATCH	
;x_end
        clrb	X_FLAG
	jnb	EJ_FLAG,@CDDVD_EJECTED

	jmp	IS_XCDVDMAN

;TO SLEEP ... , PERHARPS TO DREAM ...
;	mov	m, #00Ah			;set up edge register
;	mov	!rb, #%00000110			;RB3 wait for HI ( = 0 ),RB2 wait for low (=1)
SLEEP_MODE						
	mov	m, #009h			;clear all wakeup pending bits
	clr	w				;  
	mov	!rb,w				;
	mov	m, #00Bh			;enable wakeup...
	jb	PSX_FLAG,no_bios_wake
	mov	!rb, #%11110001			;... on RB3 ( EJECT ),RB2 (reset) & RB1 (bios cs) 
	sleep
no_bios_wake
	mov	!rb, #%11110011			;... on RB3 ( EJECT ),RB2 (reset) & RB1 (bios cs) 
	sleep

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
;V10               
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

	jnb	PSX_FLAG,:set_psx2
	mov	COUNT1,#11      
	mov	w,#73
	jmp	:loopxx	

:set_psx2

	cje	PS2_ID1, #'1', :set_V1
	cje	PS2_ID1, #'2', :set_V3
	cje	PS2_ID1, #'5', :set_V4
	jmp	:set_Vx				; V9/10

:set_V1
	mov	BIOS_DATA,#$C0
	jmp	:set_P
:set_V3
	mov	BIOS_DATA,#$D8
	jmp	:set_P	
:set_V4
	mov	BIOS_DATA,#$0C		
	jmp	:set_P	
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
	
	mov	w,#7		; V5678
	jmp	:loopxx
:set_V9           
	mov	w,#23
	jmp	:loopxx	
:set_V10                
	setb	V10_FLAG
	mov	w,#39
	jmp	:loopxx	
:set_V12
	setb	V12_FLAG
	setb	V10_FLAG	
	mov	w,#39
:loopxx
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
	
	jb	PSX_FLAG,@PS2_PATCH2

:loop0
	; OSDSYS Wait for 60 00 04 08 ... 
	jb	EPROM_OE, :loop0		; wait for OE = LOW
	nop
	cjne	BIOS_DATA, #060h, :loop0	; is byte1 = #060h
	jnb	EPROM_OE,$
	jb	EPROM_OE,$
	nop
;	call	wait_bios_oe_low_p1; next byte
	cjne	BIOS_DATA, #000h, :loop0	; is byte2 = #000h
	jnb	EPROM_OE,$
	jb	EPROM_OE,$
	nop
;	call	wait_bios_oe_low_p1; next byte
	cjne	BIOS_DATA, #004h, :loop0	; is byte3 = #004h
	jnb	EPROM_OE,$
	jb	EPROM_OE,$
	nop
;	call	wait_bios_oe_low_p1; next byte
	cjne	BIOS_DATA, #008h, :loop0	; is byte4 = #008h

	jnb	IO_EJECT,:looper
	snb	L_FLAG
	sleep	

:looper

	mov	FSR,#$15
	
;-----------------------------------------------------------
; Patch data for bios OSDSYS 
;-----------------------------------------------------------
	
BIOS_OSDSYS
:loop1
	jb	EPROM_OE, $; next byte(OE low..)
;	nop
	cjne	BIOS_DATA, #007h, :loop1	; is byte1 = #006h



:loop66	jb	EPROM_OE, $		; next byte / wait for bios OE low
	nop
	cjne	BIOS_DATA, #003h, :loop66; is byte1 = #0E0h
	jnb	EPROM_OE, $
	jb	EPROM_OE, $
	cjne	BIOS_DATA, #024h, :loop66; is byte2 = #003h
	jnb	EPROM_OE, $
	mov	!BIOS_DATA, w


	jb	EPROM_OE, $			; wait for bios OE low(next byte)


	call	@PATCH

	jb	V12L_FLAG,@LOGO12:back
	jb	EJ_FLAG, @TEST_RESET
	jmp	@PS2_PATCH2
	

org $400

LOAD_EXPLOID
	add	pc,w

Ex_v3 ;--------------------------
	retw	$5D	
	retw	$11	
	retw	$24	
	retw	$00	
	retw	$24	
	retw	$91	
	retw	$A4	
	retw	$6A	
	retw	$EA	
	retw	$11	
	retw	$24	
	retw	$40	
	retw	$7A	      
	retw	$91	  
	retw	$A4	
	retw	$04	
	retw	$3C	
	retw	$11	
	retw	$3C	
	retw	$29	
	retw	$00	
	retw	$31	
	retw	$36	  
	retw	$EC         
	retw	$23           
	retw	$91        
	retw	$AC
	retw	$91	
	retw	$24
	retw	$11
	retw	$3C 	   
	retw	$B8       
	retw	$5E
	retw	$31
	retw	$36
	retw	$F0
	retw	$23 	        
	retw	$91        
	retw	$AC
	retw	$29
	retw	$00
	retw	$11
	retw	$3C
	retw	$BF    
	retw	$5E     	
	retw	$20           
	retw	$A2
	
Ex_v4               ;----------------------------------
	retw	$68
	retw	$11
	retw	$24
	retw	$34
	retw	$23
	retw	$91
	retw	$A4
	retw	$6F
	retw	$E9
	retw	$11
	retw	$24
	retw	$60
	retw	$7D 
	retw	$91
	retw	$A4	
	retw	$04	
	retw	$3C	
	retw	$11	
	retw	$3C	
	retw	$29	
	retw	$00	
	retw	$31	
	retw	$36	  
	retw	$20        
	retw	$23	       
	retw	$91        
	retw	$AC
	retw	$90	
	retw	$24
	retw	$11
	retw	$3C 	   
	retw	$48        
	retw	$6A	
	retw	$31
	retw	$36
	retw	$24
	retw	$23             
	retw	$91        
	retw	$AC
	retw	$29 
	retw	$00
	retw	$11
	retw	$3C
	retw	$4F
	retw	$6A     	
	retw	$20
	retw	$A2

Ex_vx              ;------------------------------------
	retw	$70       
	retw	$11
	retw	$24
	retw	$0C
	retw	$25
	retw	$91
	retw	$A4
	retw	$F1
	retw	$E9
	retw	$11
	retw	$24
	retw	$30
	retw	$7D 
	retw	$91	  
	retw	$A4	
	retw	$04	
	retw	$3C	
	retw	$11	
	retw	$3C	
	retw	$29	
	retw	$00	
	retw	$31	
	retw	$36	  
	retw	$F8       
	retw	$24	       
	retw	$91        
	retw	$AC
	retw	$90	
	retw	$24
	retw	$11
	retw	$3C 	   	
	retw	$D8        
	retw	$71
	retw	$31
	retw	$36
	retw	$FC
	retw	$24 	        
	retw	$91        
	retw	$AC
	retw	$29 
	retw	$00
	retw	$11
	retw	$3C
	retw	$DF          
	retw	$71     	
	retw	$20
	retw	$A2

Ex_v9       
 ;------------------------------------------
	retw	$2B      
	retw	$90
	retw	$A4
	retw	$21
	retw	$00
	retw	$10
	retw	$3C
	retw	$D4
	retw	$E5
	retw	$11
	retw	$24
	retw	$04
	retw	$94 
	retw	$11	  
	retw	$A6	
	retw	$90	
	retw	$24	
	retw	$11	
	retw	$3C	
	retw	$88	
	retw	$7E	
	retw	$31	
	retw	$36	  
	retw	$5C     
	retw	$2B
	retw	$91     
	retw	$AC
	retw	$B0	
	retw	$AF
	retw	$11
	retw	$3C 	
	retw	$00     
	retw	$00
	retw	$31
	retw	$36
	retw	$60
	retw	$2B	
	retw	$91	
	retw	$AC
	retw	$2A
	retw	$00
	retw	$11
	retw	$3C	
	retw	$8F
	retw	$7E     	
	retw	$20           
	retw	$A2
	
Ex_v10 ; ----------------------------------------
	retw	$2D
	retw	$90
	retw	$A4
	retw	$21
	retw	$00
	retw	$10
	retw	$3C
	retw	$D8
	retw	$E3
	retw	$11
	retw	$24
	retw	$64
	retw	$9E
	retw	$11	 
	retw	$A6
	retw	$90
	retw	$24
	retw	$11
	retw	$3C
	retw	$F8
	retw	$C1
	retw	$31
	retw	$36	 
	retw	$CC
	retw	$2D
	retw	$91
	retw	$AC
	retw	$B0
	retw	$AF
	retw	$11
	retw	$3C
	retw	$00
	retw	$00
	retw	$31
	retw	$36	 
	retw	$D0
	retw	$2D
	retw	$91
	retw	$AC
	retw	$2B
	retw	$00
	retw	$11
	retw	$3C
	retw	$FF
	retw	$C1
	retw	$20
	retw	$A2

wait_bios_oe_low_p4
	jb	EPROM_OE,$
IFDEF	MODE54	
	nop	
ENDIF	
	ret

EXPLOIT
                    
	setb	EJ_FLAG
;	setb	L_FLAG
	mov	COUNT1,#47
	mov	COUNT2,w	

	cje	PS2_ID1, #'2', :e3
	cje	PS2_ID1, #'5', :e4
	cje	PS2_ID1, #'6', :ex
	cje	PS2_ID1, #'7', :e9
	cje	PS2_ID1, #'9', :e10
	

:e1		
	mov	BIOS_DATA,#$B8
	clr	w	
	jmp	:loopxx1

:e3	
	mov	BIOS_DATA,#$38
 	clr	w
	jmp	:loopxx	               

:e4	
	mov	BIOS_DATA,#$B8
	mov	w,#47
	jmp	:loopxx	 	

:ex	
	mov	BIOS_DATA,#$48
	mov	w,#94
	jmp	:loopxx	               	
	                     
:e9	                     
	mov	BIOS_DATA,#$68
	mov	w,#141	
	jmp	:loopxx	               

:e10	                     
	mov	BIOS_DATA,#$D8
	mov	w,#188
	
:loopxx
	mov	COUNT3,w
	mov	FSR,#$15
:loop
	mov	w,COUNT3     
	call	LOAD_EXPLOID
	mov	INDF,w
	inc	FSR     
	or	FSR,#%00010000
	inc	COUNT3	
	djnz	COUNT1,:loop


	jmp	@PS2_PATCH:loop0

:loopxx1
	mov	COUNT3,w
	mov	FSR,#$15
:loop1
	mov	w,COUNT3     
	call	@LOAD_EXPLOID_v1
	mov	INDF,w
	inc	FSR     
	or	FSR,#%00010000
	inc	COUNT3	
	djnz	COUNT1,:loop1


	jmp	@PS2_PATCH:loop0

PSX1DRV

V7DRV
	mov	BIOS_DATA,#$3C
	mov	FSR,#$15
	mov	COUNT2,#11
	
;10 01 00 43 30
psx1drv_l0
	jb	EPROM_OE,$	
;	nop
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
	cjne	BIOS_DATA, #$30,psx1drv_l0a		; 3C C7 34 19 19 E2 B2 19 E2 BA

	jnb	EPROM_OE, $	

	mov	!BIOS_DATA, w

	jb	EPROM_OE, $			; wait for bios OE low(next byte)

	call	@PATCH

	djnz	COUNT4,V7DRV	
	clr	FSR

LOGO
	mov	COUNT1,#52			;byte to skip
	mov	COUNT3,#24
	mov	COUNT4,w	

logo_l1						;match FDFF8514
	jb	EPROM_OE,$	
	;nop
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

	jmp	@psx_not_ejected


org $600

wait_bios_oe_low_p3
	jb	EPROM_OE,$
IFDEF	MODE54	
	nop
ENDIF
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

	retw	$08	; 27 ; 1C
	retw	$11
	retw	$3C
	retw	$C1
	retw	$00
	retw	$31
	retw	$36
	retw	$84
	retw	$16
	retw	$91
	retw	$AC	

	retw	$0C		
	retw	$00
	retw	$00
	retw	$00

PS2_LOGO	
	retw	$21	;23  ; 3B ; 36 ; 3B
	retw	$08	;24	;37  ; 3C
	retw	$02
	retw	$00
	retw	$01
	retw	$00
	retw	$C6
	retw	$24
	
	mov	COUNT3,#41
	jb	V10_FLAG,LOADV10A
	mov	COUNT3,#36	

	retw	$D0		;37
	retw	$80

	mov	COUNT3,#43
	jmp	LLOADC

LOADV10A	
	retw	$50		;42
	retw	$81

LLOADC
	retw	$83		;44
	retw	$8F
	retw	$26
	retw	$10
	retw	$41
	retw	$00
	retw	$00
	retw	$18
	retw	$C4
	retw	$2C
	retw	$00
	retw	$00
	retw	$A2
	retw	$AC
	retw	$04
	retw	$00
	retw	$A5
	retw	$24
	retw	$F9
	retw	$FF
	retw	$80
	retw	$54
	retw	$00
	retw	$00
	retw	$A2
	retw	$8C
	retw	$2F
	retw	$01
	retw	$22	
	retw	$92
	retw	$1A
	retw	$00
	retw	$42
	retw	$38
	retw	$01
	retw	$00
	retw	$47	
	retw	$2C

	mov	COUNT3,#92
	jb	V10_FLAG,LOADV10B
	mov	COUNT3,#87
		
	retw	$CC	;88
	retw	$80

	mov	COUNT3,#94
	jmp	LLOADEND

LOADV10B

	retw	$4C	;93
	retw	$81

LLOADEND
	retw	$87	;95
	retw	$AF
	
V12END
	retw	$AE	
	retw	$05
	retw	$04		
	retw	$08
	
XMAN
	mov	COUNT1,#78
	mov	COUNT2,w
        clr	w
        jmp	PS2_PS2LOGO:loopa	

PS2_PS2LOGO	

        clr	w
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

;	mode	#$0F
	clr	FSR

	jb	X_FLAG,@XCDVDMAN
:loopz
	mov	COUNT2,#71	
	jb	V12_FLAG,@LOGO12
	mov	COUNT2,#51

;	jmp	@PATCHLOGO2

PATCHLOGO2
	mov	COUNT2,#51

:loop00
;V10 logo patch only 
	jb	EPROM_OE, $			; wait for OE = LOW
	nop
	cjne	BIOS_DATA, #066h, :loop00	; is byte1 = #0AFh
	jnb	EPROM_OE,$
	jb	EPROM_OE,$		
	cjne	BIOS_DATA, #01Eh, :loop00	; is byte1 = #006h
	jnb	EPROM_OE,$
	jb	EPROM_OE,$		
	cjne	BIOS_DATA, #042h, :loop00	; is byte3 = #008h
	jmp	:patchl	

:patchl

	mov	FSR,#$3C
	mov	BIOS_DATA, #$21
	
:loop1			
	jb	EPROM_OE, :loop1		; wait for OE = LOW
	nop
	cjne	BIOS_DATA, #08Ch, :loop1	; is last byte = #00Ch

	jnb	EPROM_OE, $ 
	
	mov	!BIOS_DATA, #$00   
	jb	EPROM_OE, $ 	
	
	call	@PATCH

	djnz	COUNT4,PATCHLOGO2
	setb	EJ_FLAG	
	jmp	@IS_XCDVDMAN

LOGO12
	mov	FSR,#$1C	;27
	setb	V12L_FLAG
	mov	BIOS_DATA,#$40

:loop0
	jb	EPROM_OE, :loop0		; wait for OE = LOW
;	nop
	cjne	BIOS_DATA, #09Dh, :loop0	; 
	jnb	EPROM_OE,$
	jb	EPROM_OE,$	
;	nop
	cjne	BIOS_DATA, #062h, :loop0	; 
	jnb	EPROM_OE,$
	jb	EPROM_OE,$
;	nop
	cjne	BIOS_DATA, #0ACh, :loop0	; 

	jmp	@BIOS_OSDSYS	

:back	
	setb	EJ_FLAG
	jmp	@IS_XCDVDMAN

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
	
; data: 0011 1011, 1010 0000, 0011 0011, 0010 1000, 0010 0000, 1111 1111, 0000 0100, 0100 0001
;	$3B $A0 $33 $28 $20 $FF $04 $41

;E version patch
	


	retw	$44
	retw	$FD
	retw	$13
	retw	$2B
	retw	$61
	retw	$22
	retw	$13
	retw	$31							

; data : 0100 0100, 1111 1101, 0001 0011, 0010 1011 , 0110 0001 ,0010 0010, 0001 0011 ,0011 0001
;	$44 $FD $13 $2B $61 $22 $13 $31
	
;I version patch 



	retw	$8C
	retw	$B0
	retw	$03
	retw	$3A
	retw	$31
	retw	$33
	retw	$19
	retw	$91							

; data $8C $B0 $03 $3A $31 $33 $19 $91

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

;-----------------------------------------------------------------------------------------------------
;Patch DVD
;This ruotine will authenticate DVD to PS2 and is executed a certain number ( variable ?)  of times...
;boots dvd-r , dvd-rw on V9 :)
;-----------------------------------------------------------------------------------------------------
MEDIA_PATCH
	clrb	FFCLR
	nop
	setb	FFCLR
dvd_patch1
	jb	DVD_CNT_CLK,$			;wait sync byte 01 C8 80
	clrb	FFCLR
	;nop
	mov	W,CDDVD_DATA
	setb	FFCLR
	and	w,#$B0
	mov	VAR_TEMP,w
	
	cjne 	VAR_TEMP,#$A0,dvd_patch1	;F6

media_l1	
	jb	DVD_CNT_CLK,$			;wait sync byte
	clrb	FFCLR
;	nop
	mov	W,CDDVD_DATA
	setb	FFCLR
	and	w,#$B0	
	mov	VAR_TEMP,w
		
	cje 	VAR_TEMP,#$B0,media_l2	;F6	
	cjne	VAR_TEMP,#$00,dvd_patch1	;C8 10
media_l2	
	jb	DVD_CNT_CLK,$			;wait sync byte
	clrb	FFCLR
;	nop
	mov	W,CDDVD_DATA
	setb	FFCLR     
	and	w,#$B0	
	mov	VAR_TEMP,w
		   
	cje 	VAR_TEMP,#$B0,dvd_patch3	;F6	
	cjne	VAR_TEMP,#$A0,dvd_patch1	;80	A0

	jb	L_FLAG,dvd_c		; movie sleep
	jb	PSX_FLAG,@SLEEP_MODE		; movie sleep

dvd_c
	mov	COUNT1, #16				;skip # byte
	call	CDDVDSKIP_P8

dvd_patch2
;	mov	w, #$00				;patch bus first time !			
	clr	w
	mov	CDDVD_DATA, w
	mode	#$0F	
	mov	w, #%00011110			;'0' = output !

	mov	!CDDVD_DATA, w

;	jb	DVD_CNT_CLK,$			;patch to	0F 01 0F 01 
;	clrb	FFCLR				;dvdr game  is 	0F 25 0F 25
;	nop					;dvdrom game is 02 01 02 01
;	setb	FFCLR				;only F,G bit need patch :)
;	mov	!CDDVD_DATA, w

	mov	COUNT1, #4				;skip # byte
	call	CDDVDSKIP_P8
;
;	jb	DVD_CNT_CLK,$			;dvd-rw game is 0F 32 0F 32
;	clrb	FFCLR				;dvd9 video is  02 01 02 01
;	nop
;	setb	FFCLR
;	
;	jb	DVD_CNT_CLK,$			;
;	clrb	FFCLR
;	nop
;	setb	FFCLR
;
;	jb	DVD_CNT_CLK,$			;
;	clrb	FFCLR
;	nop
;	setb	FFCLR
;
;	jb	DVD_CNT_CLK,$
	mov	!CDDVD_DATA,#$FF
;	clrb	FFCLR
;	nop
;	setb	FFCLR

dvd_patch3
;	jb	PSX_FLAG,@PSX_PATCH			;psx mode ...

CDDVD_PATCH_PS2_CD
dvd_l1
	jnb	BIOS_CS,exit_patch
	jb	DVD_CNT_CLK,dvd_l1			;wait sync byte FA FF FF ...
	clrb	FFCLR
	nop
	setb	FFCLR
	snb	RB.7
	snb	RB.4
	jmp	dvd_l1	
;	cjne	CDDVD_DATA,#$E7,dvd_l1	;FA
dvd_l2
	jnb	BIOS_CS,exit_patch
	jb	DVD_CNT_CLK,dvd_l2			;wait sync byte
	clrb	FFCLR
	nop
	setb	FFCLR
	snb	RB.7
	sb	RB.4
	jmp	dvd_l1	
;	cjne	CDDVD_DATA,#$F7,dvd_l1	;FF
dvd_l3
	jnb	BIOS_CS,exit_patch
	jb	DVD_CNT_CLK,dvd_l3			;wait sync byte
	clrb	FFCLR
	nop
	setb	FFCLR
	snb	RB.7
	sb	RB.4
	jmp	dvd_l1	
;	cjne	CDDVD_DATA,#$F7,dvd_l1	;FF
dvd_l4
	jnb	BIOS_CS,exit_patch
	jb	DVD_CNT_CLK,dvd_l4			;wait sync byte
	clrb	FFCLR
	nop
	setb	FFCLR
	sb	RB.7
	snb	RB.4
	jmp	dvd_l1	
;	cjne	CDDVD_DATA,#$07,dvd_l1	;00 	
dvd_l5
	jnb	BIOS_CS,exit_patch	
	jb	DVD_CNT_CLK,dvd_l5			;wait sync byte
	clrb	FFCLR
	nop
	setb	FFCLR
	sb	RB.7
	sb	RB.4
	jmp	dvd_l1	
;	cjne	CDDVD_DATA,#$17,dvd_l1	;01 	
dvd_l6
	jnb	BIOS_CS,exit_patch
	jb	DVD_CNT_CLK,dvd_l6			;wait sync byte
	clrb	FFCLR
	nop
	setb	FFCLR
	sb	RB.7
	sb	RB.4
	jmp	dvd_l1		
;	cjne	CDDVD_DATA,#$17,dvd_l1	;01 			
dvd_l7
	jnb	BIOS_CS,exit_patch
	jb	DVD_CNT_CLK,dvd_l7			;wait sync byte
	clrb	FFCLR
	nop
	setb	FFCLR
	sb	RB.7
	snb	RB.4
	jmp	dvd_l1
;	cjne	CDDVD_DATA,#$07,dvd_l1	;00		

	jb	L_FLAG,dvd_c1
	jb	PSX_FLAG,@PSX_PATCH			;psx mode ...
dvd_c1
	mov	w, #$90				;NEW 1 time 1 BYTE patch !!!!!!!!!
	mov	CDDVD_DATA, w
	mode	#$0F		
	mov	w, #%01101111			

	jb	DVD_CNT_CLK,$			
	clrb	FFCLR				
	nop
	setb	FFCLR
	mov	!CDDVD_DATA, w	

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
	mov	COUNT1, #$03			;skip 2 byte (FF,FF) 
wait_dvd_l0
	jb	DVD_CNT_CLK,$
	clrb	FFCLR
	nop
	setb	FFCLR	
	snb	RB.7
	snb	RB.4
	jmp	wait_dvd_l0
;	cjne	CDDVD_DATA,#$E7,wait_dvd_l0

	jb	DVD_CNT_CLK,$
	clrb	FFCLR
	nop
	setb	FFCLR	
	snb	RB.7
	sb	RB.4
	jmp	wait_dvd_l0
;	cjne	CDDVD_DATA,#$F7,wait_dvd_l0

	jb	DVD_CNT_CLK,$
	clrb	FFCLR
	nop
	setb	FFCLR	
	snb	RB.7
	sb	RB.4
	jmp	wait_dvd_l0
;	cjne	CDDVD_DATA,#$F7,wait_dvd_l0
	djnz	COUNT1,wait_dvd_l0

;	mov	COUNT1, #$06			;skip 2 byte (FF,FF) 
;	call	CDDVDSKIP_P8			;

;patch region ...
	mode	#$0F
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
	mov	w,#$FF
	jb	DVD_CNT_CLK,$			;wait for low
	mov	!CDDVD_DATA,w
	clrb	FFCLR
	nop
	setb	FFCLR	

	jb	SOFT_RST,CDDVD_PATCH_PS2_CD	;loop on patch for soft reset fix !
exit_patch
	clrb	FFCLR
	clrb	SOFT_RST			;clear soft reset bit when exit disk patch ...	

CDDVD_PATCH_DONE
	jb	EJ_FLAG,@IS_XCDVDMAN		;routine was called from eject...no logo patch required...

	jmp	@PS2_PS2LOGO:loopz



org $7FF							
	jmp	INIT_CHIP			;reset vector

END