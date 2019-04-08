[org 0x7c00]
    mov bp, 0x9000
    mov sp, bp
    mov bx, MSG_REAL_MODE
    call print
    call print_nl

    call switch_to_pm
    jmp $

; 16 bits print
print:
    pusha

print_start:
    mov al, [bx]
    cmp al, 0
    je print_done

    mov ah, 0x0e
    int 0x10

    add bx,1
    jmp print_start

print_done:
    popa
    ret

print_nl:
    pusha
    mov ah, 0x0e
    mov al, 0x0a        ; newline
    int 0x10
    mov al, 0x0d        ; carriage return
    int 0x10
    popa
    ret

print_hex:
    pusha

    mov cx, 0           ; for our index var

print_hex_loop:
    cmp cx, 4           ; loop 4 times
    je print_hex_end

    ; comnvert last char of dx to ascii
    mov ax, dx
    and ax, 0x000f
    add al, 0x30
    cmp al, 0x39        ; if > 9 then add additional 8 for A-F
    jle print_hex_step2
    add al, 7

print_hex_step2:
    mov bx, HEX_OUT+5
    sub bx, cx
    mov [bx], al
    ror dx, 4

    add cx, 1
    jmp print_hex_loop

print_hex_end:
    mov si, HEX_OUT
    call print 

    popa
    ret

HEX_OUT:
    db '0x0000', 0

; disk tools
; load 'dh' sectors from drive 'dl' into es:bx
disk_load:
    pusha

    push dx

    mov ah, 0x02            ; ah <- int 0x13 function 0x02 = read
    mov al, dh              ; al <- number of sectors to read (0x01 .. 0x80)
    mov cl, 0x02            ; cl <- sector (0x01 .. 0x11)
                            ; 0x01 is boot sector, 2 is the first available sector
    mov ch, 0x00            ; ch <- cylinder (0x .. 0x3ff, upper 2 bits in cl)
    ; dl <- drive number. Caller sets it as parameter and gets it from bios
    ; (0 = fd0, 1 = fd1, 0x80 = hdd0, 0x81 = hdd1)
    mov dh, 0x00            ; dh <- head number (0x0 .. 0xf)

    ; [es:bx] <- pointer where the data will be stored
    ; caller sets this up
    int 0x13                ; BIOS interrupt
    jc disk_error           ; error stored in carry bit

    pop dx
    cmp al, dh              ; BIOS sets al to number of sectors read
    jne sector_errors
    popa
    ret

disk_error:
    mov bx, DISK_ERROR
    call print
    call print_nl
    mov dh, ah              ; ah = error code, dl - drive that dropped the error
    call print_hex
    jmp disk_loop

sector_errors:
    mov bx, SECTORS_ERROR
    call print

disk_loop:
    jmp $

DISK_ERROR: db "Disk read error", 0
SECTORS_ERROR: db "Incorrect number of sectors read", 0


gdt_start:
    ; gdt starts with null 8 bytes
    dd 0x0
    dd 0x0

; gdt code for segment. base = 0x00000000, length = 0xfffff
gdt_code:
    dw 0xffff               ; segment length, bits 0-15
    dw 0x0                  ; segment base, bits 0-15
    db 0x0                  ; segment base, bits 16-234
    db 10011010b            ; flags 8 bits
    db 11001111b            ; flags 4 bits + segment length bits 16-19
    db 0x0                  ; segment base bits 24-31

; gdt for data segment, same setup as code segment but changes in flags
gdt_data:
    dw 0xffff               ; segment length, bits 0-15
    dw 0x0                  ; segment base, bits 0-15
    db 0x0                  ; segment base, bits 16-234
    db 10010010b            ; flags 8 bits
    db 11001111b            ; flags 4 bits + segment length bits 16-19
    db 0x0                  ; segment base bits 24-31

gdt_end:

; gdt descriptor
gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; size (16 bit), always 1 less then true size
    dd gdt_start                ; address (32 bit)

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

bits 32]

VIDEO_MEMORY equ 0xb8000
WHITE_ON_BLACK equ 0x04

print_string_pm:
    pusha
    mov edx, VIDEO_MEMORY

print_string_pm_loop:
    mov al, [ebx]
    mov ah, WHITE_ON_BLACK

    cmp al, 0
    je print_string_pm_done

    mov [edx], ax           ; star character + attribute in video memory
    add ebx, 1              ; advance 1 character
    add edx, 2              ; advance video memory by 2 (char + attr)

    jmp print_string_pm_loop

print_string_pm_done:
    popa
    ret

[bits 16]
switch_to_pm:
    cli                     ; diswable interrupts
    lgdt [gdt_descriptor]   ; load the GDT descriptor
    mov eax, cr0
    or eax, 0x1             ; set the 32 bit flag
    mov cr0, eax            ; warp 32!
    jmp CODE_SEG:init_pm    ; far jump using different segment

[bits 32]
init_pm:
    mov ax, DATA_SEG        ; update segment registers
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    
    mov ebp, 0x90000        ; update stack at the top of the free space
    mov esp, ebp
    
    call BEGIN_PM

[bits 32]
BEGIN_PM:
    mov ebx, MSG_PROT_MODE
    call print_string_pm
    
    jmp $

MSG_REAL_MODE db "Started in 16 bit real mode", 0
MSG_PROT_MODE db "Loaded 32-bit protected mode", 0

;times 510 - ($ - $$) db 0
;dw 0xaa55