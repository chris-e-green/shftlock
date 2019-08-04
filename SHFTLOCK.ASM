; SHIFTLOK.ASM
; makes caps lock operate as a shift lock instead.
;
;----------------------------------------------------------------
; EQUATES
;----------------------------------------------------------------
CR            EQU  0DH
LF            EQU  0AH
ON            EQU  0FFH
OFF           EQU  00H
AT_KEYB       EQU  10H
SHIFT_STATUS  EQU  0417H              ; shift key status byte
KB_DATA       EQU  60H                ; keyboard data port
OTHER_INT_OK  EQU  20H                ; End of Interrupt
COMMAND_8259  EQU  20H                ; 8259 int contrlr command port
KB_ACCESS     EQU  16H                ; BIOS keyboard access int.
RETURN_FLAGS  EQU  02H                ; return keyboard flags funct.
CTL_KEY       EQU  1DH                ; scan code for left ctrl
ALT_KEY       EQU  38H                ; scan code for left alt
LSHIFT_KEY    EQU  2AH                ; scan code for l shift
RSHIFT_KEY    EQU  36H                ; scan code for r shift
LSHIFT_REL    EQU  0AAH               ; scan code for l shift release
RSHIFT_REL    EQU  0B6H               ; scan code for r shift release
CAPS_LOCK_KEY EQU  3AH                ; scan code for caps lock
CAPS_LOCK_REL EQU  0BAH               ; scan code for caps lock release
INS_KEY       EQU  52H                ; scan code for insert
SLASH_KEY     EQU  35H                ; scan code for / key
BACKSLASH_KEY EQU  2BH                ; scan code for \ key
HOT_KEY_ON    EQU  SLASH_KEY          ; HOT KEY ON scan code
HOT_KEY_OFF   EQU  BACKSLASH_KEY      ; HOT KEY OFF scan code
CTL_ALT_MASK  EQU  0CH                ; mask for Ctl+Alt
SHIFT_MASK    EQU  03H                ; mask for l+r shift
CAPS_MASK     EQU  40H                ; capslock mask
;
;----------------------------------------------------------------
; START OF CODE
;----------------------------------------------------------------
;
CODE          SEGMENT PARA PUBLIC 'CODE'
              ASSUME CS:CODE
              ORG  2CH
ENV_SEGMENT   DW   ?
              ORG  80H
COMMAND_TAIL  DW   ?

              ORG  100H
BEGIN:        JMP  INIT               ; initialization
;
;----------------------------------------------------------------
; CONSTANTS AND VARIABLES
;----------------------------------------------------------------
INSTALL_MSG      DB   CR,LF,"ShiftLock 1.0 by C.E.Green installed"
                 DB   CR,LF,"  Ctl-Alt-/ turns ShiftLock on",CR,LF
                 DB   "  Ctl-Alt-\ turns ShiftLock off",CR,LF,"$"
SHFTLCK_ACTV     DB   OFF             ; on if our interrupt is active
SHIFT            DB   OFF             ; on if we turned on shift
CAPS             DB   OFF             ; on if waiting for release
FLAG             DB   0               ; status of keys
XT_CAPSLOCK      DB   ?               ; keeps track of XT caps lock key
KEYBTYPE         DB   0               ; keyboard type
OLD_INT_9        LABEL DWORD          ; old interrupt 9 vector
OLD_INT          DD   ?
;
;----------------------------------------------------------------
; EXECUTION COMES HERE WHENEVER A KEY IS PRESSED OR RELEASED
;----------------------------------------------------------------
; process:
; get scan code.
; if the scan code indicates release, ignore.
; if the scan code is shift release and caps lock is set, turn off caps lock.
; if caps lock is set, and the scan code is 
;   02..0d, 1a,1b,27..29,2b,33..35, change the shift status bit to on.
; otherwise, process the character as normal.
;
KB_INT        PROC NEAR
              STI                     ; enable interrupts
              PUSH AX                 ; save AX
              PUSH BX                 ; save BX
              PUSH ES                 ; save ES
              MOV  AH,RETURN_FLAGS    ; get status of special keys
              INT  KB_ACCESS
              MOV  FLAG,AL            ; store it in flag

              CMP  SHIFT,ON           ; did we turn on shift last time? 
              JNE  SHIFT_OFF          ; no, keep going.
              MOV  SHIFT,OFF          ; yes, turn it off
              AND  FLAG,NOT SHIFT_MASK ; and turn off shift bits 

SHIFT_OFF:
              IN   AL,KB_DATA         ; get scan code
              MOV  BL,AL              ; save it for later
              IN   AL,61H 
	      MOV  AH,AL
              OR   AL,80H
              OUT  61H,AL
              XCHG AH,AL
              OUT  61H,AL
              MOV  AL,BL              ; restore the scan code to AL

CHECK_KEYSTROKE:
              CMP  AL,HOT_KEY_ON      ; is it the 'on' hot key?
              JE   PROCESSHOTON       ; yes, process hot key
              CMP  AL,HOT_KEY_OFF     ; is it the 'off' hot key?
              JE   PROCESSHOTOFF      ; yes, process hot key
              CMP  AL,CAPS_LOCK_REL   ; is it a caps lock release?
              JNE  NEXT               ; no, so continue
              MOV  CAPS,OFF           ; yes, so signal received.
NEXT:
              CMP  AL,CAPS_LOCK_KEY   ; is it a caps lock key?
              JNE  IF_SHIFTLOCK       ; no, continue
              CMP  CAPS,ON            ; are we waiting for a release?
              JE   IF_SHIFTLOCK       ; yes, don't swap status
              NOT  XT_CAPSLOCK        ; no, swap xt capslock status
              MOV  CAPS,ON            ; and signal to wait for a release
              JMP  IF_SHIFTLOCK       ; continue process
PROCESSHOTON:
              CALL CTRL_ALTCHECK      ; are Ctl+Alt keys pressed?
              JNE  IF_SHIFTLOCK       ; no, then hotkey not down.
              CMP  SHFTLCK_ACTV,ON    ; was shiftlock already active?
              JE   EXIT_RTI           ; if so, ignore the keystroke
              MOV  SHFTLCK_ACTV,ON    ; turn on shift lock
              CALL CAPSCHECK          ; is capslock on?
              JE   XT_CAPS_ON         ; yes 
              MOV  XT_CAPSLOCK,OFF    ; no, turn off flag
              JMP  EXIT_RTI           ; and exit
XT_CAPS_ON:
              MOV  XT_CAPSLOCK,ON     ; turn on flag
              JMP  EXIT_RTI           ; and exit
PROCESSHOTOFF:
              CALL CTRL_ALTCHECK      ; are Ctl+Alt keys pressed?
              JNE  IF_SHIFTLOCK       ; no, then hotkey not down.
              CMP  SHFTLCK_ACTV,OFF   ; was shiftlock already off?
              JE   EXIT_RTI           ; if so, ignore the keystroke
              MOV  SHFTLCK_ACTV,OFF   ; turn off shift lock
              CMP  XT_CAPSLOCK,OFF
              JE   XTCAPSOFF
              OR   FLAG,CAPS_MASK     ; turn on caps lock
              JMP  EXIT_RTI           ; and exit
XTCAPSOFF:
              AND  FLAG,NOT CAPS_MASK ; turn off caps lock 
              JMP  EXIT_RTI           ; and exit

EXIT_RTI:
              CALL EXIT0
              MOV  AL,OTHER_INT_OK    ; signal other interrupts 
              OUT  COMMAND_8259,AL    ; are okay now
              POP  ES                 ; restore registers
              POP  BX
              POP  AX
              CLI
              IRET                    ; return

IF_SHIFTLOCK:
              CMP  SHFTLCK_ACTV,ON
              JNE  EXIT_INT9          ; skip if inactive
              CALL CAPSCHECK          ; is capslock on?
              JNE  EXIT_INT9          ; no, so exit.
              CMP  BL,CAPS_LOCK_KEY   ; is it a caps lock key?
              JE   EXIT_RTI           ; yes, ignore key
              CMP  BL,LSHIFT_KEY      ; is it a left shift key?
              JE   EXIT_RTI           ; yes, ignore key
              CMP  BL,RSHIFT_KEY      ; is it a right shift key?
              JE   EXIT_RTI           ; yes, ignore key

              CMP  BL,LSHIFT_REL      ; is it a left shift release?
              JE   TURNOFFCAPS        ; yes, turn off caps lock
              CMP  BL,RSHIFT_REL      ; is it a right shift release?
              JE   TURNOFFCAPS        ; yes, turn off caps lock

; if the scan was a numeric key, turn on the shift key, otherwise exit.

              CMP  BL,02H             ; less than '1!'
              JB   EXIT_INT9          ; so process normally

              CMP  BL,0DH             ; less than or equal to '+='
              JBE  SHIFT_ON           ; so process our way

              CMP  BL,1AH             ; less than '{['
              JB   EXIT_INT9          ; so process normally

              CMP  BL,1BH             ; less than or equal to '}]'
              JBE  SHIFT_ON           ; so process our way

              CMP  BL,27H             ; less than ':;'
              JB   EXIT_INT9          ; so process normally

              CMP  BL,29H             ; less than or equal to '~`'
              JBE  SHIFT_ON           ; so process our way

              CMP  BL,2BH             ; less than '|\'
              JB   EXIT_INT9          ; so process normally

              CMP  BL,2BH             ; less than or equal to '|\'
              JBE  SHIFT_ON           ; so process our way

              CMP  BL,33H             ; less than '<,'
              JB   EXIT_INT9          ; so process normally

              CMP  BL,35H             ; less than or equal to '?/'
              JBE  SHIFT_ON           ; so process our way

              JMP  EXIT_INT9          ; otherwise process normally

EXIT_INT9:
              CALL EXIT0
              POP  ES                 ; restore ES
              POP  BX                 ; restore BX
              POP  AX                 ; restore AX
              CLI
              JMP  OLD_INT_9          ; go to normal INT 9 handler
TURNOFFCAPS:
              AND  FLAG,NOT CAPS_MASK ; turn off caps lock 
              JMP  EXIT_INT9          ; and exit

SHIFT_ON:
              OR   FLAG,SHIFT_MASK    ; turn on shift keys
              MOV  SHIFT,ON           ; turn on shifted-by-us
              JMP  EXIT_INT9          ; and exit

KB_INT        ENDP

CAPSCHECK     PROC NEAR
              MOV  AL,FLAG            ; get status of special keys
              AND  AL,CAPS_MASK       ; is caps lock on?
              CMP  AL,CAPS_MASK
              RET
CAPSCHECK     ENDP

CTRL_ALTCHECK PROC NEAR
              MOV  AL,FLAG            ; get status of special keys
              AND  AL,CTL_ALT_MASK    ; allow Ctl+Alt key bits only
              CMP  AL,CTL_ALT_MASK    ; are Ctl+Alt keys depressed?
              RET
CTRL_ALTCHECK ENDP              

EXIT0         PROC NEAR
              XOR BX,BX               ; put segment 0000H into ES
              MOV ES,BX
              MOV AL,FLAG             ; retrieve key status
              MOV ES:SHIFT_STATUS,AL  ; update system key status
              RET
EXIT0         ENDP     
;
;----------------------------------------------------------------
; SET INTERRUPT VECTORS TO POINT TO RESIDENT CODE
;----------------------------------------------------------------
ALREADY_INST  DB  0
OTHER_SEG     DW  0
ERRORMSG0     DB "Program not installed",CR,LF,"$"
ERRORMSG1     DB "Syntax: SHIFTLOK [/O][/U][/H]",CR,LF
              DB CR,LF,"/O turns on ShiftLock automatically",CR,LF
              DB "/U uninstalls ShiftLock",CR,LF
              DB "/H displays this information",CR,LF,"$"
ERRORMSG2     DB "Could not uninstall",CR,LF,"$"
ERRORMSG3     DB "Program already installed",CR,LF,"$"
MSG0          DB "Program uninstalled",CR,LF,"$"
;
INITIALIZE    PROC NEAR
;
INIT:

; save and set the interrupt 9 vectors to enable our new routine

              CLD
              MOV AX,0F000H
              MOV ES,AX
              MOV AL,ES:0FFFEH
              MOV WORD PTR [BEGIN],0
              XOR BX,BX
              MOV AX,CS
FIND_COPY:
              INC BX
              MOV ES,BX
              CMP AX,BX
              JE  FIND_COPY1
              MOV SI,OFFSET BEGIN
              MOV DI,SI
              MOV CX,16
              REPE CMPSB
              JNE FIND_COPY
              INC ALREADY_INST
FIND_COPY1:
              MOV OTHER_SEG,ES
              MOV SI,OFFSET COMMAND_TAIL+1
PARSE_LINE_LOOP:
              LODSB
              CMP AL,32
              JE  PARSE_LINE_LOOP
              CMP AL,13
              JE  PARSE_LINE_END
              CMP AL,"/"                ; is this a / character?
              JNE PARSE_LINE_ERROR
              LODSB
              OR  AL,20H
              CMP AL,"u"
              JE  UNINSTALL_FOUND
              CMP AL,"o"
              JNE PARSE_LINE_ERROR
              MOV SHFTLCK_ACTV,ON
              JMP PARSE_LINE_LOOP
PARSE_LINE_ERROR:
              MOV DX,OFFSET ERRORMSG1
              JMP SHORT DISP_ERROR
UNINSTALL_FOUND:
              MOV DX,OFFSET ERRORMSG0
              CMP ALREADY_INST,0
              JE  DISP_ERROR
              CALL REMOVE
              MOV DX,OFFSET ERRORMSG2
              JC  DISP_ERROR
              MOV DX,OFFSET MSG0
              MOV AH,9
              INT 21H
EXIT:
              MOV AX,4C00H
              INT 21H                   ; exit with errorlevel=0
PARSE_LINE_END:
              CMP ALREADY_INST,0
              JE  INSTALL
              MOV DX,OFFSET ERRORMSG3  
DISP_ERROR:
              MOV AH,9
              INT 21H
              MOV AX,4C01H
              INT 21H                   ; Exit with errorlevel=1

INSTALL:
              MOV AX,3509H              ; get old interrupt 9 vector
              INT 21H
              MOV WORD PTR OLD_INT,BX   ; save it
              MOV WORD PTR OLD_INT[2],ES
              MOV AX,2509H              ; set interrupt 9 vector
              LEA DX,KB_INT             ; point to our keyboard handler
              INT 21H
              XOR AX,AX
              MOV ES,AX
              MOV AL,ES:496H            ; determine keyboard type
              MOV KEYBTYPE,AL           
              MOV DX,OFFSET INSTALL_MSG ; install message
              MOV AH,9                  ; dos write string
              INT 21H
              LEA DX,INITIALIZE         ; point DX to end of resident code
              INT 27H                   ; terminate but stay resident
INITIALIZE    ENDP
;
REMOVE        PROC NEAR
              CMP ALREADY_INST,0
              JE  REMOVE_ERROR
              MOV AX,3509H
              INT 21H
              MOV AX,ES
              CMP AX,OTHER_SEG
              JNE REMOVE_ERROR
              PUSH DS
              LDS DX,ES:[OLD_INT]
              MOV AX,2509H
              INT 21H
              POP DS
              MOV CX,ES:[ENV_SEGMENT]
              MOV AH,49H
              INT 21H
              MOV ES,CX
              MOV AH,49H
              INT 21H
REMOVE_EXIT:
              CLC
REMOVE_EXIT1:
              RET
REMOVE_ERROR:
              STC
              JMP REMOVE_EXIT1
REMOVE        ENDP

CODE          ENDS
              END BEGIN

