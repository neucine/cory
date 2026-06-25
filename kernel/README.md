# Kernel

The Cycor kernel is the small privileged substrate for isolation, memory,
scheduling, capabilities, IPC, events, device access, accounting, and trace
hooks.

Layout:

- `arch`: CPU architecture support.
- `platform`: board, SoC, and virtual machine support.
- `core`: architecture-independent kernel mechanisms.

