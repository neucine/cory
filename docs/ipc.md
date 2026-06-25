# IPC Model

## 1. Purpose

Cycor IPC enables isolated services to cooperate.

The IPC model should support:

- message passing
- capability transfer
- shared buffer references
- async waiting
- event notification
- service restart boundaries

## 2. Core objects

- `Channel`
- `Message`
- `Event`
- `WaitSet`
- `SharedBuffer`

## 3. Message shape

A message may contain:

- small inline payload
- transferred capabilities
- references to shared buffers
- event/fence handles
- protocol-specific metadata

Large data should not be copied through IPC.

## 4. Capability transfer

IPC is the main way to delegate authority.

Example:

```text
ServiceManager -> FakeSensor:
    Capability<Device, Configure>
    Capability<Channel, Send>
    Capability<SharedBufferAllocator, Manage>
```

## 5. WaitSet

A wait set allows a service to wait on multiple sources:

- channel message
- event signal
- timer expiry
- interrupt event
- process exit
- buffer fence

Example service loop:

```text
loop:
    event = waitset.next()
    handle(event)
```

## 6. Imaging example

```text
FakeSensor -> FakeISP:
    message: FrameReady
    buffer: Capability<SharedBuffer, Read | Write>
    done: Capability<Event, Signal>

FakeISP -> Preview:
    message: PreviewFrame
    buffer: Capability<SharedBuffer, Read>

FakeISP -> StorageWriter:
    message: StoreFrame
    buffer: Capability<SharedBuffer, Read>
```
