/* SPDX-License-Identifier: MPL-2.0 */

.section .text.entry
.globl _start
_start:
    # 1. Setup DMWIN, REMOVED
    # probably unnecessary as we do not use DMWIN, we uses paging map

    # 2.0 Setup stack pointer(temporary value, used for calling setup_tlb)
    la.global   $sp, boot_stack_top

    # 2.1 Setup TLB
    bl          setup_tlb

    li.d        $t2, 0x0000ffffffffffff # PHYS_ADDR_MASK

    # 3. Setup tlb refill exception handler
    la.global   $t0, handle_tlb_refill
    and         $t0, $t0, $t2
    csrwr       $t0, 0x88       # LOONGARCH_CSR_TLBRENTRY

    # 4. Setup boot_pagetable
    la.global   $t0, boot_pagetable
    la.global   $t1, boot_pagetable_2nd
    and         $t1, $t1, $t2
    st.d        $t1, $t0, 0     # boot_pagetable[0] = phys(boot_pagetable_2nd)
    addi.d      $t0, $t0, 2047
    st.d        $t1, $t0, 2041  # boot_pagetable[511] = phys(boot_pagetable_2nd)

    # 5. Enable MMU
    la.global   $t0, boot_pagetable
    and         $t0, $t0, $t2
    csrwr       $t0, 0x1a       # LOONGARCH_CSR_PGDH
    ori         $t0, $zero, 0x0
    csrwr       $t0, 0x19       # LOONGARCH_CSR_PGDL
    invtlb      0x00, $r0, $r0

    # 6. Enable PG, TODO

    li.d        $t1, 0xffffffff00000000 # VIRT_ADDR_OFFSET

    # 7. Set up stack pointer
    or          $sp, $sp, $t1

    # 8. Read cpuid and fdt_base
    csrrd       $a0, 0x20       # cpuid
    li.d        $a1, 0x100000   # FDT_BASE

    # 9. jump to loongarch_main
    la.global   $t0, loongarch_main
    or          $t0, $t0, $t1
    jirl        $zero, $t0, 0

.section .text
.balign 4096
.global handle_tlb_refill
handle_tlb_refill:
    # TODO

.section .bss.stack

.globl boot_stack_bottom
boot_stack_bottom:
    .space 0x40000 # 64 KiB

.globl boot_stack_top
boot_stack_top:

.section .data

.align 12
.globl boot_pagetable
boot_pagetable:
    .zero 8 * 511
    # 0x0000_ff80_0000_0000 -> 0x0000_0000_0000_0000
    .quad 0 # To be assigned with phys(boot_pagetable_2nd)

.globl boot_pagetable_2nd
boot_pagetable_2nd:
    .zero 8 * 508
    # 0x0000_007f_8000_0000 -> 0x0000_0000_8000_0000
    .quad 0x00000000 | 0x1c3 # V | D | HUGE | P | W
    .quad 0x40000000 | 0x1c3 # V | D | HUGE | P | W
    .quad 0x80000000 | 0x1c3 # V | D | HUGE | P | W
    .quad 0
