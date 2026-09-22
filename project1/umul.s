## Author: David Uk
##
## You may implement the following with any of the instructions in the RV32I instruction set
## and described in the reference sheet. Do not use any of the mul[h][s][u] instructions which
## are *not* described in the reference sheet. Remember to respect the calling convention - if
## you choose to use any of the callee saved registers s[0-11], remember to save them to the
## stack before reusing them (note, you should not need to do this but are free to do so).
##
## [Description]
## Multiplies two 32-bit *unsigned* numbers and provides a 32-bit *unsigned* result
## consisting of the lower 32 bits of the product.
##
## [Arguments]
## a0 = multiplicand
## a1 = multiplier
##
## [Returns]
## a0 = 32-bit product
        .text
    .globl umul
umul:
    # t0 = running product
    # t1 = current multiplicand
    # t2 = current multiplier
    # t3 = least significant bit of multiplier

    addi t0, zero, 0
    addi t1, a0, 0
    addi t2, a1, 0

loop:
    # If multiplier is zero, multiplication is finished
    beq  t2, zero, done

    # Check lowest bit of multiplier
    andi t3, t2, 1
    beq  t3, zero, skip_add

    # Add current multiplicand when bit is 1
    add  t0, t0, t1

skip_add:
    # Move to next binary position
    slli t1, t1, 1
    srli t2, t2, 1

    # Unconditional branch
    beq  zero, zero, loop

done:
    # Return product in a0
    addi a0, t0, 0
    jalr zero, 0(ra)
