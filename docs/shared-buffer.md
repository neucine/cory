# SharedBuffer Model

## 1. Purpose

`SharedBuffer` is a first-class Cycor kernel object for moving large data across isolated services without copying.

This is essential for imaging workloads, where frame buffers may be tens or hundreds of megabytes.

## 2. Requirements

The kernel should support:

- allocation
- mapping into address spaces
- rights-restricted access
- explicit ownership or producer/consumer state
- lifetime tracking
- resource accounting
- event/fence synchronization
- DMA-related flags later
- cache coherency controls later
- physical contiguity constraints later

## 3. Basic operations

Conceptual operations:

```text
create(size, flags) -> Capability<SharedBuffer, Manage | Map | Read | Write>
map(buffer, address_space, rights) -> Mapping
unmap(mapping)
duplicate(buffer, reduced_rights)
transfer(buffer, target_process)
signal_ready(buffer, event)
```

## 4. Rights

Possible rights:

- `Read`
- `Write`
- `Map`
- `Transfer`
- `Manage`

## 5. Imaging flow

```text
FakeSensor:
    create SharedBuffer
    fill frame-like data
    send buffer to FakeISP

FakeISP:
    receive buffer
    process buffer
    send derived buffers to Preview and StorageWriter

Preview:
    read preview buffer

StorageWriter:
    read storage buffer
    write to storage service
```

## 6. Kernel boundary

The kernel should know:

- buffer size
- owner
- mappings
- rights
- lifetime
- accounting
- synchronization state

The kernel should not know:

- RAW format
- JPEG
- DNG
- demosaic
- color science
- camera exposure policy
