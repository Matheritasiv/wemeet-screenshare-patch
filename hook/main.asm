default rel

section .text   align = 1
extern exit, getenv, printf
global _start

_start:
    mov     rbx,    2
.loop:
    lea     rdi,    [env_str]
    call    getenv
    lea     rdi,    [fmt_str]
    mov     rsi,    rax
    xor     eax,    eax
    call    printf
    dec     ebx
    jne     .loop
    xor     edi,    edi
    call    exit

section .data   align = 1
env_str     db      "PWD", 0
fmt_str     db      `[32;1mPWD="%s"[m\n`, 0
