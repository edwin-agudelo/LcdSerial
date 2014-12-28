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

	;list p="16f628A"
	include "P16f628A.inc"

; Estos son los define que necesito
statt   equ 0x20
wregt   equ 0x21
dreg	equ	0x22 	; registro para los retrasos
dxreg	equ	0x23	; registro para retrasos largos
vreg	equ	0x24	; registro para cargar los valores a visualizar
verr	equ	0x25	; registro para almacenar el caracter a mostrar
temp	equ	0x26	; registro para almacenar temporales
cont	equ	0x27	; registro contador
cntrx	equ	0x28	; registro contador de bytes de llegada
band	equ	0x29	; registro de banderas
treg	equ	0x2a	; registro para transmitir valor
cntc	equ	0x2b	; registro contador de caracteres
drx		equ	0x30	; inicio de los registros que se reciben

; Flags y valores de pines
ena		equ 0x7		; LCD Enable
rs		equ	0x4		; LCD Register Select
rw		equ	0x6		; LCD Read/Write
bcklg	equ	0x7		; LCD Backlight
echo	equ	0x0		; eco de RX
prcrx	equ	0x1		; procesar RX
lact	equ	0x2		; Linea en la que esta (0/1:Arriba/Abajo)

	; TODO INSERT CONFIG CODE HERE USING CONFIG BITS GENERATOR
	__CONFIG _INTOSC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _BODEN_OFF & _LVP_OFF & _CP_OFF & _MCLRE_ON

	org     0x0000            ; processor reset vector
    GOTO    START                   ; go to beginning of program

; TODO ADD INTERRUPTS HERE IF USED
    org     0x04
    bcf		INTCON,GIE
    movwf	wregt
    movfw	STATUS
    movwf	statt
    bcf		STATUS,RP1
    bcf		STATUS,RP0
    btfsc	INTCON, INTF
    goto	Irq
    btfsc	PIR1, RCIF
    goto	IRx
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
	bsf		STATUS, RP0
	bcf		STATUS, RP1
	clrf	TRISA
	movlw	0xE3
	movwf	TRISB
	movlw	0x19 ; 25 dec
	movwf	SPBRG
	bcf		STATUS, RP0
	movlw	0x90
	movwf	RCSTA
	bsf		STATUS, RP0
	movlw	0x24
	movwf	TXSTA
	movlw	0x20
	movwf	PIE1
	movlw	0x30
	movwf	INTCON
	bcf		STATUS, RP0
	
	; Inicializo variables
	clrf	cntrx
	clrf	cntc
	
	
	; Alisto la LCD para escribir
	bsf		PORTA, rs
	bsf		PORTA, rw
	bsf		PORTA, ena
	; Primer retardo: 15ms
	movlw	0xfa
	movwf	dreg
	call	Delay
	movlw	0xfa
	movwf	dreg
	call	Delay
	movlw	0xfa
	movwf	dreg
	call	Delay
	movlw	0xfa
	movwf	dreg
	call	Delay
	movlw	0xfa
	movwf	dreg
	call	Delay
	movlw	0xfa
	movwf	dreg
	call	Delay
	clrf	PORTA
	movlw	0x3
	iorwf	PORTA,f
	bsf		PORTA,ena
	bcf		PORTA,ena
	; Segundo retraso: 4,1ms
	movlw	0xfa
	movwf	dreg
	call	Delay
	movlw	0xa0
	movwf	dreg
	call	Delay
	movlw	0x3
	iorwf	PORTA,f
	bsf		PORTA,ena
	bcf		PORTA,ena
	; Tercer retraso: 0,1ms
	movlw	0xa
	movwf	dreg
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
	movwf	dreg
	call	Delay
	movlw	0x1
	movwf	vreg
	call 	lcd_w
	movlw	0xa4
	movwf	dreg
	call	Delay
	clrf	vreg
	call	lcd_w
	movlw	0x6
	movwf	vreg
	call	lcd_w
	bsf		INTCON,PEIE
	bsf		INTCON,GIE
	; Espero que este listo el LCD
	
	bsf		PORTA,rs
	clrf	cont
	clrf	band
ciclo:
	movfw	cont
	sublw	0x9
	btfsc	STATUS,Z
	goto	ms2
	;goto	acabo
	movlw	high T_msg
	movwf	PCLATH
	movfw	cont
	call	T_msg
	movwf	verr
	call	visu
	incf	cntc,f
	incf	cont,f
	goto	ciclo
ms2:
	;bcf		PORTA, rs
	;movlw	0xC0
	;movwf	verr
	;call 	visu
	;bsf		PORTA, rs
	call	segLin
	clrf	cont
ciclo2:
	movfw	cont
	sublw	0x9
	btfsc	STATUS,Z
	goto	acabo
	movlw	high T_msg
	movwf	PCLATH
	movfw	cont
	call	T_msg
	movwf	verr
	call	visu
	incf	cntc,f
	incf	cont,f
	goto	ciclo2
	
	
acabo:
	btfsc	band, prcrx
	call	prcTrama
	goto	acabo
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Subrutinas
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; rutina de retraso de 10us 
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
	decfsz	dreg,F
	goto 	Delay
	return
	
lcd_w:
	movfw	PORTA
	andlw	0xf0
	iorwf	vreg,W
	movwf	PORTA
	bsf		PORTA,ena
	bcf		PORTA,ena
	movlw	0x4
	movwf	dreg
	call	Delay
	return
	
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
	
priLin:
	bcf		band, lact
	clrf	cntc
	bcf		PORTA, rs
	movlw	0x80
	movwf	verr
	call 	visu
	bsf		PORTA, rs
	return
	
segLin:
	bcf		band, lact
	bcf		PORTA, rs
	movlw	0xC0
	movwf	verr
	call 	visu
	bsf		PORTA, rs
	movlw	0x10
	movwf	cntc
	return

	
borrar_lcd:
	bcf		PORTA, rs
	clrf	vreg
	call	lcd_w
	movlw	0xa4
	movwf	dreg
	call	Delay
	movlw	0x1
	movwf	vreg
	call	lcd_w
	movlw	0xa4
	movwf	dreg
	call	Delay
	bsf		PORTA, rs
	clrf	cntc
	return
	
stx:
	movfw	treg
	movwf	TXREG
	bsf		STATUS, RP0
buecho:
	btfss	TXSTA, TRMT
	goto	buecho
	bcf		STATUS, RP0
	return
	
prcTrama:
	bcf		band, prcrx
	movfw	drx
	sublw	#'a'
	btfsc	STATUS,Z  ; 0x1, imprimir caracter
	goto	impc
	movfw	drx
	sublw	#'b'
	btfsc	STATUS, Z ; 0x2, borrar pantalla
	goto	borr
	movfw	drx
	sublw	#'c'
	goto	camLin
	goto	fprc
impc:
	movlw	drx
	addlw	0x1
	movwf	FSR
	movfw	INDF
	movwf	verr
	call	visu
	incf	cntc,f
	movfw	cntc
	sublw	0xf
	btfsc	STATUS, Z
	call	segLin
	movfw	cntc
	sublw	0x1f
	btfsc	STATUS, Z
	call	priLin
	goto	fprc
camLin:
	movlw	drx
	addlw	0x1
	movwf	FSR
	movfw	INDF
	sublw	0x1
	btfss	STATUS, Z
	goto	cam1
	call	segLin
	goto	fprc
cam1:
	call	priLin
	goto	fprc
	
borr:
	call	borrar_lcd
fprc:
	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Interrupciones
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Irq:
	bcf		INTCON, INTF
	call	borrar_lcd
	goto	IntOk

IRx:
	movfw	RCREG
	movwf	temp
	movfw	cntrx
	addlw	drx
	movwf	FSR
	movfw	temp
	movwf	INDF
	incf	cntrx,f
	movfw	cntrx
	sublw	0x3
	btfss	STATUS,Z
	goto	fIRx
	clrf	cntrx
	bsf		band,prcrx	
fIRx:
	bsf		band,echo
	goto	IntOk
	
IntOk:
    movfw	statt
	movwf	STATUS
	movfw	wregt
	bsf		INTCON,GIE
	retfie

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Tablas
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
 	
T_msg:
	addwf PCL,f
	retlw #'E'
	retlw #' '
	retlw #'L'
	retlw #' '
	retlw #'P'
	retlw #' '
	retlw #'J'
	retlw #' '
	retlw #'E'
	
T_nums
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



	end
