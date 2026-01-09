#PURPOSE: Program to manage memory usage - allocates
# and deallocates memory as requested
#
#NOTES: The programs using these routines will ask
# for a certain size of memory. We actually
# use more than that size, but we put it
# at the beginning, before the pointer
# we hand back. We add a size field and
# an AVAILABLE/UNAVAILABLE marker. So, the
# memory looks like this
#
# #########################################################
# #Available Marker#Size of memory#Actual memory locations#
# #########################################################
#                                 ^--Returned pointer
#                                                points here
# The pointer we return only points to the actual
# locations requested to make it easier for the
# calling program. It also allows us to change our
# structure without the calling program having to
# change at all.

.section .data

##GLOBAL VARIABLES###

#This points to the beginning of the memory we are managing
heap_begin:
.long 0 

#This points to one location past the memory we are managing
current_break:
.long 0

######STRUCTURE INFORMATION####

#size of space for memory region header
.equ HEADER_SIZE, 8

#Location of the "available" flag in the header
.equ HDR_AVAIL_OFFSET, 0

#Location of the size field in the header
.equ HDR_SIZE_OFFSET, 4

###########CONSTANTS###########

.equ UNAVAILABLE, 0 #This is the number we will use to mark
                    #space that has been given out

.equ AVAILABLE, 1   #This is the number we will use to mark
                    #space that has been returned, and is
                    #available for giving

.equ SYS_BRK, 45    #system call number for the break system call

.equ LINUX_SYSCALL, 0x80 #make system calls easier to read

###########STACK POSITIONS#####

.equ ST_MEM_SIZE, 8  #stack position of memory size to allocate

.equ ST_MEMORY_SEG, 4 #stack position of memory region to free

.section .text

##########FUNCTIONS############

##allocate_init##
#PURPOSE: call this function to initialize the
#         functions (specifically, this sets heap_begin and
#         current_break). This has no parameters and no
#         return value.

.globl allocate_init
.type allocate_init,@function
allocate_init:
    pushl %ebp              #standard function stuff
    movl %esp, %ebp

    #If the brk system call is called with 0 in %ebx, it
    #returns the last valid usable address
    movl $SYS_BRK, %eax     #find out where the break is
    movl $0, %ebx
    int $LINUX_SYSCALL

    incl %eax               #%eax now has the last valid
                            #address, and we want the
                            #memory location after that

    movl %eax, current_break #store the current break

    movl %eax, heap_begin   #store the current break as our
                            #first address. This will cause
                            #the allocate function to get
                            #more memory from Linux the
                            #first time it is run

    movl %ebp, %esp         #exit the function
    popl %ebp
    ret

#END OF FUNCTION allocate_init

##allocate##
#PURPOSE: This function is used to grab a section of
#         memory. It checks to see if there are any
#         free blocks, and, if not, it asks Linux
#         for a new one.
#
#PARAMETERS: This function has one parameter - the size
#            of the memory block we want to allocate
#
#RETURN VALUE:
#           This function returns the address of the
#           allocated memory in %eax. If there is no
#           memory available, it will return 0 in %eax
#
#Variables used:
#              %ecx - hold the size of the requested memory
#                     (first/only parameter)
#              %eax - current memory region being examined
#              %ebx - current break position
#              %edx - size of current memory region
#
#We scan through each memory region starting with
#heap_begin. We look at the size of each one, and if
#it has been allocated. If it's big enough for the
#requested size, and its available, it grabs that one.
#If it does not find a region large enough, it asks
#Linux for more memory. In that case, it moves
#current_break up

.globl allocate
.type allocate,@function
allocate:
    pushl %ebp
    movl %esp, %ebp

    movl ST_MEM_SIZE(%ebp), %ecx    #%ecx holds the size requested
    movl heap_begin, %eax           #%eax holds current search location
    movl current_break, %ebx        #%ebx holds current break

alloc_loop_begin:
    cmpl %ebx, %eax                 #Need more memory if equal
    je move_break

    #Grab the size of this memory region
    movl HDR_SIZE_OFFSET(%eax), %edx

    #If unavailable, go to next one
    cmpl $UNAVAILABLE, HDR_AVAIL_OFFSET(%eax)
    je next_location

    #If available, check if it's big enough
    cmpl %edx, %ecx
    jle allocate_here               #If requested <= available, use it

next_location:
    #Move to next memory region
    addl $HEADER_SIZE, %eax         #Skip header
    addl %edx, %eax                 #Skip data
    jmp alloc_loop_begin

allocate_here:
    #Mark as unavailable
    movl $UNAVAILABLE, HDR_AVAIL_OFFSET(%eax)
    #Move %eax past header to usable memory
    addl $HEADER_SIZE, %eax

    movl %ebp, %esp
    popl %ebp
    ret

move_break:
    #Need to ask Linux for more memory
    #%ebx holds current break
    #Need to increase by: HEADER_SIZE + requested size

    addl $HEADER_SIZE, %ebx         #Add header size
    addl %ecx, %ebx                 #Add requested size
    #%ebx now holds where we want the new break

    #Save registers
    pushl %eax
    pushl %ecx
    pushl %ebx

    #Call brk
    movl $SYS_BRK, %eax
    movl %ebx, %ebx                 #New break position
    int $LINUX_SYSCALL

    #Check for error (returns 0 on error)
    cmpl $0, %eax
    je error

    #Restore registers
    popl %ebx
    popl %ecx
    popl %eax

    #Update current_break
    movl %ebx, current_break

    #Set up header for new region
    movl $UNAVAILABLE, HDR_AVAIL_OFFSET(%eax)
    movl %ecx, HDR_SIZE_OFFSET(%eax)

    #Move %eax to usable memory (past header)
    addl $HEADER_SIZE, %eax

    movl %ebp, %esp
    popl %ebp
    ret

error:
    #Return 0 on error
    movl $0, %eax
    movl %ebp, %esp
    popl %ebp
    ret

#END OF FUNCTION allocate

##deallocate##
#PURPOSE: Give back memory when done using it
#
#PARAMETERS: Memory address to return (passed on stack)
#
#RETURN VALUE: None
#
#PROCESS: Move pointer back to header, mark as available

.globl deallocate
.type deallocate,@function
deallocate:
    #No standard prologue since we don't use %ebp

    movl ST_MEMORY_SEG(%esp), %eax  #Get address to free
    subl $HEADER_SIZE, %eax         #Move back to header
    movl $AVAILABLE, HDR_AVAIL_OFFSET(%eax) #Mark as available

    ret

#END OF FUNCTION deallocate
