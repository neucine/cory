import .arch.aarch64.context as aarch64_context;
import .arch.riscv64.context as riscv64_context;
import .memory.address_space;
import .memory.page_table;
import { Spec } from .memory.page_table;
import .memory.phys;
import .memory.user_loader;
import { UserLoaderStatus } from .memory.user_loader;
import .memory.user_memory;
import { UserMemoryStatus } from .memory.user_memory;
import .memory.vm;
import .console;
import .object.capability;
import { CapabilityRights } from .object.capability;
import .object.kernel_object;
import { KernelObjectKind } from .object.kernel_object;
import .panic as panic_mod;
import .syscall;
import { SyscallError, SyscallOp, SyscallOrigin, SyscallStatus } from .syscall;
import .task.capability_space;
import { CapabilitySpaceStatus } from .task.capability_space;
import .task.context;
import { ContextStatus } from .task.context;
import .task.process;
import { ProcessKind, ProcessStatus } from .task.process;
import .task.scheduler;
import { SchedulerStatus } from .task.scheduler;
import .task.thread;
import { ThreadState, ThreadStatus } from .task.thread;
import .task.user_entry as user_entry_mod;
import { UserEntryStatus } from .task.user_entry;
import .task.user_program;
import { UserProgramStatus } from .task.user_program;

fn fail(name: string): void {
    println(name);
    panic_mod.panic();
}

fn allocate_arch_context(arch: i32, thread_id: usize): usize {
    if arch == page_table.arch_aarch64 {
        return aarch64_context.allocate(thread_id);
    }
    if arch == page_table.arch_riscv64 {
        return riscv64_context.allocate(thread_id);
    }
    return context.invalid_arch_context;
}

fn user_status_flags_for_arch(arch: i32): usize {
    if arch == page_table.arch_aarch64 {
        return aarch64_context.user_status_flags();
    }
    if arch == page_table.arch_riscv64 {
        return riscv64_context.user_status_flags();
    }
    return 0;
}

pub fn run_process_tests(kernel_space_id: usize, kernel_process_id: usize): void {
    if process.count() != 1 {
        fail("selftest: process kernel count");
    }
    if process.current() != kernel_process_id {
        fail("selftest: process current kernel");
    }
    const kernel_process = process.get(kernel_process_id);
    if kernel_process.id != kernel_process_id {
        fail("selftest: process kernel id");
    }
    if kernel_process.kind != ProcessKind.kernel {
        fail("selftest: process kernel kind");
    }
    if !kernel_process.active {
        fail("selftest: process kernel active");
    }
    if kernel_process.address_space_id != kernel_space_id {
        fail("selftest: process kernel address space");
    }
    if kernel_process.object_id == kernel_object.invalid_id {
        fail("selftest: process kernel object id");
    }
    if kernel_object.get(kernel_process.object_id).kind != KernelObjectKind.process {
        fail("selftest: process kernel object kind");
    }
    if kernel_object.get(kernel_process.object_id).ref_count != 2 {
        fail("selftest: process kernel object refcount");
    }
    if kernel_process.capability_id == capability.invalid_id {
        fail("selftest: process kernel capability id");
    }
    if kernel_process.capability_slot == capability_space.invalid_slot {
        fail("selftest: process kernel capability slot");
    }
    if capability.get(kernel_process.capability_id).object_id != kernel_process.object_id {
        fail("selftest: process kernel capability object");
    }
    if !capability.has_rights(kernel_process.capability_id, CapabilityRights.inspect | CapabilityRights.manage) {
        fail("selftest: process kernel capability rights");
    }
    if kernel_process.address_space_capability_id == capability.invalid_id {
        fail("selftest: process address space capability id");
    }
    if kernel_process.address_space_capability_slot == capability_space.invalid_slot {
        fail("selftest: process address space capability slot");
    }
    if capability.get(kernel_process.address_space_capability_id).object_id != address_space.object_id(kernel_space_id) {
        fail("selftest: process address space capability object");
    }
    if !capability.has_rights(kernel_process.address_space_capability_id, CapabilityRights.inspect | CapabilityRights.manage) {
        fail("selftest: process address space capability rights");
    }
    if capability_space.count(kernel_process_id) != 2 {
        fail("selftest: process capability space count");
    }
    if capability_space.get(kernel_process_id, kernel_process.capability_slot) != kernel_process.capability_id {
        fail("selftest: process capability slot root");
    }
    if capability_space.get(kernel_process_id, kernel_process.address_space_capability_slot) != kernel_process.address_space_capability_id {
        fail("selftest: process capability slot address space");
    }
    if !capability_space.has_rights(kernel_process_id, kernel_process.capability_slot, CapabilityRights.inspect | CapabilityRights.manage) {
        fail("selftest: process capability slot root rights");
    }
    if !capability_space.has_rights(kernel_process_id, kernel_process.address_space_capability_slot, CapabilityRights.inspect | CapabilityRights.manage) {
        fail("selftest: process capability slot address rights");
    }
    if capability_space.get(kernel_process_id, 2) != capability.invalid_id {
        fail("selftest: process capability invalid slot");
    }
    if capability_space.status() != CapabilitySpaceStatus.invalid_slot {
        fail("selftest: process capability invalid slot status");
    }
    if capability_space.install(process.invalid_id, kernel_process.capability_id) != capability_space.invalid_slot {
        fail("selftest: process capability invalid owner");
    }
    if capability_space.status() != CapabilitySpaceStatus.invalid_owner {
        fail("selftest: process capability invalid owner status");
    }
    if capability_space.install(kernel_process_id, capability.invalid_id) != capability_space.invalid_slot {
        fail("selftest: process capability invalid capability");
    }
    if capability_space.status() != CapabilitySpaceStatus.invalid_capability {
        fail("selftest: process capability invalid capability status");
    }
    const removable_capability = capability.duplicate(kernel_process.capability_id, CapabilityRights.inspect);
    if removable_capability == capability.invalid_id {
        fail("selftest: process removable cap duplicate");
    }
    const removable_slot = capability_space.install(kernel_process_id, removable_capability);
    if removable_slot == capability_space.invalid_slot {
        fail("selftest: process removable cap install");
    }
    if capability_space.count(kernel_process_id) != 3 {
        fail("selftest: process removable cap count");
    }
    if !capability_space.remove(kernel_process_id, removable_slot) {
        fail("selftest: process removable cap remove");
    }
    if capability_space.count(kernel_process_id) != 2 {
        fail("selftest: process removable cap removed count");
    }
    if capability_space.get(kernel_process_id, removable_slot) != capability.invalid_id {
        fail("selftest: process removable cap removed get");
    }
    if capability_space.status() != CapabilitySpaceStatus.invalid_slot {
        fail("selftest: process removable cap removed status");
    }
    if !capability.release(removable_capability) {
        fail("selftest: process removable cap release");
    }
    const stale_capability = capability.duplicate(kernel_process.capability_id, CapabilityRights.inspect);
    if stale_capability == capability.invalid_id {
        fail("selftest: process stale cap duplicate");
    }
    const stale_slot = capability_space.install(kernel_process_id, stale_capability);
    if stale_slot == capability_space.invalid_slot {
        fail("selftest: process stale cap install");
    }
    if !capability.release(stale_capability) {
        fail("selftest: process stale cap release");
    }
    if capability_space.get(kernel_process_id, stale_slot) != capability.invalid_id {
        fail("selftest: process stale cap get");
    }
    if capability_space.status() != CapabilitySpaceStatus.invalid_capability {
        fail("selftest: process stale cap status");
    }
    if capability_space.count(kernel_process_id) != 2 {
        fail("selftest: process stale cap count");
    }

    if process.create_kernel_bootstrap(address_space.invalid_id, address_space.capability_id(kernel_space_id)) != process.invalid_id {
        fail("selftest: process invalid address space");
    }
    if process.status() != ProcessStatus.invalid_address_space {
        fail("selftest: process invalid address space status");
    }
    if process.create_kernel_bootstrap(kernel_space_id, capability.invalid_id) != process.invalid_id {
        fail("selftest: process invalid capability");
    }
    if process.status() != ProcessStatus.invalid_capability {
        fail("selftest: process invalid capability status");
    }

    const inspect_capability = capability.duplicate(address_space.capability_id(kernel_space_id), CapabilityRights.inspect);
    if inspect_capability == capability.invalid_id {
        fail("selftest: process inspect cap duplicate");
    }
    if process.create_kernel_bootstrap(kernel_space_id, inspect_capability) != process.invalid_id {
        fail("selftest: process missing manage");
    }
    if process.status() != ProcessStatus.capability_right_missing {
        fail("selftest: process missing manage status");
    }
    if !capability.release(inspect_capability) {
        fail("selftest: process release inspect cap");
    }

    const other_object = kernel_object.allocate(KernelObjectKind.channel);
    if other_object == kernel_object.invalid_id {
        fail("selftest: process other object");
    }
    const other_capability = capability.mint(other_object, CapabilityRights.inspect | CapabilityRights.manage | CapabilityRights.duplicate);
    if other_capability == capability.invalid_id {
        fail("selftest: process other capability");
    }
    if process.create_kernel_bootstrap(kernel_space_id, other_capability) != process.invalid_id {
        fail("selftest: process wrong object capability");
    }
    if process.status() != ProcessStatus.capability_object_mismatch {
        fail("selftest: process wrong object status");
    }
    if !capability.release(other_capability) {
        fail("selftest: process release other capability");
    }
    if !kernel_object.release(other_object) {
        fail("selftest: process release other object");
    }

    if process.release(kernel_process_id) {
        fail("selftest: process release active kernel");
    }
    if process.status() != ProcessStatus.active_process {
        fail("selftest: process release active status");
    }
    if process.count() != 1 {
        fail("selftest: process release active count");
    }
    if capability_space.count(kernel_process_id) != 2 {
        fail("selftest: process release active cap space count");
    }
    if process.get(kernel_process_id).id != kernel_process_id {
        fail("selftest: process release active still live");
    }

    const inactive_process_id = process.create_kernel_inactive(kernel_space_id, address_space.capability_id(kernel_space_id));
    if inactive_process_id == process.invalid_id {
        fail("selftest: process inactive create");
    }
    if process.current() != kernel_process_id {
        fail("selftest: process inactive current unchanged");
    }
    if process.count() != 2 {
        fail("selftest: process inactive count");
    }
    const inactive_process = process.get(inactive_process_id);
    if inactive_process.id != inactive_process_id {
        fail("selftest: process inactive id");
    }
    if inactive_process.active {
        fail("selftest: process inactive active flag");
    }
    if inactive_process.exited {
        fail("selftest: process inactive exited flag");
    }
    if inactive_process.exit_code != 0 {
        fail("selftest: process inactive exit code");
    }
    if !process.mark_active(inactive_process_id) {
        fail("selftest: process inactive mark active");
    }
    if !process.get(inactive_process_id).active {
        fail("selftest: process inactive active after mark");
    }
    if !process.mark_inactive(inactive_process_id) {
        fail("selftest: process inactive mark inactive");
    }
    if process.get(inactive_process_id).active {
        fail("selftest: process inactive inactive after mark");
    }
    if !process.mark_exited(inactive_process_id, 17) {
        fail("selftest: process inactive mark exited");
    }
    const exited_process = process.get(inactive_process_id);
    if exited_process.active {
        fail("selftest: process exited active flag");
    }
    if !exited_process.exited {
        fail("selftest: process exited flag");
    }
    if exited_process.exit_code != 17 {
        fail("selftest: process exited code");
    }
    if !process.mark_active(inactive_process_id) {
        fail("selftest: process exited reactivate");
    }
    const reactivated_process = process.get(inactive_process_id);
    if !reactivated_process.active {
        fail("selftest: process reactivated active flag");
    }
    if reactivated_process.exited {
        fail("selftest: process reactivated exited flag");
    }
    if reactivated_process.exit_code != 0 {
        fail("selftest: process reactivated exit code");
    }
    if !process.mark_inactive(inactive_process_id) {
        fail("selftest: process reactivated mark inactive");
    }
    if process.wait_exit_code(inactive_process_id) != 0 {
        fail("selftest: process wait inactive code");
    }
    if process.status() != ProcessStatus.not_exited {
        fail("selftest: process wait inactive status");
    }
    if inactive_process.capability_slot == capability_space.invalid_slot {
        fail("selftest: process inactive root cap slot stored");
    }
    if inactive_process.address_space_capability_slot == capability_space.invalid_slot {
        fail("selftest: process inactive address cap slot stored");
    }
    if capability_space.count(inactive_process_id) != 2 {
        fail("selftest: process inactive cap space count");
    }
    if capability_space.get(inactive_process_id, inactive_process.capability_slot) != inactive_process.capability_id {
        fail("selftest: process inactive root cap slot");
    }
    if capability_space.get(inactive_process_id, inactive_process.address_space_capability_slot) != inactive_process.address_space_capability_id {
        fail("selftest: process inactive address cap slot");
    }
    if !process.release(inactive_process_id) {
        fail("selftest: process release inactive");
    }
    if process.count() != 1 {
        fail("selftest: process release count");
    }
    if process.get(inactive_process_id).id != process.invalid_id {
        fail("selftest: process release stale get");
    }
    if capability_space.count(inactive_process_id) != 0 {
        fail("selftest: process release cap space count");
    }
    if capability_space.status() != CapabilitySpaceStatus.invalid_owner {
        fail("selftest: process release cap space status");
    }
    if capability.get(inactive_process.capability_id).live {
        fail("selftest: process release root cap");
    }
    if capability.get(inactive_process.address_space_capability_id).live {
        fail("selftest: process release address cap");
    }
    if kernel_object.is_live(inactive_process.object_id) {
        fail("selftest: process release object");
    }
    if process.release(inactive_process_id) {
        fail("selftest: process stale release");
    }
    if process.status() != ProcessStatus.invalid_id {
        fail("selftest: process stale release status");
    }

    const reaped_process_id = process.create_kernel_inactive(kernel_space_id, address_space.capability_id(kernel_space_id));
    if reaped_process_id == process.invalid_id {
        fail("selftest: process reap create");
    }
    if !process.mark_exited(reaped_process_id, 23) {
        fail("selftest: process reap mark exited");
    }
    if process.wait_exit_code(reaped_process_id) != 23 {
        fail("selftest: process reap wait code");
    }
    if process.status() != ProcessStatus.ok {
        fail("selftest: process reap wait status");
    }
    if process.reap_exited(reaped_process_id) != 23 {
        fail("selftest: process reap code");
    }
    if process.status() != ProcessStatus.ok {
        fail("selftest: process reap status");
    }
    if process.get(reaped_process_id).id != process.invalid_id {
        fail("selftest: process reap stale get");
    }
    if process.reap_exited(reaped_process_id) != 0 {
        fail("selftest: process reap stale code");
    }
    if process.status() != ProcessStatus.invalid_id {
        fail("selftest: process reap stale status");
    }
}

pub fn run_thread_tests(kernel_process_id: usize, kernel_thread_id: usize, arch: i32, spec: Spec): void {
    if thread.count() != 1 {
        fail("selftest: thread kernel count");
    }
    if thread.current() != kernel_thread_id {
        fail("selftest: thread current kernel");
    }
    const kernel_thread = thread.get(kernel_thread_id);
    if kernel_thread.id != kernel_thread_id {
        fail("selftest: thread kernel id");
    }
    if kernel_thread.process_id != kernel_process_id {
        fail("selftest: thread kernel process");
    }
    if kernel_thread.state != ThreadState.running {
        fail("selftest: thread kernel state");
    }
    if kernel_thread.entry_addr != 0 {
        fail("selftest: thread kernel entry");
    }
    if kernel_thread.stack_base != 0 {
        fail("selftest: thread kernel stack");
    }
    if kernel_thread.object_id == kernel_object.invalid_id {
        fail("selftest: thread kernel object id");
    }
    if kernel_object.get(kernel_thread.object_id).kind != KernelObjectKind.thread {
        fail("selftest: thread kernel object kind");
    }
    if kernel_object.get(kernel_thread.object_id).ref_count != 2 {
        fail("selftest: thread kernel object refcount");
    }
    if kernel_thread.capability_id == capability.invalid_id {
        fail("selftest: thread kernel capability id");
    }
    if kernel_thread.capability_slot == capability_space.invalid_slot {
        fail("selftest: thread kernel capability slot");
    }
    if capability_space.count(kernel_process_id) != 3 {
        fail("selftest: thread capability space count");
    }
    if capability_space.get(kernel_process_id, kernel_thread.capability_slot) != kernel_thread.capability_id {
        fail("selftest: thread capability space handle");
    }
    if capability.get(kernel_thread.capability_id).object_id != kernel_thread.object_id {
        fail("selftest: thread kernel capability object");
    }
    if !capability.has_rights(kernel_thread.capability_id, CapabilityRights.inspect | CapabilityRights.manage) {
        fail("selftest: thread kernel capability rights");
    }
    if !context.has_context(kernel_thread_id) {
        fail("selftest: thread kernel context");
    }
    if context.has_context(thread.invalid_id) {
        fail("selftest: thread invalid context lookup");
    }
    if context.get(thread.invalid_id).initialized {
        fail("selftest: thread invalid context get");
    }
    const kernel_context = context.get(kernel_thread_id);
    if !kernel_context.initialized {
        fail("selftest: thread kernel context initialized");
    }
    if kernel_context.id == context.invalid_id {
        fail("selftest: thread kernel context id");
    }
    if kernel_context.instruction_pointer != 0 {
        fail("selftest: thread kernel context ip");
    }
    if kernel_context.stack_pointer != 0 {
        fail("selftest: thread kernel context sp");
    }
    if kernel_context.arch_id != arch {
        fail("selftest: thread kernel context arch");
    }
    if kernel_context.arch_context_id == context.invalid_arch_context {
        fail("selftest: thread kernel arch context id");
    }
    if arch == page_table.arch_aarch64 {
        if !aarch64_context.is_live(kernel_context.arch_context_id) {
            fail("selftest: thread kernel aarch64 arch context live");
        }
        if aarch64_context.owner_thread_id(kernel_context.arch_context_id) != kernel_thread_id {
            fail("selftest: thread kernel aarch64 arch context owner");
        }
        if aarch64_context.instruction_pointer(kernel_context.arch_context_id) != kernel_context.instruction_pointer {
            fail("selftest: thread kernel aarch64 arch context ip");
        }
        if aarch64_context.stack_pointer(kernel_context.arch_context_id) != kernel_context.stack_pointer {
            fail("selftest: thread kernel aarch64 arch context sp");
        }
        if aarch64_context.status_flags(kernel_context.arch_context_id) != kernel_context.status_flags {
            fail("selftest: thread kernel aarch64 arch context flags");
        }
    }
    if arch == page_table.arch_riscv64 {
        if !riscv64_context.is_live(kernel_context.arch_context_id) {
            fail("selftest: thread kernel riscv64 arch context live");
        }
        if riscv64_context.owner_thread_id(kernel_context.arch_context_id) != kernel_thread_id {
            fail("selftest: thread kernel riscv64 arch context owner");
        }
        if riscv64_context.instruction_pointer(kernel_context.arch_context_id) != kernel_context.instruction_pointer {
            fail("selftest: thread kernel riscv64 arch context ip");
        }
        if riscv64_context.stack_pointer(kernel_context.arch_context_id) != kernel_context.stack_pointer {
            fail("selftest: thread kernel riscv64 arch context sp");
        }
    if riscv64_context.status_flags(kernel_context.arch_context_id) != kernel_context.status_flags {
            fail("selftest: thread kernel riscv64 arch context flags");
        }
    }

    if !user_entry_mod.asm_image_header_constants_match() {
        fail("selftest: user image asm header constants");
    }
    const user_image_entry = vm.user_virtual_base_for_spec(spec) + spec.page_size;
    const raw_user_image = user_entry_mod.image_from_entry(user_image_entry);
    if raw_user_image.image_phys != user_image_entry {
        fail("selftest: user image raw base");
    }
    if raw_user_image.entry_phys != user_image_entry {
        fail("selftest: user image raw entry");
    }
    if raw_user_image.header_size != 0 {
        fail("selftest: user image raw header size");
    }
    if raw_user_image.code_size != spec.page_size {
        fail("selftest: user image raw size");
    }
    if raw_user_image.stack_pages != 1 {
        fail("selftest: user image raw stack pages");
    }
    if raw_user_image.activate_process {
        fail("selftest: user image raw activation");
    }
    const init_user_image = user_entry_mod.init_image_from_entry(user_image_entry);
    if !init_user_image.activate_process {
        fail("selftest: user image init activation");
    }
    const bad_header_entry_image = user_entry_mod.image_from_parts(user_image_entry, user_image_entry + 16, user_entry_mod.image_header_size, spec.page_size, 1, false);
    if user_entry_mod.prepare_image_thread(arch, 0, spec, bad_header_entry_image).status != UserEntryStatus.invalid_image {
        fail("selftest: user image rejects entry in header");
    }
    const entry_at_end_image = user_entry_mod.image_from_parts(user_image_entry, user_image_entry + spec.page_size, 0, spec.page_size, 1, false);
    if user_entry_mod.prepare_image_thread(arch, 0, spec, entry_at_end_image).status != UserEntryStatus.invalid_image {
        fail("selftest: user image rejects entry at end");
    }
    const page_crossing_image = user_entry_mod.image_from_parts(user_image_entry + 16, user_image_entry + 16, 0, spec.page_size, 1, false);
    if user_entry_mod.prepare_image_thread(arch, 0, spec, page_crossing_image).status != UserEntryStatus.invalid_image {
        fail("selftest: user image rejects page crossing span");
    }

    if thread.create_kernel_bootstrap(process.invalid_id, 0) != thread.invalid_id {
        fail("selftest: thread invalid process");
    }
    if thread.status() != ThreadStatus.invalid_process {
        fail("selftest: thread invalid process status");
    }
    if thread.create_kernel_bootstrap(kernel_process_id, 3) != thread.invalid_id {
        fail("selftest: thread invalid slot");
    }
    if thread.status() != ThreadStatus.invalid_capability_slot {
        fail("selftest: thread invalid slot status");
    }
    const inspect_capability = capability.duplicate(process.get(kernel_process_id).capability_id, CapabilityRights.inspect);
    if inspect_capability == capability.invalid_id {
        fail("selftest: thread inspect cap duplicate");
    }
    const inspect_slot = capability_space.install(kernel_process_id, inspect_capability);
    if inspect_slot == capability_space.invalid_slot {
        fail("selftest: thread inspect cap install");
    }
    if thread.create_kernel_bootstrap(kernel_process_id, inspect_slot) != thread.invalid_id {
        fail("selftest: thread missing manage");
    }
    if thread.status() != ThreadStatus.capability_right_missing {
        fail("selftest: thread missing manage status");
    }
    if !capability_space.remove(kernel_process_id, inspect_slot) {
        fail("selftest: thread inspect cap remove");
    }
    if capability_space.count(kernel_process_id) != 3 {
        fail("selftest: thread inspect cap removed count");
    }
    if !capability.release(inspect_capability) {
        fail("selftest: thread release inspect cap");
    }

    if thread.create_kernel_bootstrap(kernel_process_id, process.get(kernel_process_id).address_space_capability_slot) != thread.invalid_id {
        fail("selftest: thread wrong object");
    }
    if thread.status() != ThreadStatus.capability_object_mismatch {
        fail("selftest: thread wrong object status");
    }

    const user_root = phys.alloc_page();
    if user_root == 0 {
        fail("selftest: thread user root page");
    }
    const user_space_id = address_space.create_user_rooted(user_root, spec);
    if user_space_id == address_space.invalid_id {
        fail("selftest: thread user address space create");
    }
    if process.create_user_inactive(address_space.invalid_id, address_space.capability_id(user_space_id)) != process.invalid_id {
        fail("selftest: thread user process rejects invalid address space");
    }
    if process.status() != ProcessStatus.invalid_address_space {
        fail("selftest: thread user process rejects invalid status");
    }
    const user_process_id = process.create_user_inactive(user_space_id, address_space.capability_id(user_space_id));
    if user_process_id == process.invalid_id {
        fail("selftest: thread user process create");
    }
    const user_process = process.get(user_process_id);
    if user_process.kind != ProcessKind.user {
        fail("selftest: thread user process kind");
    }
    if user_process.active {
        fail("selftest: thread user process inactive");
    }
    if user_process.address_space_id != user_space_id {
        fail("selftest: thread user process address space");
    }
    if user_process.address_space_capability_slot == capability_space.invalid_slot {
        fail("selftest: thread user process address cap slot");
    }
    if capability_space.get(user_process_id, user_process.address_space_capability_slot) != user_process.address_space_capability_id {
        fail("selftest: thread user process address cap installed");
    }
    if !capability.has_rights(user_process.address_space_capability_id, CapabilityRights.inspect | CapabilityRights.map) {
        fail("selftest: thread user process address cap rights");
    }
    if capability.has_rights(user_process.address_space_capability_id, CapabilityRights.manage) {
        fail("selftest: thread user process address cap manage");
    }
    const user_entry = vm.user_virtual_base_for_spec(spec) + spec.page_size;
    const user_payload = phys.alloc_page();
    if user_payload == 0 {
        fail("selftest: thread user payload alloc");
    }
    if !user_loader.map_page(arch, user_space_id, user_process.address_space_capability_id, user_entry, user_payload, vm.rights_user_rw(), spec) {
        fail("selftest: thread user loader map");
    }
    if user_loader.status() != UserLoaderStatus.ok {
        fail("selftest: thread user loader map status");
    }
    if user_loader.lookup_phys(arch, user_space_id, user_entry, spec) != user_payload {
        fail("selftest: thread user loader lookup");
    }
    if !user_memory.validate_user_range(arch, user_process_id, user_entry, 16, spec) {
        fail("selftest: user memory validate mapped range");
    }
    if user_memory.status() != UserMemoryStatus.ok {
        fail("selftest: user memory validate status");
    }
    if user_memory.validate_user_range(arch, user_process_id, user_entry, 0, spec) {
        fail("selftest: user memory zero len");
    }
    if user_memory.status() != UserMemoryStatus.invalid_range {
        fail("selftest: user memory zero len status");
    }
    if user_memory.validate_user_range(arch, user_process_id, vm.kernel_virtual_base_for_spec(spec), 16, spec) {
        fail("selftest: user memory kernel range");
    }
    if user_memory.status() != UserMemoryStatus.invalid_range {
        fail("selftest: user memory kernel range status");
    }
    if user_memory.write_to_console_from_user(arch, user_process_id, user_entry, user_memory.max_debug_copy + 1, spec) != 0 {
        fail("selftest: user memory debug oversize");
    }
    if user_memory.status() != UserMemoryStatus.buffer_too_large {
        fail("selftest: user memory debug oversize status");
    }
    console.seed_help_exit_input();
    var drained_console_bytes: usize = 0;
    while drained_console_bytes < console.help_exit_script_len {
        if console.read_byte() == console.no_input {
            fail("selftest: user memory console drain");
        }
        drained_console_bytes = drained_console_bytes + 1;
    }
    if user_memory.read_line_from_console_to_user(arch, user_process_id, user_entry, 16, spec) != 0 {
        fail("selftest: user memory console no input");
    }
    if user_memory.status() != UserMemoryStatus.no_input {
        fail("selftest: user memory console no input status");
    }
    if user_loader.map_page(arch, user_space_id, user_process.address_space_capability_id, user_entry, user_payload, vm.rights_user_rw(), spec) {
        fail("selftest: thread user loader duplicate");
    }
    if user_loader.status() != UserLoaderStatus.page_table_update_failed {
        fail("selftest: thread user loader duplicate status");
    }
    const second_user_payload = phys.alloc_page();
    if second_user_payload == 0 {
        fail("selftest: thread user second payload alloc");
    }
    if user_loader.map_page(arch, user_space_id, user_process.address_space_capability_id, vm.kernel_virtual_base_for_spec(spec), second_user_payload, vm.rights_user_rw(), spec) {
        fail("selftest: thread user loader kernel virt");
    }
    if user_loader.status() != UserLoaderStatus.invalid_mapping {
        fail("selftest: thread user loader kernel virt status");
    }
    if user_loader.map_page(arch, user_space_id, user_process.address_space_capability_id, user_entry + spec.page_size, second_user_payload, vm.rights_kernel_rw(), spec) {
        fail("selftest: thread user loader kernel rights");
    }
    if user_loader.status() != UserLoaderStatus.invalid_mapping {
        fail("selftest: thread user loader kernel rights status");
    }
    if user_loader.map_page(arch, user_space_id, process.get(kernel_process_id).address_space_capability_id, user_entry + spec.page_size, second_user_payload, vm.rights_user_rw(), spec) {
        fail("selftest: thread user loader wrong cap");
    }
    if user_loader.status() != UserLoaderStatus.invalid_mapping {
        fail("selftest: thread user loader wrong cap status");
    }
    if thread.create_user_ready(kernel_process_id, process.get(kernel_process_id).capability_slot, 0x1000, 0x2000) != thread.invalid_id {
        fail("selftest: thread user rejects kernel process");
    }
    if thread.status() != ThreadStatus.invalid_process {
        fail("selftest: thread user rejects kernel status");
    }
    if thread.create_user_ready(user_process_id, user_process.capability_slot, 0, user_entry + (2 * spec.page_size)) != thread.invalid_id {
        fail("selftest: thread user rejects zero entry");
    }
    if thread.status() != ThreadStatus.invalid_entry {
        fail("selftest: thread user rejects zero entry status");
    }
    if thread.create_user_ready(user_process_id, user_process.capability_slot, user_entry, 0) != thread.invalid_id {
        fail("selftest: thread user rejects zero stack");
    }
    if thread.status() != ThreadStatus.invalid_stack {
        fail("selftest: thread user rejects zero stack status");
    }
    const user_thread_id = thread.create_user_ready(user_process_id, user_process.capability_slot, user_entry, user_entry + (2 * spec.page_size));
    if user_thread_id == thread.invalid_id {
        fail("selftest: thread user create");
    }
    const user_thread = thread.get(user_thread_id);
    if user_thread.state != ThreadState.ready {
        fail("selftest: thread user state");
    }
    if user_thread.process_id != user_process_id {
        fail("selftest: thread user process id");
    }
    if user_thread.entry_addr != user_entry {
        fail("selftest: thread user entry");
    }
    if user_thread.stack_base != user_entry + (2 * spec.page_size) {
        fail("selftest: thread user stack");
    }
    if user_thread.capability_slot == capability_space.invalid_slot {
        fail("selftest: thread user cap slot");
    }
    if capability_space.get(user_process_id, user_thread.capability_slot) != user_thread.capability_id {
        fail("selftest: thread user cap installed");
    }
    if capability.get(user_thread.capability_id).object_id != user_thread.object_id {
        fail("selftest: thread user cap object");
    }
    if kernel_object.get(user_thread.object_id).kind != KernelObjectKind.thread {
        fail("selftest: thread user object kind");
    }
    user_program.init();
    if user_program.count() != 0 {
        fail("selftest: user program initial count");
    }
    if user_program.register_prepared(user_program.invalid_program_id, user_process_id, user_thread_id) {
        fail("selftest: user program rejects zero id");
    }
    if user_program.status() != UserProgramStatus.invalid_program {
        fail("selftest: user program rejects zero status");
    }
    if user_program.register_prepared(1, process.invalid_id, user_thread_id) {
        fail("selftest: user program rejects invalid process");
    }
    if user_program.status() != UserProgramStatus.invalid_process {
        fail("selftest: user program invalid process status");
    }
    if user_program.register_prepared(1, user_process_id, thread.invalid_id) {
        fail("selftest: user program rejects invalid thread");
    }
    if user_program.status() != UserProgramStatus.invalid_thread {
        fail("selftest: user program invalid thread status");
    }
    if user_program.register_prepared(1, user_process_id, kernel_thread_id) {
        fail("selftest: user program rejects wrong thread process");
    }
    if user_program.status() != UserProgramStatus.invalid_thread {
        fail("selftest: user program wrong thread process status");
    }
    if !user_program.register_prepared(1, user_process_id, user_thread_id) {
        fail("selftest: user program register");
    }
    if user_program.count() != 1 {
        fail("selftest: user program count");
    }
    if user_program.register_prepared(1, user_process_id, user_thread_id) {
        fail("selftest: user program duplicate");
    }
    if user_program.status() != UserProgramStatus.duplicate_program {
        fail("selftest: user program duplicate status");
    }
    const registered_program = user_program.get(1);
    if registered_program.process_id != user_process_id {
        fail("selftest: user program process");
    }
    if registered_program.thread_id != user_thread_id {
        fail("selftest: user program thread");
    }
    if user_program.get(2).program_id != user_program.invalid_program_id {
        fail("selftest: user program missing");
    }
    if user_program.status() != UserProgramStatus.invalid_program {
        fail("selftest: user program missing status");
    }
    if !process.mark_active(user_process_id) {
        fail("selftest: user program mark active");
    }
    if user_program.get(1).program_id != user_program.invalid_program_id {
        fail("selftest: user program active process");
    }
    if user_program.status() != UserProgramStatus.active_process {
        fail("selftest: user program active process status");
    }
    if !process.mark_inactive(user_process_id) {
        fail("selftest: user program mark inactive");
    }
    if !thread.mark_blocked(user_thread_id) {
        fail("selftest: user program mark blocked");
    }
    if user_program.get(1).program_id != user_program.invalid_program_id {
        fail("selftest: user program blocked thread");
    }
    if user_program.status() != UserProgramStatus.invalid_thread {
        fail("selftest: user program blocked thread status");
    }
    if !thread.mark_ready(user_thread_id) {
        fail("selftest: user program restore ready");
    }
    user_program.init();
    const user_arch_context = allocate_arch_context(arch, user_thread_id);
    if user_arch_context == context.invalid_arch_context {
        fail("selftest: thread user arch context allocate");
    }
    if !context.attach_user_context(user_thread_id, arch, user_arch_context) {
        fail("selftest: thread user context attach");
    }
    const user_context = context.get(user_thread_id);
    if !user_context.initialized {
        fail("selftest: thread user context initialized");
    }
    if user_context.thread_id != user_thread_id {
        fail("selftest: thread user context thread");
    }
    if user_context.instruction_pointer != user_entry {
        fail("selftest: thread user context ip");
    }
    if user_context.stack_pointer != user_entry + (2 * spec.page_size) {
        fail("selftest: thread user context sp");
    }
    if user_context.status_flags != user_status_flags_for_arch(arch) {
        fail("selftest: thread user context flags");
    }
    if user_context.arch_id != arch {
        fail("selftest: thread user context arch");
    }
    if user_context.arch_context_id != user_arch_context {
        fail("selftest: thread user context arch id");
    }
    if arch == page_table.arch_aarch64 {
        if aarch64_context.instruction_pointer(user_arch_context) != user_context.instruction_pointer {
            fail("selftest: thread user aarch64 context ip");
        }
        if aarch64_context.stack_pointer(user_arch_context) != user_context.stack_pointer {
            fail("selftest: thread user aarch64 context sp");
        }
        if aarch64_context.status_flags(user_arch_context) != user_context.status_flags {
            fail("selftest: thread user aarch64 context flags");
        }
    }
    if arch == page_table.arch_riscv64 {
        if riscv64_context.instruction_pointer(user_arch_context) != user_context.instruction_pointer {
            fail("selftest: thread user riscv64 context ip");
        }
        if riscv64_context.stack_pointer(user_arch_context) != user_context.stack_pointer {
            fail("selftest: thread user riscv64 context sp");
        }
        if riscv64_context.status_flags(user_arch_context) != user_context.status_flags {
            fail("selftest: thread user riscv64 context flags");
        }
    }
    const duplicate_user_arch_context = allocate_arch_context(arch, user_thread_id);
    if duplicate_user_arch_context == context.invalid_arch_context {
        fail("selftest: thread user duplicate arch context allocate");
    }
    if context.attach_user_context(user_thread_id, arch, duplicate_user_arch_context) {
        fail("selftest: thread user duplicate context");
    }
    if context.status() != ContextStatus.duplicate_context {
        fail("selftest: thread user duplicate context status");
    }
    if context.attach_user_context(kernel_thread_id, arch, duplicate_user_arch_context) {
        fail("selftest: thread user rejects kernel context");
    }
    if context.status() != ContextStatus.invalid_thread_kind {
        fail("selftest: thread user rejects kernel context status");
    }
}

pub fn run_scheduler_tests(kernel_process_id: usize, kernel_thread_id: usize): void {
    if !syscall.asm_numbers_match() {
        fail("selftest: syscall asm numbers");
    }
    if syscall.from_number(syscall.number_scheduler_yield_current) != SyscallOp.scheduler_yield_current {
        fail("selftest: syscall scheduler yield number");
    }
    if syscall.from_number(syscall.number_scheduler_block_current) != SyscallOp.scheduler_block_current {
        fail("selftest: syscall scheduler block number");
    }
    if syscall.from_number(syscall.number_debug_write) != SyscallOp.debug_write {
        fail("selftest: syscall debug write number");
    }
    if syscall.from_number(syscall.number_process_exit_current) != SyscallOp.process_exit_current {
        fail("selftest: syscall process exit number");
    }
    if syscall.from_number(syscall.number_process_wait_exited) != SyscallOp.process_wait_exited {
        fail("selftest: syscall process wait number");
    }
    if syscall.from_number(syscall.number_process_current) != SyscallOp.process_current {
        fail("selftest: syscall process current number");
    }
    if syscall.from_number(syscall.number_process_spawn_known) != SyscallOp.process_spawn_known {
        fail("selftest: syscall process spawn number");
    }
    if syscall.from_number(syscall.number_program_inspect) != SyscallOp.program_inspect {
        fail("selftest: syscall program inspect number");
    }
    if syscall.from_number(syscall.number_console_read) != SyscallOp.console_read {
        fail("selftest: syscall console read number");
    }
    if syscall.from_number(syscall.number_console_write) != SyscallOp.console_write {
        fail("selftest: syscall console write number");
    }
    if syscall.from_number(syscall.number_unknown) != SyscallOp.unknown {
        fail("selftest: syscall unknown number");
    }
    if syscall.decode_number(syscall.number_scheduler_yield_current) != SyscallOp.scheduler_yield_current {
        fail("selftest: syscall decode yield number");
    }
    if syscall.status() != SyscallStatus.ok {
        fail("selftest: syscall decode yield status");
    }
    if syscall.decode_number(syscall.number_scheduler_block_current) != SyscallOp.scheduler_block_current {
        fail("selftest: syscall decode block number");
    }
    if syscall.status() != SyscallStatus.ok {
        fail("selftest: syscall decode block status");
    }
    if syscall.decode_number(syscall.number_unknown) != SyscallOp.unknown {
        fail("selftest: syscall decode unknown number");
    }
    if syscall.status() != SyscallStatus.unknown_number {
        fail("selftest: syscall decode unknown status");
    }
    const yield_request = syscall.decode_request(syscall.number_scheduler_yield_current);
    if yield_request.origin != SyscallOrigin.kernel {
        fail("selftest: syscall request yield origin");
    }
    if yield_request.number != syscall.number_scheduler_yield_current {
        fail("selftest: syscall request yield number");
    }
    if yield_request.op != SyscallOp.scheduler_yield_current {
        fail("selftest: syscall request yield op");
    }
    if yield_request.status != SyscallStatus.ok {
        fail("selftest: syscall request yield status");
    }
    const unknown_request = syscall.decode_request(syscall.number_unknown);
    if unknown_request.number != syscall.number_unknown {
        fail("selftest: syscall request unknown number");
    }
    if unknown_request.op != SyscallOp.unknown {
        fail("selftest: syscall request unknown op");
    }
    if unknown_request.status != SyscallStatus.unknown_number {
        fail("selftest: syscall request unknown status");
    }
    const arg_request = syscall.decode_request_with_args(syscall.number_scheduler_yield_current, 10, 11, 12, 13);
    if arg_request.op != SyscallOp.scheduler_yield_current {
        fail("selftest: syscall request args op");
    }
    if arg_request.arg0 != 10 {
        fail("selftest: syscall request arg0");
    }
    if arg_request.arg1 != 11 {
        fail("selftest: syscall request arg1");
    }
    if arg_request.arg2 != 12 {
        fail("selftest: syscall request arg2");
    }
    if arg_request.arg3 != 13 {
        fail("selftest: syscall request arg3");
    }
    const user_request = syscall.decode_user_request(syscall.number_scheduler_yield_current);
    if user_request.origin != SyscallOrigin.user {
        fail("selftest: syscall user request origin");
    }
    if user_request.op != SyscallOp.scheduler_yield_current {
        fail("selftest: syscall user request op");
    }
    const explicit_user_request = syscall.decode_request_for_origin(SyscallOrigin.user, syscall.number_scheduler_block_current, 30, 31, 32, 33);
    if explicit_user_request.origin != SyscallOrigin.user {
        fail("selftest: syscall explicit user origin");
    }
    if explicit_user_request.op != SyscallOp.scheduler_block_current {
        fail("selftest: syscall explicit user op");
    }
    if explicit_user_request.arg0 != 30 {
        fail("selftest: syscall explicit user arg0");
    }
    if explicit_user_request.arg3 != 33 {
        fail("selftest: syscall explicit user arg3");
    }
    const debug_write_request = syscall.decode_request_for_origin(SyscallOrigin.user, syscall.number_debug_write, 40, 41, 42, 43);
    if debug_write_request.op != SyscallOp.debug_write {
        fail("selftest: syscall debug write op");
    }
    if debug_write_request.arg0 != 40 {
        fail("selftest: syscall debug write ptr arg");
    }
    if debug_write_request.arg1 != 41 {
        fail("selftest: syscall debug write len arg");
    }
    const exit_request = syscall.decode_request_for_origin(SyscallOrigin.user, syscall.number_process_exit_current, 44, 45, 46, 47);
    if exit_request.op != SyscallOp.process_exit_current {
        fail("selftest: syscall process exit op");
    }
    if exit_request.arg0 != 44 {
        fail("selftest: syscall process exit arg");
    }
    const wait_request = syscall.decode_request_for_origin(SyscallOrigin.user, syscall.number_process_wait_exited, 48, 49, 50, 51);
    if wait_request.op != SyscallOp.process_wait_exited {
        fail("selftest: syscall process wait op");
    }
    if wait_request.arg0 != 48 {
        fail("selftest: syscall process wait arg");
    }
    const current_request = syscall.decode_request_for_origin(SyscallOrigin.user, syscall.number_process_current, 52, 53, 54, 55);
    if current_request.op != SyscallOp.process_current {
        fail("selftest: syscall process current op");
    }
    if current_request.arg0 != 52 {
        fail("selftest: syscall process current arg0");
    }
    if current_request.arg3 != 55 {
        fail("selftest: syscall process current arg3");
    }
    const spawn_request = syscall.decode_request_for_origin(SyscallOrigin.user, syscall.number_process_spawn_known, 56, 57, 58, 59);
    if spawn_request.op != SyscallOp.process_spawn_known {
        fail("selftest: syscall process spawn op");
    }
    if spawn_request.arg0 != 56 {
        fail("selftest: syscall process spawn arg0");
    }
    const inspect_request = syscall.decode_request_for_origin(SyscallOrigin.user, syscall.number_program_inspect, 60, 61, 62, 63);
    if inspect_request.op != SyscallOp.program_inspect {
        fail("selftest: syscall program inspect op");
    }
    if inspect_request.arg0 != 60 {
        fail("selftest: syscall program inspect arg0");
    }
    const console_read_request = syscall.decode_request_for_origin(SyscallOrigin.user, syscall.number_console_read, 64, 65, 66, 67);
    if console_read_request.op != SyscallOp.console_read {
        fail("selftest: syscall console read op");
    }
    if console_read_request.arg0 != 64 {
        fail("selftest: syscall console read arg0");
    }
    if console_read_request.arg1 != 65 {
        fail("selftest: syscall console read arg1");
    }
    const console_write_request = syscall.decode_request_for_origin(SyscallOrigin.user, syscall.number_console_write, 68, 69, 70, 71);
    if console_write_request.op != SyscallOp.console_write {
        fail("selftest: syscall console write op");
    }
    if console_write_request.arg0 != 68 {
        fail("selftest: syscall console write arg0");
    }
    const ok_result = syscall.ok_result(20, 21);
    if ok_result.error != SyscallError.ok {
        fail("selftest: syscall ok result error");
    }
    if ok_result.value0 != 20 {
        fail("selftest: syscall ok result value0");
    }
    if ok_result.value1 != 21 {
        fail("selftest: syscall ok result value1");
    }
    const unknown_result = syscall.result_for_request(unknown_request);
    if unknown_result.error != SyscallError.unknown_number {
        fail("selftest: syscall unknown result error");
    }
    const yield_result = syscall.result_for_request(yield_request);
    if yield_result.error != SyscallError.ok {
        fail("selftest: syscall yield result error");
    }
    if syscall.result_error_code(yield_result) != 0 {
        fail("selftest: syscall yield result code");
    }
    const unsupported_result = syscall.result_for_request(explicit_user_request);
    if unsupported_result.error != SyscallError.unsupported_return {
        fail("selftest: syscall unsupported result error");
    }
    if syscall.result_error_code(unsupported_result) != 2 {
        fail("selftest: syscall unsupported result code");
    }
    const bad_user_buffer = syscall.error_result(SyscallError.invalid_user_buffer);
    if syscall.result_error_code(bad_user_buffer) != 3 {
        fail("selftest: syscall invalid user buffer code");
    }
    const bad_process = syscall.error_result(SyscallError.invalid_process);
    if syscall.result_error_code(bad_process) != 4 {
        fail("selftest: syscall invalid process code");
    }
    const not_exited = syscall.error_result(SyscallError.process_not_exited);
    if syscall.result_error_code(not_exited) != 5 {
        fail("selftest: syscall process not exited code");
    }
    const no_input = syscall.error_result(SyscallError.no_input);
    if syscall.result_error_code(no_input) != 6 {
        fail("selftest: syscall no input code");
    }
    if scheduler.current() != kernel_thread_id {
        fail("selftest: scheduler current kernel");
    }
    if scheduler.count() != 0 {
        fail("selftest: scheduler initial count");
    }
    if scheduler.peek() != thread.invalid_id {
        fail("selftest: scheduler peek empty");
    }
    if scheduler.status() != SchedulerStatus.empty {
        fail("selftest: scheduler peek empty status");
    }
    if scheduler.dequeue() != thread.invalid_id {
        fail("selftest: scheduler dequeue empty");
    }
    if scheduler.status() != SchedulerStatus.empty {
        fail("selftest: scheduler dequeue empty status");
    }
    if scheduler.enqueue(kernel_thread_id) {
        fail("selftest: scheduler enqueue running");
    }
    if scheduler.status() != SchedulerStatus.not_ready {
        fail("selftest: scheduler enqueue running status");
    }

    const ready_thread = thread.create_kernel_ready(kernel_process_id, process.get(kernel_process_id).capability_slot);
    if ready_thread == thread.invalid_id {
        fail("selftest: scheduler ready thread create");
    }
    const ready_entry = thread.get(ready_thread);
    if ready_entry.capability_slot == capability_space.invalid_slot {
        fail("selftest: scheduler ready thread capability slot");
    }
    if capability_space.get(kernel_process_id, ready_entry.capability_slot) != ready_entry.capability_id {
        fail("selftest: scheduler ready thread capability handle");
    }
    if capability.get(ready_entry.capability_id).object_id != ready_entry.object_id {
        fail("selftest: scheduler ready thread capability object");
    }
    const arch = context.get(kernel_thread_id).arch_id;
    const ready_arch_context = allocate_arch_context(arch, ready_thread);
    if ready_arch_context == context.invalid_arch_context {
        fail("selftest: scheduler ready arch context allocate");
    }
    if !context.attach_kernel_context(ready_thread, 0x1000, 0x2000, arch, ready_arch_context) {
        fail("selftest: scheduler ready context attach");
    }
    const ready_context = context.get(ready_thread);
    if !ready_context.initialized {
        fail("selftest: scheduler ready context initialized");
    }
    if ready_context.id == context.invalid_id {
        fail("selftest: scheduler ready context id");
    }
    if ready_context.instruction_pointer != 0x1000 {
        fail("selftest: scheduler ready context ip");
    }
    if ready_context.stack_pointer != 0x2000 {
        fail("selftest: scheduler ready context sp");
    }
    if ready_context.arch_id != arch {
        fail("selftest: scheduler ready context arch");
    }
    if ready_context.arch_context_id != ready_arch_context {
        fail("selftest: scheduler ready context arch id");
    }
    if arch == page_table.arch_aarch64 {
        if aarch64_context.instruction_pointer(ready_arch_context) != ready_context.instruction_pointer {
            fail("selftest: scheduler aarch64 ready context ip");
        }
        if aarch64_context.stack_pointer(ready_arch_context) != ready_context.stack_pointer {
            fail("selftest: scheduler aarch64 ready context sp");
        }
        if aarch64_context.status_flags(ready_arch_context) != ready_context.status_flags {
            fail("selftest: scheduler aarch64 ready context flags");
        }
    }
    if arch == page_table.arch_riscv64 {
        if riscv64_context.instruction_pointer(ready_arch_context) != ready_context.instruction_pointer {
            fail("selftest: scheduler riscv64 ready context ip");
        }
        if riscv64_context.stack_pointer(ready_arch_context) != ready_context.stack_pointer {
            fail("selftest: scheduler riscv64 ready context sp");
        }
        if riscv64_context.status_flags(ready_arch_context) != ready_context.status_flags {
            fail("selftest: scheduler riscv64 ready context flags");
        }
    }
    if !context.save_resume_state(ready_thread, 0x7000, 0x8000, 0x9000) {
        fail("selftest: scheduler save resume");
    }
    const ready_resume = context.get_resume_state(ready_thread);
    if !ready_resume.valid {
        fail("selftest: scheduler ready resume valid");
    }
    if ready_resume.instruction_pointer != 0x7000 {
        fail("selftest: scheduler ready resume ip");
    }
    if ready_resume.stack_pointer != 0x8000 {
        fail("selftest: scheduler ready resume sp");
    }
    if ready_resume.status_flags != 0x9000 {
        fail("selftest: scheduler ready resume flags");
    }
    const saved_context = context.get(ready_thread);
    if saved_context.instruction_pointer != 0x7000 {
        fail("selftest: scheduler saved context ip");
    }
    if saved_context.stack_pointer != 0x8000 {
        fail("selftest: scheduler saved context sp");
    }
    if saved_context.status_flags != 0x9000 {
        fail("selftest: scheduler saved context flags");
    }
    if arch == page_table.arch_aarch64 {
        if aarch64_context.instruction_pointer(ready_arch_context) != saved_context.instruction_pointer {
            fail("selftest: scheduler aarch64 saved context ip");
        }
        if aarch64_context.stack_pointer(ready_arch_context) != saved_context.stack_pointer {
            fail("selftest: scheduler aarch64 saved context sp");
        }
        if aarch64_context.status_flags(ready_arch_context) != saved_context.status_flags {
            fail("selftest: scheduler aarch64 saved context flags");
        }
    }
    if arch == page_table.arch_riscv64 {
        if riscv64_context.instruction_pointer(ready_arch_context) != saved_context.instruction_pointer {
            fail("selftest: scheduler riscv64 saved context ip");
        }
        if riscv64_context.stack_pointer(ready_arch_context) != saved_context.stack_pointer {
            fail("selftest: scheduler riscv64 saved context sp");
        }
        if riscv64_context.status_flags(ready_arch_context) != saved_context.status_flags {
            fail("selftest: scheduler riscv64 saved context flags");
        }
    }
    if context.save_resume_state(thread.invalid_id, 1, 2, 3) {
        fail("selftest: scheduler save invalid thread");
    }
    if context.status() != ContextStatus.invalid_thread {
        fail("selftest: scheduler save invalid thread status");
    }
    if context.get_resume_state(thread.invalid_id).valid {
        fail("selftest: scheduler invalid resume state");
    }
    if context.status() != ContextStatus.invalid_thread {
        fail("selftest: scheduler invalid resume state status");
    }
    const duplicate_arch_context = allocate_arch_context(arch, ready_thread);
    if duplicate_arch_context == context.invalid_arch_context {
        fail("selftest: scheduler duplicate arch context allocate");
    }
    if context.attach_kernel_context(ready_thread, 0x3000, 0x4000, arch, duplicate_arch_context) {
        fail("selftest: scheduler duplicate context");
    }
    if context.status() != ContextStatus.duplicate_context {
        fail("selftest: scheduler duplicate context status");
    }
    if thread.get(ready_thread).state != ThreadState.ready {
        fail("selftest: scheduler ready thread state");
    }
    if !scheduler.enqueue(ready_thread) {
        fail("selftest: scheduler enqueue ready");
    }
    if scheduler.count() != 1 {
        fail("selftest: scheduler count after enqueue");
    }
    if scheduler.peek() != ready_thread {
        fail("selftest: scheduler peek ready");
    }
    if scheduler.enqueue(ready_thread) {
        fail("selftest: scheduler enqueue duplicate");
    }
    if scheduler.status() != SchedulerStatus.duplicate {
        fail("selftest: scheduler duplicate status");
    }
    const front_thread = thread.create_kernel_ready(kernel_process_id, process.get(kernel_process_id).capability_slot);
    if front_thread == thread.invalid_id {
        fail("selftest: scheduler front thread create");
    }
    if !scheduler.enqueue_front(front_thread) {
        fail("selftest: scheduler enqueue front");
    }
    if scheduler.count() != 2 {
        fail("selftest: scheduler front count");
    }
    if scheduler.peek() != front_thread {
        fail("selftest: scheduler front peek");
    }
    if scheduler.dequeue() != front_thread {
        fail("selftest: scheduler front dequeue");
    }
    if scheduler.count() != 1 {
        fail("selftest: scheduler front count after dequeue");
    }
    if !thread.mark_dead(front_thread) {
        fail("selftest: scheduler front cleanup");
    }

    const scheduled = scheduler.schedule_next_saving_current(0xa000, 0xb000, 0xc000);
    if scheduled != ready_thread {
        fail("selftest: scheduler schedule ready");
    }
    if scheduler.current() != ready_thread {
        fail("selftest: scheduler schedule current");
    }
    const selected_resume = context.get_resume_state(scheduled);
    if !selected_resume.valid {
        fail("selftest: scheduler selected resume valid");
    }
    if selected_resume.instruction_pointer != 0x7000 {
        fail("selftest: scheduler selected resume ip");
    }
    if selected_resume.stack_pointer != 0x8000 {
        fail("selftest: scheduler selected resume sp");
    }
    if selected_resume.status_flags != 0x9000 {
        fail("selftest: scheduler selected resume flags");
    }
    if thread.get(ready_thread).state != ThreadState.running {
        fail("selftest: scheduler schedule ready running");
    }
    if thread.get(kernel_thread_id).state != ThreadState.ready {
        fail("selftest: scheduler schedule previous ready");
    }
    if scheduler.count() != 1 {
        fail("selftest: scheduler schedule count");
    }
    if scheduler.peek() != kernel_thread_id {
        fail("selftest: scheduler schedule previous queued");
    }
    const saved_kernel_context = context.get(kernel_thread_id);
    if saved_kernel_context.instruction_pointer != 0xa000 {
        fail("selftest: scheduler saved previous ip");
    }
    if saved_kernel_context.stack_pointer != 0xb000 {
        fail("selftest: scheduler saved previous sp");
    }
    if saved_kernel_context.status_flags != 0xc000 {
        fail("selftest: scheduler saved previous flags");
    }
    if arch == page_table.arch_aarch64 {
        if aarch64_context.instruction_pointer(saved_kernel_context.arch_context_id) != saved_kernel_context.instruction_pointer {
            fail("selftest: scheduler aarch64 saved previous ip");
        }
        if aarch64_context.stack_pointer(saved_kernel_context.arch_context_id) != saved_kernel_context.stack_pointer {
            fail("selftest: scheduler aarch64 saved previous sp");
        }
        if aarch64_context.status_flags(saved_kernel_context.arch_context_id) != saved_kernel_context.status_flags {
            fail("selftest: scheduler aarch64 saved previous flags");
        }
    }
    if arch == page_table.arch_riscv64 {
        if riscv64_context.instruction_pointer(saved_kernel_context.arch_context_id) != saved_kernel_context.instruction_pointer {
            fail("selftest: scheduler riscv64 saved previous ip");
        }
        if riscv64_context.stack_pointer(saved_kernel_context.arch_context_id) != saved_kernel_context.stack_pointer {
            fail("selftest: scheduler riscv64 saved previous sp");
        }
        if riscv64_context.status_flags(saved_kernel_context.arch_context_id) != saved_kernel_context.status_flags {
            fail("selftest: scheduler riscv64 saved previous flags");
        }
    }
    const scheduled_back = scheduler.schedule_next();
    if scheduled_back != kernel_thread_id {
        fail("selftest: scheduler schedule back");
    }
    if scheduler.current() != kernel_thread_id {
        fail("selftest: scheduler schedule back current");
    }
    if thread.get(kernel_thread_id).state != ThreadState.running {
        fail("selftest: scheduler schedule back running");
    }
    if thread.get(ready_thread).state != ThreadState.ready {
        fail("selftest: scheduler schedule back previous ready");
    }

    const kernel_process = process.get(kernel_process_id);
    const tail_thread = thread.create_kernel_ready(kernel_process_id, kernel_process.capability_slot);
    if tail_thread == thread.invalid_id {
        fail("selftest: scheduler front-save tail create");
    }
    if !scheduler.enqueue(tail_thread) {
        fail("selftest: scheduler front-save enqueue tail");
    }
    const front_saved = scheduler.schedule_next_saving_current_to_front(0xa100, 0xb100, 0xc100);
    if front_saved != ready_thread {
        fail("selftest: scheduler front-save selected");
    }
    if scheduler.current() != ready_thread {
        fail("selftest: scheduler front-save current");
    }
    if scheduler.peek() != kernel_thread_id {
        fail("selftest: scheduler front-save previous first");
    }
    const front_saved_kernel_context = context.get(kernel_thread_id);
    if front_saved_kernel_context.instruction_pointer != 0xa100 {
        fail("selftest: scheduler front-save previous ip");
    }
    if front_saved_kernel_context.stack_pointer != 0xb100 {
        fail("selftest: scheduler front-save previous sp");
    }
    if front_saved_kernel_context.status_flags != 0xc100 {
        fail("selftest: scheduler front-save previous flags");
    }
    const front_restored = scheduler.schedule_next();
    if front_restored != kernel_thread_id {
        fail("selftest: scheduler front-save restore");
    }
    const removed_tail = scheduler.dequeue();
    if removed_tail != tail_thread {
        fail("selftest: scheduler front-save tail dequeue");
    }
    if !thread.mark_dead(tail_thread) {
        fail("selftest: scheduler front-save tail cleanup");
    }

    const blocked_switch = scheduler.block_current_saving_context(0xd000, 0xe000, 0xf000);
    if blocked_switch != ready_thread {
        fail("selftest: scheduler block switch");
    }
    if scheduler.current() != ready_thread {
        fail("selftest: scheduler block switch current");
    }
    if thread.get(kernel_thread_id).state != ThreadState.blocked {
        fail("selftest: scheduler block previous");
    }
    const blocked_resume = context.get_resume_state(kernel_thread_id);
    if !blocked_resume.valid {
        fail("selftest: scheduler blocked resume valid");
    }
    if blocked_resume.instruction_pointer != 0xd000 {
        fail("selftest: scheduler blocked resume ip");
    }
    if blocked_resume.stack_pointer != 0xe000 {
        fail("selftest: scheduler blocked resume sp");
    }
    if blocked_resume.status_flags != 0xf000 {
        fail("selftest: scheduler blocked resume flags");
    }
    if scheduler.count() != 0 {
        fail("selftest: scheduler block switch count");
    }
    if !thread.mark_ready(kernel_thread_id) {
        fail("selftest: scheduler unblock kernel");
    }
    if !scheduler.enqueue(kernel_thread_id) {
        fail("selftest: scheduler enqueue unblocked kernel");
    }
    const restored_kernel = scheduler.schedule_next();
    if restored_kernel != kernel_thread_id {
        fail("selftest: scheduler restore blocked kernel");
    }
    if scheduler.current() != kernel_thread_id {
        fail("selftest: scheduler restore blocked current");
    }
    if thread.get(kernel_thread_id).state != ThreadState.running {
        fail("selftest: scheduler restored kernel running");
    }
    if thread.get(ready_thread).state != ThreadState.ready {
        fail("selftest: scheduler restored previous ready");
    }

    const dequeued = scheduler.dequeue();
    if dequeued != ready_thread {
        fail("selftest: scheduler dequeue ready");
    }
    if scheduler.count() != 0 {
        fail("selftest: scheduler count after dequeue");
    }
    if !scheduler.set_current(dequeued) {
        fail("selftest: scheduler set current ready");
    }
    if scheduler.current() != dequeued {
        fail("selftest: scheduler current ready");
    }
    if thread.get(dequeued).state != ThreadState.running {
        fail("selftest: scheduler current state");
    }
    if !thread.mark_blocked(dequeued) {
        fail("selftest: scheduler mark blocked");
    }
    if scheduler.enqueue(dequeued) {
        fail("selftest: scheduler enqueue blocked");
    }
    if scheduler.status() != SchedulerStatus.not_ready {
        fail("selftest: scheduler enqueue blocked status");
    }
    if scheduler.schedule_next_saving_current(1, 2, 3) != thread.invalid_id {
        fail("selftest: scheduler save blocked current");
    }
    if scheduler.status() != SchedulerStatus.not_ready {
        fail("selftest: scheduler save blocked current status");
    }
    if !thread.mark_dead(dequeued) {
        fail("selftest: scheduler mark dead");
    }
    const dead_thread = thread.create_kernel_ready(kernel_process_id, process.get(kernel_process_id).capability_slot);
    if dead_thread == thread.invalid_id {
        fail("selftest: scheduler dead thread create");
    }
    if !thread.mark_dead(dead_thread) {
        fail("selftest: scheduler dead thread mark");
    }
    const dead_arch_context = allocate_arch_context(arch, dead_thread);
    if dead_arch_context == context.invalid_arch_context {
        fail("selftest: scheduler dead arch context allocate");
    }
    if context.attach_kernel_context(dead_thread, 0, 0, arch, dead_arch_context) {
        fail("selftest: scheduler dead context");
    }
    if context.status() != ContextStatus.dead_thread {
        fail("selftest: scheduler dead context status");
    }
    if context.attach_kernel_context(thread.invalid_id, 0, 0, arch, context.invalid_arch_context) {
        fail("selftest: scheduler invalid context");
    }
    if context.status() != ContextStatus.invalid_thread {
        fail("selftest: scheduler invalid context status");
    }
    const invalid_arch_thread = thread.create_kernel_ready(kernel_process_id, process.get(kernel_process_id).capability_slot);
    if invalid_arch_thread == thread.invalid_id {
        fail("selftest: scheduler invalid arch thread create");
    }
    if context.attach_kernel_context(invalid_arch_thread, 0, 0, 0, 0) {
        fail("selftest: scheduler invalid arch context");
    }
    if context.status() != ContextStatus.invalid_arch {
        fail("selftest: scheduler invalid arch context status");
    }
    if context.save_resume_state(invalid_arch_thread, 1, 2, 3) {
        fail("selftest: scheduler save missing context");
    }
    if context.status() != ContextStatus.missing_context {
        fail("selftest: scheduler save missing context status");
    }
    if context.get_resume_state(invalid_arch_thread).valid {
        fail("selftest: scheduler missing resume state");
    }
    if context.status() != ContextStatus.missing_context {
        fail("selftest: scheduler missing resume state status");
    }
    const invalid_arch_context_thread = thread.create_kernel_ready(kernel_process_id, process.get(kernel_process_id).capability_slot);
    if invalid_arch_context_thread == thread.invalid_id {
        fail("selftest: scheduler invalid arch context thread create");
    }
    if context.attach_kernel_context(invalid_arch_context_thread, 0, 0, arch, context.invalid_arch_context) {
        fail("selftest: scheduler invalid arch context id");
    }
    if context.status() != ContextStatus.invalid_arch_context {
        fail("selftest: scheduler invalid arch context id status");
    }
    if scheduler.enqueue(dequeued) {
        fail("selftest: scheduler enqueue dead");
    }
    if scheduler.status() != SchedulerStatus.not_ready {
        fail("selftest: scheduler enqueue dead status");
    }
    if !scheduler.set_current(kernel_thread_id) {
        fail("selftest: scheduler restore current");
    }
    const exiting_thread = thread.create_kernel_ready(kernel_process_id, process.get(kernel_process_id).capability_slot);
    if exiting_thread == thread.invalid_id {
        fail("selftest: scheduler exiting thread create");
    }
    const exit_target_thread = thread.create_kernel_ready(kernel_process_id, process.get(kernel_process_id).capability_slot);
    if exit_target_thread == thread.invalid_id {
        fail("selftest: scheduler exit target create");
    }
    if !scheduler.set_current(exiting_thread) {
        fail("selftest: scheduler set exiting current");
    }
    if !scheduler.enqueue(exit_target_thread) {
        fail("selftest: scheduler enqueue exit target");
    }
    if scheduler.exit_current() != exit_target_thread {
        fail("selftest: scheduler exit selects target");
    }
    if thread.get(exiting_thread).state != ThreadState.dead {
        fail("selftest: scheduler exit marks dead");
    }
    if thread.get(exit_target_thread).state != ThreadState.running {
        fail("selftest: scheduler exit target running");
    }
    if scheduler.current() != exit_target_thread {
        fail("selftest: scheduler exit current target");
    }
    if !thread.mark_dead(exit_target_thread) {
        fail("selftest: scheduler exit target cleanup");
    }
    if !scheduler.set_current(kernel_thread_id) {
        fail("selftest: scheduler restore after exit");
    }
    const saved_empty_current = scheduler.schedule_next_saving_current(4, 5, 6);
    if saved_empty_current != kernel_thread_id {
        fail("selftest: scheduler save empty keeps current");
    }
    if scheduler.status() != SchedulerStatus.empty {
        fail("selftest: scheduler save empty status");
    }
    if scheduler.current() != kernel_thread_id {
        fail("selftest: scheduler save empty current");
    }
    const empty_saved_context = context.get(kernel_thread_id);
    if empty_saved_context.instruction_pointer != 4 {
        fail("selftest: scheduler save empty ip");
    }
    if empty_saved_context.stack_pointer != 5 {
        fail("selftest: scheduler save empty sp");
    }
    if empty_saved_context.status_flags != 6 {
        fail("selftest: scheduler save empty flags");
    }
    if arch == page_table.arch_aarch64 {
        if aarch64_context.instruction_pointer(empty_saved_context.arch_context_id) != empty_saved_context.instruction_pointer {
            fail("selftest: scheduler aarch64 save empty ip");
        }
        if aarch64_context.stack_pointer(empty_saved_context.arch_context_id) != empty_saved_context.stack_pointer {
            fail("selftest: scheduler aarch64 save empty sp");
        }
        if aarch64_context.status_flags(empty_saved_context.arch_context_id) != empty_saved_context.status_flags {
            fail("selftest: scheduler aarch64 save empty flags");
        }
    }
    if arch == page_table.arch_riscv64 {
        if riscv64_context.instruction_pointer(empty_saved_context.arch_context_id) != empty_saved_context.instruction_pointer {
            fail("selftest: scheduler riscv64 save empty ip");
        }
        if riscv64_context.stack_pointer(empty_saved_context.arch_context_id) != empty_saved_context.stack_pointer {
            fail("selftest: scheduler riscv64 save empty sp");
        }
        if riscv64_context.status_flags(empty_saved_context.arch_context_id) != empty_saved_context.status_flags {
            fail("selftest: scheduler riscv64 save empty flags");
        }
    }
    if scheduler.schedule_next() != kernel_thread_id {
        fail("selftest: scheduler schedule empty keeps current");
    }
    if scheduler.status() != SchedulerStatus.empty {
        fail("selftest: scheduler schedule empty status");
    }
}
