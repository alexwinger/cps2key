;   pin configuration: (cartridge pin) [key CIC pin]
;
;                       ,---_---.
;                   +5V |1     8| GND
;                  data |2     7| nReset
;                   GP4 |3     6| clock
;                   GP3 |4     5| setup
;                       `-------'
;
;

processor 12F675
#include <xc.inc>
      
; CONFIG
  CONFIG  FOSC = INTRCIO        ; Oscillator Selection bits (INTOSC oscillator: I/O function on GP4/OSC2/CLKOUT pin, I/O function on GP5/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled)
  CONFIG  PWRTE = OFF           ; Power-Up Timer Enable bit (PWRT disabled)
  CONFIG  MCLRE = OFF           ; GP3/MCLR pin function select (GP3/MCLR pin function is digital I/O, MCLR internally tied to VDD)
  CONFIG  BOREN = ON            ; Brown-out Detect Enable bit (BOD enabled)
  CONFIG  CP = OFF              ; Code Protection bit (Program Memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  

resetPin equ 0
clockPin equ 1
setupPin equ 2
dataPin  equ 5

_delay0 equ 0x20
_delay1 equ 0x21
key_byte_index equ 0x22
bit_counter    equ 0x23
rotation_register equ 0x24

; Program
PSECT code,abs
 
;   Org 0x0000
;   Reset-Vector
start:
    CALL prepare_outputs
    CALL program_cps2
    CALL release_pins
    GOTO loop

table_read:
    ADDWF PCL,F          ; !!Program-Counter-Modification
key_table:
    RETLW 0x0F
    RETLW 0x00
    RETLW 0x02
    RETLW 0x40
    RETLW 0x00
    RETLW 0x08
    RETLW 0x04
    RETLW 0xC3
    RETLW 0x39
    RETLW 0xC4
    RETLW 0x22
    RETLW 0x26
    RETLW 0xC8
    RETLW 0xD1
    RETLW 0x40
    RETLW 0x14
    RETLW 0x44
    RETLW 0xC2
    RETLW 0x8A
    RETLW 0x64

;Prepare Outputs
prepare_outputs:
    BSF STATUS,STATUS_RP0_POSITION
        BCF TRISIO,dataPin
	BCF TRISIO,setupPin
	BCF ANSEL,setupPin      ;Disable ADC function
	BCF TRISIO,clockPin
	BCF ANSEL,clockPin      ;Disable ADC function
	BCF TRISIO,resetPin
	BCF ANSEL,resetPin      ;Disable ADC function

    BCF STATUS,STATUS_RP0_POSITION       ;
	BCF GPIO,setupPin           ;GPIO2 = 0
	BCF GPIO,clockPin           ;GPIO1 = 0
	BCF GPIO,dataPin            ;GPIO5 = 0
	BSF GPIO,resetPin           ;GPIO0 = 1
RETURN
    
release_pins:
    BSF STATUS,STATUS_RP0_POSITION
	BSF TRISIO,dataPin
	BSF TRISIO,setupPin
	BSF TRISIO,clockPin
	BSF TRISIO,resetPin
    BCF STATUS,STATUS_RP0_POSITION
RETURN

clk:
    BSF GPIO,clockPin
    
    MOVLW 0x03
    MOVWF _delay1
    MOVLW 0x97
    MOVWF _delay0
    CALL delay
    
    BCF GPIO,clockPin
    
    MOVLW 0x03
    MOVWF _delay1
    MOVLW 0x97
    MOVWF _delay0
    CALL delay
RETURN

program_unlock:
    BSF GPIO,setupPin
    BCF GPIO,resetPin
    
    MOVLW 0x0B           ;   b'00001011'  d'011'
    MOVWF _delay1
    MOVLW 0x62           ;   b'01100010'  d'098'  "b"
    MOVWF _delay0
    CALL delay
    
    MOVLW 0x03           ;   b'00000011'  d'003'
    MOVWF _delay1
    MOVLW 0x97           ;   b'10010111'  d'151'
    MOVWF _delay0
    CALL delay
    
    
    MOVLW 0x03           ;   b'00000011'  d'003'
    MOVWF _delay1
    MOVLW 0x97           ;   b'10010111'  d'151'
    MOVWF _delay0
    CALL delay
    
    MOVLW 0x03           ;   b'00000011'  d'003'    
    MOVWF _delay1
    MOVLW 0x97           ;   b'10010111'  d'151'
    MOVWF _delay0
    CALL delay
RETURN

program_cps2:    
    CALL program_unlock

;Send Key
    
    CLRF key_byte_index
read_key_byte:
    
    ;Read byte from KEY
    MOVLW HIGH key_table
    MOVWF PCLATH
    MOVF key_byte_index,W
    CALL table_read
    
    ;Send byte
    CALL send_byte
    
    INCF key_byte_index,W
    MOVWF key_byte_index
    XORLW 21 ;If index == 21 Key ended
    BTFSS STATUS, STATUS_Z_POSITION
    GOTO read_key_byte
    
    CALL end_cps2_programming
    RETURN
    
;W contains the byte to be sent
send_byte:
    MOVWF rotation_register
    MOVLW 8
    MOVWF bit_counter
    
    rotate_bit:
	RLF rotation_register,F
	CALL set_data_pin
	CALL clk
	
    DECFSZ bit_counter,F
    GOTO rotate_bit
    RETURN
    


set_data_pin:
    BTFSC STATUS, STATUS_C_POSITION
    GOTO _set_pin
    BCF GPIO,dataPin
    RETURN
    _set_pin:
    BSF GPIO,dataPin    
    RETURN

end_cps2_programming:
    BCF GPIO,setupPin
    BSF GPIO,resetPin
    
    MOVLW 0x03           ;   b'00000011'  d'003'
    MOVWF _delay1
    MOVLW 0x97           ;   b'10010111'  d'151'
    MOVWF _delay0
    CALL delay
    
    BCF GPIO,clockPin
    BCF GPIO,dataPin
    RETURN

delay:
    DECFSZ _delay0,F
    GOTO delay
    DECFSZ _delay1,F
    GOTO delay
    RETURN    
    
loop:
    GOTO loop

End start



