ENTRY(_start)

PHDRS
{
  headers PT_PHDR PHDRS;
  interp PT_INTERP;
  dynamic PT_DYNAMIC;
  dyninfo PT_LOAD FILEHDR PHDRS;
  data PT_LOAD;
  text PT_LOAD;
}

SECTIONS
{
  . = SIZEOF_HEADERS;
  .interp : SUBALIGN(1) { *(.interp) } :dyninfo :interp
  .dynsym : SUBALIGN(1) { *(.dynsym) } :dyninfo
  .dynstr : SUBALIGN(1) { *(.dynstr) } :dyninfo
  .hash : SUBALIGN(1) { *(.hash) } :dyninfo
  .rela.plt : SUBALIGN(1) { *(.rela.plt) } :dyninfo
  .rela.dyn : SUBALIGN(1) { *(.rela.dyn) } :dyninfo

  . = ALIGN(CONSTANT(MAXPAGESIZE)) + . % CONSTANT(MAXPAGESIZE);
  .dynamic : SUBALIGN(1) { *(.dynamic) } :data :dynamic
  .data : SUBALIGN(1) { *(.data*) } :data
  .got.plt : SUBALIGN(1) { *(.got.plt) } :data
  .got : SUBALIGN(1) { *(.got) } :data

  . = ALIGN(CONSTANT(MAXPAGESIZE)) + . % CONSTANT(MAXPAGESIZE);
  .text : SUBALIGN(1) { *(.text*) *(.rodata*) } :text
  .plt : SUBALIGN(1) { *(.plt) } :text

  /DISCARD/ : {
    *(.comment)
    *(.note*)
    *(.eh_frame*)
    *(.eh_frame_hdr*)
    *(.gnu*)
    *(.init*)
    *(.fini*)
    *(.bss*)
  }
}
