main:
    addi t5, zero, 8
    slli t5, t5, 2
    sub  t0, a0, t5
    slli t1, t0, 2
    add  t1, t1, t0
    addi t2, zero, 0
    addi t3, t1, 0
    addi t4, zero, 9
loop:
    blt  t3, t4, done
    sub  t3, t3, t4
    addi t2, t2, 1
    beq  zero, zero, loop
done:
    addi a0, t2, 0
    jalr zero, 0(ra)
