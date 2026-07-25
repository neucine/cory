.section .text.normal_user, "ax"
.balign 4096
.global cory_normal_user_image_header
.type cory_normal_user_image_header, @object
cory_normal_user_image_header:
    .incbin "user/build/cory-user-init-riscv64.bin"

.section .rodata.initramfs, "a"
.balign 4096
.global cory_initramfs_start
.type cory_initramfs_start, @object
cory_initramfs_start:
    .incbin "user/build/initramfs-riscv64.bin"
.global cory_initramfs_end
cory_initramfs_end:

.section .text.initramfs, "ax"
.balign 4
.global cory_initramfs_addr
.type cory_initramfs_addr, @function
cory_initramfs_addr:
    la a0, cory_initramfs_start
    ret

.global cory_initramfs_size
.type cory_initramfs_size, @function
cory_initramfs_size:
    la a0, cory_initramfs_end
    la a1, cory_initramfs_start
    sub a0, a0, a1
    ret
