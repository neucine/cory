extern c("cory_identity_map_page") fn platform_identity_map_page(phys_addr: c_ulong): c_ulong;

pub fn map_page(phys_addr: usize): bool {
    return platform_identity_map_page(phys_addr as c_ulong) != 0;
}
