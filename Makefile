
CC = i386-elf-gcc



# generic rules for wildcards
%.c: %.c ${HEADERS}
	$(CC) ${CFLAGS} -c $< -o $@

%.o: %.asm
	nasm $< -f elf -o $@

%.bin: %.asm
	nasm $< -f bin -o $@

clean:
	rm -rf *.bin *.o *.elf