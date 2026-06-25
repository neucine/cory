# FakeSensor

FakeSensor simulates frame production for the MVP imaging pipeline.

It should create or receive writable `SharedBuffer` objects, fill frame-like
data, and send buffer capabilities to FakeISP over a channel.

