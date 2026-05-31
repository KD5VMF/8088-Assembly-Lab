; ================================================================
; HASHLIVE.ASM
;
; Live 8088 / 8086 DOS HASH benchmark
;
; Build:
;   TASM HASHLIVE
;   TLINK HASHLIVE
;
; Run:
;   HASHLIVE
;
; Controls:
;   R       = reset counters
;   Q / ESC = quit
;
; Notes:
;   - Uses normal VGA text mode 03h
;   - Direct writes to B800h text video RAM
;   - No disk writes
;   - 8088-safe / 8086-safe instructions only
;   - Custom HASH32 rolling mix benchmark
;   - One hash processes a 256-byte internal block
; ================================================================

.8086
JUMPS

.MODEL SMALL
.STACK 100h

HASH_BLOCK_SIZE EQU 256
HASHES_PER_CHUNK EQU 8

.DATA

ScreenAttr      DB 0Ah
TitleAttr       DB 0Ah
DimAttr         DB 02h
HotAttr         DB 0Eh

quitFlag        DB 0
spinIndex       DB 0

lastTick        DW 0

hashLo          DW 0ACE1h
hashHi          DW 1357h
saltLo          DW 2468h
saltHi          DW 0BEEFh

totalHashLo     DW 0
totalHashHi     DW 0
periodHashLo    DW 0
periodHashHi    DW 0
rateHashLo      DW 0
rateHashHi      DW 0

elapsedLo       DW 0
elapsedHi       DW 0

bytesTmpLo      DW 0
bytesTmpHi      DW 0

decNumLo        DW 0
decNumHi        DW 0
outRow          DB 0
outCol          DB 0
outWidth        DB 0
decStarted      DB 0
digitVal        DB 0

charTemp        DB 0

DataBuf         DB HASH_BLOCK_SIZE DUP(0)

Spinner         DB 124,47,45,92

DivHi           DW 03B9Ah,005F5h,00098h,0000Fh,00001h
                DW 00000h,00000h,00000h,00000h,00000h

DivLo           DW 0CA00h,0E100h,09680h,04240h,086A0h
                DW 02710h,003E8h,00064h,0000Ah,00001h

sTitle          DB 'LIVE HASH BENCHMARK - 8088 / 8086 REAL MODE',0
sSub            DB 'CUSTOM HASH32 MIXER - 256 BYTE BLOCKS - NO DISK WRITES',0

sLine1          DB '+------------------------------------------------------------------------------+',0
sLine2          DB '|                                                                              |',0
sLine3          DB '+------------------------------------------------------------------------------+',0

sHashSec        DB 'HASHES / SECOND :',0
sBytesSec       DB 'BYTES  / SECOND :',0
sTotalHash      DB 'TOTAL HASHES   :',0
sTotalBytes     DB 'TOTAL BYTES    :',0
sHashNow        DB 'LIVE HASH32    : 0x',0
sElapsed        DB 'ELAPSED SECONDS:',0
sBlock          DB 'BLOCK SIZE     : 256 BYTES PER HASH',0
sMode           DB 'ENGINE         : 8088 INTEGER ADD/XOR/ROTATE MIX',0
sKeys           DB 'R = RESET    Q / ESC = QUIT',0
sBarLabel       DB 'LIVE ACTIVITY:',0
sWork           DB 'DATA -> ADD -> XOR -> ROTATE -> MIX -> HASH',0

.CODE

start:
        mov ax, @data
        mov ds, ax

        ; Text mode 80x25
        mov ax, 0003h
        int 10h

        ; Hide cursor
        mov ah, 01h
        mov ch, 20h
        mov cl, 00h
        int 10h

        call ClearScreen
        call InitData
        call DrawStaticScreen
        call ResetBenchmark
        call UpdateScreen

MainLoop:
        mov cx, HASHES_PER_CHUNK

HashChunkLoop:
        call HashBlock
        loop HashChunkLoop

        call HandleKeys
        cmp byte ptr [quitFlag], 0
        jne ExitProgram

        call CheckSecond

        jmp MainLoop

ExitProgram:
        mov ax, 0003h
        int 10h

        mov ax, 4C00h
        int 21h

; ------------------------------------------------
; Initialize internal benchmark data buffer
; ------------------------------------------------
InitData PROC NEAR
        push ax
        push cx
        push di

        mov di, OFFSET DataBuf
        xor al, al
        mov cx, HASH_BLOCK_SIZE

ID_Loop:
        mov [di], al
        inc al
        inc di
        loop ID_Loop

        pop di
        pop cx
        pop ax
        ret
InitData ENDP

; ------------------------------------------------
; Reset benchmark counters and seed
; ------------------------------------------------
ResetBenchmark PROC NEAR
        push ax
        push cx
        push dx

        mov word ptr [hashLo], 0ACE1h
        mov word ptr [hashHi], 1357h
        mov word ptr [saltLo], 2468h
        mov word ptr [saltHi], 0BEEFh

        mov word ptr [totalHashLo], 0
        mov word ptr [totalHashHi], 0
        mov word ptr [periodHashLo], 0
        mov word ptr [periodHashHi], 0
        mov word ptr [rateHashLo], 0
        mov word ptr [rateHashHi], 0
        mov word ptr [elapsedLo], 0
        mov word ptr [elapsedHi], 0

        mov ah, 00h
        int 1Ah
        mov [lastTick], dx

        pop dx
        pop cx
        pop ax
        ret
ResetBenchmark ENDP

; ------------------------------------------------
; One HASH32 operation over 256-byte DataBuf
; ------------------------------------------------
HashBlock PROC NEAR
        push ax
        push bx
        push cx
        push dx
        push si
        push di

        mov bx, [hashLo]
        mov dx, [hashHi]

        mov si, OFFSET DataBuf
        mov cx, HASH_BLOCK_SIZE

HB_Loop:
        lodsb

        xor al, byte ptr [saltLo]
        xor ah, ah

        add bx, ax
        adc dx, 0

        ; 32-bit-ish rotate/mix using DX:BX
        shl bx, 1
        rcl dx, 1
        adc bx, 0

        mov ax, dx
        xor bx, ax

        add dx, 09E37h
        xor dx, bx

        loop HB_Loop

        mov [hashLo], bx
        mov [hashHi], dx

        ; Advance salt
        inc word ptr [saltLo]
        jnz HB_SaltOkay
        inc word ptr [saltHi]

HB_SaltOkay:
        ; Mutate one byte in the data buffer so the workload changes
        mov bx, [saltLo]
        and bx, 00FFh
        mov di, OFFSET DataBuf
        add di, bx

        mov al, byte ptr [hashLo]
        xor al, byte ptr [hashHi]
        xor al, byte ptr [saltHi]
        mov [di], al

        ; total hashes++
        inc word ptr [totalHashLo]
        jnz HB_TotalOkay
        inc word ptr [totalHashHi]

HB_TotalOkay:
        ; period hashes++
        inc word ptr [periodHashLo]
        jnz HB_PeriodOkay
        inc word ptr [periodHashHi]

HB_PeriodOkay:
        pop di
        pop si
        pop dx
        pop cx
        pop bx
        pop ax
        ret
HashBlock ENDP

; ------------------------------------------------
; Check BIOS timer. Update display about once per second.
; BIOS tick rate is about 18.2 Hz.
; ------------------------------------------------
CheckSecond PROC NEAR
        push ax
        push cx
        push dx

        mov ah, 00h
        int 1Ah

        mov ax, dx
        sub ax, [lastTick]

        cmp ax, 18
        jae CS_Update
        jmp CS_Done

CS_Update:
        mov [lastTick], dx

        ; rate = period hashes
        mov ax, [periodHashLo]
        mov [rateHashLo], ax
        mov ax, [periodHashHi]
        mov [rateHashHi], ax

        ; period = 0
        mov word ptr [periodHashLo], 0
        mov word ptr [periodHashHi], 0

        ; elapsed seconds++
        inc word ptr [elapsedLo]
        jnz CS_ElapsedOkay
        inc word ptr [elapsedHi]

CS_ElapsedOkay:
        inc byte ptr [spinIndex]
        call UpdateScreen

CS_Done:
        pop dx
        pop cx
        pop ax
        ret
CheckSecond ENDP

; ------------------------------------------------
; Keyboard handler
; ------------------------------------------------
HandleKeys PROC NEAR
        push ax

        mov ah, 01h
        int 16h
        jz HK_Done

        mov ah, 00h
        int 16h

        cmp al, 1Bh
        je HK_Quit

        cmp al, 'q'
        je HK_Quit
        cmp al, 'Q'
        je HK_Quit

        cmp al, 'r'
        je HK_Reset
        cmp al, 'R'
        je HK_Reset

        jmp HK_Done

HK_Quit:
        mov byte ptr [quitFlag], 1
        jmp HK_Done

HK_Reset:
        call ResetBenchmark
        call UpdateScreen

HK_Done:
        pop ax
        ret
HandleKeys ENDP

; ------------------------------------------------
; Draw static screen
; ------------------------------------------------
DrawStaticScreen PROC NEAR
        push ax
        push bx
        push dx
        push si

        mov bl, [ScreenAttr]

        mov dh, 0
        mov dl, 0
        mov si, OFFSET sLine1
        call PrintStringAt

        mov dh, 1
        mov dl, 0
        mov si, OFFSET sLine2
        call PrintStringAt

        mov dh, 2
        mov dl, 0
        mov si, OFFSET sLine3
        call PrintStringAt

        mov dh, 1
        mov dl, 17
        mov bl, [HotAttr]
        mov si, OFFSET sTitle
        call PrintStringAt

        mov dh, 3
        mov dl, 10
        mov bl, [DimAttr]
        mov si, OFFSET sSub
        call PrintStringAt

        mov dh, 5
        mov dl, 10
        mov bl, [ScreenAttr]
        mov si, OFFSET sHashSec
        call PrintStringAt

        mov dh, 6
        mov dl, 10
        mov si, OFFSET sBytesSec
        call PrintStringAt

        mov dh, 7
        mov dl, 10
        mov si, OFFSET sTotalHash
        call PrintStringAt

        mov dh, 8
        mov dl, 10
        mov si, OFFSET sTotalBytes
        call PrintStringAt

        mov dh, 9
        mov dl, 10
        mov si, OFFSET sHashNow
        call PrintStringAt

        mov dh, 10
        mov dl, 10
        mov si, OFFSET sElapsed
        call PrintStringAt

        mov dh, 12
        mov dl, 10
        mov si, OFFSET sBlock
        call PrintStringAt

        mov dh, 13
        mov dl, 10
        mov si, OFFSET sMode
        call PrintStringAt

        mov dh, 15
        mov dl, 10
        mov si, OFFSET sBarLabel
        call PrintStringAt

        mov dh, 18
        mov dl, 17
        mov bl, [DimAttr]
        mov si, OFFSET sWork
        call PrintStringAt

        mov dh, 22
        mov dl, 25
        mov bl, [HotAttr]
        mov si, OFFSET sKeys
        call PrintStringAt

        pop si
        pop dx
        pop bx
        pop ax
        ret
DrawStaticScreen ENDP

; ------------------------------------------------
; Update live numbers
; ------------------------------------------------
UpdateScreen PROC NEAR
        push ax
        push bx
        push cx
        push dx
        push si

        ; Spinner
        mov al, [spinIndex]
        and al, 03h
        xor ah, ah
        mov si, ax
        mov al, Spinner[si]
        mov dh, 1
        mov dl, 72
        mov bl, [HotAttr]
        call PrintCharAt

        ; hashes/sec
        mov ax, [rateHashLo]
        mov bx, [rateHashHi]
        mov dh, 5
        mov dl, 30
        mov cl, 16
        call PrintDec32Field

        ; bytes/sec = rate hashes * 256
        mov ax, [rateHashLo]
        mov bx, [rateHashHi]
        call MakeBytesFromHashes

        mov ax, [bytesTmpLo]
        mov bx, [bytesTmpHi]
        mov dh, 6
        mov dl, 30
        mov cl, 16
        call PrintDec32Field

        ; total hashes
        mov ax, [totalHashLo]
        mov bx, [totalHashHi]
        mov dh, 7
        mov dl, 30
        mov cl, 16
        call PrintDec32Field

        ; total bytes = total hashes * 256
        mov ax, [totalHashLo]
        mov bx, [totalHashHi]
        call MakeBytesFromHashes

        mov ax, [bytesTmpLo]
        mov bx, [bytesTmpHi]
        mov dh, 8
        mov dl, 30
        mov cl, 16
        call PrintDec32Field

        ; live hash hex
        mov ax, [hashHi]
        mov dh, 9
        mov dl, 31
        call PrintHexWordAt

        mov ax, [hashLo]
        mov dh, 9
        mov dl, 35
        call PrintHexWordAt

        ; elapsed seconds
        mov ax, [elapsedLo]
        mov bx, [elapsedHi]
        mov dh, 10
        mov dl, 30
        mov cl, 16
        call PrintDec32Field

        call DrawActivityBar

        pop si
        pop dx
        pop cx
        pop bx
        pop ax
        ret
UpdateScreen ENDP

; ------------------------------------------------
; Make bytesTmp = hashes * 256
; Input:
;   BX:AX = hash count
; Output:
;   bytesTmpHi:bytesTmpLo
; ------------------------------------------------
MakeBytesFromHashes PROC NEAR
        push ax
        push bx
        push cx
        push dx

        ; save original low word in DX
        mov dx, ax

        ; low result = low << 8
        mov cl, 8
        shl ax, cl
        mov [bytesTmpLo], ax

        ; high result = high << 8 OR originalLow >> 8
        mov ax, bx
        mov cl, 8
        shl ax, cl

        xor bx, bx
        mov bl, dh
        or ax, bx
        mov [bytesTmpHi], ax

        pop dx
        pop cx
        pop bx
        pop ax
        ret
MakeBytesFromHashes ENDP

; ------------------------------------------------
; Draw live activity bar based on changing hash
; ------------------------------------------------
DrawActivityBar PROC NEAR
        push ax
        push bx
        push cx
        push dx
        push di
        push es

        mov ax, 0B800h
        mov es, ax

        mov dh, 15
        mov dl, 25
        call CalcDI

        ; Clear 45 chars
        mov cx, 45
        mov ax, 0020h

DAB_Clear:
        mov es:[di], ax
        add di, 2
        loop DAB_Clear

        mov dh, 15
        mov dl, 25
        call CalcDI

        mov ax, [hashLo]
        xor ax, [hashHi]
        and ax, 003Fh

        cmp ax, 45
        jbe DAB_CountOkay
        mov ax, 45

DAB_CountOkay:
        mov cx, ax
        cmp cx, 0
        jne DAB_Fill
        mov cx, 1

DAB_Fill:
        mov al, 219
        mov ah, [ScreenAttr]

DAB_Loop:
        mov es:[di], ax
        add di, 2
        loop DAB_Loop

        pop es
        pop di
        pop dx
        pop cx
        pop bx
        pop ax
        ret
DrawActivityBar ENDP

; ------------------------------------------------
; Clear entire text screen
; ------------------------------------------------
ClearScreen PROC NEAR
        push ax
        push cx
        push di
        push es

        mov ax, 0B800h
        mov es, ax

        xor di, di
        mov ax, 0020h
        mov cx, 2000
        cld
        rep stosw

        pop es
        pop di
        pop cx
        pop ax
        ret
ClearScreen ENDP

; ------------------------------------------------
; Calculate text offset
; Input:
;   DH = row
;   DL = col
; Output:
;   DI = offset in B800h text memory
; ------------------------------------------------
CalcDI PROC NEAR
        push ax
        push bx
        push dx

        mov al, dh
        xor ah, ah
        mov bx, 160
        mul bx

        xor bh, bh
        mov bl, dl
        shl bx, 1

        add ax, bx
        mov di, ax

        pop dx
        pop bx
        pop ax
        ret
CalcDI ENDP

; ------------------------------------------------
; Print zero-terminated string at row/col
; Input:
;   DH = row
;   DL = col
;   DS:SI = string
;   BL = attribute
; ------------------------------------------------
PrintStringAt PROC NEAR
        push ax
        push bx
        push dx
        push si
        push di
        push es

        mov ax, 0B800h
        mov es, ax

        call CalcDI
        mov ah, bl

PSA_Loop:
        lodsb
        cmp al, 0
        je PSA_Done

        mov es:[di], ax
        add di, 2
        jmp PSA_Loop

PSA_Done:
        pop es
        pop di
        pop si
        pop dx
        pop bx
        pop ax
        ret
PrintStringAt ENDP

; ------------------------------------------------
; Print one character at row/col
; Input:
;   AL = char
;   DH = row
;   DL = col
;   BL = attribute
; ------------------------------------------------
PrintCharAt PROC NEAR
        push ax
        push bx
        push dx
        push di
        push es

        mov [charTemp], al

        mov ax, 0B800h
        mov es, ax

        call CalcDI

        mov al, [charTemp]
        mov ah, bl
        mov es:[di], ax

        pop es
        pop di
        pop dx
        pop bx
        pop ax
        ret
PrintCharAt ENDP

; ------------------------------------------------
; Print 32-bit unsigned decimal field
; Input:
;   BX:AX = number
;   DH = row
;   DL = col
;   CL = field width
; ------------------------------------------------
PrintDec32Field PROC NEAR
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push es

        mov [decNumLo], ax
        mov [decNumHi], bx
        mov [outRow], dh
        mov [outCol], dl
        mov [outWidth], cl

        mov ax, 0B800h
        mov es, ax

        call ClearFieldFromGlobals

        mov dh, [outRow]
        mov dl, [outCol]
        call CalcDI

        mov byte ptr [decStarted], 0

        xor si, si
        mov cx, 10

PD32_DivLoop:
        mov byte ptr [digitVal], 0

PD32_SubLoop:
        mov ax, [decNumHi]
        cmp ax, DivHi[si]
        jb PD32_DigitReady
        ja PD32_DoSub

        mov ax, [decNumLo]
        cmp ax, DivLo[si]
        jb PD32_DigitReady

PD32_DoSub:
        mov ax, [decNumLo]
        sub ax, DivLo[si]
        mov [decNumLo], ax

        mov ax, [decNumHi]
        sbb ax, DivHi[si]
        mov [decNumHi], ax

        inc byte ptr [digitVal]
        jmp PD32_SubLoop

PD32_DigitReady:
        mov al, [digitVal]

        cmp byte ptr [decStarted], 0
        jne PD32_PrintDigit

        cmp al, 0
        jne PD32_StartPrint

        cmp cx, 1
        jne PD32_SkipDigit

PD32_StartPrint:
        mov byte ptr [decStarted], 1

PD32_PrintDigit:
        add al, '0'
        mov ah, [ScreenAttr]
        mov es:[di], ax
        add di, 2

PD32_SkipDigit:
        add si, 2
        loop PD32_DivLoop

        pop es
        pop di
        pop si
        pop dx
        pop cx
        pop bx
        pop ax
        ret
PrintDec32Field ENDP

; ------------------------------------------------
; Clear field using outRow/outCol/outWidth
; ------------------------------------------------
ClearFieldFromGlobals PROC NEAR
        push ax
        push cx
        push dx
        push di

        mov dh, [outRow]
        mov dl, [outCol]
        call CalcDI

        xor ch, ch
        mov cl, [outWidth]
        mov ax, 0020h

CFG_Loop:
        mov es:[di], ax
        add di, 2
        loop CFG_Loop

        pop di
        pop dx
        pop cx
        pop ax
        ret
ClearFieldFromGlobals ENDP

; ------------------------------------------------
; Print 16-bit word as 4 hex digits
; Input:
;   AX = word
;   DH = row
;   DL = col
; ------------------------------------------------
PrintHexWordAt PROC NEAR
        push ax
        push bx
        push cx
        push dx
        push di
        push es

        mov bx, ax

        mov ax, 0B800h
        mov es, ax

        call CalcDI

        ; high byte, high nibble
        mov al, bh
        mov cl, 4
        shr al, cl
        call PutHexNibble

        ; high byte, low nibble
        mov al, bh
        and al, 0Fh
        call PutHexNibble

        ; low byte, high nibble
        mov al, bl
        mov cl, 4
        shr al, cl
        call PutHexNibble

        ; low byte, low nibble
        mov al, bl
        and al, 0Fh
        call PutHexNibble

        pop es
        pop di
        pop dx
        pop cx
        pop bx
        pop ax
        ret
PrintHexWordAt ENDP

; ------------------------------------------------
; Put one hex nibble at ES:DI
; Input:
;   AL = 0..15
; ------------------------------------------------
PutHexNibble PROC NEAR
        push ax

        and al, 0Fh
        cmp al, 9
        jbe PHN_Number

        add al, 7

PHN_Number:
        add al, '0'
        mov ah, [HotAttr]
        mov es:[di], ax
        add di, 2

        pop ax
        ret
PutHexNibble ENDP

END start
