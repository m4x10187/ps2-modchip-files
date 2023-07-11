
; this file is used by both sasm and r5900  :-)


; used by PS2_BIOS
BIOS_JAP	EQU 0x01
BIOS_V1		EQU 0x02
BIOS_V3		EQU 0x04
BIOS_V4		EQU 0x08
BIOS_XX		EQU 0x10

; Uncomment your ps2
PS2_BIOS EQU    0xFF		; Ps2 v1-v8(if get error pick your ps2 only!!)
;PS2_BIOS EQU BIOS_JAP		; TODO: JAP 10000/15000
;PS2_BIOS EQU BIOS_V1		; v1(chip 010), v2?
;PS2_BIOS EQU BIOS_V3		; v2?, v3(chip 020)
;PS2_BIOS EQU BIOS_V4		; v4(chip 030)
;PS2_BIOS EQU BIOS_XX		; v5(chip 040, 050), v6(chip 060), v7(chip 070, 080), v8(chip 090)

KILL_LOGO		EQU 1	; Uncomment to kill logo...
POWER_DOWN		EQU 1	; Uncomment 1/2 sleep(USE PLZ AND NOT FULL_SLEEP or DVD_FIX)

;NO_BUS			EQU 1	; Uncomment for scex only(no dvd/cd D,C,B,I,H,G,W).. NOT!
;MODE54	EQU 1			; 54M clock

; TODO!!!!!!!!!!!!!
;BOOT_MENU		EQU 1	; TODO boot menu(from Memory Card).............
;VMODEFIX		EQU 1	; TODO ...  auto NTSC2PAL/PAL2NTSC
;REGION_FREE		EQU 1	; TODO/REMOVED i have no dvd to test with :( ...
;DEMARCO_VISION		EQU 1	; TODO ... 50:50 can b done with software only



