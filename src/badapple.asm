; -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+- ;

;              BAD ASSEMBLER              ;
;      bad apple written in nasm for      ;
;              x86 real mode              ;

; -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+- ;

; - - - - - - - - OPTIONS - - - - - - - - ;

%define VIDEO_WIDTH         160
%define VIDEO_HEIGHT        100

%define DRAW_FUNCTION       video_set_pixel_2x2

%define CYLINDER_NUMBER     0
%define SECTOR_NUMBER       2

%define DRIVE_NUMBER        0
%define SECTORS_PER_READ    36 ; 72, 36
%define B_SECTORS_PER_READ  SECTORS_PER_READ * 512

%define READ_OFFSET_DS      0x1000
%define READ_OFFSET         0x0000

%define TIMER_FREQUENCY     0xE90B ; see calculate-frequency.py

%define INTERRUPT_OFFSET    8

%define WAIT_FOR_KEYPRESS   1

; - - - - -  COMPILER SETTINGS  - - - - - ;

use16       ; enable 16-bit mode
org 0x7C00  ; program loads to 0x7C00

_start:     ; start label

; - - - - - - - ENTRY POINT - - - - - - - ;

 %if WAIT_FOR_KEYPRESS = 1

    call wait_for_keypress ; wait for keypress if WAIT_FOR_KEYPRESS = 1

%endif

    call timer_initialize  ; initialize pit
    call video_set_mode    ; set video mode
    call player_play       ; play video

    jmp  $                 ; exit loop

; - - - - - - - -  TIMER  - - - - - - - - ;

; Sets timer ISR and frequency.           ;
timer_initialize:
    cli  ; disable interrupts

    call timer_set_frequency
    call timer_change_isr

    sti  ; enable interrupts
    ret

; Changes current timer ISR to isr_timer. ;
timer_change_isr:
    push ax

    xor  ax, ax
    mov  word [ INTERRUPT_OFFSET * 4 ], isr_timer ; move isr_timer function
    mov  word [ INTERRUPT_OFFSET * 4 + 2 ], ax    ; to interrupt table

    pop  ax
    ret

; Sets time frequency to TIMER_FREQUENCY. ;
timer_set_frequency:
    push ax

    mov  al,   0x43
    out  0x43, al ; send mode 43h

    mov  ax,   TIMER_FREQUENCY
    out  0x40, al ; send first byte
    mov  al,   ah
    out  0x40, al ; send second byte

    pop  ax
    ret


; - - - - - - - DISK READER - - - - - - - ;

; Reads SECTORS_PER_READ sectors to       ;
; READ_OFFSET_DS:READ_OFFSET.             ;
; CH: track/cylinder number. CL: sector.  ;
disk_read_sectors:
    pusha

    mov  ah, 0x02             ; read disk sectors
    mov  al, SECTORS_PER_READ ; number of sectors to read
    mov  dh, 0x00             ; head number
    mov  dl, DRIVE_NUMBER     ; drive number

    mov  bx, READ_OFFSET_DS   ; data segment offset
    mov  es, bx

    mov  bx, READ_OFFSET      ; data offset

    int  0x13

    popa
    ret

; - - - - - - GRAPHICS PLAYER - - - - - - ;

; Plays the recorded video on             ;
; READ_OFFSET_DS:READ_OFFSET.             ;
player_play:
    popa

    push ds

    mov  ch, CYLINDER_NUMBER
    mov  cl, SECTOR_NUMBER
    mov  si, READ_OFFSET

    .read:
        call disk_read_sectors
    .iter:
        push ds
        mov  ax, READ_OFFSET_DS
        mov  ds, ax

        lodsb

        pop ds

        test al, al
        jz  .exit

        call video_decode_draw

        cmp  si, B_SECTORS_PER_READ
        jne  .iter

        mov  si, READ_OFFSET
        inc  ch

        jmp  .read
    .exit:
        pop ds
        popa
        ret

; Decodes byte in AL and draws it.        ;
video_decode_draw:
    push ax
    
    mov  ah, al   ; copy byte to AH

    shr  al, 0x07 ; set AL register to type
    and  ah, 0x7F ; set AH register to length

    call video_change_color

    .iter:
        test ah, ah
        jz   .exit  ; exit if length = 0

        dec  ah

        call video_draw_next
        call video_increment_sync

        jmp  .iter
    .exit:
        pop  ax
        ret

; Increments the video position and       ;
; synchronizes frame rendering.           ;
video_increment_sync:
    pusha

    mov  bx, mem_frame_x
    mov  cx, [bx] ; load X position

    mov  bx, mem_frame_y
    mov  dx, [bx] ; load Y position

    inc  cx       ; incremenent X position

    cmp  cx, VIDEO_WIDTH
    jne  .exit    ; exit if X is not at line end

    xor  cx, cx   ; otherwise, set X to 0
    inc  dx       ; and incremenet Y

    cmp  dx, VIDEO_HEIGHT
    jne  .exit    ; exit if Y is not at frame end

    call video_sync_frame

    xor dx, dx    ; otherwise, sync and set Y to 0

    .exit:
        mov   bx,  mem_frame_x
        mov  [bx], cx ; save X position

        mov   bx,  mem_frame_y
        mov  [bx], dx ; save Y position

        popa
        ret

; Draws color in AL in current position.  ;
video_draw_next:
    pusha

    mov  bx, mem_frame_x
    mov  cx, [bx] ; load X position

    mov  bx, mem_frame_y
    mov  dx, [bx] ; load Y position

    call DRAW_FUNCTION

    popa
    ret

; Changes current color depends on AL.    ;
video_change_color:
    cmp  al, 0x00
    je   .exit
    mov  al, 0x0F
    .exit:
        ret

; Waits for frame change.                 ;
video_sync_frame:
    pusha

    mov  bx,   mem_frame_sync  ; load mem_frame_sync address

    .wait:
        mov  al, [bx]          ; load current sync state to al
        test al, al
        jz   .wait             ; jump to wait if al == 0x00

    xor  al,   al              ; reset state
    mov  [bx], al              ; and write it to mem_frame_sync

    popa
    ret

; - - - - - - - -  VIDEO  - - - - - - - - ;

; Changes video mode to                   ;
; 320x200 * 8 colors.                     ;
video_set_mode:
    push ax

    xor  ah, ah   ; set video mode
    mov  al, 0x13 ; 320x200 * 8 colors

    int  0x10

    pop  ax
    ret


; Sets pixel in VRAM, where x: CX, y: DX, ;
; and color: AL.                          ;
video_set_pixel:
    push ds
    pusha

    imul dx, 320 ; y * bytes per scanline
    add  dx, cx  ; + x. now byte position in DX

    mov  bx, 0xA000
    mov  ds, bx  ; set data segment to VRAM

    mov  bx, dx
    mov  [bx], al

    popa
    pop ds

    ret

; Sets 2x2 pixel in VRAM, where x: CX,    ;
; y: DX and color: AL.                    ;
video_set_pixel_2x2:
    pusha

    imul cx, 0x02
    imul dx, 0x02

    call video_set_pixel

    add cx, 0x01

    call video_set_pixel

    add dx, 0x01

    call video_set_pixel

    add cx, -0x01
    
    call video_set_pixel

    popa
    ret

; - - - - - - - -  OTHER  - - - - - - - - ;

%if WAIT_FOR_KEYPRESS = 1

wait_for_keypress:
    xor ah, ah
    int 0x16
    ret

%endif

; - - - - - - - - - ISR - - - - - - - - - ;

; Called every time timer calls an IRQ0.  ;
; Changes mem_frame_sync byte to 0xFF.    ;
isr_timer:
    push ax
    push bx

    mov  bx,   mem_frame_sync
    mov  al,   0xFF

    mov  [bx], al

    mov  al,   0x20
    out  0x20, al

    pop bx
    pop ax

    iret

; - - - - - - - - - MEM - - - - - - - - - ;

mem_frame_sync:  db 0h

mem_frame_x:     dw 0h
mem_frame_y:     dw 0h

; - - - - - - -  SIGNATURE  - - - - - - - ;

_end:
    times 0x1FE - _end + _start db 0 ; repeat 0 to end
    db    0x55, 0xAA                 ; end signature

; - - - - - - - - - END - - - - - - - - - ;
