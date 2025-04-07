// SPDX-License-Identifier: MPL-2.0

//! Platform-specific code for the LoongArch platform.

use core::sync::atomic::Ordering;

pub mod boot;
pub mod cpu;
pub mod device;
pub mod iommu;
pub(crate) mod irq;
pub(crate) mod mm;
pub(crate) mod pci;
pub mod qemu;
pub mod serial;
pub mod task;
pub mod timer;
pub mod trap;

#[cfg(feature = "cvm_guest")]
pub(crate) fn init_cvm_guest() {
    // Unimplemented, no-op
}

/// Return the frequency of TSC. The unit is Hz.
pub fn tsc_freq() -> u64 {
    timer::TIMEBASE_FREQ.load(Ordering::Relaxed)
}

/// Reads the current value of the processor’s time-stamp counter (TSC).
pub fn read_tsc() -> u64 {
    let mut pmc: usize;
    unsafe {
        core::arch::asm!(
            "rdtime.d {}, $zero",
            out(reg) pmc,
        );
    }
    pmc as u64
}

pub(crate) fn enable_cpu_features() {
    // enable float point
    loongArch64::register::euen::set_fpe(true);
}

pub(crate) unsafe fn late_init_on_bsp() {
    // SAFETY: this function is only called once on BSP.
    unsafe {
        trap::init(true);
    }
    irq::init();

    // SAFETY: we're on the BSP and we're ready to boot all APs.
    unsafe { crate::boot::smp::boot_all_aps() };

    timer::init();
    let _ = crate::bus::pci::init();
}

pub(crate) unsafe fn init_on_ap() {
    unimplemented!()
}

pub(crate) fn interrupts_ack(_irq_number: usize) {
    unimplemented!()
}

// No TDX for LoongArch
#[macro_export]
macro_rules! if_tdx_enabled {
    ($if_block:block else $else_block:block) => {{
        $else_block
    }};
    ($if_block:block) => {};
}
