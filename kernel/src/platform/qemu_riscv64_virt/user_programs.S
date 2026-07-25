.section .text.normal_user, "ax"
.balign 4096
.global cory_normal_user_image_header
.type cory_normal_user_image_header, @object
cory_normal_user_image_header:
    .incbin "user/build/cory-user-init-riscv64.bin"

.section .text.normal_user, "ax"
.balign 4096
.global cory_normal_shell_user_image_header
.type cory_normal_shell_user_image_header, @object
cory_normal_shell_user_image_header:
    .incbin "user/build/cory-user-shell-riscv64.bin"

.section .text.normal_user, "ax"
.balign 4096
.global cory_normal_selftest_user_image_header
.type cory_normal_selftest_user_image_header, @object
cory_normal_selftest_user_image_header:
    .incbin "user/build/cory-user-selftest-riscv64.bin"

.section .text.normal_user, "ax"
.balign 4096
.global cory_normal_echo_user_image_header
.type cory_normal_echo_user_image_header, @object
cory_normal_echo_user_image_header:
    .incbin "user/build/cory-user-echo-riscv64.bin"

.section .text.normal_user, "ax"
.balign 4096
.global cory_normal_ps_user_image_header
.type cory_normal_ps_user_image_header, @object
cory_normal_ps_user_image_header:
    .incbin "user/build/cory-user-ps-riscv64.bin"

.section .text.normal_user, "ax"
.balign 4096
.global cory_normal_ls_user_image_header
.type cory_normal_ls_user_image_header, @object
cory_normal_ls_user_image_header:
    .incbin "user/build/cory-user-ls-riscv64.bin"

.section .text.normal_user, "ax"
.balign 4096
.global cory_normal_cat_user_image_header
.type cory_normal_cat_user_image_header, @object
cory_normal_cat_user_image_header:
    .incbin "user/build/cory-user-cat-riscv64.bin"

.section .rodata.initramfs, "a"
.balign 8
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
