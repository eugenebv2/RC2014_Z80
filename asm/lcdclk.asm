;===============================================================================
;  SC719_LCD_RTC_Clock.asm
;
;  A tiny real-time clock display for RomWBW / HBIOS systems using an SC719
;  HD44780-compatible 16x2 LCD interface in 4-bit mode.
;
;  Displays:
;    Line 1 (centered):  HH:MM:SS   (colons ALWAYS ON)
;    Line 2 (centered):  20YY-MM-DD
;
;  Hardware assumptions (SC719 style LCD port):
;    PORT_LCD (default 00h) is the LCD control/data latch.
;      bit2 = RS  (0=command, 1=data)
;      bit3 = E   (enable pulse)
;      bit4-7 = D4-D7 (4-bit data bus)
;      R/W is tied low (write-only)
;
;  Software assumptions (RomWBW HBIOS):
;    RTCGETTIM is called via:
;      B  = 20h
;      HL = buffer (6 bytes)
;      RST 1
;
;    Buffer returns (BCD):
;      [0]=YY  [1]=MM  [2]=DD  [3]=HH  [4]=MM  [5]=SS
;
;  Assemble to a .COM style program (ORG 0100h), then run.
;
;  Notes:
;    - Delay loops are "crude" and depend on CPU speed. If LCD init is flaky,
;      increase delays.
;    - We only refresh the LCD when seconds change (less flicker, less bus spam).
;
;  URL: https://smallcomputercentral.com/examples/example-alphanumeric-lcd/
;===============================================================================

            ORG     0100H
            JMP     START

;---------------------- CONFIG -------------------------------------------------
PORTLCD    EQU     00H            ; SC719 base address (JP1 = 00h)

; Centered positions on 16x2:
;   "HH:MM:SS" = 8 chars, centered => column 4 (0-based) on line 1
;   "20YY-MM-DD" = 10 chars, centered => column 3 on line 2
;
; HD44780 DDRAM:
;   line1 starts at 00h
;   line2 starts at 40h
TIMEPOS    EQU     04H            ; line1 col4
DATEPOS    EQU     43H            ; line2 col3 (40h + 03h)

;===============================================================================
START:
            DI
            LXI     SP,STACKEND

            ; Initialize variables
            MVI     A,0FFH
            STA     PREVSEC       ; previous seconds (init to impossible value)

            ; LCD initialization sequence
            CALL    DELAY60MS     ; give LCD power-up time
            CALL    LCDINIT4BIT  ; put LCD in 4-bit mode, clear, etc.
            CALL    LCDCLEAR

MAIN:
            ; Read RTC into TIMBUF (BCD)
            CALL    READRTC

            ; Only update if seconds changed
            LDA     TIMBUF+5       ; SS
            MOV     D,A
            LDA     PREVSEC
            CMP     D
            JZ      IDLE

            MOV     A,D
            STA     PREVSEC

            ; Build strings for display
            CALL    BUILDTIME
            CALL    BUILDDATE

            ; Write time string (8 chars)
            MVI     A,TIMEPOS
            CALL    LCDSETDDRAM
            LXI     H,TIMESTR
            MVI     B,08H
            CALL    LCDPUTN

            ; Write date string (10 chars)
            MVI     A,DATEPOS
            CALL    LCDSETDDRAM
            LXI     H,DATESTR
            MVI     B,0AH
            CALL    LCDPUTN

IDLE:
            ; Small idle delay to avoid hammering RTC/HBIOS
            CALL    SHORTDLY
            JMP     MAIN

;===============================================================================
; READRTC
;   RomWBW HBIOS RTCGETTIM
;     B = 20h
;     HL = TIMBUF
;     RST 1
;   Returns YY,MM,DD,HH,MM,SS in BCD into TIMBUF[0..5].
;===============================================================================
READRTC:
            LXI     H,TIMBUF
            MVI     B,020H
            RST     1
            RET

;===============================================================================
; BUILD_TIME
;   Creates TIME_STR = "HH:MM:SS"
;   Colons are ALWAYS ON (no blinking).
;===============================================================================
BUILDTIME:
            ; HH
            LDA     TIMBUF+3
            CALL    BCD2ASC
            MOV     A,H
            STA     TIMESTR+0
            MOV     A,L
            STA     TIMESTR+1

            ; First colon ALWAYS ':'
            MVI     A,':'
            STA     TIMESTR+2

            ; MM
            LDA     TIMBUF+4
            CALL    BCD2ASC
            MOV     A,H
            STA     TIMESTR+3
            MOV     A,L
            STA     TIMESTR+4

            ; Second colon ALWAYS ':'
            MVI     A,':'
            STA     TIMESTR+5

            ; SS
            LDA     TIMBUF+5
            CALL    BCD2ASC
            MOV     A,H
            STA     TIMESTR+6
            MOV     A,L
            STA     TIMESTR+7
            RET

;===============================================================================
; BUILD_DATE
;   Creates DATE_STR = "20YY-MM-DD"
;===============================================================================
BUILDDATE:
            MVI     A,'2'
            STA     DATESTR+0
            MVI     A,'0'
            STA     DATESTR+1

            ; YY
            LDA     TIMBUF+0
            CALL    BCD2ASC
            MOV     A,H
            STA     DATESTR+2
            MOV     A,L
            STA     DATESTR+3

            MVI     A,'-'
            STA     DATESTR+4

            ; MM
            LDA     TIMBUF+1
            CALL    BCD2ASC
            MOV     A,H
            STA     DATESTR+5
            MOV     A,L
            STA     DATESTR+6

            MVI     A,'-'
            STA     DATESTR+7

            ; DD
            LDA     TIMBUF+2
            CALL    BCD2ASC
            MOV     A,H
            STA     DATESTR+8
            MOV     A,L
            STA     DATESTR+9
            RET

;===============================================================================
; BCD2ASC
;   Input:  A = packed BCD (e.g., 0x25 = "25")
;   Output: H = ASCII tens, L = ASCII ones
;===============================================================================
BCD2ASC:
            MOV     D,A
            ANI     00FH           ; low nibble = ones
            ADI     '0'
            MOV     L,A

            MOV     A,D
            ANI     0F0H           ; high nibble = tens
            RRC
            RRC
            RRC
            RRC
            ADI     '0'
            MOV     H,A
            RET

;===============================================================================
; LCD_PUTN
;   Print B bytes from [HL] as LCD data bytes.
;===============================================================================
LCDPUTN:
            MOV     A,B
            ORA     A
            RZ
LP1:        MOV     A,M
            CALL    LCDBYTEDATA
            INX     H
            DCR     B
            JNZ     LP1
            RET

;===============================================================================
; LCD 4-bit low-level routines (SC719 mapping)
;   bit2=RS, bit3=E, bits4-7=D4-D7
;===============================================================================

; Pulse the Enable line (E) to latch current nibble into LCD
LCDPULSEE:
            OUT     PORTLCD
            CALL    DELAYTINY
            ORI     08H            ; E=1
            OUT     PORTLCD
            CALL    DELAYTINY
            ANI     0F7H           ; E=0
            OUT     PORTLCD
            CALL    DELAYTINY
            RET

; Send an upper nibble as a command (RS=0)
LCDNIBCMD:
            ANI     0F0H           ; keep D4-D7, clear RS/E
            CALL    LCDPULSEE
            RET

; Send an upper nibble as data (RS=1)
LCDNIBDATA:
            ANI     0F0H
            ORI     04H            ; RS=1
            CALL    LCDPULSEE
            RET

; Send a full 8-bit command in two nibbles
LCDBYTECMD:
            PUSH    D
            MOV     D,A

            ANI     0F0H
            CALL    LCDNIBCMD

            MOV     A,D
            ANI     00FH           ; move low nibble into high nibble
            RLC
            RLC
            RLC
            RLC
            ANI     0F0H
            CALL    LCDNIBCMD

            POP     D
            CALL    DELAY2MS      ; safe wait for most commands
            RET

; Send a full 8-bit data byte in two nibbles
LCDBYTEDATA:
            PUSH    D
            MOV     D,A

            ANI     0F0H
            CALL    LCDNIBDATA

            MOV     A,D
            ANI     00FH
            RLC
            RLC
            RLC
            RLC
            ANI     0F0H
            CALL    LCDNIBDATA

            POP     D
            CALL    DELAY2MS
            RET

; Set LCD cursor via DDRAM address (A = address)
LCDSETDDRAM:
            ORI     080H
            CALL    LCDBYTECMD
            RET

; Clear LCD display
LCDCLEAR:
            MVI     A,001H
            CALL    LCDBYTECMD
            CALL    DELAY60MS     ; clear needs longer delay
            RET

; Put LCD into 4-bit mode and configure 2-line display
LCDINIT4BIT:
            XRA     A
            OUT     PORTLCD
            CALL    DELAY20MS

            ; HD44780 8-bit wake-up sequence:
            ; send high nibble 0x3 three times (still in unknown state)
            MVI     A,030H
            CALL    LCDNIBCMD
            CALL    DELAY10MS
            MVI     A,030H
            CALL    LCDNIBCMD
            CALL    DELAY10MS
            MVI     A,030H
            CALL    LCDNIBCMD
            CALL    DELAY10MS

            ; switch to 4-bit mode (send high nibble 0x2)
            MVI     A,020H
            CALL    LCDNIBCMD
            CALL    DELAY10MS

            ; function set: 4-bit, 2 lines, 5x8 font
            MVI     A,028H
            CALL    LCDBYTECMD

            ; display off
            MVI     A,008H
            CALL    LCDBYTECMD

            ; clear
            MVI     A,001H
            CALL    LCDBYTECMD
            CALL    DELAY60MS

            ; entry mode: increment, no shift
            MVI     A,006H
            CALL    LCDBYTECMD

            ; display on, cursor off, blink off
            MVI     A,00CH
            CALL    LCDBYTECMD
            RET

;===============================================================================
; Crude delay loops (tweak if needed for your CPU speed)
;===============================================================================
DELAYTINY:
            PUSH    B
            MVI     B,12H
DT1:        DCR     B
            JNZ     DT1
            POP     B
            RET

DELAY2MS:
            PUSH    B
            PUSH    D
            MVI     B,08H
D2A:        MVI     D,0FFH
D2B:        DCR     D
            JNZ     D2B
            DCR     B
            JNZ     D2A
            POP     D
            POP     B
            RET

DELAY10MS:
            PUSH    B
            MVI     B,05H
D10:        CALL    DELAY2MS
            DCR     B
            JNZ     D10
            POP     B
            RET

DELAY20MS:
            PUSH    B
            MVI     B,0AH
D20:        CALL    DELAY2MS
            DCR     B
            JNZ     D20
            POP     B
            RET

DELAY60MS:
            PUSH    B
            MVI     B,1EH
D60:        CALL    DELAY2MS
            DCR     B
            JNZ     D60
            POP     B
            RET

; Light throttle delay between polls
SHORTDLY:
            LXI     H,2000H
SD1:        DCX     H
            MOV     A,H
            ORA     L
            JNZ     SD1
            RET

;===============================================================================
; Data + stack
;===============================================================================
TIMBUF:      DS      6              ; YY MM DD HH MM SS (BCD)
TIMESTR:    DS      8              ; "HH:MM:SS"
DATESTR:    DS      10             ; "20YY-MM-DD"
PREVSEC:    DB      00H            ; previous seconds (BCD)

STACK:       DS      80
STACKEND:

            END     START

