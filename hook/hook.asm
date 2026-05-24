default rel

section .text   align = 1
extern dlsym
global getenv, ptr_src

getenv:
    ; If `rdi ^ [rsp] == (0x0001 | 0x0002) << 48`, then it is a hook call.
    ; NOTE: The hook caller should save `rax` if necessary.
    mov     rax,    [rsp]
    xor     rax,    rdi
    shl     rax,    16
    test    rax,    rax
    jne     .real_call
    mov     rax,    rdi
    sar     rax,    48
    cmp     eax,    0
    jg      .hook_call
.real_call:
    mov     rax,    [ptr_call]
    test    rax,    rax
    jne     .cached_call
    push    rdi
    xor     edi,    edi
    dec     rdi                 ; RTLD_NEXT
    lea     rsi,    [name_call]
    call    [dlsym wrt ..got]
    mov     [ptr_call], rax
    pop     rdi
.cached_call:
    jmp     rax                 ; real getenv()
.hook_call:
    cmp     eax,    2
    jg      .return             ; invalid hook call
    ; The hook starts here.
    mov     rax,    [ptr_src wrt ..gottpoff]
    je      .flip
    ;   case `eax == 1`: A hook call from `libscreen_share_module.so`.
    ;                    Save the address of src.
    ;                    KEEP: r11
    mov     FS:[rax], rsi
.return:
    ret
.flip:
    ;   case `eax == 2`: A hook call from `libxcast.so`.
    ;                    Check the address of src, and flip R & B bytes to dst.
    ;                    INPUT: rbp=src, rbx=dst, r14d*r15d=len
    ;                    SAFE: rdi, rsi, rcx, r12, r13, r14, r15
    ;                    OUTPUT: al=1 if mismatch
    ;                            return to `[rsp]+0xbe` if match
    cmp     FS:[rax], rbp
    je      .do_flip
    mov     al,     1
    ret
.do_flip:
    xor     edi,    edi
    mov     FS:[rax], rdi
    sar     r14d,   2
    imul    r14d,   r15d
    ;     SIMD flip procedure, using AVX2 instruction set
    vmovdqu         xmm8,   oword [shuf_mask]
    vinserti128     ymm8,   ymm8,   xmm8,   1
    mov     ecx,    r14d
    and     r14d,   0x3f
    shr     ecx,    6
    test    ecx,    ecx
    jz      .loop_64px_end
.loop_64px:
    vmovdqu         ymm0,   yword [rbp+0x00]
    vmovdqu         ymm1,   yword [rbp+0x20]
    vmovdqu         ymm2,   yword [rbp+0x40]
    vpshufb         ymm0,   ymm0,   ymm8
    vpshufb         ymm1,   ymm1,   ymm8
    vpshufb         ymm2,   ymm2,   ymm8
    vmovdqu         yword [rbx+0x00], ymm0
    vmovdqu         yword [rbx+0x20], ymm1
    vmovdqu         yword [rbx+0x40], ymm2
    vmovdqu         ymm3,   yword [rbp+0x60]
    vmovdqu         ymm4,   yword [rbp+0x80]
    vpshufb         ymm3,   ymm3,   ymm8
    vpshufb         ymm4,   ymm4,   ymm8
    vmovdqu         yword [rbx+0x60], ymm3
    vmovdqu         yword [rbx+0x80], ymm4
    vmovdqu         ymm5,   yword [rbp+0xa0]
    vmovdqu         ymm6,   yword [rbp+0xc0]
    vmovdqu         ymm7,   yword [rbp+0xe0]
    vpshufb         ymm5,   ymm5,   ymm8
    vpshufb         ymm6,   ymm6,   ymm8
    vpshufb         ymm7,   ymm7,   ymm8
    vmovdqu         yword [rbx+0xa0], ymm5
    vmovdqu         yword [rbx+0xc0], ymm6
    vmovdqu         yword [rbx+0xe0], ymm7
    add     rbp,    0x100
    add     rbx,    0x100
    dec     ecx
    jne     .loop_64px
.loop_64px_end:
    mov     ecx,    r14d
    and     r14d,   0x7
    shr     ecx,    3
    jecxz   .loop_8px_end
.loop_8px:
    vmovdqu         ymm0,   yword [rbp]
    vpshufb         ymm0,   ymm0,   ymm8
    vmovdqu         yword [rbx], ymm0
    add     rbp,    0x20
    add     rbx,    0x20
    dec     ecx
    jne     .loop_8px
.loop_8px_end:
    test    r14d,   r14d
    je      .loop_1px_end
.loop_1px:
    mov     eax,    dword [rbp+rcx]
    mov     edi,    eax
    shr     edi,    16
    xor     edi,    eax
    and     edi,    0xff
    xor     eax,    edi
    shl     edi,    16
    xor     eax,    edi
    mov     dword [rbx+rcx], eax
    add     ecx,    4
    dec     r14d
    jne     .loop_1px
.loop_1px_end:
    ;     set the continuation
    add     qword [rsp], 0xbe
    ret

section .rodata align = 1
name_call   db      "getenv", 0
shuf_mask   db      2, 1, 0, 3, 6, 5, 4, 7, 10, 9, 8, 11, 14, 13, 12, 15

section .bss
ptr_call    resq    1

section .tbss
ptr_src     resq    1
