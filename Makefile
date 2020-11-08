# MPLAB IDE generated this makefile for use with GNU make.
# Project: LcdSerial.mcp
# Date: Mon Dec 22 22:13:42 2014

AS = MPASMWIN.exe
CC = 
LD = mplink.exe
AR = mplib.exe
RM = rm

principal.cof : principal.o
	$(CC) /p16F628A "principal.o" /u_DEBUG /z__MPLAB_BUILD=1 /z__MPLAB_DEBUG=1 /o"principal.cof" /M"principal.map" /W /x

principal.o : principal.asm ../../../Program\ Files\ (x86)/Microchip/MPASM\ Suite/P16f628A.inc
	$(AS) /q /p16F628A "principal.asm" /l"principal.lst" /e"principal.err" /d__DEBUG=1

clean : 
	$(CC) "principal.o" "principal.hex" "principal.err" "principal.lst" "principal.cof"

