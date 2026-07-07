import .kernel.arch.aarch64.context as aarch64_context;
import .kernel.arch.riscv64.context as riscv64_context;
import .kernel.memory.address_space;
import .kernel.memory.page_table;
import .kernel.object.capability;
import { CapabilityRights } from .kernel.object.capability;
import .kernel.object.kernel_object;
import { KernelObjectKind } from .kernel.object.kernel_object;
import .kernel.panic as panic_mod;
import .kernel.task.capability_space;
import { CapabilitySpaceStatus } from .kernel.task.capability_space;
import .kernel.task.context;
import { ContextStatus } from .kernel.task.context;
import .kernel.task.process;
import { ProcessKind, ProcessStatus } from .kernel.task.process;
import .kernel.task.scheduler;
import { SchedulerStatus } from .kernel.task.scheduler;
import .kernel.task.thread;
import { ThreadState, ThreadStatus } from .kernel.task.thread;

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
}

pub fn run_thread_tests(kernel_process_id: usize, kernel_thread_id: usize, arch: i32): void {
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
}

pub fn run_scheduler_tests(kernel_process_id: usize, kernel_thread_id: usize): void {
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
    if scheduler.schedule_next() != kernel_thread_id {
        fail("selftest: scheduler schedule empty keeps current");
    }
    if scheduler.status() != SchedulerStatus.empty {
        fail("selftest: scheduler schedule empty status");
    }
}
