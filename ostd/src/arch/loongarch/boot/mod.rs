// SPDX-License-Identifier: MPL-2.0

//! The LoongArch boot module defines the entrypoints of Asterinas.

use core::arch::global_asm;

global_asm!(include_str!("boot.S"));

/// The entry point of the Rust code portion of Asterinas.
#[no_mangle]
pub extern "C" fn loongarch_boot(_cpu_id: usize, device_tree_paddr: usize) -> ! {
    call_ostd_main();
}
