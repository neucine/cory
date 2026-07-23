pub struct Layout {
    pub ram_start: usize;
    pub ram_end: usize;
    pub kernel_load: usize;
    pub page_size: usize;
    pub device_mmio_start: usize;
    pub device_mmio_end: usize;
    pub device_mmio2_start: usize;
    pub device_mmio2_end: usize;
}
