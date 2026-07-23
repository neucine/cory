import .arch.riscv64.page_table;

extern c("cory_riscv64_activate_identity_vm") fn arch_activate_identity_vm(satp: c_ulong): void;
extern c("cory_riscv64_switch_satp") fn arch_switch_satp(satp: c_ulong): void;

// QEMU virt RISC-V64 owns the final SATP switch because the assembly symbol is
// target-local. Page-table geometry and SATP construction stay in arch code;
// this module only bridges that value to the platform-linked shim.
pub fn activate_identity_vm(root_table_phys: usize): void {
    const satp = page_table.activation_satp(root_table_phys) as c_ulong;
    arch_activate_identity_vm(satp);
}

pub fn switch_user_root(root_table_phys: usize): void {
    arch_switch_satp(page_table.activation_satp(root_table_phys) as c_ulong);
}
