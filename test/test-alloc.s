# test-alloc.s - Simple allocator test

.section .text
.globl _start

_start:
    # Initialize allocator
    call allocate_init

    # Test 1: Allocate 100 bytes
    pushl $100
    call allocate
    addl $4, %esp
    
    # Check if allocation succeeded
    cmpl $0, %eax
    je alloc_failed
    
    # Save pointer
    movl %eax, %edi
    
    # Test 2: Allocate another 200 bytes
    pushl $200
    call allocate
    addl $4, %esp
    
    cmpl $0, %eax
    je alloc_failed
    
    movl %eax, %esi
    
    # Test 3: Free first allocation
    pushl %edi
    call deallocate
    addl $4, %esp
    
    # Test 4: Allocate 50 bytes (should reuse freed space)
    pushl $50
    call allocate
    addl $4, %esp
    
    cmpl $0, %eax
    je alloc_failed
    
    # Test 5: Free everything
    pushl %eax
    call deallocate
    addl $4, %esp
    
    pushl %esi
    call deallocate
    addl $4, %esp
    
    # Success - exit 0
    movl $1, %eax
    movl $0, %ebx
    int $0x80

alloc_failed:
    # Failed - exit 1
    movl $1, %eax
    movl $1, %ebx
    int $0x80
