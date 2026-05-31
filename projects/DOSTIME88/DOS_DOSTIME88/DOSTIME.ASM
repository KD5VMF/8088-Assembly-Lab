; ================================================================
; DOSTIME.ASM - DOS TIME SYNC 88 REV8
;
; 8088/8086-compatible DOS serial time receiver.
;
; Windows side runs TimeSyncHost.cs.
;
; DOS sends once per second:
;     DYYYYMMDDHHMMSS
;
; Windows sends only once per day or if DOS time is off by 2+ sec:
;     TYYYYMMDDHHMMSS plus optional D/S DST flag or TYYYYMMDDHHMMSSD/S
;
; DOS receives T packet and sets DOS date/time.
; REV3 adds robust receive window, leading-junk tolerant T packet parsing,
; and an AOK acknowledgment line after every successful set.
;
; REV4 fixes date-setting reliability:
;   - accepts optional DST flag: TYYYYMMDDHHMMSSD or ...S
;   - sets DOS date and DOS time
;   - also attempts AT BIOS RTC date/time set through INT 1Ah
;   - verifies the DOS date after setting before sending AOK
;
; REV5 fixes stubborn date/RTC machines:
;   - sets DOS date first and verifies immediately
;   - tries BIOS RTC date/time
;   - also writes AT-compatible CMOS RTC registers directly
;   - sets DOS date/time again after RTC writes
;
; REV6 fixes 4-digit year parsing:
;   - REV5 parsed TYYYY as only the first two digits * 100
;   - 2026 could become 2000, while month/day still looked correct
;   - PARSE4 now preserves the low two year digits across MUL
;
; Build:
;     TASM DOSTIME
;     TLINK DOSTIME
;
; First run asks COM setup and saves DOSTIME.CFG.
; Press C while running to change setup later.
;
; REV8 fixes TASM relative-jump-out-of-range errors in PROCESS_LINE.
; Serial uses BIOS INT 14h, 8N1. Supported baud choices:
;     1200, 2400, 4800, 9600
; ================================================================

.8086
.MODEL SMALL
.STACK 0200h

.DATA

CFG_SIZE        EQU CFG_END - CFG_MAGIC

CFG_FILE        db 'DOSTIME.CFG',0
CFG_MAGIC       db 'TS88'
CFG_COMNUM      db 1        ; 1..4 shown to user
CFG_BAUDCODE    db 4        ; 1=1200,2=2400,3=4800,4=9600
CFG_MODE        db 0E3h     ; INT14 mode byte, 9600 8N1
CFG_END         LABEL BYTE

COM_INDEX       dw 0        ; INT 14h uses 0=COM1, 1=COM2...
QUIT_FLAG       db 0
LAST_SEC        db 0FFh
RX_LEN          db 0
LAST_STATUS     db 0

RX_COUNT        dw 0
TX_COUNT        dw 0
SYNC_COUNT      dw 0
BAD_COUNT       dw 0

IN_YEAR         dw 0        ; full 4-digit year for DOS, e.g. 2026
IN_CENTURY      db 0        ; first two digits, e.g. 20
IN_YEAR2        db 0        ; last two digits, e.g. 26
IN_MONTH        db 0
IN_DAY          db 0
IN_HOUR         db 0
IN_MIN          db 0
IN_SEC          db 0
IN_DST          db 0        ; 1=daylight saving flag from Windows, 0=standard/unknown
DATE_SET_OK     db 0
TIME_SET_OK     db 0
RTC_SET_TRIED   db 0
CMOS_SET_TRIED  db 0
CMOS_STATUS_B_OLD db 0

PKT_BUF         db 32 dup(0)
RX_BUF          db 40 dup(0)
NUM_BUF         db 8 dup(0)

CRLF            db 13,10,'$'
MSG_TITLE       db 13,10,'DOS TIME SYNC 88 REV8',13,10,'8088/8086 SERIAL CLOCK RECEIVER',13,10,13,10,'$'
MSG_NOCFG       db 'No valid DOSTIME.CFG found. Setup required.',13,10,'$'
MSG_SETUP       db 'Serial setup - use same COM/baud on Windows.',13,10,13,10,'$'
MSG_COM         db 'COM port 1-4 [default 1]: $'
MSG_BAUD        db 13,10,'Baud:',13,10,'  1=1200',13,10,'  2=2400',13,10,'  3=4800',13,10,'  4=9600 recommended',13,10,'Choice [default 4]: $'
MSG_SAVED       db 13,10,13,10,'Saved DOSTIME.CFG. Press any key...',13,10,'$'

LINE1           db '----------------------------------------------------------------------------$'
TITLE_LINE      db 'DOS TIME SYNC 88 REV8    8088/8086 SERIAL CLOCK RECEIVER$'
PROTO_LINE      db 'PROTO: DOS SENDS DYYYYMMDDHHMMSS   WINDOWS SENDS TYYYYMMDDHHMMSSD/S$'
KEY_LINE        db 'C=CHANGE COM SETUP/SAVE CFG        Q=QUIT$'
LBL_CFG         db 'CONFIG:$'
LBL_DOS         db 'DOS CLOCK PACKET:$'
LBL_PC          db 'LAST PC PACKET :$'
LBL_STAT        db 'STATUS:$'
LBL_CNT         db 'COUNTS: RX=$'
LBL_TX          db ' TX=$'
LBL_SYNC        db ' SYNC=$'
LBL_BAD         db ' BAD=$'
TXT_WAIT        db 'WAITING FOR WINDOWS TIME HOST$'
TXT_SYNC        db 'TIME SET OK$'
TXT_BAD         db 'BAD PACKET IGNORED$'
TXT_DATEFAIL    db 'DATE/RTC SET VERIFY FAILED$'
TXT_SETUP       db 'SETUP CHANGED AND SAVED$'
TXT_COM         db 'COM$'
TXT_BAUD1200    db '  1200 8N1$'
TXT_BAUD2400    db '  2400 8N1$'
TXT_BAUD4800    db '  4800 8N1$'
TXT_BAUD9600    db '  9600 8N1$'
TXT_NONE        db '----------------$'

.CODE

START:
    mov ax, @data
    mov ds, ax
    mov es, ax

    call LOAD_CONFIG
    cmp al, 1
    je HAVE_CONFIG

    mov dx, OFFSET MSG_NOCFG
    call DOS_PRINT
    call ASK_SETUP

HAVE_CONFIG:
    call APPLY_CONFIG
    call SERIAL_INIT
    call DRAW_SCREEN
    call SEND_HEARTBEAT

MAIN_LOOP:
    call CHECK_KEYS
    cmp byte ptr [QUIT_FLAG], 1
    je EXIT_PROGRAM

    call POLL_SERIAL
    call HEARTBEAT_IF_SECOND_CHANGED
    jmp MAIN_LOOP

EXIT_PROGRAM:
    mov ax, 4C00h
    int 21h

; ================================================================
; DOS CONSOLE HELPERS
; ================================================================

DOS_PRINT PROC
    mov ah, 09h
    int 21h
    ret
DOS_PRINT ENDP

DOS_KEY_ECHO PROC
    mov ah, 01h
    int 21h
    ret
DOS_KEY_ECHO ENDP

DOS_KEY_WAIT PROC
    mov ah, 08h
    int 21h
    ret
DOS_KEY_WAIT ENDP

GOTOXY PROC
    ; DH=row, DL=col
    push ax
    push bx
    mov ah, 02h
    mov bh, 0
    int 10h
    pop bx
    pop ax
    ret
GOTOXY ENDP

PRINT_AT PROC
    ; DH=row, DL=col, DX cannot hold string because it holds coords.
    ; SI = $ string.
    push dx
    call GOTOXY
    mov dx, si
    call DOS_PRINT
    pop dx
    ret
PRINT_AT ENDP

CLEAR_EOL PROC
    ; DH=row, DL=col, CX=count
    push ax
    push bx
    push cx
    call GOTOXY
    mov ah, 09h
    mov al, ' '
    mov bh, 0
    mov bl, 07h
    int 10h
    pop cx
    pop bx
    pop ax
    ret
CLEAR_EOL ENDP

; ================================================================
; CONFIG
; ================================================================

LOAD_CONFIG PROC
    push bx
    push cx
    push dx

    mov dx, OFFSET CFG_FILE
    mov ax, 3D00h
    int 21h
    jc LC_BAD

    mov bx, ax
    mov ah, 3Fh
    mov cx, CFG_SIZE
    mov dx, OFFSET CFG_MAGIC
    int 21h

    push ax
    mov ah, 3Eh
    int 21h
    pop ax

    cmp ax, CFG_SIZE
    jne LC_BAD
    cmp byte ptr [CFG_MAGIC], 'T'
    jne LC_BAD
    cmp byte ptr [CFG_MAGIC+1], 'S'
    jne LC_BAD
    cmp byte ptr [CFG_MAGIC+2], '8'
    jne LC_BAD
    cmp byte ptr [CFG_MAGIC+3], '8'
    jne LC_BAD

    mov al, 1
    jmp LC_DONE

LC_BAD:
    mov byte ptr [CFG_MAGIC], 'T'
    mov byte ptr [CFG_MAGIC+1], 'S'
    mov byte ptr [CFG_MAGIC+2], '8'
    mov byte ptr [CFG_MAGIC+3], '8'
    mov byte ptr [CFG_COMNUM], 1
    mov byte ptr [CFG_BAUDCODE], 4
    mov byte ptr [CFG_MODE], 0E3h
    xor al, al

LC_DONE:
    pop dx
    pop cx
    pop bx
    ret
LOAD_CONFIG ENDP

SAVE_CONFIG PROC
    push ax
    push bx
    push cx
    push dx

    mov byte ptr [CFG_MAGIC], 'T'
    mov byte ptr [CFG_MAGIC+1], 'S'
    mov byte ptr [CFG_MAGIC+2], '8'
    mov byte ptr [CFG_MAGIC+3], '8'

    mov dx, OFFSET CFG_FILE
    xor cx, cx
    mov ah, 3Ch
    int 21h
    jc SC_DONE

    mov bx, ax
    mov ah, 40h
    mov cx, CFG_SIZE
    mov dx, OFFSET CFG_MAGIC
    int 21h

    mov ah, 3Eh
    int 21h

SC_DONE:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
SAVE_CONFIG ENDP

ASK_SETUP PROC
    push ax
    push dx

    mov dx, OFFSET MSG_TITLE
    call DOS_PRINT
    mov dx, OFFSET MSG_SETUP
    call DOS_PRINT

    mov dx, OFFSET MSG_COM
    call DOS_PRINT
    call DOS_KEY_ECHO
    cmp al, '1'
    jb AS_DEF_COM
    cmp al, '4'
    ja AS_DEF_COM
    sub al, '0'
    mov [CFG_COMNUM], al
    jmp AS_COM_OK
AS_DEF_COM:
    mov byte ptr [CFG_COMNUM], 1
AS_COM_OK:

    mov dx, OFFSET MSG_BAUD
    call DOS_PRINT
    call DOS_KEY_ECHO
    cmp al, '1'
    jb AS_DEF_BAUD
    cmp al, '4'
    ja AS_DEF_BAUD
    sub al, '0'
    mov [CFG_BAUDCODE], al
    jmp AS_BAUD_OK
AS_DEF_BAUD:
    mov byte ptr [CFG_BAUDCODE], 4
AS_BAUD_OK:
    call BAUD_TO_MODE
    call SAVE_CONFIG
    mov dx, OFFSET MSG_SAVED
    call DOS_PRINT
    call DOS_KEY_WAIT

    pop dx
    pop ax
    ret
ASK_SETUP ENDP

BAUD_TO_MODE PROC
    mov al, [CFG_BAUDCODE]
    cmp al, 1
    jne BTM_2
    mov byte ptr [CFG_MODE], 83h       ; 1200 8N1
    ret
BTM_2:
    cmp al, 2
    jne BTM_3
    mov byte ptr [CFG_MODE], 0A3h      ; 2400 8N1
    ret
BTM_3:
    cmp al, 3
    jne BTM_4
    mov byte ptr [CFG_MODE], 0C3h      ; 4800 8N1
    ret
BTM_4:
    mov byte ptr [CFG_BAUDCODE], 4
    mov byte ptr [CFG_MODE], 0E3h      ; 9600 8N1
    ret
BAUD_TO_MODE ENDP

APPLY_CONFIG PROC
    call BAUD_TO_MODE
    xor ax, ax
    mov al, [CFG_COMNUM]
    dec ax
    mov [COM_INDEX], ax
    ret
APPLY_CONFIG ENDP

; ================================================================
; SERIAL BIOS INT 14h
; ================================================================

SERIAL_INIT PROC
    push ax
    push dx
    mov ah, 00h
    mov al, [CFG_MODE]
    mov dx, [COM_INDEX]
    int 14h
    pop dx
    pop ax
    ret
SERIAL_INIT ENDP

SERIAL_STATUS PROC
    ; CF=1 if RX char available
    push ax
    push dx
    mov ah, 03h
    mov dx, [COM_INDEX]
    int 14h
    test ah, 01h
    jz SS_NO
    stc
    jmp SS_DONE
SS_NO:
    clc
SS_DONE:
    pop dx
    pop ax
    ret
SERIAL_STATUS ENDP

SERIAL_RX PROC
    ; returns AL char
    push dx
    mov ah, 02h
    mov dx, [COM_INDEX]
    int 14h
    pop dx
    ret
SERIAL_RX ENDP

SERIAL_TX PROC
    ; AL char
    push ax
    push dx
    mov ah, 01h
    mov dx, [COM_INDEX]
    int 14h
    pop dx
    pop ax
    ret
SERIAL_TX ENDP

SERIAL_TX_STRING PROC
    ; SI = zero-terminated string
    push ax
    push si
STS_LOOP:
    lodsb
    cmp al, 0
    je STS_DONE
    call SERIAL_TX
    jmp STS_LOOP
STS_DONE:
    pop si
    pop ax
    ret
SERIAL_TX_STRING ENDP

; ================================================================
; PACKET BUILD / DISPLAY
; ================================================================

PUT2_BUF PROC
    ; AX=0..99, DI destination, advances DI
    push ax
    push bx
    push dx
    xor dx, dx
    mov bx, 10
    div bx
    add al, '0'
    stosb
    mov al, dl
    add al, '0'
    stosb
    pop dx
    pop bx
    pop ax
    ret
PUT2_BUF ENDP

PUT4_BUF PROC
    ; AX=0..9999, DI destination, advances DI
    push ax
    push bx
    push dx
    mov bx, 1000
    xor dx, dx
    div bx
    add al, '0'
    stosb
    mov ax, dx
    mov bx, 100
    xor dx, dx
    div bx
    add al, '0'
    stosb
    mov ax, dx
    mov bx, 10
    xor dx, dx
    div bx
    add al, '0'
    stosb
    mov al, dl
    add al, '0'
    stosb
    pop dx
    pop bx
    pop ax
    ret
PUT4_BUF ENDP

MAKE_DOS_PACKET PROC
    push ax
    push cx
    push dx
    push di

    mov di, OFFSET PKT_BUF
    mov al, 'D'
    stosb

    mov ah, 2Ah
    int 21h
    mov ax, cx
    call PUT4_BUF
    xor ax, ax
    mov al, dh
    call PUT2_BUF
    xor ax, ax
    mov al, dl
    call PUT2_BUF

    mov ah, 2Ch
    int 21h
    xor ax, ax
    mov al, ch
    call PUT2_BUF
    xor ax, ax
    mov al, cl
    call PUT2_BUF
    xor ax, ax
    mov al, dh
    call PUT2_BUF

    mov al, 0
    stosb

    pop di
    pop dx
    pop cx
    pop ax
    ret
MAKE_DOS_PACKET ENDP

SEND_HEARTBEAT PROC
    push ax
    push si
    call MAKE_DOS_PACKET
    mov si, OFFSET PKT_BUF
    call SERIAL_TX_STRING
    mov al, 13
    call SERIAL_TX
    mov al, 10
    call SERIAL_TX
    inc word ptr [TX_COUNT]

    ; REV3: immediately listen for the Windows correction before doing
    ; display work. This greatly improves reliability on old UARTs.
    call POLL_SERIAL_WINDOW

    call DRAW_DOS_PACKET
    call DRAW_COUNTS
    pop si
    pop ax
    ret
SEND_HEARTBEAT ENDP

HEARTBEAT_IF_SECOND_CHANGED PROC
    push ax
    push cx
    push dx
    mov ah, 2Ch
    int 21h
    cmp dh, [LAST_SEC]
    je HIS_DONE
    mov [LAST_SEC], dh
    call SEND_HEARTBEAT
HIS_DONE:
    pop dx
    pop cx
    pop ax
    ret
HEARTBEAT_IF_SECOND_CHANGED ENDP


; ================================================================
; RECEIVE WINDOW AFTER DOS TRANSMIT
; ================================================================

POLL_SERIAL_WINDOW PROC
    ; Poll RX for several BIOS timer ticks after sending a heartbeat.
    ; This helps old one-byte UART / BIOS INT 14h systems catch the
    ; Windows reply before screen drawing can let characters overrun.
    push ax
    push bx
    push cx
    push dx

    mov ah, 00h
    int 1Ah
    mov bx, dx
    mov cx, 6              ; about 0.3 seconds worst-case at 18.2 Hz

PSW_LOOP:
    call POLL_SERIAL
    call CHECK_KEYS
    cmp byte ptr [QUIT_FLAG], 1
    je PSW_DONE

    mov ah, 00h
    int 1Ah
    cmp dx, bx
    je PSW_LOOP
    mov bx, dx
    loop PSW_LOOP

PSW_DONE:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
POLL_SERIAL_WINDOW ENDP

SEND_ACK_OK PROC
    ; Let the Windows host know DOS actually accepted and set the time.
    push ax
    mov al, 'A'
    call SERIAL_TX
    mov al, 'O'
    call SERIAL_TX
    mov al, 'K'
    call SERIAL_TX
    mov al, 13
    call SERIAL_TX
    mov al, 10
    call SERIAL_TX
    pop ax
    ret
SEND_ACK_OK ENDP

; ================================================================
; PARSE / SET TIME
; ================================================================

PARSE2 PROC
    ; SI->2 digits, AX result, advances SI, CF=1 bad
    push bx
    push dx
    lodsb
    cmp al, '0'
    jb P2_BAD
    cmp al, '9'
    ja P2_BAD
    sub al, '0'
    mov bl, al
    lodsb
    cmp al, '0'
    jb P2_BAD
    cmp al, '9'
    ja P2_BAD
    sub al, '0'
    mov dl, al
    xor ax, ax
    mov al, bl
    mov bl, 10
    mul bl
    xor dh, dh
    add ax, dx
    clc
    jmp P2_DONE
P2_BAD:
    stc
P2_DONE:
    pop dx
    pop bx
    ret
PARSE2 ENDP

PARSE4 PROC
    ; SI->4 digits, AX result, advances SI, CF=1 bad.
    ; REV6 fix: keep the low two digits safe while MUL overwrites DX.
    ; Example: "2026" must become 2026, not 2000.
    push bx
    push cx
    push dx

    call PARSE2
    jc P4_BAD
    mov bx, ax              ; high two digits, e.g. 20

    call PARSE2
    jc P4_BAD
    mov cx, ax              ; low two digits, e.g. 26

    mov ax, bx
    mov bx, 100
    mul bx                  ; AX = high_two * 100, DX overwritten
    add ax, cx              ; AX = high_two*100 + low_two
    clc
    jmp P4_DONE

P4_BAD:
    stc
P4_DONE:
    pop dx
    pop cx
    pop bx
    ret
PARSE4 ENDP


BIN_TO_BCD_AL PROC
    ; Input AX = 0..99. Output AL = packed BCD.
    push bx
    push dx
    xor dx, dx
    mov bx, 10
    div bx
    shl al, 4
    and dl, 0Fh
    or al, dl
    pop dx
    pop bx
    ret
BIN_TO_BCD_AL ENDP

SET_DOS_DATE_TIME PROC
    ; Returns AL=1 if DOS date and time calls accepted, AL=0 if failed.
    mov byte ptr [DATE_SET_OK], 0
    mov byte ptr [TIME_SET_OK], 0

    ; DOS Set Date: AH=2Bh, CX=year, DH=month, DL=day.
    mov ah, 2Bh
    mov cx, [IN_YEAR]
    mov dh, [IN_MONTH]
    mov dl, [IN_DAY]
    int 21h
    cmp al, 0FFh
    je SDDT_FAIL
    mov byte ptr [DATE_SET_OK], 1

    ; DOS Set Time: AH=2Dh, CH=hour, CL=minute, DH=second, DL=hundredths.
    mov ah, 2Dh
    mov ch, [IN_HOUR]
    mov cl, [IN_MIN]
    mov dh, [IN_SEC]
    mov dl, 0
    int 21h
    cmp al, 0FFh
    je SDDT_FAIL
    mov byte ptr [TIME_SET_OK], 1

    mov al, 1
    ret
SDDT_FAIL:
    xor al, al
    ret
SET_DOS_DATE_TIME ENDP

SET_BIOS_RTC_DATE_TIME PROC
    ; Optional AT-class RTC update. This is ignored if unsupported.
    ; INT 1Ah AH=05h Set RTC Date, AH=03h Set RTC Time.
    ; Values are packed BCD. XT-class systems may simply ignore/fail this.
    ; REV7: use the packet's separate century and two-digit year values.
    ;       Many AT RTCs only store YY in the normal year register.
    push ax
    push bx
    push cx
    push dx

    mov byte ptr [RTC_SET_TRIED], 1

    ; Build BCD century/year directly from parsed packet values.
    xor ax, ax
    mov al, [IN_CENTURY]   ; e.g. 20
    call BIN_TO_BCD_AL
    mov ch, al
    xor ax, ax
    mov al, [IN_YEAR2]     ; e.g. 26
    call BIN_TO_BCD_AL
    mov cl, al

    xor ax, ax
    mov al, [IN_MONTH]
    call BIN_TO_BCD_AL
    mov dh, al
    xor ax, ax
    mov al, [IN_DAY]
    call BIN_TO_BCD_AL
    mov dl, al
    mov ah, 05h
    int 1Ah                ; CF may indicate failure; ignore for XT compatibility.

    xor ax, ax
    mov al, [IN_HOUR]
    call BIN_TO_BCD_AL
    mov ch, al
    xor ax, ax
    mov al, [IN_MIN]
    call BIN_TO_BCD_AL
    mov cl, al
    xor ax, ax
    mov al, [IN_SEC]
    call BIN_TO_BCD_AL
    mov dh, al
    mov dl, [IN_DST]       ; 0=standard/unknown, 1=daylight saving active.
    mov ah, 03h
    int 1Ah                ; CF may indicate failure; ignore for XT compatibility.

    pop dx
    pop cx
    pop bx
    pop ax
    ret
SET_BIOS_RTC_DATE_TIME ENDP

; ================================================================
; REV5 DIRECT AT CMOS RTC DATE/TIME WRITE
; ================================================================
; Some DOS/BIOS combinations accept the DOS time call but do not
; reliably copy the date into the motherboard RTC. 286/386/AT-class
; PCs normally have an MC146818-compatible RTC at CMOS ports 70h/71h.
; This routine writes those registers directly after the normal DOS
; and BIOS paths. On XT-class machines without this RTC, it is harmless
; to try, but it may not have any effect.
;
; CMOS register map used here:
;   00h seconds, 02h minutes, 04h hours
;   07h day-of-month, 08h month, 09h year
;   0Bh status B, 32h century when present
;
; If status B bit 2 says binary mode, values are written as binary.
; Otherwise values are written as packed BCD, which is the normal PC mode.
; ================================================================

IO_DELAY PROC
    push cx
    mov cx, 20
IOD_LOOP:
    loop IOD_LOOP
    pop cx
    ret
IO_DELAY ENDP

READ_CMOS_REG PROC
    ; Input AL = CMOS index. Output AL = value.
    push dx
    mov dx, 0070h
    out dx, al
    call IO_DELAY
    inc dx
    in al, dx
    pop dx
    ret
READ_CMOS_REG ENDP

WRITE_CMOS_REG PROC
    ; Input BL = CMOS index, AL = value.
    push ax
    push dx
    mov ah, al
    mov al, bl
    mov dx, 0070h
    out dx, al
    call IO_DELAY
    inc dx
    mov al, ah
    out dx, al
    call IO_DELAY
    pop dx
    pop ax
    ret
WRITE_CMOS_REG ENDP

CMOS_WRITE_00_99 PROC
    ; Input BL = CMOS index, AL = binary value 0..99.
    ; Writes binary or BCD based on old status B bit 2.
    push ax
    test byte ptr [CMOS_STATUS_B_OLD], 04h
    jnz CWB_HAVE_VALUE
    xor ah, ah
    call BIN_TO_BCD_AL
CWB_HAVE_VALUE:
    call WRITE_CMOS_REG
    pop ax
    ret
CMOS_WRITE_00_99 ENDP

SET_CMOS_RTC_DIRECT_DATE_TIME PROC
    push ax
    push bx
    push cx
    push dx
    pushf

    mov byte ptr [CMOS_SET_TRIED], 1

    cli

    ; Read and remember old Status B, then set SET bit 7 so the RTC
    ; update cycle is stopped while date/time registers are changed.
    mov al, 0Bh
    call READ_CMOS_REG
    mov [CMOS_STATUS_B_OLD], al
    or al, 82h              ; SET bit + force 24-hour mode for writes
    mov bl, 0Bh
    call WRITE_CMOS_REG

    ; seconds
    mov al, [IN_SEC]
    mov bl, 00h
    call CMOS_WRITE_00_99

    ; minutes
    mov al, [IN_MIN]
    mov bl, 02h
    call CMOS_WRITE_00_99

    ; hours - assumes 24-hour RTC mode, which normal DOS/AT systems use.
    mov al, [IN_HOUR]
    mov bl, 04h
    call CMOS_WRITE_00_99

    ; day of month
    mov al, [IN_DAY]
    mov bl, 07h
    call CMOS_WRITE_00_99

    ; month
    mov al, [IN_MONTH]
    mov bl, 08h
    call CMOS_WRITE_00_99

    ; REV7: RTC year register 09h is only two digits on AT machines.
    ; Write YY to register 09h and century to register 32h when present.
    xor ax, ax
    mov al, [IN_YEAR2]     ; e.g. 26 for 2026
    mov bl, 09h
    call CMOS_WRITE_00_99

    xor ax, ax
    mov al, [IN_CENTURY]   ; e.g. 20 for 2026
    mov bl, 32h
    call CMOS_WRITE_00_99

    ; Restore Status B, but clear SET bit so the RTC resumes running.
    mov al, [CMOS_STATUS_B_OLD]
    or al, 02h              ; leave RTC in 24-hour mode
    and al, 7Fh             ; clear SET bit so clock resumes
    mov bl, 0Bh
    call WRITE_CMOS_REG

    popf
    pop dx
    pop cx
    pop bx
    pop ax
    ret
SET_CMOS_RTC_DIRECT_DATE_TIME ENDP

VERIFY_DOS_DATE PROC
    ; Returns AL=1 if DOS date now exactly matches incoming packet.
    push cx
    push dx
    mov ah, 2Ah
    int 21h                ; CX=year, DH=month, DL=day
    cmp cx, [IN_YEAR]
    jne VDD_FAIL
    cmp dh, [IN_MONTH]
    jne VDD_FAIL
    cmp dl, [IN_DAY]
    jne VDD_FAIL
    mov al, 1
    jmp VDD_DONE
VDD_FAIL:
    xor al, al
VDD_DONE:
    pop dx
    pop cx
    ret
VERIFY_DOS_DATE ENDP

APPLY_INCOMING_DATE_TIME PROC
    ; REV5: apply date/time through every useful path:
    ;   1) DOS date/time through INT 21h
    ;   2) verify DOS date immediately
    ;   3) BIOS RTC date/time through INT 1Ah when supported
    ;   4) direct AT CMOS RTC write for stubborn 286/386/AT systems
    ;   5) DOS date/time again, because DOS keeps its own running clock
    ; Returns AL=1 success, AL=0 fail.

    call SET_DOS_DATE_TIME
    cmp al, 1
    jne AIDT_FAIL

    call VERIFY_DOS_DATE
    cmp al, 1
    jne AIDT_FAIL

    call SET_BIOS_RTC_DATE_TIME
    call SET_CMOS_RTC_DIRECT_DATE_TIME

    ; Re-apply DOS system date/time after touching RTC hardware.
    call SET_DOS_DATE_TIME
    cmp al, 1
    jne AIDT_FAIL

    call VERIFY_DOS_DATE
    cmp al, 1
    jne AIDT_FAIL

    mov al, 1
    ret
AIDT_FAIL:
    xor al, al
    ret
APPLY_INCOMING_DATE_TIME ENDP

PROCESS_LINE PROC
    push ax
    push bx
    push cx
    push dx
    push si

    ; REV8: avoid long conditional jumps. TASM/8086 conditional
    ; branches are short only, so failed parses jump through nearby
    ; labels to a normal near JMP PL_BAD.
    ;
    ; REV3: tolerate leading junk characters before the T packet.
    ; Valid packet anywhere in the line: TYYYYMMDDHHMMSS[D/S]
    mov si, OFFSET RX_BUF

PL_FIND_T:
    lodsb
    cmp al, 0
    jne PL_NOT_END
    jmp PL_BAD

PL_NOT_END:
    cmp al, 'T'
    je PL_HAVE_T
    jmp PL_FIND_T

PL_HAVE_T:
    ; REV7/REV8: parse YYYY as CC + YY.
    ; DOS needs full 2026; AT CMOS normally stores year=26
    ; and, on many AT-class machines, century=20 in CMOS reg 32h.

    call PARSE2
    jnc PL_CC_OK
    jmp PL_BAD
PL_CC_OK:
    mov [IN_CENTURY], al

    call PARSE2
    jnc PL_YY_OK
    jmp PL_BAD
PL_YY_OK:
    mov [IN_YEAR2], al

    xor ax, ax
    mov al, [IN_CENTURY]
    mov bx, 100
    mul bx                  ; AX = century * 100
    xor bx, bx
    mov bl, [IN_YEAR2]
    add ax, bx              ; AX = full year, e.g. 2026
    mov [IN_YEAR], ax

    call PARSE2
    jnc PL_MONTH_OK
    jmp PL_BAD
PL_MONTH_OK:
    mov [IN_MONTH], al

    call PARSE2
    jnc PL_DAY_OK
    jmp PL_BAD
PL_DAY_OK:
    mov [IN_DAY], al

    call PARSE2
    jnc PL_HOUR_OK
    jmp PL_BAD
PL_HOUR_OK:
    mov [IN_HOUR], al

    call PARSE2
    jnc PL_MIN_OK
    jmp PL_BAD
PL_MIN_OK:
    mov [IN_MIN], al

    call PARSE2
    jnc PL_SEC_OK
    jmp PL_BAD
PL_SEC_OK:
    mov [IN_SEC], al

    ; Optional trailing DST flag from Windows.
    ; D = daylight-saving time active, S = standard time.
    ; DOS does not calculate DST; Windows sends already-correct local time.
    mov byte ptr [IN_DST], 0
    mov al, [si]
    cmp al, 'D'
    je PL_DST_ON
    cmp al, 'd'
    je PL_DST_ON
    jmp PL_DST_DONE

PL_DST_ON:
    mov byte ptr [IN_DST], 1

PL_DST_DONE:
    call APPLY_INCOMING_DATE_TIME
    cmp al, 1
    je PL_APPLY_OK
    jmp PL_DATE_FAILED

PL_APPLY_OK:
    inc word ptr [SYNC_COUNT]
    mov byte ptr [LAST_STATUS], 1
    call SEND_ACK_OK
    call DRAW_PC_PACKET
    call DRAW_STATUS
    call DRAW_COUNTS
    jmp PL_DONE

PL_DATE_FAILED:
    inc word ptr [BAD_COUNT]
    mov byte ptr [LAST_STATUS], 4
    call DRAW_PC_PACKET
    call DRAW_STATUS
    call DRAW_COUNTS
    jmp PL_DONE

PL_BAD:
    inc word ptr [BAD_COUNT]
    mov byte ptr [LAST_STATUS], 2
    call DRAW_STATUS
    call DRAW_COUNTS

PL_DONE:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
PROCESS_LINE ENDP

POLL_SERIAL PROC
    push ax
    push bx

PS_LOOP:
    call SERIAL_STATUS
    jnc PS_DONE
    call SERIAL_RX
    cmp al, 13
    je PS_EOL
    cmp al, 10
    je PS_EOL
    mov bl, [RX_LEN]
    cmp bl, 38
    jae PS_LOOP
    xor bh, bh
    mov [RX_BUF+bx], al
    inc byte ptr [RX_LEN]
    jmp PS_LOOP

PS_EOL:
    cmp byte ptr [RX_LEN], 0
    je PS_CLEAR
    xor bx, bx
    mov bl, [RX_LEN]
    mov byte ptr [RX_BUF+bx], 0
    inc word ptr [RX_COUNT]
    call PROCESS_LINE
PS_CLEAR:
    mov byte ptr [RX_LEN], 0
    mov byte ptr [RX_BUF], 0
    jmp PS_LOOP

PS_DONE:
    pop bx
    pop ax
    ret
POLL_SERIAL ENDP

; ================================================================
; SCREEN DRAWING
; ================================================================

DRAW_SCREEN PROC
    mov ax, 0003h
    int 10h

    mov dh, 0
    mov dl, 2
    mov si, OFFSET LINE1
    call PRINT_AT
    mov dh, 1
    mov dl, 9
    mov si, OFFSET TITLE_LINE
    call PRINT_AT
    mov dh, 2
    mov dl, 2
    mov si, OFFSET LINE1
    call PRINT_AT

    mov dh, 4
    mov dl, 5
    mov si, OFFSET LBL_CFG
    call PRINT_AT
    call DRAW_CONFIG

    mov dh, 6
    mov dl, 5
    mov si, OFFSET LBL_DOS
    call PRINT_AT

    mov dh, 7
    mov dl, 5
    mov si, OFFSET LBL_PC
    call PRINT_AT
    mov dh, 7
    mov dl, 23
    mov si, OFFSET TXT_NONE
    call PRINT_AT

    mov dh, 9
    mov dl, 5
    mov si, OFFSET LBL_STAT
    call PRINT_AT
    mov byte ptr [LAST_STATUS], 0
    call DRAW_STATUS

    mov dh, 11
    mov dl, 5
    mov si, OFFSET LBL_CNT
    call PRINT_AT
    call DRAW_COUNTS

    mov dh, 20
    mov dl, 2
    mov si, OFFSET LINE1
    call PRINT_AT
    mov dh, 21
    mov dl, 7
    mov si, OFFSET PROTO_LINE
    call PRINT_AT
    mov dh, 22
    mov dl, 18
    mov si, OFFSET KEY_LINE
    call PRINT_AT
    mov dh, 23
    mov dl, 2
    mov si, OFFSET LINE1
    call PRINT_AT
    ret
DRAW_SCREEN ENDP

DRAW_CONFIG PROC
    mov dh, 4
    mov dl, 15
    mov si, OFFSET TXT_COM
    call PRINT_AT
    mov ah, 02h
    mov dl, [CFG_COMNUM]
    add dl, '0'
    int 21h

    mov ah, 02h
    mov dl, ' '
    int 21h

    mov al, [CFG_BAUDCODE]
    cmp al, 1
    jne DC_2
    mov si, OFFSET TXT_BAUD1200
    jmp DC_PRINT
DC_2:
    cmp al, 2
    jne DC_3
    mov si, OFFSET TXT_BAUD2400
    jmp DC_PRINT
DC_3:
    cmp al, 3
    jne DC_4
    mov si, OFFSET TXT_BAUD4800
    jmp DC_PRINT
DC_4:
    mov si, OFFSET TXT_BAUD9600
DC_PRINT:
    mov dh, 4
    mov dl, 21
    call PRINT_AT
    ret
DRAW_CONFIG ENDP

DRAW_DOS_PACKET PROC
    push si
    mov dh, 6
    mov dl, 23
    mov cx, 20
    call CLEAR_EOL
    mov dh, 6
    mov dl, 23
    mov si, OFFSET PKT_BUF
    call PRINT_AT_Z
    pop si
    ret
DRAW_DOS_PACKET ENDP

DRAW_PC_PACKET PROC
    push si
    mov dh, 7
    mov dl, 23
    mov cx, 25
    call CLEAR_EOL
    mov dh, 7
    mov dl, 23
    mov si, OFFSET RX_BUF
    call PRINT_AT_Z
    pop si
    ret
DRAW_PC_PACKET ENDP

DRAW_STATUS PROC
    mov dh, 9
    mov dl, 13
    mov cx, 40
    call CLEAR_EOL
    mov al, [LAST_STATUS]
    cmp al, 1
    jne DS_NOT_SYNC
    mov si, OFFSET TXT_SYNC
    jmp DS_PRINT
DS_NOT_SYNC:
    cmp al, 2
    jne DS_NOT_BAD
    mov si, OFFSET TXT_BAD
    jmp DS_PRINT
DS_NOT_BAD:
    cmp al, 4
    jne DS_WAIT
    mov si, OFFSET TXT_DATEFAIL
    jmp DS_PRINT
DS_WAIT:
    cmp al, 3
    jne DS_WAIT2
    mov si, OFFSET TXT_SETUP
    jmp DS_PRINT
DS_WAIT2:
    mov si, OFFSET TXT_WAIT
DS_PRINT:
    mov dh, 9
    mov dl, 13
    call PRINT_AT
    ret
DRAW_STATUS ENDP

DRAW_COUNTS PROC
    mov dh, 11
    mov dl, 16
    mov cx, 55
    call CLEAR_EOL
    mov dh, 11
    mov dl, 16
    call GOTOXY
    mov ax, [RX_COUNT]
    call PRINT_WORD_DEC
    mov si, OFFSET LBL_TX
    mov dx, si
    call DOS_PRINT
    mov ax, [TX_COUNT]
    call PRINT_WORD_DEC
    mov si, OFFSET LBL_SYNC
    mov dx, si
    call DOS_PRINT
    mov ax, [SYNC_COUNT]
    call PRINT_WORD_DEC
    mov si, OFFSET LBL_BAD
    mov dx, si
    call DOS_PRINT
    mov ax, [BAD_COUNT]
    call PRINT_WORD_DEC
    ret
DRAW_COUNTS ENDP

PRINT_AT_Z PROC
    ; DH/DL position, SI zero-terminated string
    push ax
    push dx
    call GOTOXY
PAZ_LOOP:
    lodsb
    cmp al, 0
    je PAZ_DONE
    mov ah, 02h
    mov dl, al
    int 21h
    jmp PAZ_LOOP
PAZ_DONE:
    pop dx
    pop ax
    ret
PRINT_AT_Z ENDP

PRINT_WORD_DEC PROC
    ; AX unsigned word to current cursor
    push ax
    push bx
    push cx
    push dx
    push si
    mov si, OFFSET NUM_BUF+7
    mov byte ptr [si], '$'
    dec si
    cmp ax, 0
    jne PWD_LOOP
    mov byte ptr [si], '0'
    dec si
    jmp PWD_DONE
PWD_LOOP:
    xor dx, dx
    mov bx, 10
    div bx
    add dl, '0'
    mov [si], dl
    dec si
    cmp ax, 0
    jne PWD_LOOP
PWD_DONE:
    inc si
    mov dx, si
    call DOS_PRINT
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
PRINT_WORD_DEC ENDP

; ================================================================
; KEYBOARD
; ================================================================

CHECK_KEYS PROC
    push ax
    mov ah, 01h
    int 16h
    jnz CK_HAVE
    pop ax
    ret
CK_HAVE:
    mov ah, 00h
    int 16h
    cmp al, 'q'
    je CK_QUIT
    cmp al, 'Q'
    je CK_QUIT
    cmp al, 'c'
    je CK_SETUP
    cmp al, 'C'
    je CK_SETUP
    pop ax
    ret
CK_QUIT:
    mov byte ptr [QUIT_FLAG], 1
    pop ax
    ret
CK_SETUP:
    call ASK_SETUP
    call APPLY_CONFIG
    call SERIAL_INIT
    call DRAW_SCREEN
    mov byte ptr [LAST_STATUS], 3
    call DRAW_STATUS
    call SEND_HEARTBEAT
    pop ax
    ret
CHECK_KEYS ENDP

END START
