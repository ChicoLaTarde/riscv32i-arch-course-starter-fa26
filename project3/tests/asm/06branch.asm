.text
main:
  #-------------------------------------------------------------
  # Branch tests: taken and not-taken, every condition code.
  #
  # Pattern: branch to a local label if the branch *should* be
  # taken, immediately followed by "j fail". If the branch logic
  # is broken (not taken when it should be), execution falls
  # straight into the fail trap.
  #-------------------------------------------------------------

test_2: # BEQ taken
 li x1, 5
 li x2, 5
 li gp, 2
 beq x1, x2, 2f
 j fail
2:

test_3: # BEQ not-taken
 li x1, 5
 li x2, 6
 li gp, 3
 beq x1, x2, fail


test_4: # BNE taken
 li x1, 5
 li x2, 6
 li gp, 4
 bne x1, x2, 4f
 j fail
4:

test_5: # BNE not-taken
 li x1, 5
 li x2, 5
 li gp, 5
 bne x1, x2, fail


test_6: # BLT taken (signed: -1 < 1)
 li x1, -1
 li x2, 1
 li gp, 6
 blt x1, x2, 6f
 j fail
6:

test_7: # BLT not-taken (signed: 1 < -1 is false)
 li x1, 1
 li x2, -1
 li gp, 7
 blt x1, x2, fail


test_8: # BGE taken (signed: 1 >= -1)
 li x1, 1
 li x2, -1
 li gp, 8
 bge x1, x2, 8f
 j fail
8:

test_9: # BGE not-taken (signed: -1 >= 1 is false)
 li x1, -1
 li x2, 1
 li gp, 9
 bge x1, x2, fail


test_10: # BLTU taken (unsigned: 1 < 0xffffffff)
 li x1, 1
 li x2, -1
 li gp, 10
 bltu x1, x2, 10f
 j fail
10:

test_11: # BLTU not-taken (unsigned: 0xffffffff < 1 is false)
 li x1, -1
 li x2, 1
 li gp, 11
 bltu x1, x2, fail


test_12: # BGEU taken (unsigned: 0xffffffff >= 1)
 li x1, -1
 li x2, 1
 li gp, 12
 bgeu x1, x2, 12f
 j fail
12:

test_13: # BGEU not-taken (unsigned: 1 >= 0xffffffff is false)
 li x1, 1
 li x2, -1
 li gp, 13
 bgeu x1, x2, fail


pass:
	li a0, 1
	ebreak
fail:
	li a0, 0xdead
	ebreak
