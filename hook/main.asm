default rel

section .text   align = 1
extern exit, getenv, printf
global _start

_start:
    lea     rdi,    [env_str]
    call    getenv
    lea     rdi,    [fmt_str]
    mov     rsi,    rax
    xor     eax,    eax
    call    printf
    xor     edi,    edi
    call    exit

section .data   align = 1
env_str     db      "PWD", 0
fmt_str     db      `PWD="%s"\n`, 0
