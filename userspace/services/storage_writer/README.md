# StorageWriter

StorageWriter receives read-only frame buffer capabilities and simulates
persisting frame data through a storage service boundary.

The MVP should account for storage latency without copying large frame payloads
through IPC.

