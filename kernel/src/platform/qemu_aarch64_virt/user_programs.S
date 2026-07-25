.section .text.normal_user, "ax"
.balign 4096
.global cory_normal_user_image_header
.type cory_normal_user_image_header, %object
cory_normal_user_image_header:
    .incbin "user/build/cory-user-init-aarch64.bin"

.section .text.normal_user, "ax"
.balign 4096
.global cory_normal_shell_user_image_header
.type cory_normal_shell_user_image_header, %object
cory_normal_shell_user_image_header:
    .incbin "user/build/cory-user-shell-aarch64.bin"

.section .text.normal_user, "ax"
.balign 4096
.global cory_normal_selftest_user_image_header
.type cory_normal_selftest_user_image_header, %object
cory_normal_selftest_user_image_header:
    .incbin "user/build/cory-user-selftest-aarch64.bin"

.section .text.normal_user, "ax"
.balign 4096
.global cory_normal_echo_user_image_header
.type cory_normal_echo_user_image_header, %object
cory_normal_echo_user_image_header:
    .incbin "user/build/cory-user-echo-aarch64.bin"

.section .text.normal_user, "ax"
.balign 4096
.global cory_normal_ps_user_image_header
.type cory_normal_ps_user_image_header, %object
cory_normal_ps_user_image_header:
    .incbin "user/build/cory-user-ps-aarch64.bin"

.section .text.normal_user, "ax"
.balign 4096
.global cory_normal_ls_user_image_header
.type cory_normal_ls_user_image_header, %object
cory_normal_ls_user_image_header:
    .incbin "user/build/cory-user-ls-aarch64.bin"

.section .text.normal_user, "ax"
.balign 4096
.global cory_normal_cat_user_image_header
.type cory_normal_cat_user_image_header, %object
cory_normal_cat_user_image_header:
    .incbin "user/build/cory-user-cat-aarch64.bin"

.section .rodata.initramfs, "a"
.balign 8
.global cory_initramfs_start
.type cory_initramfs_start, %object
cory_initramfs_start:
    .incbin "user/build/initramfs-aarch64.bin"
.global cory_initramfs_end
cory_initramfs_end:

.section .text.initramfs, "ax"
.balign 4
.global cory_initramfs_addr
.type cory_initramfs_addr, %function
cory_initramfs_addr:
    adrp x0, cory_initramfs_start
    add x0, x0, :lo12:cory_initramfs_start
    ret

.global cory_initramfs_size
.type cory_initramfs_size, %function
cory_initramfs_size:
    adrp x0, cory_initramfs_end
    add x0, x0, :lo12:cory_initramfs_end
    adrp x1, cory_initramfs_start
    add x1, x1, :lo12:cory_initramfs_start
    sub x0, x0, x1
    ret
