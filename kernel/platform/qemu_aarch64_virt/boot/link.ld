ENTRY(_start)

SECTIONS
{
  . = 0x40080000;

  .text : ALIGN(4096)
  {
    KEEP(*(.text._start))
    *(.text*)
    *(.rodata*)
  }

  .data : ALIGN(4096)
  {
    *(.data*)
  }

  .bss (NOLOAD) : ALIGN(4096)
  {
    __bss_start = .;
    *(.bss*)
    *(COMMON)
    __bss_end = .;
  }

  .bootstrap_stack (NOLOAD) : ALIGN(16)
  {
    __stack_bottom = .;
    . += 0x4000;
    __stack_top = .;
  }

  /DISCARD/ :
  {
    *(.comment)
    *(.note*)
    *(.eh_frame*)
  }
}

