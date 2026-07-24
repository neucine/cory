import .arch.aarch64.trap_frame;
import .arch.aarch64.trap_context;
import .arch.aarch64.context as aarch64_context;
import { TrapFrame } from .arch.aarch64.trap_frame;
import .console;
import .memory.user_memory;
import .memory.address_space;
import .memory.vm;
import { UserMemoryStatus } from .memory.user_memory;
import .panic as panic_mod;
import .platform.qemu_aarch64_virt.interrupt;
import .platform.qemu_aarch64_virt.memory as platform_memory;
import .platform.qemu_aarch64_virt.tick;
import .platform.qemu_aarch64_virt.vm_activation;
import .arch.aarch64.page_table;
import .syscall;
import .task.thread;
import { SyscallError, SyscallOp, SyscallOrigin, SyscallRequest, SyscallResult } from .syscall;
import .task.process;
import .task.process_arg;
import { ProcessArgStatus } from .task.process_arg;
import .task.process_reaper;
import { ReapStatus } from .task.process_reaper;
import { ProcessStatus } from .task.process;
import .task.scheduler;
import .task.context;
import .task.user_program;
import .task.user_entry;
import { UserEntryStatus } from .task.user_entry;

extern c("cory_arch_exception_init") fn cory_arch_exception_init(): void;
extern c("cory_arch_abi_probe_value") fn cory_arch_abi_probe_value(): c_ulong;
extern c("cory_arch_current_el") fn cory_arch_current_el(): c_ulong;
extern c("cory_refresh_builtin_user_images") fn refresh_builtin_user_images(): void;

const yield_brk_esr: usize = 0xf2000001;
const block_brk_esr: usize = 0xf2000002;

pub fn init(): void {
    if cory_arch_current_el() != 1 {
        println("exception: expected EL1");
        panic_mod.panic();
    }
    if !trap_frame.verify_layout() {
        println("exception: trap frame layout mismatch");
        panic_mod.panic();
    }
    cory_arch_exception_init();
    if cory_arch_abi_probe_value() != 12648430 {
        println("exception: extern c abi probe failed");
        panic_mod.panic();
    }
    println("exception: vectors ready");
}

fn report_unhandled(raw_frame: *TrapFrame): void {
    trap_frame.set_resume_state_in_frame(
        raw_frame,
        trap_frame.instruction_pointer_from_frame(raw_frame),
        trap_frame.stack_pointer_from_frame(raw_frame),
        trap_frame.status_flags_from_frame(raw_frame)
    );
    const frame = trap_frame.diagnostic_from_frame(raw_frame);
    if trap_frame.instruction_pointer_from_frame(raw_frame) != frame.elr_el1 {
        println("exception: aarch64 resume ip mismatch");
        panic_mod.panic();
    }
    if trap_frame.status_flags_from_frame(raw_frame) != frame.spsr_el1 {
        println("exception: aarch64 resume flags mismatch");
        panic_mod.panic();
    }
    println("exception: unhandled aarch64");
    println("exception: esr_el1");
    console.println_hex(frame.esr_el1);
    println("exception: elr_el1");
    console.println_hex(frame.elr_el1);
    println("exception: far_el1");
    console.println_hex(frame.far_el1);
    println("exception: spsr_el1");
    console.println_hex(frame.spsr_el1);
    panic_mod.panic();
}

fn schedule_yield(raw_frame: *TrapFrame): void {
    const resume_ip = trap_frame.explicit_resume_ip_from_frame(raw_frame);
    trap_frame.set_resume_state_in_frame(
        raw_frame,
        resume_ip,
        trap_frame.stack_pointer_from_frame(raw_frame),
        trap_frame.status_flags_from_frame(raw_frame)
    );
    println("scheduler: yield trap");
    if !trap_context.schedule_and_restore(raw_frame) {
        println("exception: yield schedule failed");
        if trap_context.status() == trap_context.status_schedule_failed {
            println("exception: schedule status failed");
        }
        if trap_context.status() == trap_context.status_resume_state_missing {
            println("exception: resume state missing");
        }
        panic_mod.panic();
    }
    println("exception: yield restore returned unexpectedly");
    panic_mod.panic();
}

fn schedule_block(raw_frame: *TrapFrame): void {
    const resume_ip = trap_frame.explicit_resume_ip_from_frame(raw_frame);
    println("scheduler: block trap");
    println("scheduler: normal thread blocked");
    if !trap_context.block_current_and_restore(raw_frame, resume_ip) {
        println("exception: block schedule failed");
        if trap_context.status() == trap_context.status_schedule_failed {
            println("exception: schedule status failed");
        }
        if trap_context.status() == trap_context.status_resume_state_missing {
            println("exception: resume state missing");
        }
        panic_mod.panic();
    }
    println("exception: block restore returned unexpectedly");
    panic_mod.panic();
}

fn syscall_number_from_sync_exception(esr_el1: usize): usize {
    if esr_el1 == yield_brk_esr {
        return syscall.number_scheduler_yield_current;
    }
    if esr_el1 == block_brk_esr {
        return syscall.number_scheduler_block_current;
    }
    if esr_el1 == 0xf2000003 {
        return syscall.number_debug_write;
    }
    if esr_el1 == 0xf2000004 {
        return syscall.number_process_exit_current;
    }
    if esr_el1 == 0xf2000005 {
        return syscall.number_process_wait_exited;
    }
    if esr_el1 == 0xf2000006 {
        return syscall.number_process_current;
    }
    if esr_el1 == 0xf2000007 {
        return syscall.number_process_spawn_known;
    }
    if esr_el1 == 0xf2000008 {
        return syscall.number_program_inspect;
    }
    if esr_el1 == 0xf2000009 {
        return syscall.number_console_read;
    }
    if esr_el1 == 0xf200000a {
        return syscall.number_console_write;
    }
    if esr_el1 == 0xf200000b {
        return syscall.number_process_list;
    }
    if esr_el1 == 0xf200000c {
        return syscall.number_process_arg_read;
    }
    return syscall.number_unknown;
}

fn syscall_origin_from_frame(raw_frame: *TrapFrame): SyscallOrigin {
    if (trap_frame.status_flags_from_frame(raw_frame) & 15) == aarch64_context.user_status_flags() {
        return SyscallOrigin.user;
    }
    return SyscallOrigin.kernel;
}

fn return_result_to_user(raw_frame: *TrapFrame, result: SyscallResult): void {
    write_result_to_user_frame(raw_frame, result);
    trap_context.restore_from_frame(raw_frame);
}

fn write_result_to_user_frame(raw_frame: *TrapFrame, result: SyscallResult): void {
    trap_frame.set_resume_state_in_frame(
        raw_frame,
        trap_frame.explicit_resume_ip_from_frame(raw_frame),
        trap_frame.stack_pointer_from_frame(raw_frame),
        trap_frame.status_flags_from_frame(raw_frame)
    );
    trap_frame.set_syscall_result_in_frame(raw_frame, syscall.result_error_code(result), result.value0, result.value1);
}

fn debug_write_user(raw_frame: *TrapFrame, request: SyscallRequest): void {
    const current_thread = thread.get(scheduler.current());
    const copied = user_memory.write_to_console_from_user(page_table.arch_id, current_thread.process_id, request.arg0, request.arg1, page_table.spec());
    if copied == 0 {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_user_buffer));
        return;
    }
    println("userspace: normal user debug write returned aarch64");
    return_result_to_user(raw_frame, syscall.ok_result(copied, 0));
}

fn console_write_user(raw_frame: *TrapFrame, request: SyscallRequest): void {
    const current_thread = thread.get(scheduler.current());
    const copied = user_memory.write_to_console_from_user(page_table.arch_id, current_thread.process_id, request.arg0, request.arg1, page_table.spec());
    if copied == 0 {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_user_buffer));
        return;
    }
    return_result_to_user(raw_frame, syscall.ok_result(copied, 0));
}

fn exit_current_user(raw_frame: *TrapFrame, request: SyscallRequest): void {
    const current_thread = thread.get(scheduler.current());
    if current_thread.id == thread.invalid_id {
        println("userspace: normal user exit missing thread aarch64");
        panic_mod.panic();
    }
    if !process.mark_exited(current_thread.process_id, request.arg0) {
        println("userspace: normal user exit process failed aarch64");
        panic_mod.panic();
    }
    println("userspace: normal user exit trap aarch64");
    if !trap_context.exit_current_and_restore(raw_frame) {
        println("userspace: normal user exit schedule failed aarch64");
        if trap_context.status() == trap_context.status_schedule_failed {
            println("exception: schedule status failed");
        }
        if trap_context.status() == trap_context.status_resume_state_missing {
            println("exception: resume state missing");
        }
        panic_mod.panic();
    }
    println("userspace: normal user exit restore returned unexpectedly");
    panic_mod.panic();
}

fn process_status_error(): SyscallError {
    if process.status() == ProcessStatus.not_exited {
        return SyscallError.process_not_exited;
    }
    return SyscallError.invalid_process;
}

fn reaper_status_error(): SyscallError {
    if process_reaper.status() == ReapStatus.not_exited {
        return SyscallError.process_not_exited;
    }
    return SyscallError.invalid_process;
}

fn wait_exited_user(raw_frame: *TrapFrame, request: SyscallRequest): void {
    var code: usize = 0;
    if request.arg1 == 0 {
        code = process.wait_exit_code(request.arg0);
    } else {
        code = process_reaper.reap_exited_user(request.arg0);
        if process_reaper.status() != ReapStatus.ok {
            return_result_to_user(raw_frame, syscall.error_result(reaper_status_error()));
            return;
        }
    }
    if process.status() != ProcessStatus.ok {
        return_result_to_user(raw_frame, syscall.error_result(process_status_error()));
        return;
    }
    return_result_to_user(raw_frame, syscall.ok_result(code, request.arg0));
}

fn current_identity_user(raw_frame: *TrapFrame): void {
    const current_thread = thread.get(scheduler.current());
    if current_thread.id == thread.invalid_id {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
        return;
    }
    const current_process = process.get(current_thread.process_id);
    if current_process.id == process.invalid_id {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
        return;
    }
    println("userspace: normal user current returned aarch64");
    return_result_to_user(raw_frame, syscall.ok_result(current_process.id, current_thread.id));
}

fn print_spawned_program(program_id: usize): void {
    if program_id == 1 {
        println("userspace: normal user spawned child aarch64");
        return;
    }
    if program_id == 2 {
        println("userspace: normal user spawned shell aarch64");
        return;
    }
    if program_id == 3 {
        println("userspace: normal user spawned echo aarch64");
        return;
    }
    if program_id == 4 {
        println("userspace: normal user spawned ps aarch64");
        return;
    }
    println("userspace: normal user spawned program aarch64");
}

fn spawn_known_user(raw_frame: *TrapFrame, request: SyscallRequest): void {
    refresh_builtin_user_images();
    const program = user_program.get(request.arg0);
    if program.program_id == user_program.invalid_program_id {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
        return;
    }
    const current_thread = thread.get(scheduler.current());
    const current_process = process.get(current_thread.process_id);
    const current_root = address_space.root_table(current_process.address_space_id);
    const identity_root = vm.bootstrap_plan(platform_memory.layout(), page_table.spec()).page_table_root;
    var target_process_id = program.process_id;
    var target_thread_id = program.thread_id;
    if program.image_phys != 0 {
        const image = user_program.image_for_program(request.arg0);
        vm_activation.switch_user_root(identity_root);
        const plan = user_entry.prepare_spawned_image_thread(page_table.arch_id, 0, page_table.spec(), image);
        vm_activation.switch_user_root(current_root);
        if plan.status != UserEntryStatus.ok {
            return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
            return;
        }
        const user_context = context.get(plan.thread_id);
        if !trap_context.seed_resume_frame(plan.arch_context_id, plan.entry_addr, plan.stack_pointer, user_context.status_flags) {
            return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
            return;
        }
        target_process_id = plan.process_id;
        target_thread_id = plan.thread_id;
    }
    const child_process = process.get(target_process_id);
    if child_process.id == process.invalid_id {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
        return;
    }
    if child_process.active or child_process.exited {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
        return;
    }
    if thread.get(target_thread_id).id == thread.invalid_id {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
        return;
    }
    if !process.mark_active(target_process_id) {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
        return;
    }
    if !process_arg.set_from_user(page_table.arch_id, current_thread.process_id, target_process_id, request.arg1, request.arg2, page_table.spec()) {
        if !process.mark_inactive(target_process_id) {
        }
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_user_buffer));
        return;
    }
    if !scheduler.enqueue_front(target_thread_id) {
        if !process.mark_inactive(target_process_id) {
        }
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
        return;
    }
    print_spawned_program(request.arg0);
    write_result_to_user_frame(raw_frame, syscall.ok_result(target_process_id, target_thread_id));
    if !trap_context.schedule_and_restore_current_to_front(raw_frame) {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
        return;
    }
    println("userspace: normal user spawn restore returned unexpectedly");
    panic_mod.panic();
}

fn inspect_program_user(raw_frame: *TrapFrame, request: SyscallRequest): void {
    refresh_builtin_user_images();
    const program = user_program.get(request.arg0);
    if program.program_id == user_program.invalid_program_id {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
        return;
    }
    println("userspace: normal user inspected program aarch64");
    return_result_to_user(raw_frame, syscall.ok_result(program.process_id, program.thread_id));
}

fn console_read_user(raw_frame: *TrapFrame, request: SyscallRequest): void {
    const current_thread = thread.get(scheduler.current());
    if current_thread.id == thread.invalid_id {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
        return;
    }
    const copied = user_memory.read_line_blocking_from_console_to_user(page_table.arch_id, current_thread.process_id, request.arg0, request.arg1, page_table.spec());
    if copied != 0 {
        return_result_to_user(raw_frame, syscall.ok_result(copied, 0));
        return;
    }
    if user_memory.status() == UserMemoryStatus.no_input {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.no_input));
        return;
    }
    return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_user_buffer));
}

fn process_list_user(raw_frame: *TrapFrame): void {
    const printed = process.print_table();
    return_result_to_user(raw_frame, syscall.ok_result(printed, 0));
}

fn process_arg_read_user(raw_frame: *TrapFrame, request: SyscallRequest): void {
    const current_thread = thread.get(scheduler.current());
    if current_thread.id == thread.invalid_id {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
        return;
    }
    const copied = process_arg.read_to_user(page_table.arch_id, current_thread.process_id, request.arg0, request.arg1, page_table.spec());
    if copied == 0 and process_arg.status() != ProcessArgStatus.ok {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_user_buffer));
        return;
    }
    return_result_to_user(raw_frame, syscall.ok_result(copied, 0));
}

fn dispatch_syscall(raw_frame: *TrapFrame, request: SyscallRequest): bool {
    if request.op == SyscallOp.scheduler_yield_current {
        if request.origin == SyscallOrigin.user {
            println("userspace: normal user yield trap aarch64");
            println("userspace: normal user yield returned aarch64");
            return_result_to_user(raw_frame, syscall.result_for_request(request));
            return true;
        }
        schedule_yield(raw_frame);
        return true;
    }
    if request.op == SyscallOp.scheduler_block_current {
        if request.origin == SyscallOrigin.user {
            println("userspace: normal user block trap aarch64");
        }
        schedule_block(raw_frame);
        return true;
    }
    if request.op == SyscallOp.debug_write {
        if request.origin == SyscallOrigin.user {
            debug_write_user(raw_frame, request);
            return true;
        }
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.unsupported_return));
        return true;
    }
    if request.op == SyscallOp.process_exit_current {
        if request.origin == SyscallOrigin.user {
            exit_current_user(raw_frame, request);
            return true;
        }
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.unsupported_return));
        return true;
    }
    if request.op == SyscallOp.process_wait_exited {
        if request.origin == SyscallOrigin.user {
            wait_exited_user(raw_frame, request);
            return true;
        }
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.unsupported_return));
        return true;
    }
    if request.op == SyscallOp.process_current {
        if request.origin == SyscallOrigin.user {
            current_identity_user(raw_frame);
            return true;
        }
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.unsupported_return));
        return true;
    }
    if request.op == SyscallOp.process_spawn_known {
        if request.origin == SyscallOrigin.user {
            spawn_known_user(raw_frame, request);
            return true;
        }
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.unsupported_return));
        return true;
    }
    if request.op == SyscallOp.program_inspect {
        if request.origin == SyscallOrigin.user {
            inspect_program_user(raw_frame, request);
            return true;
        }
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.unsupported_return));
        return true;
    }
    if request.op == SyscallOp.console_read {
        if request.origin == SyscallOrigin.user {
            console_read_user(raw_frame, request);
            return true;
        }
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.unsupported_return));
        return true;
    }
    if request.op == SyscallOp.console_write {
        if request.origin == SyscallOrigin.user {
            console_write_user(raw_frame, request);
            return true;
        }
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.unsupported_return));
        return true;
    }
    if request.op == SyscallOp.process_list {
        if request.origin == SyscallOrigin.user {
            process_list_user(raw_frame);
            return true;
        }
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.unsupported_return));
        return true;
    }
    if request.op == SyscallOp.process_arg_read {
        if request.origin == SyscallOrigin.user {
            process_arg_read_user(raw_frame, request);
            return true;
        }
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.unsupported_return));
        return true;
    }
    return false;
}

export c("cory_arch_sync_exception_entry") fn cory_arch_sync_exception_entry(raw_frame: *TrapFrame): void {
    const frame = trap_frame.diagnostic_from_frame(raw_frame);
    if dispatch_syscall(raw_frame, syscall.decode_request_for_origin(syscall_origin_from_frame(raw_frame), syscall_number_from_sync_exception(frame.esr_el1), trap_frame.argument0_from_frame(raw_frame), trap_frame.argument2_from_frame(raw_frame), trap_frame.argument3_from_frame(raw_frame), 0)) {
        return;
    }
    report_unhandled(raw_frame);
}

export c("cory_arch_irq_exception_entry") fn cory_arch_irq_exception_entry(raw_frame: *TrapFrame): void {
    interrupt.mask();
    const intid = interrupt.acknowledge();
    if tick.diagnostic_enabled() {
        if interrupt.complete_timer_irq(intid) {
            const count = tick.record_delivery();
            if count == 1 {
                println("tick: diagnostic tick");
            }
            trap_context.restore_from_frame(raw_frame);
        }
    } else if tick.enabled() {
        if interrupt.complete_timer_irq(intid) {
            const count = tick.record_delivery();
            if !interrupt.program_timer_after_ticks(tick.interval_ticks(interrupt.timer_frequency())) {
                println("exception: scheduler tick rearm failed");
                panic_mod.panic();
            }
            if scheduler.count() == 0 {
                if count == 1 {
                    println("tick: scheduler idle");
                }
                trap_context.restore_from_frame(raw_frame);
            }
            if count == 1 {
                println("tick: scheduler tick");
            }
            if !trap_context.schedule_and_restore(raw_frame) {
                println("exception: scheduler tick failed");
                if trap_context.status() == trap_context.status_schedule_failed {
                    println("exception: schedule status failed");
                }
                if trap_context.status() == trap_context.status_resume_state_missing {
                    println("exception: resume state missing");
                }
                panic_mod.panic();
            }
            println("exception: scheduler restore returned unexpectedly");
            panic_mod.panic();
        }
    } else if intid != interrupt.spurious_intid {
        interrupt.end(intid);
    }
    println("exception: unhandled aarch64 irq");
    if !tick.delivery_enabled() {
        println("exception: tick delivery disabled");
    }
    report_unhandled(raw_frame);
}
