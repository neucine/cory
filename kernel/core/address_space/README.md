# Address Spaces

Address-space abstractions own virtual mappings and user/kernel separation.

This module should remain independent of board policy. Architecture-specific
page table operations should be provided by `kernel/arch`.

