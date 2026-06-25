# Devices

Device objects provide controlled authority over hardware resources.

The kernel validates device access, controls MMIO mapping, routes interrupts,
and supports revocation. Drivers should run in userspace where practical.

