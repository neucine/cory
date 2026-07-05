import .kernel.arch.aarch64.page_table as aarch64_page_table;
import .kernel.arch.riscv64.page_table as riscv64_page_table;
import .kernel.object.capability;
import { CapabilityRights, CapabilityStatus } from .kernel.object.capability;
import .kernel.object.kernel_object;
import { KernelObjectKind, KernelObjectStatus } from .kernel.object.kernel_object;
import .kernel.memory.address_space;
import .kernel.memory.boot;
import .kernel.memory.heap;
import { Layout } from .kernel.memory.layout;
import .kernel.memory.map as memory_map;
import .kernel.memory.page_table;
import { Spec } from .kernel.memory.page_table;
import .kernel.memory.phys;
import .kernel.memory.vm;
import .kernel.panic as panic_mod;

fn fail(name: string): void {
    println(name);
    panic_mod.panic();
}


pub fn run_kernel_object_tests(): void {
    kernel_object.init();
    if kernel_object.count() != 0 {
        fail("selftest: object initial count");
    }
    if kernel_object.allocate_raw_kind(KernelObjectKind.empty as i32) != kernel_object.invalid_id {
        fail("selftest: object invalid kind");
    }
    if kernel_object.status() != KernelObjectStatus.invalid_kind {
        fail("selftest: object invalid kind status");
    }

    const address_space_object = kernel_object.allocate(KernelObjectKind.address_space);
    if address_space_object == kernel_object.invalid_id {
        fail("selftest: object allocate address space");
    }
    if kernel_object.count() != 1 {
        fail("selftest: object count after allocate");
    }
    const object = kernel_object.get(address_space_object);
    if !object.live {
        fail("selftest: object live");
    }
    if object.kind != KernelObjectKind.address_space {
        fail("selftest: object kind");
    }
    if object.ref_count != 1 {
        fail("selftest: object initial refcount");
    }
    if !kernel_object.retain(address_space_object) {
        fail("selftest: object retain");
    }
    if kernel_object.get(address_space_object).ref_count != 2 {
        fail("selftest: object retain refcount");
    }
    if !kernel_object.release(address_space_object) {
        fail("selftest: object release retain");
    }
    if kernel_object.get(address_space_object).ref_count != 1 {
        fail("selftest: object release refcount");
    }
    if !kernel_object.release(address_space_object) {
        fail("selftest: object final release");
    }
    if kernel_object.get(address_space_object).live {
        fail("selftest: object stale get");
    }
    if kernel_object.is_live(address_space_object) {
        fail("selftest: object not live after release");
    }
    if kernel_object.release(address_space_object) {
        fail("selftest: object stale release");
    }
    if kernel_object.status() != KernelObjectStatus.invalid_id {
        fail("selftest: object stale release status");
    }
}

pub fn run_capability_tests(): void {
    kernel_object.init();
    capability.init();

    const object_id = kernel_object.allocate(KernelObjectKind.channel);
    if object_id == kernel_object.invalid_id {
        fail("selftest: capability object allocate");
    }
    if capability.mint(kernel_object.invalid_id, CapabilityRights.read) != capability.invalid_id {
        fail("selftest: capability mint invalid object");
    }
    if capability.status() != CapabilityStatus.invalid_object {
        fail("selftest: capability invalid object status");
    }
    if capability.mint_raw_rights(object_id, 0) != capability.invalid_id {
        fail("selftest: capability mint empty rights");
    }
    if capability.status() != CapabilityStatus.invalid_rights {
        fail("selftest: capability empty rights status");
    }

    const root_rights = CapabilityRights.read | CapabilityRights.write | CapabilityRights.transfer | CapabilityRights.duplicate;
    const root_cap = capability.mint(object_id, root_rights);
    if root_cap == capability.invalid_id {
        fail("selftest: capability mint root");
    }
    if capability.count() != 1 {
        fail("selftest: capability root count");
    }
    if kernel_object.get(object_id).ref_count != 2 {
        fail("selftest: capability mint retain");
    }
    if !capability.has_rights(root_cap, CapabilityRights.read | CapabilityRights.write) {
        fail("selftest: capability has rw");
    }
    if capability.has_rights(root_cap, CapabilityRights.execute) {
        fail("selftest: capability lacks execute");
    }
    if !capability.can_transfer(root_cap) {
        fail("selftest: capability transfer right");
    }
    if !capability.can_duplicate(root_cap) {
        fail("selftest: capability duplicate right");
    }

    const read_cap = capability.duplicate(root_cap, CapabilityRights.read);
    if read_cap == capability.invalid_id {
        fail("selftest: capability duplicate read");
    }
    if capability.has_rights(read_cap, CapabilityRights.write) {
        fail("selftest: capability duplicate narrows");
    }
    if capability.duplicate(read_cap, CapabilityRights.read) != capability.invalid_id {
        fail("selftest: capability duplicate missing right");
    }
    if capability.status() != CapabilityStatus.missing_duplicate_right {
        fail("selftest: capability duplicate missing status");
    }
    if capability.duplicate(root_cap, CapabilityRights.execute) != capability.invalid_id {
        fail("selftest: capability duplicate exceed");
    }
    if capability.status() != CapabilityStatus.rights_exceed_source {
        fail("selftest: capability duplicate exceed status");
    }
    if kernel_object.get(object_id).ref_count != 3 {
        fail("selftest: capability duplicate retain");
    }

    if !capability.release(read_cap) {
        fail("selftest: capability release duplicate");
    }
    if capability.get(read_cap).live {
        fail("selftest: capability stale duplicate get");
    }
    if kernel_object.get(object_id).ref_count != 2 {
        fail("selftest: capability release refcount");
    }
    if !capability.release(root_cap) {
        fail("selftest: capability release root");
    }
    if capability.get(root_cap).live {
        fail("selftest: capability stale root get");
    }
    if capability.has_rights(root_cap, CapabilityRights.read) {
        fail("selftest: capability stale root rights");
    }
    if capability.status() != CapabilityStatus.invalid_capability {
        fail("selftest: capability stale root status");
    }
    if capability.count() != 0 {
        fail("selftest: capability count after release");
    }
    if kernel_object.get(object_id).ref_count != 1 {
        fail("selftest: capability object base refcount");
    }
    if !kernel_object.release(object_id) {
        fail("selftest: capability object release");
    }
    if kernel_object.is_live(object_id) {
        fail("selftest: capability object lifetime");
    }
}
