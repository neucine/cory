import .kernel.entry;
import .kernel.arch.riscv64.page_table;
import .kernel.boot;
import .kernel.kernel;
import .kernel.platform.qemu_riscv64_virt.console;
import .kernel.platform.qemu_riscv64_virt.exception;
import .kernel.platform.qemu_riscv64_virt.memory;
import .kernel.platform.qemu_riscv64_virt.vm_activation;
import .kernel.memory.vm;

export c("cycor_kernel_entry") fn cycor_kernel_entry(): void {
    entry.zero_bss();
    console.init();
    kernel.print_entry();
    exception.init();
    const map = memory.layout();
    boot.prepare_memory(map, page_table.spec(), page_table.arch_id);
    vm_activation.activate_identity_vm(vm.bootstrap_plan(map).page_table_root);
    boot.finish_after_memory_ready();
}
