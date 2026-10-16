import .arch.aarch64.page_table as aarch64_page_table;
import .arch.riscv64.page_table as riscv64_page_table;
import .object.capability;
import { CapabilityRights } from .object.capability;
import .object.kernel_object;
import { KernelObjectKind } from .object.kernel_object;
import .memory.address_space;
import { AddressSpaceKind, AddressSpaceStatus } from .memory.address_space;
import .memory.boot;
import .memory.heap;
import { Layout } from .memory.layout;
import .memory.map as memory_map;
import .memory.page_table;
import { Spec } from .memory.page_table;
import .memory.phys;
import .memory.vm;
import .panic as panic_mod;

fn fail(name: string): void {
    println(name);
    panic_mod.panic();
}

pub fn run_boot_tests(map: Layout): void {
    if map.ram_start >= map.ram_end {
        fail("selftest: ram range");
    }
    if map.kernel_load < map.ram_start {
        fail("selftest: kernel low bound");
    }
    if map.kernel_load >= map.ram_end {
        fail("selftest: kernel high bound");
    }
    if map.page_size == 0 {
        fail("selftest: page size");
    }

    const before = boot.snapshot();
    if before.start < map.kernel_load {
        fail("selftest: boot start low bound");
    }
    if before.start >= before.end {
        fail("selftest: boot start before end");
    }
    if before.next != before.start {
        fail("selftest: boot next starts clean");
    }

    const first = boot.reserve(64, 16);
    if first == 0 {
        fail("selftest: boot first reserve");
    }
    const second = boot.reserve(map.page_size, map.page_size);
    if second == 0 {
        fail("selftest: boot second reserve");
    }

    if first < before.start {
        fail("selftest: boot first low bound");
    }
    if second < first + 64 {
        fail("selftest: boot reserve ordering");
    }
    if (second & (map.page_size - 1)) != 0 {
        fail("selftest: boot page alignment");
    }
}

pub fn run_phys_tests(map: Layout): void {
    if !boot.is_frozen() {
        fail("selftest: boot frozen");
    }

    const before = phys.snapshot();
    if before.page_size != map.page_size {
        fail("selftest: phys page size");
    }
    if before.total_pages == 0 {
        fail("selftest: phys total pages");
    }
    if before.free_pages == 0 {
        fail("selftest: phys free pages");
    }
    if before.used_pages == 0 {
        fail("selftest: phys used pages");
    }
    if before.bitmap_start == 0 {
        fail("selftest: phys bitmap start");
    }
    if before.bitmap_bytes == 0 {
        fail("selftest: phys bitmap bytes");
    }

    const late_boot = boot.reserve(1, 1);
    if late_boot != 0 {
        fail("selftest: late boot reserve");
    }

    const first = phys.alloc_page();
    if first == 0 {
        fail("selftest: phys alloc page");
    }
    if (first & (map.page_size - 1)) != 0 {
        fail("selftest: phys alloc align");
    }
    if first < map.ram_start {
        fail("selftest: phys alloc low bound");
    }
    if first >= map.ram_end {
        fail("selftest: phys alloc high bound");
    }

    const after_alloc = phys.snapshot();
    if after_alloc.free_pages + 1 != before.free_pages {
        fail("selftest: phys free count after alloc");
    }

    if !phys.free_page(first) {
        fail("selftest: phys free page");
    }
    const after_free = phys.snapshot();
    if after_free.free_pages != before.free_pages {
        fail("selftest: phys free count after free");
    }

    const second = phys.alloc_page();
    if second != first {
        fail("selftest: phys reuse page");
    }
    if !phys.free_page(second) {
        fail("selftest: phys free reused page");
    }
}

pub fn run_heap_tests(map: Layout): void {
    const before = phys.snapshot();
    const first = heap.allocate(64, 16);
    if first == 0 {
        fail("selftest: heap first alloc");
    }
    if (first & 15) != 0 {
        fail("selftest: heap first align");
    }
    if first < map.ram_start {
        fail("selftest: heap first low bound");
    }
    if first >= map.ram_end {
        fail("selftest: heap first high bound");
    }

    const second = heap.allocate(map.page_size + 32, map.page_size);
    if second == 0 {
        fail("selftest: heap second alloc");
    }
    if (second & (map.page_size - 1)) != 0 {
        fail("selftest: heap page align");
    }
    if second <= first {
        fail("selftest: heap ordering");
    }

    const heap_used = heap.snapshot();
    if heap_used.page_size != map.page_size {
        fail("selftest: heap page size");
    }
    if heap_used.committed_pages < 2 {
        fail("selftest: heap committed pages");
    }
    if heap_used.start == 0 {
        fail("selftest: heap start");
    }
    if heap_used.end <= heap_used.start {
        fail("selftest: heap range");
    }
    if heap_used.next <= heap_used.start {
        fail("selftest: heap next");
    }
    if heap_used.used_bytes != heap_used.next - heap_used.start {
        fail("selftest: heap used bytes");
    }
    if heap_used.used_bytes < heap_used.requested_bytes {
        fail("selftest: heap used below requested");
    }
    if heap_used.requested_bytes != map.page_size + 96 {
        fail("selftest: heap requested bytes");
    }
    if heap.allocate(1, 0) != 0 {
        fail("selftest: heap zero align");
    }
    if heap.status() != heap.status_invalid_alignment {
        fail("selftest: heap zero align status");
    }
    if heap.allocate(1, 24) != 0 {
        fail("selftest: heap non-power align");
    }
    if heap.status() != heap.status_invalid_alignment {
        fail("selftest: heap non-power align status");
    }
    if heap.allocate(0 - 1, map.page_size) != 0 {
        fail("selftest: heap overflow");
    }
    if heap.status() != heap.status_address_overflow {
        fail("selftest: heap overflow status");
    }
    if heap.deallocate(first) {
        fail("selftest: heap free unsupported");
    }
    if heap.status() != heap.status_deallocate_unsupported {
        fail("selftest: heap free unsupported status");
    }

    const after = phys.snapshot();
    if after.free_pages + heap_used.committed_pages != before.free_pages {
        fail("selftest: heap phys page count");
    }
    if heap_used.returns_virtual {
        fail("selftest: heap early virtual mode");
    }
}

pub fn run_heap_virtual_tests(map: Layout, spec: Spec): void {
    if !heap.returns_virtual() {
        fail("selftest: heap virtual mode");
    }
    const before = heap.snapshot();
    if before.virtual_start != vm.kernel_heap_virtual_base_for_spec(spec) {
        fail("selftest: heap virtual start");
    }
    if before.virtual_end != before.virtual_start + (before.committed_pages * map.page_size) {
        fail("selftest: heap virtual end");
    }
    const allocated = heap.allocate(32, 16);
    if allocated == 0 {
        fail("selftest: heap virtual alloc");
    }
    if allocated < before.virtual_start {
        fail("selftest: heap virtual alloc low");
    }
    if allocated >= before.virtual_end {
        fail("selftest: heap virtual alloc high");
    }
    if (allocated & 15) != 0 {
        fail("selftest: heap virtual alloc align");
    }
    const after = heap.snapshot();
    if after.virtual_next != after.virtual_start + after.used_bytes {
        fail("selftest: heap virtual next");
    }
    if after.requested_bytes != before.requested_bytes + 32 {
        fail("selftest: heap virtual requested");
    }

    const growth_before = heap.snapshot();
    const remaining = growth_before.virtual_end - growth_before.virtual_next;
    const grown = heap.allocate(remaining + 32, 16);
    if grown == 0 {
        fail("selftest: heap virtual grow alloc");
    }
    const growth_after = heap.snapshot();
    if growth_after.committed_pages != growth_before.committed_pages + 1 {
        fail("selftest: heap virtual grow pages");
    }
    if growth_after.virtual_end != growth_before.virtual_end + map.page_size {
        fail("selftest: heap virtual grow end");
    }
    if grown < growth_before.virtual_start {
        fail("selftest: heap virtual grow low");
    }
    if grown >= growth_after.virtual_end {
        fail("selftest: heap virtual grow high");
    }
    unchecked {
        const ptr = grown as! *u8;
        *ptr = 0x5a;
        if *ptr != 0x5a {
            fail("selftest: heap virtual grow touch");
        }
    }
}

pub fn run_memory_map_tests(map: Layout): void {
    const snapshot = memory_map.snapshot();
    if snapshot.region_count < 4 {
        fail("selftest: memory map region count");
    }
    if snapshot.identity_region_count < 3 {
        fail("selftest: memory map identity count");
    }
    if snapshot.free_region_count == 0 {
        fail("selftest: memory map free count");
    }

    var index: usize = 0;
    var saw_kernel = false;
    var saw_boot = false;
    var saw_bitmap = false;
    var saw_heap = false;
    var saw_page_tables = false;
    var saw_device_mmio: usize = 0;
    var saw_device_mmio2: usize = 0;
    while index < memory_map.count() {
        const region = memory_map.get(index);
        if region.start >= region.end {
            fail("selftest: memory map ordered range");
        }
        if region.kind == memory_map.kind_device_mmio {
            if region.start == map.device_mmio_start and region.end == map.device_mmio_end {
                saw_device_mmio = 1;
            } else {
                if map.device_mmio2_end > map.device_mmio2_start and region.start == map.device_mmio2_start and region.end == map.device_mmio2_end {
                    saw_device_mmio2 = 1;
                } else {
                    fail("selftest: memory map mmio range");
                }
            }
        } else {
            if region.start < map.ram_start {
                fail("selftest: memory map low bound");
            }
            if region.end > map.ram_end {
                fail("selftest: memory map high bound");
            }
        }

        if index != 0 {
            const previous = memory_map.get(index - 1);
            if previous.end > region.start {
                fail("selftest: memory map overlap");
            }
        }

        if region.kind == memory_map.kind_kernel_image {
            saw_kernel = true;
            if !memory_map.needs_identity_mapping(region.kind) {
                fail("selftest: kernel image identity");
            }
        }
        if region.kind == memory_map.kind_boot_allocator {
            saw_boot = true;
            if !memory_map.needs_identity_mapping(region.kind) {
                fail("selftest: boot allocator identity");
            }
        }
        if region.kind == memory_map.kind_physical_page_bitmap {
            saw_bitmap = true;
            if !memory_map.needs_identity_mapping(region.kind) {
                fail("selftest: bitmap identity");
            }
        }
        if region.kind == memory_map.kind_pre_vm_heap {
            saw_heap = true;
            if !memory_map.needs_identity_mapping(region.kind) {
                fail("selftest: heap identity");
            }
        }
        if region.kind == memory_map.kind_bootstrap_page_tables {
            saw_page_tables = true;
            if !memory_map.needs_identity_mapping(region.kind) {
                fail("selftest: page tables identity");
            }
        }
        if region.kind == memory_map.kind_device_mmio {
            if !memory_map.needs_identity_mapping(region.kind) {
                fail("selftest: device mmio identity");
            }
        }

        index = index + 1;
    }

    if !saw_kernel {
        fail("selftest: memory map kernel region");
    }
    if !saw_boot {
        fail("selftest: memory map boot region");
    }
    if !saw_bitmap {
        fail("selftest: memory map bitmap region");
    }
    if !saw_heap {
        fail("selftest: memory map heap region");
    }
    if !saw_page_tables {
        fail("selftest: memory map page table region");
    }
    if saw_device_mmio == 0 {
        fail("selftest: memory map device mmio region");
    }
    if map.device_mmio2_end > map.device_mmio2_start and saw_device_mmio2 == 0 {
        fail("selftest: memory map device mmio2 region");
    }
}

pub fn run_vm_contract_tests(map: Layout, spec: Spec): void {
    if !vm.is_power_of_two(map.page_size) {
        fail("selftest: vm page size power");
    }
    if !vm.is_page_aligned(map.ram_start, map.page_size) {
        fail("selftest: vm ram start align");
    }
    if !vm.is_page_aligned(map.ram_end, map.page_size) {
        fail("selftest: vm ram end align");
    }
    if !vm.validate_kernel_heap_range(spec) {
        fail("selftest: vm heap range");
    }
    if vm.kernel_virtual_base_for_spec(spec) == 0 {
        fail("selftest: vm kernel virtual base");
    }
    if vm.kernel_heap_virtual_base_for_spec(spec) < vm.kernel_virtual_base_for_spec(spec) {
        fail("selftest: vm heap below kernel virtual base");
    }
    if vm.kernel_heap_virtual_end_for_spec(spec) <= vm.kernel_heap_virtual_base_for_spec(spec) {
        fail("selftest: vm heap virtual end");
    }
    if vm.kernel_heap_virtual_base_for_spec(spec) - vm.kernel_virtual_base_for_spec(spec) != vm.kernel_heap_virtual_offset {
        fail("selftest: vm heap virtual offset");
    }
    if vm.user_virtual_base_for_spec(spec) != vm.user_virtual_base {
        fail("selftest: vm user base");
    }
    if vm.user_virtual_end_for_spec(spec) != vm.user_virtual_base + vm.user_virtual_size {
        fail("selftest: vm user end");
    }
    if !vm.is_user_virtual_range(vm.user_virtual_base_for_spec(spec), spec.page_size, spec) {
        fail("selftest: vm user range start");
    }
    if !vm.is_user_virtual_range(vm.user_virtual_end_for_spec(spec) - spec.page_size, spec.page_size, spec) {
        fail("selftest: vm user range end");
    }
    if vm.is_user_virtual_range(vm.user_virtual_end_for_spec(spec), spec.page_size, spec) {
        fail("selftest: vm user range overflow");
    }
    if !vm.is_kernel_virtual_range(vm.kernel_virtual_base_for_spec(spec), spec.page_size, spec) {
        fail("selftest: vm kernel range start");
    }
    if vm.is_kernel_virtual_range(vm.user_virtual_base_for_spec(spec), spec.page_size, spec) {
        fail("selftest: vm user not kernel range");
    }
    if !vm.validate_user_page_mapping(vm.user_virtual_base_for_spec(spec), map.ram_start, vm.rights_user_rw(), spec) {
        fail("selftest: vm user mapping valid");
    }
    if vm.validate_user_page_mapping(vm.kernel_virtual_base_for_spec(spec), map.ram_start, vm.rights_user_rw(), spec) {
        fail("selftest: vm user mapping kernel addr");
    }
    if vm.validate_user_page_mapping(vm.user_virtual_base_for_spec(spec), map.ram_start, vm.rights_kernel_rw(), spec) {
        fail("selftest: vm user mapping kernel rights");
    }
    if !vm.validate_kernel_page_mapping(vm.kernel_heap_virtual_base_for_spec(spec), map.ram_start, vm.rights_kernel_rw(), spec) {
        fail("selftest: vm kernel mapping valid");
    }
    if vm.validate_kernel_page_mapping(vm.kernel_heap_virtual_base_for_spec(spec), map.ram_start, vm.rights_user_rw(), spec) {
        fail("selftest: vm kernel mapping user rights");
    }

    const phys = map.kernel_load;
    const virt = vm.identity_virtual_for_phys(phys);
    if virt != map.kernel_load {
        fail("selftest: vm identity virt");
    }
    if vm.phys_for_identity_virtual(virt) != phys {
        fail("selftest: vm identity phys");
    }

    if vm.rights_has_user(vm.rights_kernel_rw()) {
        fail("selftest: vm kernel user bit");
    }
    if !vm.rights_has_user(vm.rights_user_rw()) {
        fail("selftest: vm user bit");
    }
    if (vm.rights_kernel_rx() & vm.rights_write) != 0 {
        fail("selftest: vm rx write");
    }
    if !vm.rights_are_valid(vm.rights_kernel_rw()) {
        fail("selftest: vm kernel rw rights");
    }
    if !vm.rights_are_valid(vm.rights_kernel_rx()) {
        fail("selftest: vm kernel rx rights");
    }
    if vm.rights_are_valid(0) {
        fail("selftest: vm empty rights");
    }
    if vm.rights_are_valid(vm.rights_write) {
        fail("selftest: vm write without read");
    }

    const plan = vm.bootstrap_plan(map, spec);
    const snapshot = memory_map.snapshot();
    if plan.identity_region_count != snapshot.identity_region_count {
        fail("selftest: vm identity count");
    }
    if plan.kernel_heap_mapping_count != 1 {
        fail("selftest: vm heap mapping count");
    }
    if plan.mapping_request_count != snapshot.identity_region_count + plan.kernel_heap_mapping_count {
        fail("selftest: vm mapping count");
    }
    if plan.page_table_root == 0 {
        fail("selftest: vm page table root");
    }
    if !vm.is_page_aligned(plan.page_table_root, map.page_size) {
        fail("selftest: vm page table root align");
    }
    if plan.page_table_pages == 0 {
        fail("selftest: vm page table pages");
    }
    if plan.page_table_used_pages <= 1 {
        fail("selftest: vm page table used pages");
    }
    if plan.page_table_used_pages > plan.page_table_pages {
        fail("selftest: vm page table used above reserved");
    }
    if plan.page_table_zeroed_pages != plan.page_table_pages {
        fail("selftest: vm page table zeroed pages");
    }
    if plan.identity_region_count == 0 {
        fail("selftest: vm identity empty");
    }
    if plan.kernel_heap_base != vm.kernel_heap_virtual_base_for_spec(spec) {
        fail("selftest: vm heap base");
    }
    if plan.kernel_heap_end != vm.kernel_heap_virtual_end_for_spec(spec) {
        fail("selftest: vm heap end");
    }
    if plan.user_base != vm.user_virtual_base_for_spec(spec) {
        fail("selftest: vm plan user base");
    }
    if plan.user_end != vm.user_virtual_end_for_spec(spec) {
        fail("selftest: vm plan user end");
    }
    if plan.kernel_base != vm.kernel_virtual_base_for_spec(spec) {
        fail("selftest: vm plan kernel base");
    }
    if plan.page_size != map.page_size {
        fail("selftest: vm page size");
    }

    if vm.mapping_request_count() != plan.mapping_request_count {
        fail("selftest: vm mapping request count");
    }

    var index: usize = 0;
    var saw_page_tables = false;
    var saw_heap_virtual = false;
    const heap_used = heap.snapshot();
    while index < vm.mapping_request_count() {
        const request = vm.mapping_request(index);
        if request.size == 0 {
            fail("selftest: vm mapping size");
        }
        if !vm.is_page_aligned(request.virt_start, map.page_size) {
            fail("selftest: vm mapping virt align");
        }
        if !vm.is_page_aligned(request.phys_start, map.page_size) {
            fail("selftest: vm mapping phys align");
        }
        if !vm.is_page_aligned(request.phys_start + request.size, map.page_size) {
            fail("selftest: vm mapping end align");
        }
        if request.kind == memory_map.kind_kernel_heap_virtual {
            saw_heap_virtual = true;
            if request.virt_start != plan.kernel_heap_base {
                fail("selftest: vm heap virtual start");
            }
            if request.phys_start != heap_used.start {
                fail("selftest: vm heap virtual phys");
            }
            if request.size != heap_used.committed_pages * map.page_size {
                fail("selftest: vm heap virtual size");
            }
        } else {
            if request.virt_start != vm.identity_virtual_for_phys(request.phys_start) {
                fail("selftest: vm mapping identity");
            }
        }
        if vm.rights_has_user(request.rights) {
            fail("selftest: vm mapping user");
        }
        if request.kind == memory_map.kind_kernel_image {
            if (request.rights & vm.rights_execute) == 0 {
                fail("selftest: vm kernel image execute");
            }
            if (request.rights & vm.rights_write) == 0 {
                fail("selftest: vm kernel image write");
            }
        } else {
            if (request.rights & vm.rights_write) == 0 {
                fail("selftest: vm mapping write");
            }
        }
        if request.kind == memory_map.kind_bootstrap_page_tables {
            saw_page_tables = true;
            if request.phys_start != plan.page_table_root {
                fail("selftest: vm page table mapping root");
            }
            if request.size != plan.page_table_pages * map.page_size {
                fail("selftest: vm page table mapping size");
            }
        }
        index = index + 1;
    }
    if !saw_page_tables {
        fail("selftest: vm page table mapping");
    }
    if !saw_heap_virtual {
        fail("selftest: vm heap virtual mapping");
    }
}

pub fn run_address_space_tests(map: Layout, spec: Spec, kernel_space_id: usize): void {
    if address_space.count() != 1 {
        fail("selftest: address space kernel count");
    }
    if address_space.current() != kernel_space_id {
        fail("selftest: address space current kernel");
    }
    if kernel_object.count() != 1 {
        fail("selftest: address space kernel object count");
    }
    if capability.count() != 1 {
        fail("selftest: address space kernel cap count");
    }

    const expected_user_base = vm.user_virtual_base_for_spec(spec);
    const expected_user_end = vm.user_virtual_end_for_spec(spec);
    const expected_kernel_base = vm.kernel_virtual_base_for_spec(spec);
    const expected_heap_base = vm.kernel_heap_virtual_base_for_spec(spec);
    const expected_heap_end = vm.kernel_heap_virtual_end_for_spec(spec);
    if address_space.kind(kernel_space_id) != AddressSpaceKind.kernel {
        fail("selftest: address space kernel kind");
    }
    const kernel_object_id = address_space.object_id(kernel_space_id);
    if kernel_object_id == kernel_object.invalid_id {
        fail("selftest: address space kernel object id");
    }
    const kernel_object_value = kernel_object.get(kernel_object_id);
    if !kernel_object_value.live {
        fail("selftest: address space kernel object live");
    }
    if kernel_object_value.kind != KernelObjectKind.address_space {
        fail("selftest: address space kernel object kind");
    }
    if kernel_object_value.ref_count != 2 {
        fail("selftest: address space kernel object refcount");
    }
    const kernel_capability_id = address_space.capability_id(kernel_space_id);
    if kernel_capability_id == capability.invalid_id {
        fail("selftest: address space kernel capability id");
    }
    const kernel_capability_value = capability.get(kernel_capability_id);
    if !kernel_capability_value.live {
        fail("selftest: address space kernel capability live");
    }
    if kernel_capability_value.object_id != kernel_object_id {
        fail("selftest: address space kernel capability object");
    }
    if !address_space.capability_has_rights(kernel_space_id, CapabilityRights.map | CapabilityRights.inspect | CapabilityRights.manage) {
        fail("selftest: address space kernel capability rights");
    }
    if !address_space.capability_has_rights(kernel_space_id, CapabilityRights.duplicate) {
        fail("selftest: address space kernel capability duplicate");
    }
    if !address_space.capability_can_map_kernel_page(kernel_capability_id, kernel_space_id, expected_heap_base, map.ram_start, vm.rights_kernel_rw(), spec) {
        fail("selftest: address space kernel cap map");
    }
    if address_space.capability_can_map_kernel_page(capability.invalid_id, kernel_space_id, expected_heap_base, map.ram_start, vm.rights_kernel_rw(), spec) {
        fail("selftest: address space kernel invalid cap map");
    }
    if address_space.status() != AddressSpaceStatus.invalid_capability {
        fail("selftest: address space kernel invalid cap status");
    }
    if address_space.root_table(kernel_space_id) == 0 {
        fail("selftest: address space kernel root");
    }
    if !address_space.active(kernel_space_id) {
        fail("selftest: address space kernel active");
    }
    if address_space.user_base(kernel_space_id) != expected_user_base {
        fail("selftest: address space user base");
    }
    if address_space.user_end(kernel_space_id) != expected_user_end {
        fail("selftest: address space user end");
    }
    if address_space.kernel_base(kernel_space_id) != expected_kernel_base {
        fail("selftest: address space kernel base");
    }
    if address_space.kernel_heap_base(kernel_space_id) != expected_heap_base {
        fail("selftest: address space heap base");
    }
    if address_space.kernel_heap_end(kernel_space_id) != expected_heap_end {
        fail("selftest: address space heap end");
    }
    if !address_space.has_root(kernel_space_id) {
        fail("selftest: address space kernel has root");
    }
    if !address_space.can_map_kernel_page(kernel_space_id, expected_heap_base, map.ram_start, vm.rights_kernel_rw(), spec) {
        fail("selftest: address space kernel map");
    }
    if address_space.can_map_kernel_page(kernel_space_id, expected_heap_base, map.ram_start, vm.rights_user_rw(), spec) {
        fail("selftest: address space kernel user rights");
    }
    if address_space.can_map_user_page(kernel_space_id, expected_user_base, map.ram_start, vm.rights_user_rw(), spec) {
        fail("selftest: address space kernel user map");
    }

    const user_space_id = address_space.create_user_policy_fixture(spec);
    if user_space_id == address_space.invalid_id {
        fail("selftest: address space user fixture create");
    }
    if address_space.count() != 2 {
        fail("selftest: address space user count");
    }
    if kernel_object.count() != 2 {
        fail("selftest: address space user object count");
    }
    if capability.count() != 2 {
        fail("selftest: address space user cap count");
    }
    if address_space.kind(user_space_id) != AddressSpaceKind.user {
        fail("selftest: address space user kind");
    }
    const user_object_id = address_space.object_id(user_space_id);
    if user_object_id == kernel_object.invalid_id {
        fail("selftest: address space user object id");
    }
    if user_object_id == kernel_object_id {
        fail("selftest: address space distinct objects");
    }
    if kernel_object.get(user_object_id).kind != KernelObjectKind.address_space {
        fail("selftest: address space user object kind");
    }
    if kernel_object.get(user_object_id).ref_count != 2 {
        fail("selftest: address space user object refcount");
    }
    const user_capability_id = address_space.capability_id(user_space_id);
    if user_capability_id == capability.invalid_id {
        fail("selftest: address space user capability id");
    }
    if user_capability_id == kernel_capability_id {
        fail("selftest: address space distinct capabilities");
    }
    if capability.get(user_capability_id).object_id != user_object_id {
        fail("selftest: address space user capability object");
    }
    if !address_space.capability_has_rights(user_space_id, CapabilityRights.map | CapabilityRights.inspect) {
        fail("selftest: address space user capability rights");
    }
    if address_space.capability_has_rights(user_space_id, CapabilityRights.manage) {
        fail("selftest: address space user capability manage");
    }
    if !address_space.capability_accepts_user_mapping_policy(user_capability_id, user_space_id, expected_user_base, map.ram_start, vm.rights_user_rw(), spec) {
        fail("selftest: address space user cap policy");
    }
    if address_space.capability_accepts_user_mapping_policy(kernel_capability_id, user_space_id, expected_user_base, map.ram_start, vm.rights_user_rw(), spec) {
        fail("selftest: address space user wrong cap policy");
    }
    if address_space.status() != AddressSpaceStatus.capability_object_mismatch {
        fail("selftest: address space user wrong cap status");
    }
    if address_space.capability_can_map_kernel_page(user_capability_id, kernel_space_id, expected_heap_base, map.ram_start, vm.rights_kernel_rw(), spec) {
        fail("selftest: address space kernel wrong cap map");
    }
    if address_space.status() != AddressSpaceStatus.capability_object_mismatch {
        fail("selftest: address space kernel wrong cap status");
    }
    const inspect_capability_id = capability.duplicate(user_capability_id, CapabilityRights.inspect);
    if inspect_capability_id == capability.invalid_id {
        fail("selftest: address space inspect cap duplicate");
    }
    if address_space.capability_accepts_user_mapping_policy(inspect_capability_id, user_space_id, expected_user_base, map.ram_start, vm.rights_user_rw(), spec) {
        fail("selftest: address space inspect cap map");
    }
    if address_space.status() != AddressSpaceStatus.capability_right_missing {
        fail("selftest: address space inspect cap status");
    }
    if address_space.root_table(user_space_id) != 0 {
        fail("selftest: address space user root");
    }
    if address_space.active(user_space_id) {
        fail("selftest: address space user inactive");
    }
    if !address_space.accepts_user_mapping_policy(user_space_id, expected_user_base, map.ram_start, vm.rights_user_rw(), spec) {
        fail("selftest: address space user policy");
    }
    if address_space.accepts_user_mapping_policy(user_space_id, expected_kernel_base, map.ram_start, vm.rights_user_rw(), spec) {
        fail("selftest: address space user policy kernel addr");
    }
    if address_space.can_map_user_page(user_space_id, expected_user_base, map.ram_start, vm.rights_user_rw(), spec) {
        fail("selftest: address space user map without root");
    }
    if address_space.status() != AddressSpaceStatus.root_unallocated {
        fail("selftest: address space user root status");
    }
    if address_space.can_map_kernel_page(user_space_id, expected_heap_base, map.ram_start, vm.rights_kernel_rw(), spec) {
        fail("selftest: address space user kernel map");
    }

    if address_space.create_user_rooted(0, spec) != address_space.invalid_id {
        fail("selftest: address space rooted user zero root");
    }
    if address_space.status() != AddressSpaceStatus.invalid_user_plan {
        fail("selftest: address space rooted user zero status");
    }
    const user_root = phys.alloc_page();
    if user_root == 0 {
        fail("selftest: address space rooted user root alloc");
    }
    const rooted_user_space_id = address_space.create_user_rooted(user_root, spec);
    if rooted_user_space_id == address_space.invalid_id {
        fail("selftest: address space rooted user create");
    }
    if address_space.count() != 3 {
        fail("selftest: address space rooted user count");
    }
    if address_space.kind(rooted_user_space_id) != AddressSpaceKind.user {
        fail("selftest: address space rooted user kind");
    }
    if address_space.root_table(rooted_user_space_id) != user_root {
        fail("selftest: address space rooted user root");
    }
    if !address_space.has_root(rooted_user_space_id) {
        fail("selftest: address space rooted user has root");
    }
    if address_space.active(rooted_user_space_id) {
        fail("selftest: address space rooted user inactive");
    }
    if address_space.user_base(rooted_user_space_id) != expected_user_base {
        fail("selftest: address space rooted user base");
    }
    if address_space.user_end(rooted_user_space_id) != expected_user_end {
        fail("selftest: address space rooted user end");
    }
    if address_space.kernel_base(rooted_user_space_id) != expected_kernel_base {
        fail("selftest: address space rooted user kernel base");
    }
    const rooted_user_capability_id = address_space.capability_id(rooted_user_space_id);
    if rooted_user_capability_id == capability.invalid_id {
        fail("selftest: address space rooted user cap");
    }
    if !address_space.capability_has_rights(rooted_user_space_id, CapabilityRights.map | CapabilityRights.inspect) {
        fail("selftest: address space rooted user cap rights");
    }
    if address_space.capability_has_rights(rooted_user_space_id, CapabilityRights.manage) {
        fail("selftest: address space rooted user manage rights");
    }
    if !address_space.can_map_user_page(rooted_user_space_id, expected_user_base, map.ram_start, vm.rights_user_rw(), spec) {
        fail("selftest: address space rooted user map");
    }
    if !address_space.capability_can_map_user_page(rooted_user_capability_id, rooted_user_space_id, expected_user_base, map.ram_start, vm.rights_user_rw(), spec) {
        fail("selftest: address space rooted user cap map");
    }
    if address_space.can_map_user_page(rooted_user_space_id, expected_kernel_base, map.ram_start, vm.rights_user_rw(), spec) {
        fail("selftest: address space rooted user kernel addr");
    }
    if address_space.can_map_kernel_page(rooted_user_space_id, expected_heap_base, map.ram_start, vm.rights_kernel_rw(), spec) {
        fail("selftest: address space rooted user kernel map");
    }
}
