# SharedBuffer

`SharedBuffer` is a first-class kernel object for moving large frame-like data
between isolated services without large IPC copies.

The kernel tracks size, mappings, rights, lifetime, accounting, and
synchronization state. Image formats and camera policy stay in userspace.

