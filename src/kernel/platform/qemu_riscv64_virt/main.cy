import .kernel.entry;
import .kernel.arch.riscv64.page_table;
import .kernel.boot;
import .kernel.kernel;
import .kernel.platform.qemu_riscv64_virt.console;
import .kernel.platform.qemu_riscv64_virt.exception;
import .kernel.platform.qemu_riscv64_virt.memory;
import .kernel.platform.qemu_riscv64_virt.vm_activation;
import .kernel.memory.phys;
import .kernel.memory.vm;

extern c("cycor_riscv64_flush_kernel_tlb") fn flush_kernel_tlb(): void;

export c("cycor_heap_map_virtual_page") fn cycor_heap_map_virtual_page(virtual_addr: c_ulong): c_ulong {
    const phys_page = phys.alloc_page();
    if phys_page == 0 {
        return 0;
    }
    if !page_table.map_bootstrap_page(page_table.spec(), virtual_addr as usize, phys_page, vm.rights_kernel_rw()) {
        if !phys.free_page(phys_page) {
            return 0;
        }
        return 0;
    }
    flush_kernel_tlb();
    return phys_page as c_ulong;
}

export c("cycor_kernel_entry") fn cycor_kernel_entry(): void {
    entry.zero_bss();
    console.init();
    kernel.print_entry();
    exception.init();
    const map = memory.layout();
    boot.prepare_memory(map, page_table.spec(), page_table.arch_id);
    vm_activation.activate_identity_vm(vm.bootstrap_plan(map, page_table.spec()).page_table_root);
    boot.finish_after_memory_ready(map.page_size, vm.kernel_heap_virtual_base_for_spec(page_table.spec()));
}
