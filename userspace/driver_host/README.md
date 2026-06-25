# Driver Host

Driver hosts run device code in isolated userspace processes where practical.

They own narrow device capabilities, map MMIO only through the kernel, receive
interrupts as events, and communicate with clients through channels.

