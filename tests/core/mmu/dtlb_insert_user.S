//
// Copyright 2016 Jeff Bush
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#include "mmu_test_common.inc"

//
// Ensure the processor faults and doesn't update the TLB if dtlbinsert is
// called when in user mode.
//

                .globl _start
_start:         load_tlb_entries itlb_entries, dtlb_entries

                lea s0, handle_fault1
                setcr s0, CR_TRAP_HANDLER
                lea s0, handle_fault2
                setcr s0, CR_TLB_MISS_HANDLER

                // Enable MMU, switch to user mode
                move s0, FLAG_MMU_EN
                setcr s0, CR_FLAGS
                flush_pipeline

                li s0, 0x2000
                li s1, 0x2000 | TLB_PRESENT
                dtlbinsert s0, s1   // This should fault

                should_not_get_here

handle_fault1:  getcr s0, CR_TRAP_CAUSE
                assert_reg s0, TT_PRIVILEGED_OP

                // Check that MMU is still enabled and we have
                // switched to supervisor mode
                getcr s0, CR_FLAGS
                assert_reg s0, (FLAG_MMU_EN | FLAG_SUPERVISOR_EN)

                // Try to read data from new address. This should cause
                // a TLB miss because dtlbinsert failed.
                li s0, 0x2430
fault_loc:      load_32 s0, (s0)    // This should fault

                should_not_get_here

handle_fault2:  getcr s0, CR_TRAP_CAUSE
                assert_reg s0, TT_TLB_MISS | TRAP_CAUSE_DCACHE
                getcr s0, CR_TRAP_ADDRESS
                assert_reg s0, 0x2430

                // MMU should be disabled, but still in supervisor mode
                getcr s0, CR_FLAGS
                assert_reg s0, FLAG_SUPERVISOR_EN

                // Check that fault PC is correct
                getcr s0, CR_TRAP_PC
                lea s1, fault_loc
                cmpeq_i s0, s0, s1
                bnz s0, 1f
                call fail_test
1:

                call pass_test

itlb_entries:   .long 0x00001000, 0x00001000 | TLB_PRESENT | TLB_EXECUTABLE
                .long 0xffffffff, 0xffffffff

dtlb_entries:   .long 0x00001000, 0x00001000 | TLB_PRESENT
                .long 0xffff0000, 0xffff0000 | TLB_PRESENT | TLB_WRITABLE    // I/O area
                .long 0xffffffff, 0xffffffff
