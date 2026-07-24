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
.global cory_normal_child_user_image_header
.type cory_normal_child_user_image_header, %object
cory_normal_child_user_image_header:
    .incbin "user/build/cory-user-child-aarch64.bin"

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
