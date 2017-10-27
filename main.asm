list p=12f675
include <p12f675.inc>
errorlevel -302
   
__CONFIG   _CP_ON & _CPD_OFF & _BODEN_ON & _MCLRE_OFF & _WDT_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT
    
; Definicion de Pines del PIC12F675
; 1. Vcc=5Vdc, salida de la fuente AC
; 2. GP5 -> ENTRADA BOTÓN CONTROL DE OPERANDO. LOW=OPERANDO1 (DIVIDENDO), HIGH=OPERANDO2 (DIVISOR)
; 3. GP4
; 4. GP3 -> ENRADA BOTÓN DE OPERANDO
; 5. GP2
; 6. GP1
; 7. GP0 -> SALIDA LED DE RESULTADO
; 8. VSS=GND
    
;***DEFINICION VARIABLES
BOTON_ENTRADA		EQU	    3		;bit de GPIO para el botón de entrada de datos
BOTON_CONTROL		EQU	    5		;bit de GPIO para el botón de control del operando
LED_RESULTADO		EQU	    0		;bit de GPIO para el LED de Resultado
LED_OPERANDO		EQU	    1		;bit de GPIO para el LED que indica el operando. LOW=operando1 HIGH=operando2
INICIOSTACK		EQU	    0x20		
FLAG_FLANCO		EQU	    0x21	;registro para detectar flanco de subida del pulso del botón
REGISTRO_CONTADOR_1	EQU	    0x22	;registro para el primer byte (menos significativo) del contador
REGISTRO_CONTADOR_2	EQU	    0x23	;registro para el segundo byte del contador
REGISTRO_CONTADOR_3	EQU	    0x24	;registro para el tercer byte del contador
REGISTRO_CONTADOR_4	EQU	    0x25	;registro para el cuarto byte (más significativo) del contador
OPERANDO1		EQU	    0x26	;registro para el OPERANDO1
OPERANDO2		EQU	    0x27	;registro para el OPERANDO2
RESULTADO		EQU	    0x28	;registro para el resultado de la division
TEMP			EQU	    0x29	;registro para una variable temporal de la operación de división
CONTADOR_DELAY_A	EQU	    0x2A	; Contadores para retardos por software
CONTADOR_DELAY_B	EQU	    0x2B

ORG     0x000 ; vector de reset
    movlw   0
    movwf   INTCON ; Asegura que no hay interrupciones aun
    goto    INICIO ; salte al inicio del programa
ORG     0x004 ; vector de interrupcion (INTF)

ORG     0x030
; RUTINA DE INICIO
INICIO
CALL fConfiguracion
LOOPINICIO
    CLRWDT
    CALL fLeerDatos
    GOTO LOOPINICIO

; SUBRUTINA DE CONFIGURACION
fConfiguracion
    BSF STATUS,RP0  ; banco 1
    MOVLW 0x3C ; equivale a 0b111100, GP0 y GP1 como salida el resto como entrada
    MOVWF TRISIO
    RETURN
    
; SUBRUTINA DE LEER DATOS
fLeerDatos
    BCF STATUS,RP0 ; banco 0
    
    BTFSS GPIO,BOTON_CONTROL ; encender/apagar el led de control de operando
    BCF GPIO,LED_OPERANDO
    BSF GPIO,LED_OPERANDO
    
    BTFSS GPIO,BOTON_ENTRADA ; revisar si está presionado el botón de entrada
    GOTO lLeerDatosBotonEntradaNoPresionado ; saltar a esta posición si no está presionado
    BTFSC FLAG_FLANCO,0 ; si el flag está activo entonces se trata del mismo pulso, return
    GOTO lLeerDatosReturn
    ; inicializar el contador de espera de 4 bytes con 200000 -> 0x 00 03 0D 40
    MOVLW 0x0
    MOVWF REGISTRO_CONTADOR_4
    MOVLW 0x3
    MOVWF REGISTRO_CONTADOR_3
    MOVLW 0xD
    MOVWF REGISTRO_CONTADOR_2
    MOVLW 0x40
    MOVWF REGISTRO_CONTADOR_1
    lLeerDatosWhile
	BCF STATUS,RP0	    ;banco 0
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

	CLRWDT

	BCF STATUS,RP0
	BTFSC GPIO, 0x3
	GOTO lLeerDatosChequearContadorTerminado

	BSF FLAG_FLANCO,0

	BTFSC GPIO,BOTON_CONTROL
	GOTO lLeerDatosIngresandoOperando2

	MOVLW 1
	ADDWF OPERANDO1,1

	GOTO lLeerDatosReturn

    lLeerDatosIngresandoOperando2 MOVLW 1
	ADDWF OPERANDO2,1
	GOTO lLeerDatosReturn

    lLeerDatosChequearContadorTerminado MOVF REGISTRO_CONTADOR_4,W
	IORWF REGISTRO_CONTADOR_3,W
	IORWF REGISTRO_CONTADOR_2,W
	IORWF REGISTRO_CONTADOR_1,W
	BTFSS STATUS,2
	GOTO lLeerDatosWhile

	CALL fMostrarResultado
	GOTO lLeerDatosReturn

    lLeerDatosBotonEntradaNoPresionado CLRF FLAG_FLANCO
	GOTO lLeerDatosReturn
    lLeerDatosReturn 
	RETURN
    
; SUBRUTINA PARA MOSTRAR RESULTADO DE LA OPERACION    
fMostrarResultado
    CALL fDivisionEntera
    BCF STATUS,RP0 ; banco0
    ; se verifica si el resultado es cero en cuyo caso se retorna
    MOVLW 0
    SUBWF RESULTADO,1
    BTFSC STATUS,2
    GOTO lMostrarResultadoReturn
    GOTO lMostrarResultadoFinLoop

    lMostrarResultadoClearWDT 
	CLRWDT
	CALL fParpadearLEDResultado

    lMostrarResultadoFinLoop 
	MOVLW 1
	SUBWF RESULTADO,1
	BTFSS STATUS,2
	GOTO lMostrarResultadoClearWDT ; si el resultado no es cero entonces seguir parpadeando
	CALL fParpadearLEDResultado  ; si el resultado es cero entonces parpadear una vez
	CLRF OPERANDO1 ;limpiar los operandos 
	CLRF OPERANDO2
	GOTO lMostrarResultadoReturn
    lMostrarResultadoReturn
	RETURN
    
; SUBRUTINA PARA PARPADEAR UNA VEZ EL LED DE RESULTADO    
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
    
; SUBRUTINA QUE CALCULA LA DIVISION ENTERA    
fDivisionEntera

    BCF STATUS,RP0
    CLRF RESULTADO
    CLRF TEMP
    INCF TEMP, F

    MOVF OPERANDO2,W
    BTFSC STATUS,2 ; zero-bit, 1 si es 0    
    GOTO lDivisionEnteraReturn
    GOTO lDivisionEnteraInicio
    
    
    lDivisionEnteraWhile BCF STATUS,0 ; limpiar carry
	RLF OPERANDO2,F ;rotate left f through carry
	
	BCF STATUS,0
	RLF TEMP,F
	
    lDivisionEnteraInicio MOVF OPERANDO2,W
	SUBWF OPERANDO1,W
	BTFSC STATUS,0
	GOTO lDivisionEnteraWhile

	BCF STATUS,0 ; clear el carry
	RRF OPERANDO2,F ; rotate right f throug carry

	BCF STATUS,0 ; limpiar el carry
	RRF TEMP,F

	GOTO lDivisionEnteraFin

    lDivisionEnteraWhile2 MOVF OPERANDO2, W
	SUBWF OPERANDO1,W
	BTFSS STATUS,0
	GOTO lDivisionEnteraB

	MOVF OPERANDO2, W
	SUBWF OPERANDO1, F

	MOVF TEMP, W
	MOVWF INICIOSTACK
	MOVF INICIOSTACK, W
	IORWF RESULTADO, F

    lDivisionEnteraB BCF STATUS, 0x0
	RRF TEMP, F

	BCF STATUS, 0x0
	RRF OPERANDO2, F

    lDivisionEnteraFin MOVF TEMP, W
	BTFSS STATUS, 0x2
	GOTO lDivisionEnteraWhile2
    lDivisionEnteraReturn 
	RETURN

; SUBRUTINA PARA RETARDO DE 50 MILISEGUNDOS
fDelay50ms
    movlw	d'65'
    movwf	CONTADOR_DELAY_B
    movlw	d'238'
    movwf	CONTADOR_DELAY_A
    lLoop50ms	clrwdt ; Borra WDT
	decfsz	CONTADOR_DELAY_A,1
	goto	lLoop50ms
	decfsz	CONTADOR_DELAY_B,1
	goto	lLoop50ms
	nop
	retlw	0

END
 