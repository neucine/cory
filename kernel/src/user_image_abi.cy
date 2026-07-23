pub const image_magic: usize = 0x43594e41494d4731;
pub const image_version: usize = 1;
pub const image_header_size: usize = 48;

pub const asm_image_magic: usize = 0x43594e41494d4731;
pub const asm_image_version: usize = 1;
pub const asm_image_header_size: usize = 48;

export asm("CORY_USER_IMAGE_MAGIC") const exported_asm_image_magic: usize = 0x43594e41494d4731;
export asm("CORY_USER_IMAGE_VERSION") const exported_asm_image_version: usize = 1;
export asm("CORY_USER_IMAGE_HEADER_SIZE") const exported_asm_image_header_size: usize = 48;

pub fn asm_header_constants_match(): bool {
    if asm_image_magic != image_magic {
        return false;
    }
    if asm_image_version != image_version {
        return false;
    }
    if asm_image_header_size != image_header_size {
        return false;
    }
    return true;
}
