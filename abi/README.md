# ABI

This directory is for Cycor's kernel/userspace contract.

The native programming model is capability-based and async/event-oriented. The
low-level ABI may use numeric handles, but public native APIs should preserve
typed capability concepts where possible.

Initial ABI areas:

- syscall entry and return conventions
- capability handle representation
- message layout for channel IPC
- shared buffer transfer metadata
- event and wait-set completion records
- trace record format

