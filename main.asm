list p=12f675
include <p12f675.inc>
errorlevel -302
   
__CONFIG   _CP_ON & _CPD_OFF & _BODEN_ON & _MCLRE_OFF & _WDT_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT
    
; Definicion de Pines del PIC12F675
; 1. Vcc=5Vdc, salida de la fuente AC
; 2. GP5, 
; 3. GP4, salida digital GP4salidaPIN3   
; * GP1 -> salida al LED de resultado.
; * GP2 -> salida al LED de modo de entrada. LOW=operando 1 HIGH=OPERANDO2
; * GP0 -> entrada de operando / reset
; * GP3 -> entrada de control de operando. LOW= ingresar OPERANDO1, HIGH= ingresar OPERANDO2
; 8. VSS=GND
    
;***DEFINICION VARIABLES
BOTON_ENTRADA		EQU	    3		;bit de GPIO para el botón de entrada de datos
BOTON_CONTROL		EQU	    5		;bit de GPIO para el botón de control del operando
LED_RESULTADO		EQU	    0		;bit de GPIO para el LED de Resultado
__pcstackBANK0		EQU	    0x20		
FLAG_FLANCO		EQU	    0x21	;registro para detectar flanco de subida del pulso del botón
REGISTRO_CONTADOR_1	EQU	    0x22	;registro para el primer byte (menos significativo) del contador
REGISTRO_CONTADOR_2	EQU	    0x23	;registro para el segundo byte del contador
REGISTRO_CONTADOR_3	EQU	    0x24	;registro para el tercer byte del contador
REGISTRO_CONTADOR_4	EQU	    0x25	;registro para el cuarto byte (más significativo) del contador
OPERANDO1		EQU	    0x26	;registro para el OPERANDO1
OPERANDO2		EQU	    0x27	;registro para el OPERANDO2
RESULTADO		EQU	    0x28	;registro para el resultado de la division
TEMP			EQU	    0x29	;registro para una variable temporal de la operación de división
contA			EQU	    0x2A	; Contadores para retardos por software
contB		    	EQU	    0x2B
ORG     0x000           ; vector de reset
    movlw   0           ; carga W con 0
    movwf   INTCON      ; Asegura que no hay interrupciones aun
    goto    INICIO      ; salte al inicio del programa
ORG     0x004               ; vector de interrupcion (INTF)
   
INICIO
CALL fConfiguracion
CLRWDT
CALL fLeerDatos
GOTO INICIO
    
fConfiguracion
;   TRISIO = 0b111100;
    MOVLW 0x3C
    BSF STATUS,RP0  ; banco 1
    MOVWF TRISIO
    RETURN
fLeerDatos
    ;    DATO_TEMPORAL = 0;
    BCF STATUS,RP0 ; banco 0
    ;    if (BOTON_ENTRADA == 1) {
    BTFSS GPIO,BOTON_ENTRADA
    GOTO lLeerDatosBotonEntradaNoPresionado
    ;        if (FLAG_FLANCO == 0) {
    BTFSC FLAG_FLANCO,0
    GOTO lLeerDatosReturn
    ;            long REGISTRO_CONTADOR_1 = 200000 -> 0x 00 03 0D 40;
    MOVLW 0x0
    MOVWF REGISTRO_CONTADOR_4
    MOVLW 0x3
    MOVWF REGISTRO_CONTADOR_3
    MOVLW 0xD
    MOVWF REGISTRO_CONTADOR_2
    MOVLW 0x40
    MOVWF REGISTRO_CONTADOR_1
    ;            while (REGISTRO_CONTADOR_1 > 0) {                
    lLeerDatosWhile BCF STATUS,RP0	    ;banco 0
    BTFSC REGISTRO_CONTADOR_4,7
    GOTO lLeerDatosReturn   ; si el contador es negativo
    MOVF REGISTRO_CONTADOR_4,W
    BTFSS STATUS,0x2	; esto almacena 1 si el resultado de una operación es 0
    GOTO lLeerDatoDecrementarContador
    MOVF REGISTRO_CONTADOR_3,W
    BTFSS STATUS,0x2
    GOTO lLeerDatoDecrementarContador
    MOVF REGISTRO_CONTADOR_2, W
    BTFSS STATUS,0x2
    GOTO lLeerDatoDecrementarContador
    MOVLW 1
    SUBWF REGISTRO_CONTADOR_1,W	;le resta 1 a el byte menos significativo y guarda el resultado en el mismo byte
    BTFSS STATUS,0x2
    BTFSC STATUS,0x0 ; esto es 0 si no hay carry
    GOTO lLeerDatoDecrementarContador
    GOTO lLeerDatosReturn
    ;                REGISTRO_CONTADOR_1--;
    lLeerDatoDecrementarContador MOVLW 0xFF
    ADDWF REGISTRO_CONTADOR_1,1
    MOVLW 0xFF
    BTFSS STATUS,0
    ADDWF REGISTRO_CONTADOR_2,1
    MOVLW 0xFF
    BTFSS STATUS,0
    ADDWF REGISTRO_CONTADOR_3,1
    MOVLW 0xFF
    BTFSS STATUS,0
    ADDWF REGISTRO_CONTADOR_4,1
    ;                CLRWDT();
    CLRWDT
    ;                if (BOTON_ENTRADA == 0) {
    BCF STATUS,RP0
    BTFSC GPIO, 0x3
    GOTO lLeerDatosChequearContadorTerminado
    ;                    FLAG_FLANCO = 1;
    BSF FLAG_FLANCO,0
    ;                    if (BOTON_CONTROL == 0) { // ingresando OPERANDO1
    BTFSC GPIO,BOTON_CONTROL
    GOTO lLeerDatosIngresandoOperando2
    ;                        OPERANDO1 += DATO_TEMPORAL;
    MOVLW 1
    ADDWF OPERANDO1,1
    ;                    } else { // ingresando OPERANDO2
    GOTO lLeerDatosReturn
    ;                        OPERANDO2 += DATO_TEMPORAL;
    lLeerDatosIngresandoOperando2 MOVLW 1
    ADDWF OPERANDO2,1
    GOTO lLeerDatosReturn
    ;                } else if (REGISTRO_CONTADOR_1 == 0) {
    lLeerDatosChequearContadorTerminado MOVF REGISTRO_CONTADOR_4,W
    IORWF REGISTRO_CONTADOR_3,W
    IORWF REGISTRO_CONTADOR_2,W
    IORWF REGISTRO_CONTADOR_1,W
    BTFSS STATUS,2
    GOTO lLeerDatosWhile
    ;                    mostrarResultado();
    CALL fMostrarResultado
    GOTO lLeerDatosReturn
    ;        FLAG_FLANCO = 0;
    lLeerDatosBotonEntradaNoPresionado CLRF FLAG_FLANCO
    GOTO lLeerDatosReturn
    lLeerDatosReturn RETURN
fMostrarResultado
    CALL fDivisionEntera
    BCF STATUS,RP0 ; banco0
    ;    while (resultado > 0) {
    GOTO lMostrarResultadoFinLoop
    ;        CLRWDT();
    lMostrarResultadoClearWDT CLRWDT
    ;        parpadearLEDResultado();
    CALL fParpadearLEDResultado
    ;        resultado--;
    ;    }
    lMostrarResultadoFinLoop MOVLW 1
    SUBWF RESULTADO,1
    BTFSS STATUS,2 ; 1 si es 0 el resultado
    GOTO lMostrarResultadoClearWDT
    RETURN
fParpadearLEDResultado
    ;    apagar LED de resultado
    BCF STATUS,RP0 ; banco 0
    BCF GPIO,LED_RESULTADO
    ;    _delay(tiempoParpadeo);
    CALL fDelay50ms
    ;    encender LED de resultado
    BCF STATUS,RP0
    BSF GPIO,LED_RESULTADO
    ;    _delay(tiempoParpadeo);
    CALL fDelay50ms
    ;}
    RETURN
fDivisionEntera
    ;    unsigned char temp = 1;
    BCF STATUS,RP0
    CLRF RESULTADO
    CLRF TEMP
    INCF TEMP, F
    ;    if (OPERANDO2 == 0) {
    MOVF OPERANDO2,W
    BTFSC STATUS,2 ; zero-bit, 1 si es 0    
    GOTO lDivisionEnteraReturn
    GOTO lDivisionEnteraInicio
    ;    //  Se calcula cuantas posiciones enteras tendrá el resultado
    ;    while (OPERANDO2 <= OPERANDO1) {
    ;        OPERANDO2 <<= 1;
    lDivisionEnteraWhile BCF STATUS,0 ; limpiar carry
    RLF OPERANDO2,F ;rotate left f through carry
    ;        TEMP <<= 1;
    BCF STATUS,0
    RLF TEMP,F
    ;    }
    lDivisionEnteraInicio MOVF OPERANDO2,W
    SUBWF OPERANDO1,W
    BTFSC STATUS,0
    GOTO lDivisionEnteraWhile
    ;    OPERANDO2 >>= 1;
    BCF STATUS,0 ; clear el carry
    RRF OPERANDO2,F ; rotate right f throug carry
    ;    TEMP >>= 1;
    BCF STATUS,0 ; limpiar el carry
    RRF TEMP,F
    ;    while (TEMP ;= 0) {
    GOTO lDivisionEnteraFin
    ;        if (OPERANDO1 >= OPERANDO2) {
    lDivisionEnteraWhile2 MOVF OPERANDO2, W
    SUBWF OPERANDO1,W
    BTFSS STATUS,0
    GOTO lDivisionEnteraB
    ;            OPERANDO1 -= OPERANDO2;
    MOVF OPERANDO2, W
    SUBWF OPERANDO1, F
    ;            resultado |= TEMP;
    MOVF TEMP, W
    MOVWF __pcstackBANK0
    MOVF __pcstackBANK0, W
    IORWF RESULTADO, F
    ;        }
    ;        TEMP >>= 1;
    lDivisionEnteraB BCF STATUS, 0x0
    RRF TEMP, F
    ;        OPERANDO2 >>= 1;
    BCF STATUS, 0x0
    RRF OPERANDO2, F
    ;    }
    lDivisionEnteraFin MOVF TEMP, W
    BTFSS STATUS, 0x2
    GOTO lDivisionEnteraWhile2
    lDivisionEnteraReturn RETURN
;--------------------
fDelay50ms
    movlw	d'65'
    movwf	contB
    movlw	d'238'
    movwf	contA
    lLoop50ms	clrwdt ; Borra WDT
    decfsz	contA,1
    goto	lLoop50ms
    decfsz	contB,1
    goto	lLoop50ms
    nop
    retlw	0
; --------------------

END
 