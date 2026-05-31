; ================================================================
; ASTROM88.ASM
; 8088 / 8087 LIVE ASTROPHYSICS DATA SIMULATOR
;
; REV1:
;   - Text-only green data screen, no graphics.
;   - Does NOT change video mode at startup.
;   - Uses direct B800h text video RAM for low flicker.
;   - No disk writes while running.
;   - Detects 8087 and starts in FPU mode if found.
;   - F = force 8087 FPU math, I = force 8088 integer math.
;   - Q or ESC quits.
;   - Shows real orbital-mechanics inspired math:
;
;       V    = 29.78 * SQRT(M / R)
;       ESC  = 42.10 * SQRT(M / R)
;       P    = 2980 * R / V
;
;     where:
;       M = central mass in solar masses
;       R = orbital radius in AU
;       V = circular orbital speed in km/s
;       ESC = escape speed in km/s
;       P = orbital period in Earth years
;
;   - The visible body mass column is in Earth masses.
;     The orbit math uses the central mass column internally.
;     REV1 uses 1.000 solar mass for all rows.
;
; Build:
;   TASM ASTROM88
;   TLINK ASTROM88
;
; Output:
;   ASTROM88.EXE
;
; IMPORTANT:
;   On a real 286/386 without an x87 coprocessor, some systems may
;   fault when probing for an FPU. Use ASTRO88I.ASM for a guaranteed
;   integer-only build on machines without an 80287/80387.
; ================================================================

.8086
.8087
.MODEL TINY
.CODE
ORG 100h

VIDEO_SEG       EQU 0B800h
GREEN_ATTR      EQU 0Ah

MAX_BODIES      EQU 16
VISIBLE_BODIES  EQU 8

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
    call INIT_ASTRO

    call DRAW_STATIC_SCREEN
    call DRAW_STATUS
    call DRAW_STATS

MAIN_LOOP:
    call CHECK_KEYBOARD
    cmp byte ptr [QUIT_FLAG], 1
    je EXIT_PROGRAM

    inc word ptr [FRAME_COUNT]
    add word ptr [SIM_TIME100], 1

    mov word ptr [FRAME_VEL_SUM], 0
    mov word ptr [FRAME_G_SUM], 0
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
    ; No INT 10h AX=0003h.  Keeps current DOS text mode.

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
    ; DH=row, DL=column, result DI=row*160+col*2
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
    ; Centers inside 76-column frame starting at column 2.
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
    ; DH=row, DL=col, AX=value, CL=field width, right aligned
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
    ; DH=row, DL=col, AX=value, CL=max field width, left aligned
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
    ; DH=row, DL=col, AX=value, CL=field width, zero padded
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

PUT_FIXED2_AT PROC
    ; DH=row, DL=col, AX=value*100, CL=whole-number field width
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
    mov cl, 2
    call PUT_DEC_ZERO_AT

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

YN_DONE_LABEL:
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

    ; Status rows.
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
    mov si, OFFSET SBODIES
    call PUT_STR_AT

    mov dh, 6
    mov dl, 45
    mov si, OFFSET SSTEP
    call PUT_STR_AT

    mov dh, 6
    mov dl, 58
    mov si, OFFSET SRATE
    call PUT_STR_AT

    mov dh, 8
    mov si, OFFSET TABLE_TITLE
    call CENTER76_STR

    mov dh, 10
    mov dl, 3
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
    mov dl, 18
    mov si, OFFSET SMAX
    call PUT_STR_AT

    mov dh, 21
    mov dl, 29
    mov si, OFFSET SGAVG
    call PUT_STR_AT

    mov dh, 21
    mov dl, 44
    mov si, OFFSET SENG
    call PUT_STR_AT

    mov dh, 21
    mov dl, 56
    mov si, OFFSET SFORM
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
    mov dl, 39
    mov ax, [ACTIVE_BODIES]
    mov cl, 3
    call PUT_DEC_TIGHT_AT

    mov dh, 6
    mov dl, 50
    mov ax, [FRAME_COUNT]
    mov cl, 4
    call PUT_DEC_TIGHT_AT

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
    ; Convert completed body calculations per BIOS timer tick into
    ; estimated calculations per second. PC BIOS timer is about 18.2 Hz.
    push ax
    push bx
    push cx
    push dx
    push si

    mov dh, 6
    mov dl, 63
    mov cx, 11
    call PUT_SPACES_AT

    mov dx, [OPS_TICK_HIGH]
    mov ax, [OPS_TICK_LOW]

    cmp dx, 0
    jne RATE_USE_MOPS

    cmp ax, 55
    jae RATE_CHECK_KOPS

RATE_USE_OPS:
    ; OPS/sec ~= OPS/tick * 18.2 = OPS*18 + OPS/5
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
    cmp ax, 54945
    jae RATE_USE_MOPS

RATE_USE_KOPS:
    ; KOPS ~= OPS/tick * 182 / 10000
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
    ; MOPS ~= OPS/tick / 54945
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
    mov cl, 2
    call PUT_FIXED2_AT

    mov dh, 21
    mov dl, 22
    mov ax, [MAX_VEL]
    mov cl, 2
    call PUT_FIXED2_AT

    mov dh, 21
    mov dl, 35
    mov ax, [AVG_GIDX]
    mov cl, 4
    call PUT_DEC_TIGHT_AT

    mov dh, 21
    mov dl, 48
    call PUT_MODE_AT

    mov dh, 21
    mov dl, 62
    mov ax, [ACTIVE_BODIES]
    mov cl, 3
    call PUT_DEC_TIGHT_AT

    ret
DRAW_STATS ENDP

; ================================================================
; LIVE VISIBLE ROWS
; ================================================================

STEP_VISIBLE_ROWS PROC
    mov word ptr [DISPLAY_INDEX], 0
    mov byte ptr [SCREEN_ROW], 12

VISIBLE_LOOP:
    cmp word ptr [DISPLAY_INDEX], VISIBLE_BODIES
    jb VISIBLE_BODY
    jmp VISIBLE_DONE

VISIBLE_BODY:
    call GET_SAMPLE_BODY_OFFSET

    mov ax, [SAMPLE_OFFSET]
    mov [CURRENT_OFFSET], ax

    mov si, [CURRENT_OFFSET]
    call STEP_ONE_BODY

    mov si, [CURRENT_OFFSET]

    mov ax, [FRAME_VEL_SUM]
    add ax, [VEL100 + si]
    mov [FRAME_VEL_SUM], ax

    mov ax, [FRAME_G_SUM]
    add ax, [GIDX + si]
    mov [FRAME_G_SUM], ax

    mov ax, [VEL100 + si]
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
    mov bx, VISIBLE_BODIES
    div bx
    mov [AVG_VEL], ax

    mov ax, [FRAME_G_SUM]
    xor dx, dx
    mov bx, VISIBLE_BODIES
    div bx
    mov [AVG_GIDX], ax

    ret
STEP_VISIBLE_ROWS ENDP

DRAW_ONE_ROW PROC
    ; ID column.
    mov ax, [SAMPLE_BODY_NUM]
    inc ax
    mov dh, [SCREEN_ROW]
    mov dl, 3
    mov cl, 2
    call PUT_DEC_AT

    ; BODY name.
    mov bx, [SAMPLE_BODY_NUM]
    shl bx, 1
    mov si, [BODY_NAME_TABLE + bx]
    mov dh, [SCREEN_ROW]
    mov dl, 7
    mov cx, 8
    call PUT_STR_FIELD_AT

    ; Body mass in Earth masses, value*100.
    mov si, [CURRENT_OFFSET]
    mov ax, [BODY_MASS100 + si]
    mov dh, [SCREEN_ROW]
    mov dl, 16
    mov cl, 3
    call PUT_FIXED2_AT

    ; Orbit radius in AU, value*100.
    mov si, [CURRENT_OFFSET]
    mov ax, [RADIUS100 + si]
    mov dh, [SCREEN_ROW]
    mov dl, 24
    mov cl, 2
    call PUT_FIXED2_AT

    ; Circular orbital velocity in km/s, value*100.
    mov si, [CURRENT_OFFSET]
    mov ax, [VEL100 + si]
    mov dh, [SCREEN_ROW]
    mov dl, 32
    mov cl, 2
    call PUT_FIXED2_AT

    ; Escape velocity in km/s, value*100.
    mov si, [CURRENT_OFFSET]
    mov ax, [ESC100 + si]
    mov dh, [SCREEN_ROW]
    mov dl, 40
    mov cl, 2
    call PUT_FIXED2_AT

    ; Period in Earth years, value*100.
    mov si, [CURRENT_OFFSET]
    mov ax, [PERIOD100 + si]
    mov dh, [SCREEN_ROW]
    mov dl, 49
    mov cl, 3
    call PUT_FIXED2_AT

    ; Simplified gravity index.
    mov si, [CURRENT_OFFSET]
    mov ax, [GIDX + si]
    mov dh, [SCREEN_ROW]
    mov dl, 60
    mov cl, 4
    call PUT_DEC_AT

    ; State.
    mov si, [CURRENT_OFFSET]
    mov ax, [VEL100 + si]
    cmp ax, [ESC100 + si]
    jb DRAW_STATE_BOUND
    mov si, OFFSET STATE_ESC
    jmp DRAW_STATE

DRAW_STATE_BOUND:
    mov si, OFFSET STATE_BOUND

DRAW_STATE:
    mov dh, [SCREEN_ROW]
    mov dl, 66
    mov cx, 5
    call PUT_STR_FIELD_AT

    ; Phase angle in degrees.
    mov si, [CURRENT_OFFSET]
    mov ax, [PHASE100 + si]
    xor dx, dx
    mov bx, 100
    div bx
    mov dh, [SCREEN_ROW]
    mov dl, 73
    mov cl, 3
    call PUT_DEC_AT

    ret
DRAW_ONE_ROW ENDP

GET_SAMPLE_BODY_OFFSET PROC
    ; sample = DISPLAY_INDEX * (ACTIVE_BODIES - 1) / 7
    push ax
    push bx
    push dx

    mov ax, [DISPLAY_INDEX]
    mov bx, [ACTIVE_BODIES]
    cmp bx, 1
    ja SAMPLE_COUNT_OK
    mov bx, 1

SAMPLE_COUNT_OK:
    dec bx
    mul bx
    mov bx, 7
    div bx

    mov [SAMPLE_BODY_NUM], ax
    shl ax, 1
    mov [SAMPLE_OFFSET], ax

    pop dx
    pop bx
    pop ax
    ret
GET_SAMPLE_BODY_OFFSET ENDP

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

    call STEP_HIDDEN_BODY

    mov ah, 00h
    int 1Ah
    cmp dx, [LAST_TICK]
    jne WORK_DONE

    jmp WORK_TICK_LOOP

WORK_DONE:
    ret
WORK_UNTIL_NEXT_TICK ENDP

STEP_HIDDEN_BODY PROC
    mov ax, [HIDDEN_INDEX]
    cmp ax, [ACTIVE_BODIES]
    jb HIDDEN_INDEX_OK
    xor ax, ax
    mov [HIDDEN_INDEX], ax

HIDDEN_INDEX_OK:
    shl ax, 1
    mov si, ax
    call STEP_ONE_BODY
    inc word ptr [HIDDEN_INDEX]
    ret
STEP_HIDDEN_BODY ENDP

STEP_ONE_BODY PROC
    cmp byte ptr [MATH_MODE], 1
    je STEP_ONE_8087

STEP_ONE_FIXED:
    call CALC_BODY_FIXED
    jmp STEP_ONE_COMMON

STEP_ONE_8087:
    call CALC_BODY_8087

STEP_ONE_COMMON:
    call UPDATE_PHASE
    call EXTRA_ASTRO_LOAD

    inc word ptr [OPS_LOW]
    jnz OPS_COUNT_DONE
    inc word ptr [OPS_HIGH]

OPS_COUNT_DONE:
    ret
STEP_ONE_BODY ENDP

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
; FREE RAM
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

; ================================================================
; INIT ASTRO DATA
; ================================================================

INIT_ASTRO PROC
    mov word ptr [ACTIVE_BODIES], MAX_BODIES
    xor si, si
    mov cx, MAX_BODIES

INIT_ASTRO_LOOP:
    mov word ptr [MRATIO100 + si], 0
    mov word ptr [SQRT100 + si], 0
    mov word ptr [VEL100 + si], 0
    mov word ptr [ESC100 + si], 0
    mov word ptr [PERIOD100 + si], 1
    mov word ptr [GIDX + si], 0
    mov word ptr [PHASE_INC + si], 0

    add si, 2
    loop INIT_ASTRO_LOOP

    ret
INIT_ASTRO ENDP

; ================================================================
; 8087 ASTRO MATH
; ================================================================

CALC_BODY_8087 PROC
    ; MRATIO100 = (M/R) * 100
    ; M is CENTRAL_MASS1000 / 1000 solar masses.
    ; R is RADIUS100 / 100 AU.
    ; Result = CENTRAL_MASS1000 * 10 / RADIUS100.

    fild word ptr [CENTRAL_MASS1000 + si]
    fimul word ptr [K10]
    fidiv word ptr [RADIUS100 + si]
    fistp word ptr [MRATIO100 + si]

    ; SQRT100 = SQRT(M/R) * 100
    ; Result = SQRT(CENTRAL_MASS1000 * 1000 / RADIUS100)

    fild word ptr [CENTRAL_MASS1000 + si]
    fimul word ptr [K1000]
    fidiv word ptr [RADIUS100 + si]
    fsqrt
    fistp word ptr [SQRT100 + si]

    ; VEL100 = 29.78 * SQRT(M/R) * 100

    fild word ptr [SQRT100 + si]
    fimul word ptr [K2978]
    fidiv word ptr [K100]
    fistp word ptr [VEL100 + si]

    cmp word ptr [VEL100 + si], 1
    jae FPU_VEL_OK
    mov word ptr [VEL100 + si], 1

FPU_VEL_OK:
    ; ESC100 = 42.10 * SQRT(M/R) * 100

    fild word ptr [SQRT100 + si]
    fimul word ptr [K4210]
    fidiv word ptr [K100]
    fistp word ptr [ESC100 + si]

    ; PERIOD100 = 2980 * RADIUS100 / VEL100
    ; This produces years*100 for a 1 solar mass circular orbit.

    fild word ptr [RADIUS100 + si]
    fimul word ptr [K2980]
    fidiv word ptr [VEL100 + si]
    fistp word ptr [PERIOD100 + si]

    cmp word ptr [PERIOD100 + si], 1
    jae FPU_PER_OK
    mov word ptr [PERIOD100 + si], 1

FPU_PER_OK:
    ; Keep this one integer-like so INT and FPU screens compare nicely.
    call CALC_GIDX_FIXED

    ret
CALC_BODY_8087 ENDP

; ================================================================
; 8088 INTEGER FALLBACK ASTRO MATH
; ================================================================

CALC_BODY_FIXED PROC
    ; MRATIO100 = CENTRAL_MASS1000 * 10 / RADIUS100.
    mov ax, [CENTRAL_MASS1000 + si]
    mov bx, 10
    mul bx

    mov bx, [RADIUS100 + si]
    cmp bx, 0
    jne FIX_RATIO_DIV_OK
    mov bx, 1

FIX_RATIO_DIV_OK:
    div bx
    mov [MRATIO100 + si], ax

    ; SQRT_INPUT = CENTRAL_MASS1000 * 1000 / RADIUS100.
    mov ax, [CENTRAL_MASS1000 + si]
    mov bx, 1000
    mul bx

    mov bx, [RADIUS100 + si]
    cmp bx, 0
    jne FIX_SQRT_DIV_OK
    mov bx, 1

FIX_SQRT_DIV_OK:
    div bx
    mov [SQRT_INPUT], ax

    call ISQRT16
    mov [SQRT100 + si], ax

    ; VEL100 = SQRT100 * 2978 / 100.
    mov ax, [SQRT100 + si]
    mov bx, 2978
    mul bx
    mov bx, 100
    div bx

    cmp ax, 1
    jae FIX_VEL_OK
    mov ax, 1

FIX_VEL_OK:
    mov [VEL100 + si], ax

    ; ESC100 = SQRT100 * 4210 / 100.
    mov ax, [SQRT100 + si]
    mov bx, 4210
    mul bx
    mov bx, 100
    div bx
    mov [ESC100 + si], ax

    ; PERIOD100 = RADIUS100 * 2980 / VEL100.
    mov ax, [RADIUS100 + si]
    mov bx, 2980
    mul bx

    mov bx, [VEL100 + si]
    cmp bx, 0
    jne FIX_PERIOD_DIV_OK
    mov bx, 1

FIX_PERIOD_DIV_OK:
    div bx
    cmp ax, 1
    jae FIX_PERIOD_OK
    mov ax, 1

FIX_PERIOD_OK:
    mov [PERIOD100 + si], ax

    call CALC_GIDX_FIXED

    ret
CALC_BODY_FIXED ENDP

CALC_GIDX_FIXED PROC
    ; Simple solar-gravity index.
    ; GIDX ~= 593 * M1000 / R100 / R100
    ; This is scaled for display and intentionally lightweight.
    push ax
    push bx
    push dx

    mov ax, [CENTRAL_MASS1000 + si]
    mov bx, 593
    mul bx

    mov bx, [RADIUS100 + si]
    cmp bx, 0
    jne GIDX_DIV1_OK
    mov bx, 1

GIDX_DIV1_OK:
    div bx

    mov bx, [RADIUS100 + si]
    cmp bx, 0
    jne GIDX_DIV2_OK
    mov bx, 1

GIDX_DIV2_OK:
    xor dx, dx
    div bx

    mov [GIDX + si], ax

    pop dx
    pop bx
    pop ax
    ret
CALC_GIDX_FIXED ENDP

ISQRT16 PROC
    ; Integer square root of SQRT_INPUT.
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

UPDATE_PHASE PROC
    mov ax, [PHASE_INC + si]
    cmp ax, 0
    jne HAVE_PHASE_INC

    mov bx, [PERIOD100 + si]
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

EXTRA_ASTRO_LOAD PROC
    ; Extra deterministic astrophysics-flavored work.
    ; Keeps the CPU/FPU busy without changing the physical orbit inputs.
    push ax
    push bx
    push dx

    mov bx, [PERIOD100 + si]
    cmp bx, 1
    jae XLOAD_PERIOD_OK
    mov bx, 1

XLOAD_PERIOD_OK:
    mov ax, 36000
    xor dx, dx
    div bx
    mov [PHASE_INC + si], ax

    mov ax, [VEL100 + si]
    add ax, [ESC100 + si]
    add ax, [MRATIO100 + si]
    add ax, [GIDX + si]
    add ax, [SIM_TIME100]

    xor dx, dx
    mov bx, 997
    div bx
    mov [SCRATCH_VALUE + si], dx

    pop dx
    pop bx
    pop ax
    ret
EXTRA_ASTRO_LOAD ENDP

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
; STRINGS
; ================================================================

LINE76          db '----------------------------------------------------------------------------',0

TITLE_STR       db 'ASTROMATH 88 REV1',0
SUBTITLE_STR    db '8088 / 8087 LIVE ASTROPHYSICS DATA SIMULATOR',0
TABLE_TITLE     db 'LIVE ORBIT / GRAVITY DATA MONITOR',0

S8087           db '8087:',0
SENG            db 'ENG:',0
SLAST           db 'LAST:',0
SACTION         db 'ACT:',0
SFREE           db 'FREE:',0
SBODIES         db 'BODIES:',0
SSTEP           db 'STEP:',0
SRATE           db 'RATE:',0

SAVG            db 'AVG:',0
SMAX            db 'MAX:',0
SGAVG           db 'GAVG:',0
SFORM           db 'BOD:',0

TABLE_HEAD1     db 'ID BODY      M.E    R.AU    VEL     ESC     PERIOD   GIDX  STATE  TH',0
FORMULA_LABEL   db 'V=29.78*SQRT(M/R)   ESC=42.10*SQRT(M/R)   PERIOD=2980*R/V',0
KEYS_LABEL      db 'F=FPU        I=INT        Q/ESC=QUIT        NO DISK WRITES',0

MODE_FPU_STR    db 'FPU',0
MODE_INT_STR    db 'INT',0
YES_STR         db 'YES',0
NO_STR          db 'NO ',0

ACTION_IDLE     db 'READY',0
ACTION_FPU      db 'FPU MODE',0
ACTION_INT      db 'INT MODE',0
ACTION_NOFPU    db 'NO 8087',0

STATE_BOUND     db 'BOUND',0
STATE_ESC       db 'ESC  ',0

SPINNER_CHARS   db '|/-\',0

UNIT_OPS        db 'OPS ',0
UNIT_KOPS       db 'KOPS',0
UNIT_MOPS       db 'MOPS',0

BODY_MERC       db 'MERCURY',0
BODY_VEN        db 'VENUS',0
BODY_EARTH      db 'EARTH',0
BODY_MARS       db 'MARS',0
BODY_JUP        db 'JUPITER',0
BODY_SAT        db 'SATURN',0
BODY_URA        db 'URANUS',0
BODY_NEP        db 'NEPTUNE',0
BODY_CER        db 'CERES',0
BODY_AST1       db 'AST-01',0
BODY_AST2       db 'AST-02',0
BODY_AST3       db 'AST-03',0
BODY_HAL        db 'HALLEY',0
BODY_COM1       db 'COMET-A',0
BODY_KBO1       db 'KBO-01',0
BODY_KBO2       db 'KBO-02',0

BODY_NAME_TABLE dw OFFSET BODY_MERC
                dw OFFSET BODY_VEN
                dw OFFSET BODY_EARTH
                dw OFFSET BODY_MARS
                dw OFFSET BODY_JUP
                dw OFFSET BODY_SAT
                dw OFFSET BODY_URA
                dw OFFSET BODY_NEP
                dw OFFSET BODY_CER
                dw OFFSET BODY_AST1
                dw OFFSET BODY_AST2
                dw OFFSET BODY_AST3
                dw OFFSET BODY_HAL
                dw OFFSET BODY_COM1
                dw OFFSET BODY_KBO1
                dw OFFSET BODY_KBO2

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

YN_TEMP         db 0
CENTER_ROW      db 0
DIGIT_COUNT     db 0
NUM_BUF         db 6 dup(0)

SQRT_INPUT      dw 0

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
ACTIVE_BODIES   dw MAX_BODIES

SIM_TIME100     dw 0
FRAME_COUNT     dw 0
LAST_TICK       dw 0

DISPLAY_INDEX   dw 0
SCREEN_ROW      db 0
SAMPLE_BODY_NUM dw 0
SAMPLE_OFFSET   dw 0
CURRENT_OFFSET  dw 0
HIDDEN_INDEX    dw 0
SPINNER_INDEX   dw 0

OPS_LOW         dw 0
OPS_HIGH        dw 0
OPS_MARK_LOW    dw 0
OPS_MARK_HIGH   dw 0
OPS_TICK_LOW    dw 0
OPS_TICK_HIGH   dw 0

FRAME_VEL_SUM   dw 0
FRAME_G_SUM     dw 0
AVG_VEL         dw 0
MAX_VEL         dw 0
AVG_GIDX        dw 0

K10             dw 10
K100            dw 100
K1000           dw 1000
K2978           dw 2978
K2980           dw 2980
K4210           dw 4210

; ================================================================
; ASTRO DATA ARRAYS
; ================================================================
; BODY_MASS100 is Earth masses * 100, for display only.
; CENTRAL_MASS1000 is solar masses * 1000, used by orbit math.
; RADIUS100 is AU * 100.

BODY_MASS100    dw 6,82,100,11,31780,9516,1454,1715
                dw 0,0,0,0,0,0,0,0

CENTRAL_MASS1000 dw 1000,1000,1000,1000,1000,1000,1000,1000
                 dw 1000,1000,1000,1000,1000,1000,1000,1000

RADIUS100       dw 39,72,100,152,520,958,1920,3005
                dw 277,245,310,370,1780,80,3950,4400

PHASE100        dw 0,4500,9000,13500,18000,22500,27000,31500
                dw 500,3500,7500,11500,15500,20500,25500,30500

MRATIO100       dw MAX_BODIES dup(0)
SQRT100         dw MAX_BODIES dup(0)
VEL100          dw MAX_BODIES dup(0)
ESC100          dw MAX_BODIES dup(0)
PERIOD100       dw MAX_BODIES dup(1)
GIDX            dw MAX_BODIES dup(0)
PHASE_INC       dw MAX_BODIES dup(0)
SCRATCH_VALUE   dw MAX_BODIES dup(0)

STACK_AREA      db 512 dup(0)
STACK_TOP       LABEL WORD

PROGRAM_END     LABEL BYTE

END START
