C_SOURCES = $(wildcard kernel/*.c drivers/*.c)
HEADERS = $(wildcard kernel/*.h drivers/*.h)
# Nice syntax for file extension replacement
OBJ = ${C_SOURCES:.c=.o}

CC = i386-elf-gcc
LD = i386-elf-ld
GDB = i386-elf-gdb
QEMU = qemu-system-i386
CFLAGS = -g

os-image.bin: boot/boot32.bin kernel.bin
	cat $^ > $@

kernel.bin: boot/kernel_entry.o ${OBJ}
	$(LD) -o $@ -Ttext 0x1000 $^ --oformat binary

# used for debugging
kernel.elf: boot/kernel_entry.o ${OBJ}
	$(LD) -o $@ -Ttext 0x1000 $^

run: os-image.bin
	$(QEMU) -drive format=raw,file=$<,index=0,if=floppy

debug: os-image.bin kernel.elf
	$(QEMU) -s -drive format=raw,file=$<,index=0,if=floppy &
	$(GDB) -ex "target remote localhost:1234" -ex "symbol-file kernel.elf"

# generic rules for wildcards
%.o: %.asm ${HEADERS}
	${CC} ${CFLAGS} -ffreestanding -c $< -o $@

%.o: %.asm
	nasm $< -f elf -o $@

%.bin: %.asm
	nasm $< -f bin -o $@


clean:
	rm -f *.bin boot/*.bin boot/*.o
	rm -f kernel/*.o kernel/*.elf
