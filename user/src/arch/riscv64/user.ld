ENTRY(cory_user_image_header)

SECTIONS
{
  . = 0;

  .text : ALIGN(4096)
  {
    KEEP(*(.text.cory_user_image_header))
    KEEP(*(.text.cory_user_start))
    *(.text*)
    *(.rodata*)
  }

  .data : ALIGN(16)
  {
    *(.data*)
  }

  .bss (NOLOAD) : ALIGN(16)
  {
    *(.bss*)
    *(COMMON)
  }

  /DISCARD/ :
  {
    *(.comment)
    *(.note*)
    *(.eh_frame*)
  }
}
