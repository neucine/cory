import .kernel.arch.aarch64.page_table;

extern c("cycor_aarch64_activate_identity_vm") fn arch_activate_identity_vm(ttbr0: c_ulong, mair: c_ulong, tcr: c_ulong, sctlr_set_bits: c_ulong): void;

// QEMU virt AArch64 owns the final EL1 MMU switch because the assembly symbol is
// target-local. Page-table geometry and register values stay in arch code; this
// module only bridges those values to the platform-linked shim.
pub fn activate_identity_vm(root_table_phys: usize): void {
    const ttbr0 = page_table.activation_ttbr0(root_table_phys) as c_ulong;
    const mair = page_table.activation_mair() as c_ulong;
    const tcr = page_table.activation_tcr() as c_ulong;
    const sctlr_set_bits = page_table.activation_sctlr_set_bits() as c_ulong;
    arch_activate_identity_vm(ttbr0, mair, tcr, sctlr_set_bits);
}
