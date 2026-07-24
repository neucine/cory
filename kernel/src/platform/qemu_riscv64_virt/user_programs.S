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
.global cory_normal_child_user_image_header
.type cory_normal_child_user_image_header, @object
cory_normal_child_user_image_header:
    .incbin "user/build/cory-user-child-riscv64.bin"

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
