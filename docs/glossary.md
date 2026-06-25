# Glossary

## AArch64

64-bit Arm architecture. Cycor's primary product architecture because Raspberry Pi CM5 is Arm-based.

## Cyna

The systems programming language in the Neucine ecosystem. Cycor is intended to be written primarily in Cyna.

## Cycor

Pronounced Sai-core. A Cyna-native capability kernel substrate for language demonstration and future camera/imaging hardware.

## Capability

A transferable authority object that grants rights over a kernel object.

## Channel

A message-based IPC object.

## Event

A kernel object that can be signaled and waited on.

## WaitSet

An object allowing a task or service to wait on multiple events, channels, timers, or completions.

## SharedBuffer

A first-class kernel object for zero-copy sharing of large buffers between isolated services.

## Product track

The AArch64 / Raspberry Pi CM5 path intended for future camera and imaging hardware.

## Research track

The RISC-V64 / SiFive HiFive Unmatched path intended for architecture validation and kernel experimentation.

## Service

A userspace component that implements policy or device behavior above the kernel substrate.

## Kernel substrate

The minimal privileged layer that provides machine mechanisms but avoids embedding product policy.
