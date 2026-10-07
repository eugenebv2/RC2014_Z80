; RC2014 Z80 CTC Example
; Channel 0: Timer mode, periodic interrupts
; Assembled with z80asm or similar assembler
	.Z80
CTCPORT	88H
LEDPORT 00H

  	ORG 0100H
; -------------------------
; Z80 Mode 2 Interrupt Setup
; -------------------------
        di                  ; Disable interrupts during setup
        ld a, 02h         ; Set CPU to interrupt mode 2
        im 2

; Set up interrupt vector table at 0x8000
        ld hl, 8000h
        ld de, isrvector
        ld bc, 256
        ldir                ; Fill vector table with ISR address

; -------------------------
; Configure CTC Channel 0
; -------------------------
; CTC base address depends on RC2014 configuration
; Assume channel 0 control register at I/O port 0x80

        ld a, %01000111     ; Control word:
                            ; Bit 7: Reset
                            ; Bit 6: Timer mode (1)
                            ; Bit 5: Trigger on software load (0)
                            ; Bit 4: Prescale 256 (1)
                            ; Bit 3: Interrupt enable (1)
                            ; Bits 2-0: Channel number (0)
        out (CTCPORT), a       ; Write control word

        ld a, 100           ; Time constant (TC)
                            ; Adjust for desired frequency
        out (CTCPORT), a       ; Load TC into channel 0

        ei                  ; Enable interrupts

; -------------------------
; Main Loop
; -------------------------
mainloop:
        halt                ; Wait for interrupt
        jr mainloop

; -------------------------
; Interrupt Service Routine
; -------------------------
isrvector:
        .word isrhandler   ; All entries point to ISR

isrhandler:
        push af
        push bc
        push de
        push hl

        ; Example: Toggle bit on PIO or output port
        ld a, 0xFF
        out (LEDPORT), a       ; Example port write

        pop hl
        pop de
        pop bc
        pop af
        ei                  ; Re-enable interrupts
        reti                ; Return from interrupt

