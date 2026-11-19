.text
main:
  #-------------------------------------------------------------
  # JAL: jump-to-target and link (rd = pc + 4) correctness.
  #-------------------------------------------------------------

test_2: # JAL actually redirects control flow (skip-trap pattern)
 li gp, 2
 li x5, 0
 jal x1, test_2_target
 li x5, 1              # must be skipped if JAL jumped correctly
test_2_target:
 bne x5, x0, fail


test_3: # link register receives pc + 4
 #
 # jal x1, test_3_mid sets x1 to the address of the very next
 # instruction in program order (the "addi x5,x5,10" below), even
 # though control actually jumps to test_3_mid. We use that saved
 # address as a jalr target: if x1 is correct, jumping to it lands
 # exactly back on "addi x5,x5,10", which is independently verified
 # by the final x5 == 11 check (1 from the first pass + 10 from the
 # trampoline landing). A wrong link value lands elsewhere and will
 # not produce x5 == 11.
 li gp, 3
 li x5, 0
 jal x1, test_3_mid
 addi x5, x5, 10          # reached only via the jalr trampoline below
 j test_3_done
test_3_mid:
 addi x5, x5, 1            # first pass, via jal's jump: x5: 0 -> 1
 jalr x6, x1, 0              # jump back using the saved link value
test_3_done:
 li x29, 11
 bne x5, x29, fail


pass:
	li a0, 1
	ebreak
fail:
	li a0, 0xdead
	ebreak
