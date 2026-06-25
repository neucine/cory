# Imaging Protocols

The first imaging protocol target is the fake camera pipeline:

```text
FakeSensor -> FakeISP -> Preview
                       -> StorageWriter
```

The protocol should demonstrate:

- channel messages for control and completion
- transferred `SharedBuffer` capabilities for frame data
- events or fences for producer/consumer synchronization
- trace records for frame ownership and latency
- no large payload copies through IPC

