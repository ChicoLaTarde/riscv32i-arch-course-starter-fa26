.text
main:
  #-------------------------------------------------------------
  # Load/store: word, halfword, and byte access -- sign/zero
  # extension and byte-lane alignment at every offset within a
  # word. Base address 0x100 is well inside the 1024-byte dmem.
  #-------------------------------------------------------------

test_2: # sw / lw round trip
 li gp, 2
 li x1, 0x100
 li x2, 0xdeadbeef
 sw x2, 0(x1)
 lw x3, 0(x1)
 bne x3, x2, fail


test_3: # sh / lhu at byte_offset 0 (lower half of the word)
 li gp, 3
 li x1, 0x100
 li x4, 0x1234
 sh x4, 4(x1)
 lhu x5, 4(x1)
 li x29, 0x00001234
 bne x5, x29, fail


test_4: # sh / lh at byte_offset 2 (upper half); negative value sign-extends
 li gp, 4
 li x1, 0x100
 li x4, 0xffff8765
 sh x4, 6(x1)
 lh x6, 6(x1)
 li x29, 0xffff8765
 bne x6, x29, fail
 lhu x7, 6(x1)
 li x29, 0x00008765
 bne x7, x29, fail


test_5: # sb / lb at byte_offset 0
 li gp, 5
 li x1, 0x100
 li x4, 0x55
 sb x4, 8(x1)
 lb x8, 8(x1)
 li x29, 0x00000055
 bne x8, x29, fail
 lbu x9, 8(x1)
 bne x9, x29, fail


test_6: # sb / lb at byte_offset 1; negative byte sign-extends
 li gp, 6
 li x1, 0x100
 li x4, 0xaa
 sb x4, 9(x1)
 lb x10, 9(x1)
 li x29, 0xffffffaa
 bne x10, x29, fail
 lbu x11, 9(x1)
 li x29, 0x000000aa
 bne x11, x29, fail


test_7: # sb / lb at byte_offset 2
 li gp, 7
 li x1, 0x100
 li x4, 0xbb
 sb x4, 10(x1)
 lb x12, 10(x1)
 li x29, 0xffffffbb
 bne x12, x29, fail


test_8: # sb / lb at byte_offset 3
 li gp, 8
 li x1, 0x100
 li x4, 0xcc
 sb x4, 11(x1)
 lb x13, 11(x1)
 li x29, 0xffffffcc
 bne x13, x29, fail


pass:
	li a0, 1
	ebreak
fail:
	li a0, 0xdead
	ebreak
