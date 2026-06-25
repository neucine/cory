# Imaging Direction

## 1. Purpose

Cycor's first product direction is camera and imaging hardware based on Raspberry Pi CM5.

The kernel should not become a camera application. It should provide the substrate for an imaging OS.

## 2. Future service architecture

```text
Camera App
    -> Capture Service
        -> Sensor Service
        -> ISP Service
        -> Preview Service
        -> Storage Writer
        -> Display Service
```

Supporting services:

- Power Service
- Thermal Service
- Input Service
- Settings Service
- Gallery Service
- Diagnostics Service
- Trace Service

## 3. First demo: fake camera pipeline

The first meaningful demo should simulate the camera pipeline before real camera hardware is controlled.

```text
FakeSensor -> FakeISP -> Preview
                       -> StorageWriter
```

The fake pipeline should demonstrate:

- isolated services
- capability-limited access
- `SharedBuffer` frame movement
- async events
- trace records
- zero large IPC copies
- dropped-frame accounting

## 4. Future real hardware path

Bring-up order:

1. CM5 serial boot
2. timer and interrupt stability
3. memory stability
4. storage path
5. display path
6. input path
7. simulated capture path on real board
8. sensor/CSI research
9. ISP research
10. real camera pipeline

## 5. Scheduling requirements

Future imaging scheduling classes:

- `capture-critical`
- `preview-realtime`
- `ui-interactive`
- `storage-throughput`
- `background`
- `maintenance`

The kernel should provide mechanisms. A userspace resource manager should own most scheduling policy.

## 6. Observability requirements

The imaging stack must be able to answer:

- where did frame latency occur?
- which service held the buffer?
- did storage block the pipeline?
- did preview miss a deadline?
- did thermal policy affect capture?
- did a driver or interrupt storm cause jitter?
- how many copies occurred?
- how many frames were dropped?
