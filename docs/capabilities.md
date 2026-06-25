# Capability Model

## 1. Purpose

Capabilities are Cycor's native authority model.

A capability answers:

```text
Which object?
Which rights?
Can this authority be delegated?
Can it be duplicated?
Can it be revoked?
```

## 2. Conceptual form

```text
Capability<ObjectType, Rights>
```

This is a conceptual model. The low-level ABI may represent capabilities as handles, but the native Cyna API should expose typed capability concepts where possible.

## 3. Rights

Initial rights:

- `Read`
- `Write`
- `Execute`
- `Map`
- `Send`
- `Receive`
- `Signal`
- `Inspect`
- `Manage`
- `Configure`
- `Transfer`
- `Duplicate`
- `Revoke`

## 4. Rules

- A process cannot access a protected object without a capability.
- Rights are checked in the kernel.
- Capabilities may be transferred through IPC if allowed.
- Capabilities may be duplicated if allowed.
- Capabilities may be revoked if revocation authority exists.
- Capability tables are per-process or per-protection-domain.
- Kernel-created root capabilities are distributed by the initial system service.

## 5. Examples

```text
Capability<Channel, Send>
Capability<Channel, Receive>
Capability<SharedBuffer, Read | Map>
Capability<SharedBuffer, Read | Write | Map>
Capability<Device, Configure>
Capability<Process, Inspect | Signal>
Capability<Thread, Manage>
```

## 6. Camera relevance

A camera-oriented system can grant narrow service authority:

```text
Sensor Service:
    Device<Sensor>, Interrupt, SharedBuffer allocator

ISP Service:
    Device<ISP>, SharedBuffer read/write, Event signal

Preview Service:
    Display surface, SharedBuffer read

Storage Writer:
    Storage service write, SharedBuffer read

Camera App:
    Capture service command channel
```

No service needs global system authority.
