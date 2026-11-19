.text
main:
  #-------------------------------------------------------------
  # JALR: target = (rs1 + imm) & ~1, link = pc + 4.
  #
  # Each test uses "jal x1, <next instruction>" purely as a
  # bootstrap to get a known-correct address into x1 (the target
  # label is literally the next instruction, so the jump is a
  # no-op and x1 is unambiguously that instruction's address).
  # From there, jalr's own addition/masking is what's under test.
  #-------------------------------------------------------------

test_2: # jalr with a nonzero positive immediate
 li gp, 2
 li x5, 0
 jal x1, test_2_anchor
test_2_anchor:
 jalr x6, x1, 12           # target = x1 + 12, skipping the two li's below
 li x5, 1                    # x1 + 4 -- must be skipped
 li x5, 2                     # x1 + 8 -- must be skipped
test_2_target:                 # x1 + 12
 li x29, 0
 bne x5, x29, fail


test_3: # jalr clears bit 0 of (rs1 + imm); link = pc + 4
 li gp, 3
 li x5, 0
 jal x1, test_3_anchor
test_3_anchor:
 jalr x6, x1, 13            # raw target x1+13 is odd; must land at x1+12, not x1+13
 li x5, 1                     # x1 + 4 -- must be skipped
 li x5, 2                      # x1 + 8 -- must be skipped
test_3_target:                  # x1 + 12
 addi x7, x1, 4                  # expected link value: addr(jalr instruction) + 4
 li x29, 0
 bne x5, x29, fail
 bne x6, x7, fail


test_4: # jalr with a negative immediate (backward target)
 li gp, 4
 li x5, 0
 j test_4_jalr             # skip over the backward-jump target on the way in
test_4_target:
 li x5, 5
 j test_4_done
test_4_jalr:
 jal x1, test_4_anchor
test_4_anchor:
 jalr x6, x1, -12           # target = x1 - 12 = addr(test_4_target)
 j fail                       # unreachable if jalr computed the target correctly
test_4_done:
 li x29, 5
 bne x5, x29, fail


pass:
	li a0, 1
	ebreak
fail:
	li a0, 0xdead
	ebreak
