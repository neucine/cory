# Timers

Timers provide sleep, wakeup, preemption, and async completion support.

Architecture-specific timer register access belongs in `kernel/arch`, while
platform timer wiring belongs in `kernel/platform`.

