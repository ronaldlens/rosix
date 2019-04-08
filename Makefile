
CC = i386-elf-gcc
LD = i386-elf-ld
QEMU = qemu-system-i386

all: run

boot/kernel.bin: boot/kernel_entry.o boot/kernel.o
	$(LD) -o $@ -Ttext 0x1000 $^ --oformat binary

boot/kernel_entry.o: boot/kernel_entry.asm
	nasm $< -f elf -o $@

boot/kernel.o: boot/kernel.c
	$(CC) -ffreestanding -c $< -o $@

boot/boot32.bin: boot/boot32.asm
	nasm $< -f bin -o $@

os-image.bin: boot/boot32.bin boot/kernel.bin
	cat $^ > $@

run: os-image.bin
	$(QEMU) -fda $<
