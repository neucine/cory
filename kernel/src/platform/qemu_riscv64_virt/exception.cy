import .arch.riscv64.trap_frame;
import .arch.riscv64.trap_context;
import .arch.riscv64.context as riscv64_context;
import .arch.riscv64.page_table;
import { TrapFrame } from .arch.riscv64.trap_frame;
import .console;
import .memory.user_memory;
import { UserMemoryStatus } from .memory.user_memory;
import .panic as panic_mod;
import .platform.qemu_riscv64_virt.interrupt;
import .platform.qemu_riscv64_virt.tick;
import .syscall;
import { SyscallError, SyscallOp, SyscallOrigin, SyscallRequest, SyscallResult } from .syscall;
import .task.process;
import { ProcessStatus } from .task.process;
import .task.scheduler;
import .task.thread;
import .task.user_program;

extern c("cory_arch_trap_init") fn cory_arch_trap_init(): void;
extern c("cory_arch_abi_probe_value") fn cory_arch_abi_probe_value(): c_ulong;
extern c("cory_riscv64_user_access_begin") fn user_access_begin(): void;
extern c("cory_riscv64_user_access_end") fn user_access_end(): void;

const breakpoint_scause: usize = 3;
const user_ecall_scause: usize = 8;

pub fn init(): void {
    if !trap_frame.verify_layout() {
        println("exception: trap frame layout mismatch");
        panic_mod.panic();
    }
    cory_arch_trap_init();
    if cory_arch_abi_probe_value() != 12648430 {
        println("exception: extern c abi probe failed");
        panic_mod.panic();
    }
    println("exception: vectors ready");
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

fn syscall_origin_from_frame(raw_frame: *TrapFrame): SyscallOrigin {
    if (trap_frame.status_flags_from_frame(raw_frame) & riscv64_context.sstatus_spp) == 0 {
        return SyscallOrigin.user;
    }
    return SyscallOrigin.kernel;
}

fn syscall_request_from_frame(raw_frame: *TrapFrame, scause: usize, number: usize): SyscallRequest {
    if scause == breakpoint_scause {
        return syscall.decode_request_for_origin(syscall_origin_from_frame(raw_frame), number, 0, 0, 0, 0);
    }
    if scause == user_ecall_scause {
        return syscall.decode_request_for_origin(SyscallOrigin.user, number, 0, 0, 0, 0);
    }
    return syscall.decode_kernel_request(syscall.number_unknown);
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
    user_access_begin();
    const copied = user_memory.write_to_console_from_user(page_table.arch_id, current_thread.process_id, request.arg0, request.arg1, page_table.spec());
    user_access_end();
    if copied == 0 {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_user_buffer));
        return;
    }
    println("userspace: normal user debug write returned riscv64");
    return_result_to_user(raw_frame, syscall.ok_result(copied, 0));
}

fn console_write_user(raw_frame: *TrapFrame, request: SyscallRequest): void {
    const current_thread = thread.get(scheduler.current());
    user_access_begin();
    const copied = user_memory.write_to_console_from_user(page_table.arch_id, current_thread.process_id, request.arg0, request.arg1, page_table.spec());
    user_access_end();
    if copied == 0 {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_user_buffer));
        return;
    }
    return_result_to_user(raw_frame, syscall.ok_result(copied, 0));
}

fn exit_current_user(raw_frame: *TrapFrame, request: SyscallRequest): void {
    const current_thread = thread.get(scheduler.current());
    if current_thread.id == thread.invalid_id {
        println("userspace: normal user exit missing thread riscv64");
        panic_mod.panic();
    }
    if !process.mark_exited(current_thread.process_id, request.arg0) {
        println("userspace: normal user exit process failed riscv64");
        panic_mod.panic();
    }
    println("userspace: normal user exit trap riscv64");
    if !trap_context.exit_current_and_restore(raw_frame) {
        println("userspace: normal user exit schedule failed riscv64");
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

fn wait_exited_user(raw_frame: *TrapFrame, request: SyscallRequest): void {
    var code: usize = 0;
    if request.arg1 == 0 {
        code = process.wait_exit_code(request.arg0);
    } else {
        code = process.reap_exited(request.arg0);
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
    println("userspace: normal user current returned riscv64");
    return_result_to_user(raw_frame, syscall.ok_result(current_process.id, current_thread.id));
}

fn spawn_known_user(raw_frame: *TrapFrame, request: SyscallRequest): void {
    const program = user_program.get(request.arg0);
    if program.program_id == user_program.invalid_program_id {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
        return;
    }
    const child_process = process.get(program.process_id);
    if child_process.id == process.invalid_id {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
        return;
    }
    if child_process.active or child_process.exited {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
        return;
    }
    if thread.get(program.thread_id).id == thread.invalid_id {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
        return;
    }
    if !process.mark_active(program.process_id) {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
        return;
    }
    if !scheduler.enqueue_front(program.thread_id) {
        if !process.mark_inactive(program.process_id) {
        }
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
        return;
    }
    if request.arg0 == 2 {
        println("userspace: normal user spawned shell riscv64");
    } else {
        println("userspace: normal user spawned child riscv64");
    }
    write_result_to_user_frame(raw_frame, syscall.ok_result(program.process_id, program.thread_id));
    if !trap_context.schedule_and_restore_current_to_front(raw_frame) {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
        return;
    }
    println("userspace: normal user spawn restore returned unexpectedly");
    panic_mod.panic();
}

fn inspect_program_user(raw_frame: *TrapFrame, request: SyscallRequest): void {
    const program = user_program.get(request.arg0);
    if program.program_id == user_program.invalid_program_id {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
        return;
    }
    println("userspace: normal user inspected program riscv64");
    return_result_to_user(raw_frame, syscall.ok_result(program.process_id, program.thread_id));
}

fn console_read_user(raw_frame: *TrapFrame, request: SyscallRequest): void {
    const current_thread = thread.get(scheduler.current());
    if current_thread.id == thread.invalid_id {
        return_result_to_user(raw_frame, syscall.error_result(SyscallError.invalid_process));
        return;
    }
    user_access_begin();
    const copied = user_memory.read_line_blocking_from_console_to_user(page_table.arch_id, current_thread.process_id, request.arg0, request.arg1, page_table.spec());
    user_access_end();
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

fn dispatch_syscall(raw_frame: *TrapFrame, request: SyscallRequest): bool {
    if request.op == SyscallOp.scheduler_yield_current {
        if request.origin == SyscallOrigin.user {
            println("userspace: normal user yield trap riscv64");
            println("userspace: normal user yield returned riscv64");
            return_result_to_user(raw_frame, syscall.result_for_request(request));
            return true;
        }
        schedule_yield(raw_frame);
        return true;
    }
    if request.op == SyscallOp.scheduler_block_current {
        if request.origin == SyscallOrigin.user {
            println("userspace: normal user block trap riscv64");
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
    return false;
}

export c("cory_arch_trap_entry") fn cory_arch_trap_entry(raw_frame: *TrapFrame): void {
    const frame = trap_frame.diagnostic_from_frame(raw_frame);
    const syscall_number = trap_frame.argument0_from_frame(raw_frame);
    const request = syscall_request_from_frame(raw_frame, frame.scause, syscall_number);
    const request_with_args = syscall.decode_request_for_origin(request.origin, request.number, trap_frame.argument2_from_frame(raw_frame), trap_frame.argument3_from_frame(raw_frame), 0, 0);
    if dispatch_syscall(raw_frame, request_with_args) {
        return;
    }
    if tick.enabled() {
        if interrupt.complete_timer_irq(frame.scause) {
            const count = tick.record_delivery();
            if !interrupt.program_timer_after_ticks(tick.interval_ticks()) {
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
    }
    if interrupt.complete_timer_irq(frame.scause) {
        trap_context.restore_from_frame(raw_frame);
    }
    trap_frame.set_resume_state_in_frame(
        raw_frame,
        trap_frame.instruction_pointer_from_frame(raw_frame),
        trap_frame.stack_pointer_from_frame(raw_frame),
        trap_frame.status_flags_from_frame(raw_frame)
    );
    if trap_frame.instruction_pointer_from_frame(raw_frame) != frame.sepc {
        println("exception: riscv64 resume ip mismatch");
        panic_mod.panic();
    }
    if trap_frame.status_flags_from_frame(raw_frame) != frame.sstatus {
        println("exception: riscv64 resume flags mismatch");
        panic_mod.panic();
    }
    println("exception: unhandled riscv64");
    println("exception: scause");
    console.println_hex(frame.scause);
    println("exception: sepc");
    console.println_hex(frame.sepc);
    println("exception: stval");
    console.println_hex(frame.stval);
    println("exception: sstatus");
    console.println_hex(frame.sstatus);
    if tick.delivery_enabled() {
        println("exception: tick delivery enabled");
    }
    panic_mod.panic();
}
