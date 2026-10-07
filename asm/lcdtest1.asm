; ============================================================
;  SC126 + SC719 (I/O) @ port 00H  + LCD1602 (HD44780)
;  PURE 8080/8085 CP/M .COM program  (ORG 0100H)
;  SELF-RELIANT: no BIOS calls, no monitor services.
;
;  SCC wiring (from their LCD example):
;    SC719 port bits -> LCD:
;      bit2 = RS
;      bit3 = E
;      bit4..bit7 = D4..D7
;    R/W tied to GND
;
;  Run under CP/M:  A>HELLO
;  (will hang at end so you can see display)
; URL: https://smallcomputercentral.com/examples/example-alphanumeric-lcd/
; ============================================================

        ORG     0100H

BDOS	EQU	5H
PORTLCD        EQU     00H

START:
        ; Safe stack for pushes/pops
        LXI     SP,0FFFEH

        ; LCD power-up wait
        CALL    DELAY60MS

        ; Initialize LCD to 4-bit mode
        CALL    LCDINIT4BIT

        ; Line 1 @ 0
        MVI     A,00H
        CALL    LCDSETDDRAM
        LXI     H,MSG1
        CALL    LCDPUTSHL

        ; Line 2 @ 0 (DDRAM 0x40)
        MVI     A,40H
        CALL    LCDSETDDRAM
        LXI     H,MSG2
        CALL    LCDPUTSHL

;HANG:   JMP     HANG
 	MVI	C,0
	CALL	BDOS
	RET
; -------------------------
; Messages (00-terminated)
; -------------------------
MSG1:   DB  'H','e','l','l','o',' ','W','o','r','l','d','!',00H
MSG2:   DB  'U','s','i','n','g',' ','S','C','1','0','8',00H


; ============================================================
; LCD primitives (4-bit mode)
; ============================================================

; Pulse E using A containing:
;  - nibble in bits 7..4
;  - RS optionally in bit2
LCDPULSEE:
        ; output stable
        OUT     PORTLCD
        CALL    DELAYTINY

        ; E=1
        ORI     08H
        OUT     PORTLCD
        CALL    DELAYTINY

        ; E=0
        ANI     0F7H
        OUT     PORTLCD
        CALL    DELAYTINY
        RET

; Write nibble as command (RS=0)
; Input: A has nibble in bits 7..4
LCDNIBCMD:
        ANI     0F0H
        CALL    LCDPULSEE
        RET

; Write nibble as data (RS=1)
LCDNIBDATA:
        ANI     0F0H
        ORI     04H
        CALL    LCDPULSEE
        RET

; Write full byte as command
; Input: A = byte
LCDBYTECMD:
        PUSH    PSW

        ; high nibble
        ANI     0F0H
        CALL    LCDNIBCMD

        POP     PSW
        PUSH    PSW

        ; low nibble -> rotate into high nibble
        RAL
        RAL
        RAL
        RAL
        ANI     0F0H
        CALL    LCDNIBCMD

        POP     PSW

        ; standard command delay
        CALL    DELAY2MS
        RET

; Write full byte as data
; Input: A = byte
LCDBYTEDATA:
        PUSH    PSW

        ; high nibble
        ANI     0F0H
        CALL    LCDNIBDATA

        POP     PSW
        PUSH    PSW

        ; low nibble
        RAL
        RAL
        RAL
        RAL
        ANI     0F0H
        CALL    LCDNIBDATA

        POP     PSW

        ; data write delay
        CALL    DELAY2MS
        RET


; ============================================================
; LCD higher-level helpers
; ============================================================

; Set DDRAM address: command = 0x80 | addr
; Input: A = addr (00 for line1, 40 for line2)
LCDSETDDRAM:
        ORI     080H
        CALL    LCDBYTECMD
        RET

; Print 00-terminated string at HL
LCDPUTSHL:
P1:     MOV     A,M
        ORA     A
        RZ
        CALL    LCDBYTEDATA
        INX     H
        JMP     P1


; ============================================================
; LCD initialization (robust HD44780 sequence)
; ============================================================
LCDINIT4BIT:
        ; force outputs low
        XRA     A
        OUT     PORTLCD

        ; Wait >15ms after Vcc
        CALL    DELAY20MS

        ; Send 0x30 three times as high nibble (still in 8-bit mode)
        MVI     A,030H
        CALL    LCDNIBCMD
        CALL    DELAY10MS

        MVI     A,030H
        CALL    LCDNIBCMD
        CALL    DELAY10MS

        MVI     A,030H
        CALL    LCDNIBCMD
        CALL    DELAY10MS

        ; Set 4-bit mode: 0x20 high nibble
        MVI     A,020H
        CALL    LCDNIBCMD
        CALL    DELAY10MS

        ; Now in 4-bit mode:
        ; Function set: 0x28 (4-bit, 2-line, 5x8)
        MVI     A,028H
        CALL    LCDBYTECMD

        ; Display off: 0x08 (safe while clearing)
        MVI     A,008H
        CALL    LCDBYTECMD

        ; Clear display: 0x01 (needs long delay)
        MVI     A,001H
        CALL    LCDBYTECMD
        CALL    DELAY60MS

        ; Entry mode: 0x06 (increment, no shift)
        MVI     A,006H
        CALL    LCDBYTECMD

        ; Display on: 0x0C
        MVI     A,00CH
        CALL    LCDBYTECMD

        RET


; ============================================================
; Delays (pure busy loops, conservative)
; These don need to be exact ?just g enough?
; ============================================================

; very short (E pulse shaping)
DELAYTINY:
        PUSH    B
        MVI     B,12H
DT1:    DCR     B
        JNZ     DT1
        POP     B
        RET

; ~2ms-ish
DELAY2MS:
        PUSH    B
        PUSH    D
        MVI     B,08H
D2A:    MVI     D,0FFH
D2B:    DCR     D
        JNZ     D2B
        DCR     B
        JNZ     D2A
        POP     D
        POP     B
        RET

DELAY10MS:
        PUSH    B
        MVI     B,05H
D10:    CALL    DELAY2MS
        DCR     B
        JNZ     D10
        POP     B
        RET

DELAY20MS:
        PUSH    B
        MVI     B,0AH
D20:    CALL    DELAY2MS
        DCR     B
        JNZ     D20
        POP     B
        RET

DELAY60MS:
        PUSH    B
        MVI     B,1EH
D60:    CALL    DELAY2MS
        DCR     B
        JNZ     D60
        POP     B
        RET

        END
