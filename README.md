# memory_allocator

A memory allocator written in pure x86 assembly, from scratch.

## What it does

Implements `malloc` and `free` equivalents using the Linux `brk` syscall to manage the heap directly — no libc, no C, just assembly.

Each allocated block is prefixed with an 8-byte header:

```
+------------------+------------------+-----------------------------+
| Available marker |   Size of block  |   Actual memory (returned)  |
|     (4 bytes)    |    (4 bytes)     |                             |
+------------------+------------------+-----------------------------+
                                       ^ pointer returned to caller
```

The returned pointer skips the header so the caller does not need to know the internal structure.

## How it works

- `allocate_init` — initialises the heap by recording the current `brk` position as the start of managed memory
- `allocate` — walks the free list looking for an available block of sufficient size; if none found, extends the heap via `brk`
- `deallocate` — marks a block as available by flipping its header flag (no coalescing yet)

## Build

```bash
as --32 -o main/alloc.o main/alloc.s
as --32 -o test/test-alloc.o test/test-alloc.s
ld -m elf_i386 -o test/test-alloc test/test-alloc.o main/alloc.o
./test/test-alloc
```

Requires 32-bit support (`gcc-multilib` / `lib32-glibc` on 64-bit Linux).

## Status

- [x] Heap initialisation via `brk`
- [x] First-fit allocation with header metadata
- [x] Deallocation (mark as available)
- [ ] Free list coalescing (merge adjacent free blocks)
- [ ] `realloc` equivalent
