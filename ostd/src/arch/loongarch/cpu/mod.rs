// SPDX-License-Identifier: MPL-2.0

//! CPU

pub mod context;
pub mod local;

/// Halts the CPU.
///
/// This function halts the CPU until the next interrupt is received. By
/// halting, the CPU might consume less power. Internally it is implemented
/// using the `idle` instruction.
///
/// Since the function sleeps the CPU, it should not be used within an atomic
/// mode ([`crate::task::atomic_mode`]).
#[track_caller]
pub fn sleep_for_interrupt() {
    crate::task::atomic_mode::might_sleep();
    unsafe { loongArch64::asm::idle() };
}
