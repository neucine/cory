# Architecture Layer

Architecture code is CPU-specific and platform-neutral.

Examples:

- exception/trap entry
- context switch assembly
- MMU register access
- interrupt masking primitives
- atomic and memory model primitives

Board and virtual-machine details belong under `kernel/platform`.

