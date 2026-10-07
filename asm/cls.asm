; CLEAR.ASM
; SC126 / RomWBW / ZSDOS
; Clears an ANSI/VT100-style terminal screen and returns to CP/M.
;
; Uses CP/M BDOS function 9 (print $-terminated string).

BDOS        EQU 05H        ; CP/M BDOS entry point
BDOSPRINT  EQU 9            ; Function 9: print string at DE, '$'-terminated

        ORG 100H             ; CP/M .COM entry point

START:
        MVI C,BDOSPRINT
        LXI D,ESCCLS        ; point to escape sequence string
        CALL BDOS            ; print it
        RET                  ; back to C>

; ESC[2J   = clear entire screen
; ESC[H    = cursor home (row 1,col 1)

ESCCLS:  DB 1BH,'[2J'       ; ESC[2J
          DB 1BH,'[H'        ; ESC[H
          DB '$'             ; end of BDOS-9 string

        END START
