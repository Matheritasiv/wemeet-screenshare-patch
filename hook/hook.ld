ENTRY(_start)

PHDRS
{
  headers PT_PHDR PHDRS;
  dynamic PT_DYNAMIC;
  dyninfo PT_LOAD FILEHDR PHDRS;
  data PT_LOAD;
  text PT_LOAD;
  tlsdata PT_TLS;
}

SECTIONS
{
  . = SIZEOF_HEADERS;
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
  .bss : SUBALIGN(1) { *(.bss*) } :data

  . = ALIGN(CONSTANT(MAXPAGESIZE)) + . % CONSTANT(MAXPAGESIZE);
  .text : SUBALIGN(1) { *(.text*) *(.rodata*) } :text
  .plt : SUBALIGN(1) { *(.plt) } :text

  .tbss : SUBALIGN(1) { *(.tbss*) } :tlsdata

  /DISCARD/ : {
    *(.comment)
    *(.note*)
    *(.eh_frame*)
    *(.eh_frame_hdr*)
    *(.gnu*)
    *(.init*)
    *(.fini*)
  }
}
