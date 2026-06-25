# Userspace

Userspace contains policy and services above the kernel substrate.

Initial areas:

- `init`
- `service_manager`
- `driver_host`
- `services`

Native services should communicate through capability-based IPC, events, wait
sets, and shared buffers.

