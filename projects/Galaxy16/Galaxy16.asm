; ================================================================
; Galaxy16.asm
; 8088 / 8087 LIVE GALAXY MATH DISPLAY
;
; REV18:
;   - Does NOT change video mode at startup.
;   - Keeps REV15 table layout.
;   - Cleans up the top status box into fixed columns:
;
;       8087:YES    ENG:FPU     LAST:F      ACT:FPU MODE
;       FREE:639    RINGS:128   HID:006     RATE:528  OPS /
;
;   - Removes A/AUTO.
;   - Keeps F and I:
;       F = force 8087 FPU
;       I = force 8088 integer
;   - Hidden heavy work fixed at WORK_LEVEL = 2.
;   - No displayed AGE / FRAME / TIME growing fields.
;   - RATE shows estimated operations per second with dynamic units:
;       OPS, KOPS, or MOPS.
;   - Spinner/art moved closer to the RATE unit text.
;
; Build:
;   TASM Galaxy16
;   TLINK Galaxy16
;
; Output:
;   Galaxy16.EXE
; ================================================================

.8086
.8087
.MODEL TINY
.CODE
ORG 100h

VIDEO_SEG       EQU 0B800h
GREEN_ATTR      EQU 0Ah

MAX_RINGS       EQU 128
VISIBLE_RINGS   EQU 8

START:
    mov ax, cs
    mov ds, ax
    mov es, ax

    cli
    mov ss, ax
    mov sp, OFFSET STACK_TOP
    sti

    call SHRINK_DOS_BLOCK
    call PREP_TEXT_SCREEN_NO_MODE_CHANGE
    call DETECT_8087
    call DETECT_FREE_RAM
    call SELECT_START_MODE
    call CHOOSE_WORKLOAD
    call INIT_GALAXY

    call DRAW_STATIC_SCREEN
    call DRAW_STATUS
    call DRAW_STATS

MAIN_LOOP:
    call CHECK_KEYBOARD
    cmp byte ptr [QUIT_FLAG], 1
    je EXIT_PROGRAM

    inc word ptr [FRAME_COUNT]
    add word ptr [SIM_TIME100], 10

    mov word ptr [FRAME_ENERGY], 0
    mov word ptr [FRAME_VEL_SUM], 0
    mov word ptr [FRAME_RES_SUM], 0
    mov word ptr [FRAME_DARK_SUM], 0
    mov word ptr [MAX_VEL], 0

    mov ax, [OPS_LOW]
    mov [OPS_MARK_LOW], ax
    mov ax, [OPS_HIGH]
    mov [OPS_MARK_HIGH], ax

    call STEP_VISIBLE_ROWS
    call WORK_UNTIL_NEXT_TICK

    mov ax, [OPS_LOW]
    sub ax, [OPS_MARK_LOW]
    mov [OPS_TICK_LOW], ax
    mov ax, [OPS_HIGH]
    sbb ax, [OPS_MARK_HIGH]
    mov [OPS_TICK_HIGH], ax

    call DRAW_STATUS
    call DRAW_STATS

    jmp MAIN_LOOP

EXIT_PROGRAM:
    mov ah, 01h
    mov ch, 06h
    mov cl, 07h
    int 10h

    mov ax, 4C00h
    int 21h

; ================================================================
; DOS MEMORY BLOCK SHRINK
; ================================================================

SHRINK_DOS_BLOCK PROC
    push ax
    push bx
    push cx
    push es

    mov ax, cs
    mov es, ax

    mov bx, OFFSET PROGRAM_END
    add bx, 15
    mov cl, 4
    shr bx, cl

    mov ah, 4Ah
    int 21h

    pop es
    pop cx
    pop bx
    pop ax
    ret
SHRINK_DOS_BLOCK ENDP

; ================================================================
; SCREEN PREP - NO VIDEO MODE CHANGE
; ================================================================

PREP_TEXT_SCREEN_NO_MODE_CHANGE PROC
    ; No INT 10h AX=0003h.
    ; Keeps the current DOS text mode.

    mov ah, 01h
    mov ch, 20h
    mov cl, 00h
    int 10h

    mov ax, VIDEO_SEG
    mov es, ax
    xor di, di

    mov ah, GREEN_ATTR
    mov al, ' '
    mov cx, 2000
    cld
    rep stosw

    mov ax, cs
    mov es, ax
    ret
PREP_TEXT_SCREEN_NO_MODE_CHANGE ENDP

; ================================================================
; DIRECT VIDEO OUTPUT
; ================================================================

GET_SCREEN_OFFSET PROC
    ; DH = row
    ; DL = column
    ; DI = row*160 + col*2

    push ax
    push bx
    push cx
    push dx

    xor cx, cx
    mov cl, dl

    xor ax, ax
    mov al, dh
    mov bx, 160
    mul bx

    mov bx, cx
    shl bx, 1
    add ax, bx

    mov di, ax

    pop dx
    pop cx
    pop bx
    pop ax
    ret
GET_SCREEN_OFFSET ENDP

PUT_CHAR_AT PROC
    ; DH=row, DL=col, AL=char

    push ax
    push bx
    push es
    push di

    call GET_SCREEN_OFFSET

    mov bx, VIDEO_SEG
    mov es, bx

    mov ah, GREEN_ATTR
    stosw

    pop di
    pop es
    pop bx
    pop ax
    ret
PUT_CHAR_AT ENDP

PUT_STR_AT PROC
    ; DH=row, DL=col, SI=zero-terminated string

    push ax
    push bx
    push es
    push di
    push si

    call GET_SCREEN_OFFSET

    mov bx, VIDEO_SEG
    mov es, bx

PUT_STR_LOOP:
    lodsb
    cmp al, 0
    je PUT_STR_DONE

    mov ah, GREEN_ATTR
    stosw
    jmp PUT_STR_LOOP

PUT_STR_DONE:
    pop si
    pop di
    pop es
    pop bx
    pop ax
    ret
PUT_STR_AT ENDP

PUT_SPACES_AT PROC
    ; DH=row, DL=col, CX=count

    push ax
    push bx
    push es
    push di

    call GET_SCREEN_OFFSET

    mov bx, VIDEO_SEG
    mov es, bx

    mov ah, GREEN_ATTR
    mov al, ' '
    cld
    rep stosw

    pop di
    pop es
    pop bx
    pop ax
    ret
PUT_SPACES_AT ENDP

PUT_STR_FIELD_AT PROC
    ; DH=row, DL=col, SI=string, CX=field width

    push cx
    call PUT_SPACES_AT
    pop cx
    call PUT_STR_AT
    ret
PUT_STR_FIELD_AT ENDP

CENTER76_STR PROC
    ; Centers inside the 76-column frame starting at column 2.

    push ax
    push bx
    push cx
    push dx
    push di

    mov [CENTER_ROW], dh

    mov di, si
    xor cx, cx

CENTER76_LEN_LOOP:
    mov al, [di]
    cmp al, 0
    je CENTER76_LEN_DONE

    inc di
    inc cx
    jmp CENTER76_LEN_LOOP

CENTER76_LEN_DONE:
    mov ax, 76
    cmp cx, 76
    jb CENTER76_OK

    mov ax, 2
    jmp CENTER76_HAVE_COL

CENTER76_OK:
    sub ax, cx
    shr ax, 1
    add ax, 2

CENTER76_HAVE_COL:
    mov dh, [CENTER_ROW]
    mov dl, al
    call PUT_STR_AT

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
CENTER76_STR ENDP

; ================================================================
; NUMBER OUTPUT
; ================================================================

PUT_DEC_AT PROC
    ; DH=row, DL=col, AX=value, CL=field width
    ; Right-aligned decimal.

    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov [PD_VALUE], ax
    mov [PD_ROW], dh
    mov [PD_COL], dl
    mov [PD_WIDTH], cl

    xor ch, ch
    call PUT_SPACES_AT

    mov ax, [PD_VALUE]
    mov si, OFFSET NUM_BUF + 5
    mov byte ptr [si], 0
    dec si

    mov bx, 10
    mov byte ptr [DIGIT_COUNT], 0

    cmp ax, 0
    jne DEC_CONVERT_LOOP

    mov byte ptr [si], '0'
    dec si
    inc byte ptr [DIGIT_COUNT]
    jmp DEC_CONVERT_DONE

DEC_CONVERT_LOOP:
    xor dx, dx
    div bx
    add dl, '0'
    mov [si], dl
    dec si
    inc byte ptr [DIGIT_COUNT]
    cmp ax, 0
    jne DEC_CONVERT_LOOP

DEC_CONVERT_DONE:
    inc si

    mov dh, [PD_ROW]
    mov dl, [PD_COL]

    mov al, [PD_WIDTH]
    sub al, [DIGIT_COUNT]
    jbe DEC_NO_PAD

    add dl, al

DEC_NO_PAD:
    call GET_SCREEN_OFFSET

    mov bx, VIDEO_SEG
    mov es, bx

DEC_WRITE_LOOP:
    lodsb
    cmp al, 0
    je DEC_WRITE_DONE

    mov ah, GREEN_ATTR
    stosw
    jmp DEC_WRITE_LOOP

DEC_WRITE_DONE:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
PUT_DEC_AT ENDP

PUT_DEC_TIGHT_AT PROC
    ; DH=row, DL=col, AX=value, CL=max field width
    ; Left-aligned decimal, clears field first.

    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov [PD_VALUE], ax
    mov [PD_ROW], dh
    mov [PD_COL], dl
    mov [PD_WIDTH], cl

    xor ch, ch
    call PUT_SPACES_AT

    mov ax, [PD_VALUE]
    mov si, OFFSET NUM_BUF + 5
    mov byte ptr [si], 0
    dec si

    mov bx, 10
    mov byte ptr [DIGIT_COUNT], 0

    cmp ax, 0
    jne TD_CONVERT_LOOP

    mov byte ptr [si], '0'
    dec si
    inc byte ptr [DIGIT_COUNT]
    jmp TD_CONVERT_DONE

TD_CONVERT_LOOP:
    xor dx, dx
    div bx
    add dl, '0'
    mov [si], dl
    dec si
    inc byte ptr [DIGIT_COUNT]
    cmp ax, 0
    jne TD_CONVERT_LOOP

TD_CONVERT_DONE:
    inc si

    mov dh, [PD_ROW]
    mov dl, [PD_COL]
    call GET_SCREEN_OFFSET

    mov bx, VIDEO_SEG
    mov es, bx

TD_WRITE_LOOP:
    lodsb
    cmp al, 0
    je TD_WRITE_DONE

    mov ah, GREEN_ATTR
    stosw
    jmp TD_WRITE_LOOP

TD_WRITE_DONE:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
PUT_DEC_TIGHT_AT ENDP

PUT_DEC_ZERO_AT PROC
    ; DH=row, DL=col, AX=value, CL=field width
    ; Fixed-width zero-padded decimal.

    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov [PD_VALUE], ax
    mov [PD_ROW], dh
    mov [PD_COL], dl
    mov [PD_WIDTH], cl

    xor ch, ch
    call PUT_SPACES_AT

    mov ax, [PD_VALUE]
    mov si, OFFSET NUM_BUF + 5
    mov byte ptr [si], 0
    dec si

    mov bx, 10
    mov byte ptr [DIGIT_COUNT], 0

    cmp ax, 0
    jne ZD_CONVERT_LOOP

    mov byte ptr [si], '0'
    dec si
    inc byte ptr [DIGIT_COUNT]
    jmp ZD_CONVERT_DONE

ZD_CONVERT_LOOP:
    xor dx, dx
    div bx
    add dl, '0'
    mov [si], dl
    dec si
    inc byte ptr [DIGIT_COUNT]
    cmp ax, 0
    jne ZD_CONVERT_LOOP

ZD_CONVERT_DONE:
    inc si

    mov dh, [PD_ROW]
    mov dl, [PD_COL]
    call GET_SCREEN_OFFSET

    mov bx, VIDEO_SEG
    mov es, bx
    mov ah, GREEN_ATTR

    mov bl, [PD_WIDTH]
    sub bl, [DIGIT_COUNT]
    jbe ZD_WRITE_DIGITS

ZD_ZERO_LOOP:
    mov al, '0'
    stosw
    dec bl
    jnz ZD_ZERO_LOOP

ZD_WRITE_DIGITS:
    lodsb
    cmp al, 0
    je ZD_DONE

    mov ah, GREEN_ATTR
    stosw
    jmp ZD_WRITE_DIGITS

ZD_DONE:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
PUT_DEC_ZERO_AT ENDP

PUT_TWO_DIGITS_AT PROC
    ; DH=row, DL=col, AX=0..99

    push ax
    push bx
    push dx

    mov [P2_ROW], dh
    mov [P2_COL], dl

    xor dx, dx
    mov bx, 10
    div bx

    mov [P2_TENS], al
    mov [P2_ONES], dl

    mov dh, [P2_ROW]
    mov dl, [P2_COL]
    mov al, [P2_TENS]
    add al, '0'
    call PUT_CHAR_AT

    mov dh, [P2_ROW]
    mov dl, [P2_COL]
    inc dl
    mov al, [P2_ONES]
    add al, '0'
    call PUT_CHAR_AT

    pop dx
    pop bx
    pop ax
    ret
PUT_TWO_DIGITS_AT ENDP

PUT_FIXED2_AT PROC
    ; DH=row, DL=col, AX=value*100, CL=whole field width

    push ax
    push bx
    push cx
    push dx

    mov [PF_VALUE], ax
    mov [PF_ROW], dh
    mov [PF_COL], dl
    mov [PF_WIDTH], cl

    mov ax, [PF_VALUE]
    xor dx, dx
    mov bx, 100
    div bx

    mov [PF_FRAC], dx

    mov dh, [PF_ROW]
    mov dl, [PF_COL]
    mov cl, [PF_WIDTH]
    call PUT_DEC_AT

    mov dh, [PF_ROW]
    mov dl, [PF_COL]
    mov cl, [PF_WIDTH]
    add dl, cl
    mov al, '.'
    call PUT_CHAR_AT

    mov ax, [PF_FRAC]
    mov dh, [PF_ROW]
    mov dl, [PF_COL]
    mov cl, [PF_WIDTH]
    add dl, cl
    inc dl
    call PUT_TWO_DIGITS_AT

    pop dx
    pop cx
    pop bx
    pop ax
    ret
PUT_FIXED2_AT ENDP

PUT_MODE_AT PROC
    ; DH/DL position

    push ax
    push cx
    push si

    mov cx, 3
    call PUT_SPACES_AT

    cmp byte ptr [MATH_MODE], 1
    je PUT_MODE_FPU

PUT_MODE_INT:
    mov si, OFFSET MODE_INT_STR
    call PUT_STR_AT
    jmp PUT_MODE_DONE

PUT_MODE_FPU:
    mov si, OFFSET MODE_FPU_STR
    call PUT_STR_AT

PUT_MODE_DONE:
    pop si
    pop cx
    pop ax
    ret
PUT_MODE_AT ENDP

PUT_YN_AT PROC
    ; DH/DL position, AL=0 no, nonzero yes

    push ax
    push cx
    push si

    mov [YN_TEMP], al

    mov cx, 3
    call PUT_SPACES_AT

    cmp byte ptr [YN_TEMP], 0
    jne PUT_YES

PUT_NO:
    mov si, OFFSET NO_STR
    call PUT_STR_AT
    jmp PUT_YN_DONE

PUT_YES:
    mov si, OFFSET YES_STR
    call PUT_STR_AT

PUT_YN_DONE:
    pop si
    pop cx
    pop ax
    ret
PUT_YN_AT ENDP

PUT_ACTION_AT PROC
    push cx
    push dx
    push si

    ; ACT value starts after ACT:
    ; ACT:FPU MODE
    mov dh, 5
    mov dl, 62
    mov cx, 14

    mov al, [ACTION_CODE]

    cmp al, 2
    jne ACT_NOT_FPU
    mov si, OFFSET ACTION_FPU
    jmp ACT_DRAW

ACT_NOT_FPU:
    cmp al, 3
    jne ACT_NOT_INT
    mov si, OFFSET ACTION_INT
    jmp ACT_DRAW

ACT_NOT_INT:
    cmp al, 6
    jne ACT_IDLE
    mov si, OFFSET ACTION_NOFPU
    jmp ACT_DRAW

ACT_IDLE:
    mov si, OFFSET ACTION_IDLE

ACT_DRAW:
    call PUT_STR_FIELD_AT

    pop si
    pop dx
    pop cx
    ret
PUT_ACTION_AT ENDP

; ================================================================
; STATIC SCREEN
; ================================================================

DRAW_STATIC_SCREEN PROC
    mov dh, 0
    mov dl, 2
    mov si, OFFSET LINE76
    call PUT_STR_AT

    mov dh, 1
    mov si, OFFSET TITLE_STR
    call CENTER76_STR

    mov dh, 2
    mov si, OFFSET SUBTITLE_STR
    call CENTER76_STR

    mov dh, 3
    mov dl, 2
    mov si, OFFSET LINE76
    call PUT_STR_AT

    ; Four clean fixed status columns:
    ;
    ; 8087:YES    ENG:FPU     LAST:F      ACT:FPU MODE
    ; FREE:639    RINGS:128   HID:006     RATE:528  OPS /

    mov dh, 5
    mov dl, 18
    mov si, OFFSET S8087
    call PUT_STR_AT

    mov dh, 5
    mov dl, 32
    mov si, OFFSET SENG
    call PUT_STR_AT

    mov dh, 5
    mov dl, 45
    mov si, OFFSET SLAST
    call PUT_STR_AT

    mov dh, 5
    mov dl, 58
    mov si, OFFSET SACTION
    call PUT_STR_AT

    mov dh, 6
    mov dl, 18
    mov si, OFFSET SFREE
    call PUT_STR_AT

    mov dh, 6
    mov dl, 32
    mov si, OFFSET SRINGS
    call PUT_STR_AT

    mov dh, 6
    mov dl, 45
    mov si, OFFSET SHID
    call PUT_STR_AT

    mov dh, 6
    mov dl, 58
    mov si, OFFSET SRATE
    call PUT_STR_AT

    mov dh, 8
    mov si, OFFSET TABLE_TITLE
    call CENTER76_STR

    ; Header stays where REV15 looked good.
    mov dh, 10
    mov dl, 5
    mov si, OFFSET TABLE_HEAD1
    call PUT_STR_AT

    mov dh, 11
    mov dl, 2
    mov si, OFFSET LINE76
    call PUT_STR_AT

    mov dh, 20
    mov dl, 2
    mov si, OFFSET LINE76
    call PUT_STR_AT

    mov dh, 21
    mov dl, 7
    mov si, OFFSET SAVG
    call PUT_STR_AT

    mov dh, 21
    mov dl, 17
    mov si, OFFSET SMAX
    call PUT_STR_AT

    mov dh, 21
    mov dl, 27
    mov si, OFFSET SENERGY
    call PUT_STR_AT

    mov dh, 21
    mov dl, 38
    mov si, OFFSET SRES
    call PUT_STR_AT

    mov dh, 21
    mov dl, 51
    mov si, OFFSET SDMIX
    call PUT_STR_AT

    mov dh, 21
    mov dl, 64
    mov si, OFFSET SENG
    call PUT_STR_AT

    mov dh, 22
    mov si, OFFSET FORMULA_LABEL
    call CENTER76_STR

    mov dh, 23
    mov si, OFFSET KEYS_LABEL
    call CENTER76_STR

    ret
DRAW_STATIC_SCREEN ENDP

; ================================================================
; STATUS / STATS DRAWING
; ================================================================

DRAW_STATUS PROC
    ; Row 5 values.

    mov dh, 5
    mov dl, 23
    mov al, [HAS_8087]
    call PUT_YN_AT

    mov dh, 5
    mov dl, 36
    call PUT_MODE_AT

    mov dh, 5
    mov dl, 50
    mov al, [LAST_KEY]
    call PUT_CHAR_AT

    call PUT_ACTION_AT

    ; Row 6 values.

    mov dh, 6
    mov dl, 23
    mov ax, [FREE_KB]
    mov cl, 4
    call PUT_DEC_TIGHT_AT

    mov dh, 6
    mov dl, 38
    mov ax, [ACTIVE_RINGS]
    mov cl, 3
    call PUT_DEC_TIGHT_AT

    mov dh, 6
    mov dl, 49
    mov ax, [HIDDEN_INDEX]
    mov cl, 3
    call PUT_DEC_ZERO_AT

    call DRAW_RATE

    ; Spinner after the dynamic rate field.
    mov bx, [SPINNER_INDEX]
    and bx, 0003h
    mov al, [SPINNER_CHARS + bx]
    mov dh, 6
    mov dl, 73
    call PUT_CHAR_AT

    inc word ptr [SPINNER_INDEX]

    ret
DRAW_STATUS ENDP

DRAW_RATE PROC
    ; Convert ring-calculation steps per BIOS timer tick into an
    ; estimated per-second rate. The PC BIOS timer is about 18.2 Hz.
    ;
    ; If below 1000/sec, show raw OPS.
    ; If below 1,000,000/sec, show integer KOPS.
    ; Otherwise show integer MOPS.

    push ax
    push bx
    push cx
    push dx
    push si

    ; Clear the whole live field: value, space, unit, and spare blanks.
    mov dh, 6
    mov dl, 63
    mov cx, 11
    call PUT_SPACES_AT

    mov dx, [OPS_TICK_HIGH]
    mov ax, [OPS_TICK_LOW]

    cmp dx, 0
    jne RATE_USE_MOPS

    ; 55 operations per tick is about 1000 operations per second.
    cmp ax, 55
    jae RATE_CHECK_KOPS

RATE_USE_OPS:
    ; OPS/sec ~= OPS/tick * 18.2
    ; Use integer approximation: OPS*18 + OPS/5.
    mov bx, ax
    mov cx, 18
    mul cx
    mov cx, ax
    mov ax, bx
    xor dx, dx
    mov bx, 5
    div bx
    add ax, cx
    mov si, OFFSET UNIT_OPS
    jmp RATE_DRAW_VALUE

RATE_CHECK_KOPS:
    ; 54,945 operations per tick is about 1,000,000/sec.
    cmp ax, 54945
    jae RATE_USE_MOPS

RATE_USE_KOPS:
    ; KOPS ~= OPS/tick * 18.2 / 1000
    ;      ~= OPS/tick * 182 / 10000
    mov bx, 182
    mul bx
    mov bx, 10000
    div bx
    cmp ax, 0
    jne RATE_KOPS_NONZERO
    mov ax, 1
RATE_KOPS_NONZERO:
    mov si, OFFSET UNIT_KOPS
    jmp RATE_DRAW_VALUE

RATE_USE_MOPS:
    ; MOPS ~= OPS/tick / 54,945.
    ; Works for very fast DOS PCs/emulators too, because the operation
    ; counter is now 32-bit. Cap the display if the 32/16 divide would
    ; overflow an 8086 quotient.
    mov dx, [OPS_TICK_HIGH]
    mov ax, [OPS_TICK_LOW]
    mov bx, 54945
    cmp dx, bx
    jb RATE_MOPS_DIVIDE
    mov ax, 65535
    jmp RATE_MOPS_READY
RATE_MOPS_DIVIDE:
    div bx
    cmp ax, 0
    jne RATE_MOPS_READY
    mov ax, 1
RATE_MOPS_READY:
    mov si, OFFSET UNIT_MOPS

RATE_DRAW_VALUE:
    mov dh, 6
    mov dl, 63
    mov cl, 5
    call PUT_DEC_TIGHT_AT

    mov dh, 6
    mov dl, 69
    call PUT_STR_AT

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
DRAW_RATE ENDP

DRAW_STATS PROC
    mov dh, 21
    mov dl, 11
    mov ax, [AVG_VEL]
    mov cl, 5
    call PUT_DEC_TIGHT_AT

    mov dh, 21
    mov dl, 21
    mov ax, [MAX_VEL]
    mov cl, 5
    call PUT_DEC_TIGHT_AT

    mov dh, 21
    mov dl, 29
    mov ax, [FRAME_ENERGY]
    mov cl, 7
    call PUT_DEC_TIGHT_AT

    mov dh, 21
    mov dl, 42
    mov ax, [FRAME_RES_SUM]
    mov cl, 6
    call PUT_DEC_TIGHT_AT

    mov dh, 21
    mov dl, 56
    mov ax, [FRAME_DARK_SUM]
    mov cl, 6
    call PUT_DEC_TIGHT_AT

    mov dh, 21
    mov dl, 68
    call PUT_MODE_AT

    ret
DRAW_STATS ENDP

; ================================================================
; LIVE VISIBLE ROWS
; ================================================================

STEP_VISIBLE_ROWS PROC
    mov word ptr [DISPLAY_INDEX], 0
    mov byte ptr [SCREEN_ROW], 12

VISIBLE_LOOP:
    cmp word ptr [DISPLAY_INDEX], VISIBLE_RINGS
    jb VISIBLE_BODY
    jmp VISIBLE_DONE

VISIBLE_BODY:
    call GET_SAMPLE_RING_OFFSET

    mov ax, [SAMPLE_OFFSET]
    mov [CURRENT_OFFSET], ax

    mov si, [CURRENT_OFFSET]
    call STEP_ONE_RING

    mov si, [CURRENT_OFFSET]

    mov ax, [FRAME_VEL_SUM]
    add ax, [VEL_NOW + si]
    mov [FRAME_VEL_SUM], ax

    mov ax, [FRAME_ENERGY]
    add ax, [ENERGY_NOW + si]
    mov [FRAME_ENERGY], ax

    mov ax, [FRAME_RES_SUM]
    add ax, [RES_NOW + si]
    mov [FRAME_RES_SUM], ax

    mov ax, [FRAME_DARK_SUM]
    add ax, [DARK_M10 + si]
    add ax, [GAS_M10 + si]
    mov [FRAME_DARK_SUM], ax

    mov ax, [VEL_NOW + si]
    cmp ax, [MAX_VEL]
    jbe MAX_OK
    mov [MAX_VEL], ax

MAX_OK:
    call DRAW_ONE_ROW
    call CHECK_KEYBOARD

    inc word ptr [DISPLAY_INDEX]
    inc byte ptr [SCREEN_ROW]

    jmp VISIBLE_LOOP

VISIBLE_DONE:
    mov ax, [FRAME_VEL_SUM]
    xor dx, dx
    mov bx, VISIBLE_RINGS
    div bx
    mov [AVG_VEL], ax

    ret
STEP_VISIBLE_ROWS ENDP

DRAW_ONE_ROW PROC
    ; REV18 keeps REV15 table alignment and keeps the spinner close to RATE units.

    mov ax, [SAMPLE_RING_NUM]
    inc ax
    mov dh, [SCREEN_ROW]
    mov dl, 5
    mov cl, 3
    call PUT_DEC_AT

    mov si, [CURRENT_OFFSET]
    mov ax, [RADIUS10 + si]
    mov bx, 10
    mul bx

    mov dh, [SCREEN_ROW]
    mov dl, 9
    mov cl, 3
    call PUT_FIXED2_AT

    mov si, [CURRENT_OFFSET]
    mov ax, [BAR_M10 + si]
    mov dh, [SCREEN_ROW]
    mov dl, 16
    mov cl, 3
    call PUT_DEC_AT

    mov si, [CURRENT_OFFSET]
    mov ax, [DARK_M10 + si]
    mov dh, [SCREEN_ROW]
    mov dl, 21
    mov cl, 3
    call PUT_DEC_AT

    mov si, [CURRENT_OFFSET]
    mov ax, [GAS_M10 + si]
    mov dh, [SCREEN_ROW]
    mov dl, 26
    mov cl, 3
    call PUT_DEC_AT

    mov si, [CURRENT_OFFSET]
    mov ax, [RATIO100 + si]
    mov dh, [SCREEN_ROW]
    mov dl, 32
    mov cl, 2
    call PUT_FIXED2_AT

    mov si, [CURRENT_OFFSET]
    mov ax, [SQRT100 + si]
    mov dh, [SCREEN_ROW]
    mov dl, 38
    mov cl, 2
    call PUT_FIXED2_AT

    mov si, [CURRENT_OFFSET]
    mov ax, [VEL_NOW + si]
    mov dh, [SCREEN_ROW]
    mov dl, 44
    mov cl, 4
    call PUT_DEC_AT

    mov si, [CURRENT_OFFSET]
    mov ax, [ESC_NOW + si]
    mov dh, [SCREEN_ROW]
    mov dl, 50
    mov cl, 4
    call PUT_DEC_AT

    mov si, [CURRENT_OFFSET]
    mov ax, [PER_NOW + si]
    mov dh, [SCREEN_ROW]
    mov dl, 56
    mov cl, 5
    call PUT_DEC_AT

    mov si, [CURRENT_OFFSET]
    mov ax, [ENERGY_NOW + si]
    mov dh, [SCREEN_ROW]
    mov dl, 64
    mov cl, 5
    call PUT_DEC_AT

    mov si, [CURRENT_OFFSET]
    mov ax, [PHASE100 + si]
    xor dx, dx
    mov bx, 100
    div bx

    mov dh, [SCREEN_ROW]
    mov dl, 72
    mov cl, 3
    call PUT_DEC_AT

    ret
DRAW_ONE_ROW ENDP

GET_SAMPLE_RING_OFFSET PROC
    ; sample = DISPLAY_INDEX * (ACTIVE_RINGS - 1) / 7

    push ax
    push bx
    push dx

    mov ax, [DISPLAY_INDEX]

    mov bx, [ACTIVE_RINGS]
    cmp bx, 1
    ja SAMPLE_COUNT_OK
    mov bx, 1

SAMPLE_COUNT_OK:
    dec bx
    mul bx

    mov bx, 7
    div bx

    mov [SAMPLE_RING_NUM], ax

    shl ax, 1
    mov [SAMPLE_OFFSET], ax

    pop dx
    pop bx
    pop ax
    ret
GET_SAMPLE_RING_OFFSET ENDP

; ================================================================
; BACKGROUND WORK
; ================================================================

WORK_UNTIL_NEXT_TICK PROC
    mov ah, 00h
    int 1Ah
    mov [LAST_TICK], dx

WORK_TICK_LOOP:
    call CHECK_KEYBOARD
    cmp byte ptr [QUIT_FLAG], 1
    je WORK_DONE

    call STEP_HIDDEN_RING

    mov ah, 00h
    int 1Ah

    cmp dx, [LAST_TICK]
    jne WORK_DONE

    jmp WORK_TICK_LOOP

WORK_DONE:
    ret
WORK_UNTIL_NEXT_TICK ENDP

STEP_HIDDEN_RING PROC
    mov ax, [HIDDEN_INDEX]
    cmp ax, [ACTIVE_RINGS]
    jb HIDDEN_INDEX_OK

    xor ax, ax
    mov [HIDDEN_INDEX], ax

HIDDEN_INDEX_OK:
    shl ax, 1
    mov si, ax
    call STEP_ONE_RING

    inc word ptr [HIDDEN_INDEX]

    ret
STEP_HIDDEN_RING ENDP

STEP_ONE_RING PROC
    cmp byte ptr [MATH_MODE], 1
    je STEP_ONE_8087

STEP_ONE_FIXED:
    call CALC_RING_FIXED
    jmp STEP_ONE_COMMON

STEP_ONE_8087:
    call CALC_RING_8087

STEP_ONE_COMMON:
    call UPDATE_PHASE
    call EXTRA_MATH_LOAD
    call HEAVY_WORK_LOAD

    inc word ptr [OPS_LOW]
    jnz OPS_COUNT_DONE
    inc word ptr [OPS_HIGH]

OPS_COUNT_DONE:
    ret
STEP_ONE_RING ENDP

; ================================================================
; HEAVY WORK LOAD
; ================================================================

HEAVY_WORK_LOAD PROC
    mov cx, [WORK_LEVEL]

HW_LOOP:
    cmp byte ptr [MATH_MODE], 1
    je HW_USE_FPU

HW_USE_INT:
    call HEAVY_INT_MATH
    jmp HW_NEXT

HW_USE_FPU:
    call HEAVY_FPU_MATH

HW_NEXT:
    dec cx
    jz HW_DONE
    jmp HW_LOOP

HW_DONE:
    ret
HEAVY_WORK_LOAD ENDP

HEAVY_INT_MATH PROC
    push ax
    push bx
    push dx

    mov ax, [VEL_NOW + si]
    add ax, [SHEAR_NOW + si]
    add ax, [DENSITY_NOW + si]
    add ax, [RES_NOW + si]
    add ax, [DARK_M10 + si]
    add ax, [GAS_M10 + si]
    add ax, [SIM_TIME100]

    xor dx, dx
    mov bx, 997
    div bx

    mov [RES_NOW + si], dx

    mov ax, [ENERGY_NOW + si]
    add ax, dx
    add ax, [SHEAR_NOW + si]
    add ax, [GAS_M10 + si]

    xor dx, dx
    mov bx, 60000
    div bx

    mov [ENERGY_NOW + si], dx

    pop dx
    pop bx
    pop ax
    ret
HEAVY_INT_MATH ENDP

HEAVY_FPU_MATH PROC
    push ax
    push bx
    push dx

    fild word ptr [VEL_NOW + si]
    fimul word ptr [SHEAR_NOW + si]
    fidiv word ptr [K400]
    fiadd word ptr [DENSITY_NOW + si]
    fistp word ptr [HEAVY_TEMP]

    mov ax, [HEAVY_TEMP]
    add ax, [RES_NOW + si]
    add ax, [SIM_TIME100]

    xor dx, dx
    mov bx, 997
    div bx

    mov [RES_NOW + si], dx

    mov ax, [ENERGY_NOW + si]
    add ax, dx
    add ax, [GAS_M10 + si]

    xor dx, dx
    mov bx, 60000
    div bx

    mov [ENERGY_NOW + si], dx

    pop dx
    pop bx
    pop ax
    ret
HEAVY_FPU_MATH ENDP

; ================================================================
; KEYBOARD
; ================================================================

CHECK_KEYBOARD PROC
    mov ah, 01h
    int 16h
    jnz CK_HAVE_KEY
    ret

CK_HAVE_KEY:
    mov ah, 00h
    int 16h

    cmp al, 27
    jne CK_NOT_ESC
    jmp CK_SET_QUIT

CK_NOT_ESC:
    cmp al, 'q'
    jne CK_NOT_Q_LOW
    jmp CK_SET_QUIT

CK_NOT_Q_LOW:
    cmp al, 'Q'
    jne CK_NOT_Q_HIGH
    jmp CK_SET_QUIT

CK_NOT_Q_HIGH:
    cmp al, 'i'
    jne CK_NOT_I_LOW
    jmp CK_SET_INT

CK_NOT_I_LOW:
    cmp al, 'I'
    jne CK_NOT_I_HIGH
    jmp CK_SET_INT

CK_NOT_I_HIGH:
    cmp al, 'f'
    jne CK_NOT_F_LOW
    jmp CK_SET_FPU

CK_NOT_F_LOW:
    cmp al, 'F'
    jne CK_NOT_F_HIGH
    jmp CK_SET_FPU

CK_NOT_F_HIGH:
    ret

CK_SET_QUIT:
    mov byte ptr [LAST_KEY], 'Q'
    mov byte ptr [ACTION_CODE], 0
    mov byte ptr [QUIT_FLAG], 1
    ret

CK_SET_INT:
    mov byte ptr [LAST_KEY], 'I'
    mov byte ptr [MATH_MODE], 0
    mov byte ptr [ACTION_CODE], 3
    jmp CK_REFRESH

CK_SET_FPU:
    mov byte ptr [LAST_KEY], 'F'
    cmp byte ptr [HAS_8087], 1
    jne CK_FPU_FAIL

    mov byte ptr [MATH_MODE], 1
    mov byte ptr [ACTION_CODE], 2
    jmp CK_REFRESH

CK_FPU_FAIL:
    mov byte ptr [ACTION_CODE], 6
    jmp CK_REFRESH

CK_REFRESH:
    call DRAW_STATUS
    call DRAW_STATS
    ret
CHECK_KEYBOARD ENDP

; ================================================================
; 8087 DETECTION / MODE
; ================================================================

DETECT_8087 PROC
    mov word ptr [FPU_CW], 0FFFFh

    fninit
    fnstcw word ptr [FPU_CW]

    mov ax, [FPU_CW]
    cmp ax, 0FFFFh
    je NO_8087_FOUND

    mov byte ptr [HAS_8087], 1
    ret

NO_8087_FOUND:
    mov byte ptr [HAS_8087], 0
    ret
DETECT_8087 ENDP

SELECT_START_MODE PROC
    cmp byte ptr [HAS_8087], 1
    je START_USE_FPU

START_USE_INT:
    mov byte ptr [MATH_MODE], 0
    ret

START_USE_FPU:
    mov byte ptr [MATH_MODE], 1
    ret
SELECT_START_MODE ENDP

; ================================================================
; FREE RAM / WORKLOAD
; ================================================================

DETECT_FREE_RAM PROC
    mov ah, 48h
    mov bx, 0FFFFh
    int 21h

    mov ax, bx
    mov cl, 6
    shr ax, cl
    mov [FREE_KB], ax

    cmp ax, 0
    jne FREE_RAM_DONE

    int 12h
    mov [FREE_KB], ax

FREE_RAM_DONE:
    ret
DETECT_FREE_RAM ENDP

CHOOSE_WORKLOAD PROC
    mov ax, [FREE_KB]

    cmp ax, 64
    jb WORKLOAD_32

    cmp ax, 160
    jb WORKLOAD_64

    cmp ax, 320
    jb WORKLOAD_96

WORKLOAD_128:
    mov word ptr [ACTIVE_RINGS], 128
    ret

WORKLOAD_96:
    mov word ptr [ACTIVE_RINGS], 96
    ret

WORKLOAD_64:
    mov word ptr [ACTIVE_RINGS], 64
    ret

WORKLOAD_32:
    mov word ptr [ACTIVE_RINGS], 32
    ret
CHOOSE_WORKLOAD ENDP

; ================================================================
; INIT GALAXY
; ================================================================

INIT_GALAXY PROC
    push bp

    xor si, si
    mov cx, [ACTIVE_RINGS]

INIT_RING_LOOP:
    mov ax, si
    shr ax, 1
    mov bx, ax

    ; Radius10 = 10 + ring * 5
    ; Stored as kpc*10.
    mov ax, bx
    mov dx, 5
    mul dx
    add ax, 10
    mov [RADIUS10 + si], ax

    ; BAR_M10 = 3 + radius10/10 + ring/8
    mov ax, [RADIUS10 + si]
    xor dx, dx
    mov bp, 10
    div bp
    add ax, 3

    mov dx, bx
    shr dx, 1
    shr dx, 1
    shr dx, 1
    add ax, dx
    mov [BAR_M10 + si], ax

    ; DARK_M10 = 1 + radius10/20 + ring/5
    mov ax, [RADIUS10 + si]
    xor dx, dx
    mov bp, 20
    div bp
    add ax, 1

    push ax
    mov ax, bx
    xor dx, dx
    mov bp, 5
    div bp
    mov bp, ax
    pop ax

    add ax, bp
    mov [DARK_M10 + si], ax

    ; GAS_M10 = 8 - ring/16, minimum 1
    mov ax, bx
    mov bp, 16
    xor dx, dx
    div bp
    mov bp, ax

    mov ax, 8
    cmp bp, 7
    jae GAS_MINIMUM
    sub ax, bp
    jmp GAS_DONE

GAS_MINIMUM:
    mov ax, 1

GAS_DONE:
    mov [GAS_M10 + si], ax

    ; Total mass.
    mov ax, [BAR_M10 + si]
    add ax, [DARK_M10 + si]
    add ax, [GAS_M10 + si]
    mov [TOTAL_M10 + si], ax

    ; Initial phase.
    mov ax, bx
    mov dx, 281
    mul dx
    mov [PHASE100 + si], ax

    mov word ptr [RATIO100 + si], 0
    mov word ptr [SQRT100 + si], 0
    mov word ptr [VEL_NOW + si], 0
    mov word ptr [ESC_NOW + si], 0
    mov word ptr [PER_NOW + si], 1
    mov word ptr [PHASE_INC + si], 0
    mov word ptr [ENERGY_NOW + si], 0
    mov word ptr [DRIFT_NOW + si], 0
    mov word ptr [DENSITY_NOW + si], 0
    mov word ptr [SHEAR_NOW + si], 0
    mov word ptr [RES_NOW + si], 0

    add si, 2

    dec cx
    jz INIT_DONE
    jmp INIT_RING_LOOP

INIT_DONE:
    pop bp
    ret
INIT_GALAXY ENDP

; ================================================================
; 8087 MATH
; ================================================================

CALC_RING_8087 PROC
    fild word ptr [TOTAL_M10 + si]
    fimul word ptr [K1000]
    fidiv word ptr [RADIUS10 + si]
    fistp word ptr [RATIO100 + si]

    fild word ptr [TOTAL_M10 + si]
    fimul word ptr [TEN]
    fidiv word ptr [RADIUS10 + si]
    fsqrt
    fimul word ptr [K100]
    fistp word ptr [SQRT100 + si]

    fild word ptr [SQRT100 + si]
    fimul word ptr [K2074]
    fidiv word ptr [K1000]
    fistp word ptr [VEL_NOW + si]

    cmp word ptr [VEL_NOW + si], 1
    jae FPU_VEL_OK
    mov word ptr [VEL_NOW + si], 1

FPU_VEL_OK:
    fild word ptr [VEL_NOW + si]
    fimul word ptr [K141]
    fidiv word ptr [K100]
    fistp word ptr [ESC_NOW + si]

    fild word ptr [RADIUS10 + si]
    fimul word ptr [K6148]
    fidiv word ptr [TEN]
    fidiv word ptr [VEL_NOW + si]
    fistp word ptr [PER_NOW + si]

    cmp word ptr [PER_NOW + si], 1
    jae FPU_PER_OK
    mov word ptr [PER_NOW + si], 1

FPU_PER_OK:
    fild word ptr [TOTAL_M10 + si]
    fimul word ptr [K1000]
    fidiv word ptr [RADIUS10 + si]
    fistp word ptr [DENSITY_NOW + si]

    fild word ptr [VEL_NOW + si]
    fimul word ptr [VEL_NOW + si]
    fidiv word ptr [RADIUS10 + si]
    fistp word ptr [ENERGY_NOW + si]

    fild word ptr [VEL_NOW + si]
    fimul word ptr [K100]
    fidiv word ptr [RADIUS10 + si]
    fistp word ptr [SHEAR_NOW + si]

    ret
CALC_RING_8087 ENDP

; ================================================================
; 8088 INTEGER FALLBACK MATH
; ================================================================

CALC_RING_FIXED PROC
    mov ax, [TOTAL_M10 + si]
    mov bx, 1000
    mul bx

    mov bx, [RADIUS10 + si]
    cmp bx, 0
    jne FIX_RATIO_DIV_OK
    mov bx, 1

FIX_RATIO_DIV_OK:
    div bx
    mov [RATIO100 + si], ax

    mov ax, [RATIO100 + si]
    mov bx, 100
    mul bx
    mov [SQRT_INPUT], ax

    call ISQRT16
    mov [SQRT100 + si], ax

    mov ax, [SQRT100 + si]
    mov bx, 2074
    mul bx

    mov bx, 1000
    div bx

    cmp ax, 1
    jae FIX_VEL_OK
    mov ax, 1

FIX_VEL_OK:
    mov [VEL_NOW + si], ax

    mov ax, [VEL_NOW + si]
    mov bx, 141
    mul bx

    mov bx, 100
    div bx
    mov [ESC_NOW + si], ax

    mov ax, [RADIUS10 + si]
    mov bx, 614
    mul bx

    mov bx, [VEL_NOW + si]
    cmp bx, 0
    jne FIX_PERIOD_DIV_OK
    mov bx, 1

FIX_PERIOD_DIV_OK:
    div bx

    cmp ax, 1
    jae FIX_PERIOD_OK
    mov ax, 1

FIX_PERIOD_OK:
    mov [PER_NOW + si], ax

    mov ax, [TOTAL_M10 + si]
    mov bx, 1000
    mul bx

    mov bx, [RADIUS10 + si]
    cmp bx, 0
    jne FIX_DENSITY_DIV_OK
    mov bx, 1

FIX_DENSITY_DIV_OK:
    div bx
    mov [DENSITY_NOW + si], ax

    mov ax, [VEL_NOW + si]
    mov bx, ax
    mul bx

    mov bx, [RADIUS10 + si]
    cmp bx, 0
    jne FIX_ENERGY_DIV_OK
    mov bx, 1

FIX_ENERGY_DIV_OK:
    div bx
    mov [ENERGY_NOW + si], ax

    mov ax, [VEL_NOW + si]
    mov bx, 100
    mul bx

    mov bx, [RADIUS10 + si]
    cmp bx, 0
    jne FIX_SHEAR_DIV_OK
    mov bx, 1

FIX_SHEAR_DIV_OK:
    div bx
    mov [SHEAR_NOW + si], ax

    ret
CALC_RING_FIXED ENDP

ISQRT16 PROC
    push bx
    push dx

    xor bx, bx

SQRT_LOOP:
    inc bx

    mov ax, bx
    mul bx

    cmp dx, 0
    jne SQRT_TOO_BIG

    cmp ax, [SQRT_INPUT]
    jbe SQRT_LOOP

SQRT_TOO_BIG:
    dec bx
    mov ax, bx

    pop dx
    pop bx
    ret
ISQRT16 ENDP

; ================================================================
; EXTRA MATH / PHASE
; ================================================================

EXTRA_MATH_LOAD PROC
    push ax
    push bx
    push dx

    mov bx, [PER_NOW + si]
    cmp bx, 1
    jae PHI_PERIOD_OK
    mov bx, 1

PHI_PERIOD_OK:
    mov ax, 36000
    xor dx, dx
    div bx
    mov [PHASE_INC + si], ax

    mov ax, [PHASE100 + si]
    xor dx, dx
    mov bx, 100
    div bx

    add ax, [DENSITY_NOW + si]
    add ax, [SHEAR_NOW + si]

    mov bx, [GAS_M10 + si]
    add ax, bx
    add ax, bx
    add ax, bx

    mov bx, [DARK_M10 + si]
    add ax, bx
    add ax, bx

    add ax, [SIM_TIME100]

    mov bx, si
    shr bx, 1
    add ax, bx

    xor dx, dx
    mov bx, 1000
    div bx

    mov [RES_NOW + si], dx
    mov [DRIFT_NOW + si], dx

    mov ax, [ENERGY_NOW + si]
    add ax, dx
    add ax, [GAS_M10 + si]

    xor dx, dx
    mov bx, 60000
    div bx

    mov [ENERGY_NOW + si], dx

    pop dx
    pop bx
    pop ax
    ret
EXTRA_MATH_LOAD ENDP

UPDATE_PHASE PROC
    mov ax, [PHASE_INC + si]
    cmp ax, 0
    jne HAVE_PHASE_INC

    mov bx, [PER_NOW + si]
    cmp bx, 1
    jae PHASE_PERIOD_OK
    mov bx, 1

PHASE_PERIOD_OK:
    mov ax, 36000
    xor dx, dx
    div bx

HAVE_PHASE_INC:
    add [PHASE100 + si], ax

WRAP_PHASE:
    cmp word ptr [PHASE100 + si], 36000
    jb PHASE_DONE

    sub word ptr [PHASE100 + si], 36000
    jmp WRAP_PHASE

PHASE_DONE:
    ret
UPDATE_PHASE ENDP

; ================================================================
; STRINGS
; ================================================================

LINE76          db '----------------------------------------------------------------------------',0

TITLE_STR       db 'GALAXY MATH 88 REV18',0
SUBTITLE_STR    db '8088 / 8087 REAL GALAXY RING CALCULATIONS',0
TABLE_TITLE     db 'LIVE GALACTIC ORBIT RING MONITOR',0

S8087           db '8087:',0
SENG            db 'ENG:',0
SLAST           db 'LAST:',0
SACTION         db 'ACT:',0

SFREE           db 'FREE:',0
SRINGS          db 'RINGS:',0
SHID            db 'HID:',0
SRATE           db 'RATE:',0

SAVG            db 'AVG:',0
SMAX            db 'MAX:',0
SENERGY         db 'E:',0
SRES            db 'RES:',0
SDMIX           db 'DMIX:',0

TABLE_HEAD1     db 'RG  R.kpc  BAR  DRK  GAS   M/R   ROOT  VCIR  VESC  PERIOD  ENERGY  TH',0

FORMULA_LABEL   db 'V=207.4*SQRT((BAR+DRK+GAS)/R)   VESC=1.41*V   P=6148*R/V',0
KEYS_LABEL      db 'F=FPU        I=INT        Q/ESC=QUIT',0

MODE_FPU_STR    db 'FPU',0
MODE_INT_STR    db 'INT',0
YES_STR         db 'YES',0
NO_STR          db 'NO ',0

ACTION_IDLE     db 'READY',0
ACTION_FPU      db 'FPU MODE',0
ACTION_INT      db 'INT MODE',0
ACTION_NOFPU    db 'NO 8087',0

SPINNER_CHARS   db '|/-\',0

UNIT_OPS        db 'OPS ',0
UNIT_KOPS       db 'KOPS',0
UNIT_MOPS       db 'MOPS',0

; ================================================================
; TEMP VARIABLES
; ================================================================

PD_VALUE        dw 0
PD_ROW          db 0
PD_COL          db 0
PD_WIDTH        db 0

PF_VALUE        dw 0
PF_ROW          db 0
PF_COL          db 0
PF_WIDTH        db 0
PF_FRAC         dw 0

P2_ROW          db 0
P2_COL          db 0
P2_TENS         db 0
P2_ONES         db 0

YN_TEMP         db 0
CENTER_ROW      db 0

DIGIT_COUNT     db 0
NUM_BUF         db 6 dup(0)

; ================================================================
; MAIN VARIABLES
; ================================================================

HAS_8087        db 0
MATH_MODE       db 0
QUIT_FLAG       db 0
LAST_KEY        db '-'
ACTION_CODE     db 0

FPU_CW          dw 0FFFFh
FREE_KB         dw 0
ACTIVE_RINGS    dw 64

SIM_TIME100     dw 0
FRAME_COUNT     dw 0
LAST_TICK       dw 0

DISPLAY_INDEX   dw 0
SCREEN_ROW      db 0
SAMPLE_RING_NUM dw 0
SAMPLE_OFFSET   dw 0
CURRENT_OFFSET  dw 0

HIDDEN_INDEX    dw 0
SPINNER_INDEX   dw 0
WORK_LEVEL      dw 2

OPS_LOW         dw 0
OPS_HIGH        dw 0
OPS_MARK_LOW    dw 0
OPS_MARK_HIGH   dw 0
OPS_TICK_LOW    dw 0
OPS_TICK_HIGH   dw 0

FRAME_ENERGY    dw 0
FRAME_VEL_SUM   dw 0
FRAME_RES_SUM   dw 0
FRAME_DARK_SUM  dw 0
AVG_VEL         dw 0
MAX_VEL         dw 0

SQRT_INPUT      dw 0
HEAVY_TEMP      dw 0

TEN             dw 10
K100            dw 100
K141            dw 141
K400            dw 400
K1000           dw 1000
K2074           dw 2074
K6148           dw 6148

; ================================================================
; GALAXY ARRAYS
; ================================================================

RADIUS10        dw MAX_RINGS dup(0)

BAR_M10         dw MAX_RINGS dup(0)
DARK_M10        dw MAX_RINGS dup(0)
GAS_M10         dw MAX_RINGS dup(0)
TOTAL_M10       dw MAX_RINGS dup(0)

RATIO100        dw MAX_RINGS dup(0)
SQRT100         dw MAX_RINGS dup(0)

VEL_NOW         dw MAX_RINGS dup(0)
ESC_NOW         dw MAX_RINGS dup(0)
PER_NOW         dw MAX_RINGS dup(0)
PHASE100        dw MAX_RINGS dup(0)
PHASE_INC       dw MAX_RINGS dup(0)

ENERGY_NOW      dw MAX_RINGS dup(0)
DRIFT_NOW       dw MAX_RINGS dup(0)
DENSITY_NOW     dw MAX_RINGS dup(0)
SHEAR_NOW       dw MAX_RINGS dup(0)
RES_NOW         dw MAX_RINGS dup(0)

STACK_AREA      db 512 dup(0)
STACK_TOP       LABEL WORD

PROGRAM_END     LABEL BYTE

END START
