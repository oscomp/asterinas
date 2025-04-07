/* SPDX-License-Identifier: MPL-2.0 */

.macro SET_CSR_BITS CSR_ID, bits_start, bits_end, value
    csrrd      $t0, \CSR_ID

    li.d       $t2, (1 << (\bits_end - \bits_start + 1)) - 1
    slli.d     $t2, $t2, \bits_start

    and        $t0, $t0, $t2

    li.d       $t1, \value
    slli.d     $t1, $t1, \bits_start

    # for safety consideration
    and        $t0, $t0, $t2

    or         $t0, $t0, $t1

    csrwr      $t0, \CSR_ID
.endm

.section .text.entry
.globl _start
_start:
    # Setup DMWIN

    # Configure DMW0. VSEG = 8, PLV0, Strongly ordered uncachd
    li.d        $t0, (0x8000000000000000 | 1)
    csrwr       $t0, 0x180

    # Configure DMW1. VSEG = 9, PLV0, Coherent cached
    li.d        $t0, (0x9000000000000000 | 1 | 1 << 4)
    csrwr       $t0, 0x181

    # Configure MMU

    # PTE width: 0 for 8 bytes
    # 512 entries for each levels of dir/pt
    # | PTE width | PT base | PT width | Dir1_base    | Dir1_width | Dir2_base      | Dir2_width |
    # | 0 << 30   | 12      | 9 << 5   | (12+9) << 10 | 9 << 15    | (12+9+9) << 20 | 9 << 25    |
    li.d        $t0, ((0 << 30) | 12 | (9 << 5) | ((12+9)<<10) | (9<<15) | ((12+9*2)<<20) | (9<<25))
    csrwr       $t0, 0x1c       # LOONGARCH_CSR_PWCL
    # | Dir3_base | dir3_width |
    li.d        $t0, ((12+9*3) | (9<<6))
    csrwr       $t0, 0x1d       # LOONGARCH_CSR_PWCH

    SET_CSR_BITS 0x10, 24, 29, 12 # TLBIDX
    SET_CSR_BITS 0x1e,  0,  5, 12 # STLBPS
    SET_CSR_BITS 0x8e,  0,  5, 12 # TLBREHI

    li.d        $t2, 0x00000000ffffffff # PHYS_ADDR_MASK

    la.global   $t0, __bss
    la.global   $t1, __bss_end
    and         $t0, $t0, $t2
    and         $t1, $t1, $t2

    beq         $t0, $t1, .clear_bss_exit

.clear_bss_loop:
    st.d        $zero, $t0, 0
    addi.d      $t0, $t0, 8
    bltu        $t0, $t1, .clear_bss_loop

.clear_bss_exit:

    # Setup temporary tlb refill exception handler
    # According to loongarch reference manual, this must be a physical address and 4k aligned
    la.global   $t0, tmp_tlb_refill
    and         $t0, $t0, $t2
    csrwr       $t0, 0x88       # LOONGARCH_CSR_TLBRENTRY

    # Setup page table

    la.global   $t0, boot_pagetable
    la.global   $t1, boot_pagetable_2nd
    and         $t0, $t0, $t2   # Ensure physical address
    and         $t1, $t1, $t2
    addi.d      $t0, $t0, 2044
    st.d        $t1, $t0, 4     # boot_pagetable[256] = phys(boot_pagetable_2nd)
    st.d        $t1, $t0, 2044  # boot_pagetable[511] = phys(boot_pagetable_2nd)

    la.global   $t0, boot_pagetable_3nd
    and         $t0, $t0, $t2
    st.d        $t0, $t1, 16    # boot_pagetable_2nd[2] = phys(boot_pagetable_3nd)
    addi.d      $t1, $t1, 2040
    st.d        $t0, $t1, 2040  # boot_pagetable_2nd[510] = phys(boot_pagetable_3nd)

    # Generate 3rd level page table
    li.d        $t1, 0x80000000 | 0x1c3 # PVDWH
    li.d        $t3, 0xc0000000
    li.d        $t4, 0x00200000 # increment by 2MB

.loop_fill_3rd:
    st.d        $t1, $t0, 0
    addi.d      $t0, $t0, 8
    add.d       $t1, $t1, $t4
    bltu        $t1, $t3, .loop_fill_3rd

    # Enable MMU
    la.global   $t0, boot_pagetable
    and         $t0, $t0, $t2
    csrwr       $t0, 0x1a       # LOONGARCH_CSR_PGDH
    li.d        $t0, 0x0
    csrwr       $t0, 0x19       # LOONGARCH_CSR_PGDL
    invtlb      0x00, $zero, $zero

    # Enable paging map mode for current mode
    li.w        $t0, 0xb0       # PLV=0, IE=0, PG=1
    csrwr       $t0, 0x0        # LOONGARCH_CSR_CRMD
    li.w        $t0, 0x00       # PLV=0, PIE=0, PWE=0
    csrwr       $t0, 0x1        # LOONGARCH_CSR_PRMD

    # Clear SAVE0 csr, we identify kernel trap by SAVE0
    li.d        $t0, 0x0
    csrwr       $t0, 0x30       # LOONGARCH_CSR_SAVE0

    li.d        $t1, 0xffffffff00000000 # Kernel base offset

    # Set up stack pointer
    la.global   $sp, boot_stack_top
    or          $sp, $sp, $t1

    # Read cpuid and fdt_base
    csrrd       $a0, 0x20       # cpuid
    li.d        $a1, 0x100000   # FDT_BASE

.extern __cpu_local_start
    la.global   $r21, __cpu_local_start

    # jump to loongarch_boot
    la.global   $t0, loongarch_boot
    or          $t0, $t0, $t1
    jirl        $zero, $t0, 0

.section .text
.balign 4096
.global tmp_tlb_refill
tmp_tlb_refill:
    csrwr   $t0, 0x8b
    csrrd   $t0, 0x1b
    lddir   $t0, $t0, 3
    lddir   $t0, $t0, 2
    lddir   $t0, $t0, 1
    ldpte   $t0, 0
    ldpte   $t0, 1
    tlbfill
    csrwr   $t0, 0x8b
    ertn

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
    .quad 0
    .zero 8 * 255
    .quad 0 # To be assigned
    .zero 8 * 254
    .quad 0 # To be assigned

.align 12
.globl boot_pagetable_2nd
boot_pagetable_2nd:
    .zero 8 * 2
    .quad 0
    .zero 8 * 508
    .quad 0

.align 12
.global boot_pagetable_3nd
boot_pagetable_3nd:
    .zero 8 * 512 # To be filled
