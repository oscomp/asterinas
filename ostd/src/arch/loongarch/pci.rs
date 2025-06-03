// SPDX-License-Identifier: MPL-2.0

//! PCI bus io port

use super::device::io_port::{IoPort, ReadWriteAccess, WriteOnlyAccess};
use crate::{bus::pci::PciDeviceLocation, Result};

pub static PCI_ADDRESS_PORT: IoPort<u32, WriteOnlyAccess> = unsafe { IoPort::new(0x0) };
pub static PCI_DATA_PORT: IoPort<u32, ReadWriteAccess> = unsafe { IoPort::new(0x0) };

pub(crate) fn write32(_location: &PciDeviceLocation, _offset: u32, _value: u32) -> Result<()> {
    todo!()
}

pub(crate) fn read32(_location: &PciDeviceLocation, _offset: u32) -> Result<u32> {
    todo!()
}

pub(crate) fn has_pci_bus() -> bool {
    // TODO: implement this
    false
}
