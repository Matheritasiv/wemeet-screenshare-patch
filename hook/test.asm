default rel

section .text   align = 1
extern exit, getenv, printf
global _start

_start:
    lea     r12,    [fmt_str]

    ; original call and cached call
    mov     ebx,    2
.loop:
    lea     rdi,    [env_str]
    call    getenv
    mov     rdi,    r12
    mov     rsi,    rax
    xor     eax,    eax
    call    printf
    add     r12,    0x40
    dec     ebx
    jne     .loop

    ; bad original call
    mov     al,     1
    lea     rdi,    [.ret.0]
    call    getenv
.ret.0:
    nop     dword [rax]
    test    rax,    rax
    je      .next.0
    mov     byte [r12+3], 0x31
.next.0:
    mov     rdi,    r12
    call    printf
    add     r12,    0x40

    ; bad hook call
    xor     eax,    eax
    lea     rdi,    [.ret.1]
    bts     rdi,    50
    call    getenv
.ret.1:
    cmp     eax,    4
    je      .next.1
    mov     byte [r12+3], 0x31
.next.1:
    mov     rdi,    r12
    xor     eax,    eax
    call    printf
    add     r12,    0x40

    ; construct 128px buffer
    mov     ecx,    2
    mov     rdx,    0x0808080808080808
.loop.2.1:
    mov     rax,    0x0807060504030200
.loop.2.2:
    sub     rax,    rdx
    push    rax
    test    al,     al
    jne     .loop.2.2
    dec     ecx
    jne     .loop.2.1
    mov     rbp,    rsp

    ; hook call #1
    rdrand  r11
    sub     rsp,    0x8
    push    r11
    lea     rdi,    [.ret.2]
    bts     rdi,    48
    mov     rsi,    rbp
    call    getenv
.ret.2:
    cmp     [rsp],  r11
    je      .next.2
    mov     byte [r12+3], 0x31
.next.2:
    mov     rdi,    r12
    mov     rsi,    r11
    xor     eax,    eax
    call    printf
    add     r12,    0x40

    ; hook call #2: case mismatch
    xor     eax,    eax
    lea     rdi,    [.ret.3]
    bts     rdi,    49
    xor     rbp,    0x8
    xor     ebx,    ebx
    xor     r14d,   r14d
    xor     r15d,   r15d
    dec     r14d
    inc     r15d
    call    getenv
.ret.3:
    test    al,     al
    jne     .next.3
    mov     byte [r12+3], 0x31
.next.3:
    mov     rdi,    r12
    movzx   esi,    al
    xor     eax,    eax
    call    printf
    add     r12,    0x40

    ; hook call #2: case match
    lea     rdi,    [.ret.4]
    bts     rdi,    49
    xor     rbp,    0x8
    mov     rbx,    rsp
    sub     rbx,    0x1f8
    mov     r14d,   0x1fc
    add     rsp,    0x10
    call    getenv
.ret.4:
    sub     rsp,    0x10
    mov     r11,    qword [rsp]
    mov     dword [rsp+0x4], 0xfffcfdfe
    mov     rbx,    rsp
    sub     rbx,    0x1f8
    mov     ecx,    2
    mov     rdx,    0x0808080808080808
.loop.4.1:
    mov     rax,    0x0704050603000102
.loop.4.2:
    cmp     qword [rbx], rax
    jne     .fail.4
    add     rax,    rdx
    add     rbx,    0x8
    test    al,     0xf8
    jne     .loop.4.2
    dec     ecx
    jne     .loop.4.1
    jmp     .next.4
.fail.4:
    mov     byte [r12+3], 0x31
.next.4:
    mov     rdi,    r12
    mov     rsi,    r11
    xor     eax,    eax
    call    printf

    xor     edi,    edi
    call    exit

times 0xbe-($-.ret.4) int3

    jmp     .ret.4

section .data   align = 1
env_str     db      "PWD", 0
align 64
fmt_str     db      `\e[32;1m[1/7]            PWD="%s"\e[m\n`, 0
align 64
            db      `\e[32;1m[2/7]    (cache) PWD="%s"\e[m\n`, 0
align 64
            db      `\e[32;1m[3/7]      (bad) PWD=(null)\e[m\n`, 0
align 64
            db      `\e[34;1m[4/7]  (invalid) HOOK CALL\e[m\n`, 0
align 64
            db      `\e[34;1m[5/7]            HOOK CALL #1: r11=%#16lx\e[m\n`, 0
align 64
            db      `\e[34;1m[6/7] (mismatch) HOOK CALL #2:  al=%#2x\e[m\n`, 0
align 64
            db      `\e[34;1m[7/7]    (match) HOOK CALL #2: mem=%#16lx\e[m\n`, 0
