;===============================================
;
; Programa para la visualizacion de mensajes 
; en una LCD de 16x2, mediante comunicacion
; serial
; Ing. Edwin A. Agudelo G.
; SBI
; 2014
;
;===============================================
	
;===============================================
; Revisiones
;
; 2018-07-xx: Se ajustan los caracteres de envio
;	      junto con la funcionalidad de re-
;	      cibir una serie de caracteres(32)
; 2019-07-XX: Se agrega la funcionalidad de re-
;             cibir solo 2 caracteres, una ban-
;	      dera y un caracter
; 2019-07-XX: Se aumenta el tiempo de retardo en
;	      el inicio para evitar que haya una
;	      pantalla bloqueada al iniciar.
; 2020-12-04: Se ajusta la parte de los 2 carac-
;	      teres, se ajusta el tiempo de 
;	      timeout para la recepcion de datos.
; 2023-03   : Se cambian varias funciones y se 
;	      reacomoda el codigo para dar claridad.
;===============================================

	include "p16f628a.inc"

; Estos son los define que necesito
statt   equ	0x20
wregt   equ	0x21
delayr	equ	0x22 	; registro para los retrasos
dxreg	equ	0x23	; registro para retrasos largos
vreg	equ	0x24	; registro para cargar los valores a visualizar
verr	equ	0x25	; registro para almacenar el caracter a mostrar
temp	equ	0x26	; registro para almacenar temporales
cont	equ	0x27	; registro contador
cntrx	equ	0x28	; registro contador de bytes de llegada
band	equ	0x29	; registro de banderas
treg	equ	0x2a	; registro para transmitir valor
cntc	equ	0x2b	; registro contador de caracteres
delmsr	equ	0x2c	; registro para retardos de a 1MS(1 en este registro equivale a 1MS de retardo)
entcnv	equ	0x2d	; registro para almacenar los datos a convertir
const	equ	0x2e	; registro para almacenar la constante a restar en la conversion
cmov	equ	0x2f	; registro para almacenar el actual desplazamiento
fsrt	equ	0x30	; registro para almecenar el valor del registro FSR
nlinea  equ	0x31	; registro para almacenar el numero de linea actual
valcnv	equ	0x32	; registro inicial para almacenar el valor a convertir
drx	equ	0x38	; inicio de los registros que se reciben

; Flags y valores de pines
ena	equ	0x7		; LCD Enable
rs	equ	0x4		; LCD Register Select
rw	equ	0x6		; LCD Read/Write
bcklg	equ	0x3		; LCD Backlight
bussy	equ	0x4		; Ocupado
echo	equ	0x0		; Eco de RX
prcrx	equ	0x1		; Procesar RX
lact	equ	0x2		; Linea en la que esta (0/1:Arriba/Abajo)
recb	equ	0x3		; Flag para identificar el momento en que esta recibiendo

    ; TODO INSERT CONFIG CODE HERE USING CONFIG BITS GENERATOR
    __CONFIG _INTOSC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _BODEN_OFF & _LVP_OFF & _CP_OFF & _MCLRE_ON

    org     0x0000            ; processor reset vector
    GOTO    START                   ; go to beginning of program

; TODO ADD INTERRUPTS HERE IF USED
    org		0x04
    bcf		INTCON,GIE
    movwf	wregt
    movfw	STATUS
    movwf	statt
    movfw	FSR
    movwf	fsrt
    bcf		STATUS,RP1
    bcf		STATUS,RP0
    btfsc	INTCON, INTF
    goto	Irq
    btfsc	PIR1, RCIF
    goto	IRx
    btfsc	INTCON, T0IF
    goto	IntTMR
    goto	IntOk

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Programa principal
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

START:
	clrf	PORTA
	clrf	PORTB
	movlw	0x07
	movwf	CMCON
	bsf	STATUS, RP0
	bcf	STATUS, RP1
	clrf	TRISA
	movlw	0xE3
	movwf	TRISB
	movlw	0x19 ; 25 dec
	movwf	SPBRG
	bcf	STATUS, RP0
	movlw	0x90
	movwf	RCSTA
	bsf	STATUS, RP0
	movlw	0x24
	movwf	TXSTA
	movlw	0x20
	movwf	PIE1
	movlw	0x30
	movwf	INTCON
	bcf	STATUS, RP0
	
	; voy con el TIM
	clrf	TMR0
	bsf	STATUS, RP0
	bsf	OPTION_REG, PS0
	bcf	OPTION_REG, PS1
	bsf	OPTION_REG, PS2
	bcf	OPTION_REG, PSA
	bcf	OPTION_REG, T0CS
	bcf	STATUS, RP0
	bsf	INTCON, T0IE
	
	; Inicializo variables
	clrf	cntrx
	clrf	cntc
	
	
	; **************************************
	; Esta parte inicializa el LCD
	; **************************************
	
	; Alisto la LCD para escribir
	bsf	PORTA, rs
	bsf	PORTA, rw
	bcf	PORTA, ena
	; Primer retardo: 32ms
	movlw	0x20
	movwf	delmsr
	call	DelMS
	clrf	PORTA
	movlw	0x3
	iorwf	PORTA,f
	bsf	PORTA,ena
	bcf	PORTA,ena
	; Segundo retraso: 5ms
	movlw	0x05
	movwf	delmsr
	call	DelMS
	movlw	0x3
	iorwf	PORTA,f
	bsf	PORTA,ena
	bcf	PORTA,ena
	; Tercer retraso: 0,1ms
	movlw	0xb
	movwf	delayr
	call	Delay
	; Secuencia Inicializadora
	movlw	0x3
	movwf	vreg
	call	lcd_w
	movlw	0x2
	movwf	vreg
	call	lcd_w
	movlw	0x2
	movwf	vreg
	call	lcd_w
	movlw	0x8
	movwf	vreg
	call	lcd_w
	clrf	vreg
	call	lcd_w
	movlw	0xc
	movwf	vreg
	call	lcd_w
	clrf	vreg
	call	lcd_w
	movlw	0xa4
	movwf	delayr
	call	Delay
	movlw	0x1
	movwf	vreg
	call 	lcd_w
	movlw	0xa4
	movwf	delayr
	call	Delay
	clrf	vreg
	call	lcd_w
	movlw	0x6
	movwf	vreg
	call	lcd_w
	bcf	INTCON, T0IF
	bsf	INTCON,PEIE
	bsf	INTCON,GIE
	; Espero que este listo el LCD
	
	bsf	PORTA,rs
	clrf	nlinea
	clrf	cont
	clrf	band
	bsf	PORTB, bcklg
	bsf	PORTB, bussy
wellcome_1:
	movfw	cont
	sublw	0x8
	btfsc	STATUS,Z
	goto	ini_w2
	movlw	high T_msg
	movwf	PCLATH
	movfw	cont
	call	T_msg
	movwf	verr
	call	visu
	incf	cntc,f
	incf	cont,f
	goto	wellcome_1
ini_w2:
	call	CambioLinea
	clrf	cont
wellcome_2:
	movfw	cont
	sublw	0x8
	btfsc	STATUS,Z
	goto	ciclo_principal
	movlw	high T_msg
	movwf	PCLATH
	movfw	cont
	call	T_msg
	movwf	verr
	call	visu
	incf	cntc,f
	incf	cont,f
	goto	wellcome_2
	
ciclo_principal:
	btfsc	band,prcrx
	call	prcTrama
	nop
	nop
	goto	ciclo_principal
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Subrutinas
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;*********************************************	
; rutina de retraso de 10us 
;*********************************************	
Delay:
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	decfsz	delayr,F
	goto 	Delay
	return
	
;*********************************************	
; rutina de retraso por ms	
;*********************************************	
DelMS:
	movlw	0x64
	movwf	delayr
	call	Delay
	decfsz	delmsr
	goto	DelMS
	return
	
;*********************************************	
; Convierte de numeros a caracteres 
;*********************************************	
ConverDec:
	clrf	cmov
cargak:	
	movlw	valcnv
	addwf	cmov, W
	movwf	FSR
	movlw	'0'
	movwf	INDF
	movlw	high T_cont
	movwf	PCLATH
	movfw	cmov
	call	T_cont
	movwf	const	; cargo el valor
operak:
	movfw	const
	subwf	entcnv,w
	btfss	STATUS, C
	goto	cambiak
	incf	INDF,f
	movfw	const
	subwf	entcnv,f ; disminuyo
	goto	operak
cambiak:
	incf	cmov,f
	movfw	cmov
	sublw	0x3
	btfss	STATUS, Z
	goto	cargak
	return
	
;*********************************************	
; Escribe los 4 bits bajos en la LCD
;*********************************************	
lcd_w:
	movfw	PORTA
	andlw	0xf0
	iorwf	vreg,W
	movwf	PORTA
	bsf	PORTA,ena
	bcf	PORTA,ena
	movlw	0x4
	movwf	delayr
	call	Delay
	return
	
;*********************************************	
; Coordina la escritura de un byte (8 bits)
; en una LCD
;*********************************************	
visu:
	movfw	verr
	andlw	0xf0
	movwf	vreg
	swapf	vreg,f
	call 	lcd_w
	movfw	verr
	andlw	0x0f
	movwf	vreg
	call	lcd_w
	return
	
;*********************************************	
; Cambia de linea
;*********************************************	
CambioLinea:
	clrf	cntc
	movfw	nlinea
	sublw	0x1
	btfsc	STATUS,Z
	goto	priLin

;*********************************************	
; Salta el cursor a la segunda linea
;*********************************************	
segLin:
	movlw	0x1
	movwf	nlinea
	bcf	PORTA, rs
	movlw	0xC0
	movwf	verr
	call 	visu
	bsf	PORTA, rs
	return
	
;*********************************************	
; Salta el cursor a la primera linea
;*********************************************	
priLin:
	clrf	nlinea
	bcf	PORTA, rs
	movlw	0x80
	movwf	verr
	call 	visu
	bsf	PORTA, rs	
	return
	

;*********************************************	
; Borra todos los caracteres de la LCD
; y deja el cursor en la primera posicion
; en la primera linea
;*********************************************	
borrar_lcd:
	bcf	PORTA, rs
	clrf	vreg
	call	lcd_w
	movlw	0xa4
	movwf	delayr
	call	Delay
	movlw	0x1
	movwf	vreg
	call	lcd_w
	movlw	0xa4
	movwf	delayr
	call	Delay
	bsf	PORTA, rs
	clrf	cntc
	clrf	nlinea
	return
	
stx:
	movfw	treg
	movwf	TXREG
	bsf	STATUS, RP0

buecho:
	btfss	TXSTA, TRMT
	goto	buecho
	bcf	STATUS, RP0
	return
	
;*********************************************	
; Procesa la trama recibida por el puerto
; serial
;*********************************************	
prcTrama:
	bcf	band, prcrx
	bsf	PORTB, bussy
	movfw	drx
	sublw	0xA 
	btfsc	STATUS,Z  ; 0xA, imprimir caracter
	goto	imprimir_caracter
	movfw	drx
	sublw	0xB 
	btfsc	STATUS, Z ; 0xB, borrar pantalla
	goto	borrar_pantalla
	movfw	drx
	sublw	0xC  
	btfsc	STATUS, Z ; 0xC, Cambiar de lineas
	goto	cambiar_linea
	movfw	drx
	sublw	0xD 
	btfsc	STATUS, Z ; 0xD, el siguiente caracter lo leo como numero
	goto	imprimir_numero
	goto	fin_prcTrama
	
;*********************************************	
; Toma el caracter recibido y lo imprime
; en la LCD
;*********************************************	
imprimir_caracter:
	movlw	drx
	addlw	0x1
	movwf	FSR
	movfw	INDF
	movwf	verr
	call	visu
	incf	cntc,f
	movfw	cntc
	sublw	0x10
	btfsc	STATUS, Z
	call	CambioLinea
	goto	fin_prcTrama

;*********************************************	
; Borra la LCD
;*********************************************	
borrar_pantalla:
	call	borrar_lcd
	goto	fin_prcTrama

;*********************************************	
; Cambia la linea de la LCD por comando
;*********************************************	
cambiar_linea:
	call	CambioLinea
	goto	fin_prcTrama

;*********************************************	
; Procesa la llegada de un numero
;*********************************************	
imprimir_numero:
	movlw	drx
	addlw	0x1
	movwf	FSR
	movfw	INDF
	movwf	entcnv
	call	ConverDec
	clrf	cmov
imprimir_digito:
	movlw	valcnv
	addwf	cmov,w
	movwf	FSR
	movfw	INDF
	movwf	verr
	call	visu
	incf	cntc,f
	movfw	cntc
	sublw	0x10
	btfsc	STATUS, Z
	call	CambioLinea
	incf	cmov,f
	movfw	cmov
	sublw	0x3
	btfss	STATUS, Z
	goto	imprimir_digito

fin_prcTrama:
	bcf	PORTB, bussy
	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Interrupciones
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;*********************************************	
; Borra por IRQ
;*********************************************	
Irq:
	bcf	INTCON, INTF
	call	borrar_lcd
	goto	IntOk

;*********************************************	
; Recibe un caracter por RS232
;*********************************************	
IRx:
	clrf	TMR0
	movfw	RCREG
	movwf	temp
	movfw	cntrx
	addlw	drx
	movwf	FSR
	movfw	temp
	movwf	INDF
	incf	cntrx,f
	movfw	cntrx
	sublw	0x2
	btfss	STATUS,Z
	goto	fIRx
	clrf	cntrx
	bsf	band,prcrx
	bcf	band,recb
	goto	IntOk
fIRx:
	bsf	band,recb
	bsf	band,echo
	goto	IntOk

;*********************************************	
; Procesa la Int por timer
;*********************************************	
IntTMR:
	bcf	INTCON, T0IF
	btfss	band,recb
	goto	IntOk
	bcf	band,recb
	clrf	cntrx
	goto	IntOk
	
IntOk:
	movfw	fsrt
	movwf	FSR
	movfw	statt
	movwf	STATUS
	movfw	wregt
	bsf	INTCON,GIE
	retfie

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Tablas
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
 	
T_msg:
	addwf PCL,f
	retlw #'>'
	retlw #'L'
	retlw #'C'
	retlw #'D'
	retlw #' '
	retlw #'O'
	retlw #'K'
	retlw #'<'
	
T_nums:
	addwf PCL,f
	retlw #'0'
	retlw #'1'
	retlw #'2'
	retlw #'3'
	retlw #'4'
	retlw #'5'
	retlw #'6'
	retlw #'7'
	retlw #'8'
	retlw #'9'
	retlw #'.'
	
T_cont:
	addwf PCL,f
	retlw 0x64
	retlw 0xA
	retlw 0x1
	retlw 0x0



	end
