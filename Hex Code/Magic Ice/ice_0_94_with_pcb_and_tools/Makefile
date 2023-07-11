
TARGET = magic_ice

FILES = magic_ice.sx		\
	define.inc		\
	obj			\
	obj/osdsys_10k.bin	\
	obj/osdsys_10k.inc	\
	obj/osdsys_v1.bin	\
	obj/osdsys_v1.inc	\
	obj/osdsys_v3.bin	\
	obj/osdsys_v3.inc	\
	obj/osdsys_v4.bin	\
	obj/osdsys_v4.inc	\
	obj/osdsys_vx.bin	\
	obj/osdsys_vx.inc	\
	obj/ps2logo.bin		\
	obj/ps2logo.inc		\

$(TARGET).hex: $(FILES) $(TARGET).bin
	sasm.exe /P SX28AC $(TARGET).sx
#	del $(TARGET).map
#	del $(TARGET).sym
	sxfree.exe -i:$(TARGET).bin

# make rce_magic3.bin then rce_magic3.hex if win ok...
$(TARGET).bin: $(FILES)
	sasm.exe /P SX28AC /F BIN16 $(TARGET).sx
	del $(TARGET).bin
	ren $(TARGET).obj $(TARGET).bin
#	del $(TARGET).map
#	del $(TARGET).sym
obj:
	mkdir obj

obj/osdsys_10k.bin: osdsys_10k.mip define.inc
	asm5900.exe osdsys_10k.mip /o:obj/osdsys_10k.bin
obj/osdsys_10k.inc: obj/osdsys_10k.bin
	mip2sx.exe -i:obj/osdsys_10k.bin -o:obj/osdsys_10k.inc

obj/osdsys_v1.bin: osdsys_v1.mip define.inc
	asm5900.exe osdsys_v1.mip /o:obj/osdsys_v1.bin
obj/osdsys_v1.inc: obj/osdsys_v1.bin
	mip2sx.exe -i:obj/osdsys_v1.bin -o:obj/osdsys_v1.inc
	
obj/osdsys_v3.bin: osdsys_v3.mip define.inc
	asm5900.exe osdsys_v3.mip /o:obj/osdsys_v3.bin
obj/osdsys_v3.inc: obj/osdsys_v3.bin
	mip2sx.exe -i:obj/osdsys_v3.bin -o:obj/osdsys_v3.inc

obj/osdsys_v4.bin: osdsys_v4.mip define.inc
	asm5900.exe osdsys_v4.mip /o:obj/osdsys_v4.bin
obj/osdsys_v4.inc: obj/osdsys_v4.bin
	mip2sx.exe -i:obj/osdsys_v4.bin -o:obj/osdsys_v4.inc

obj/osdsys_vx.bin: osdsys_vx.mip define.inc
	asm5900.exe osdsys_vx.mip /o:obj/osdsys_vx.bin
obj/osdsys_vx.inc: obj/osdsys_vx.bin
	mip2sx.exe -i:obj/osdsys_vx.bin -o:obj/osdsys_vx.inc

obj/ps2logo.bin: ps2logo.mip define.inc
	asm5900.exe ps2logo.mip /o:obj/ps2logo.bin
obj/ps2logo.inc: obj/ps2logo.bin
	mip2sx.exe -i:obj/ps2logo.bin -o:obj/ps2logo.inc

clean:
	del *.bak
	del /q obj\*.*
	del $(TARGET).lst
	del $(TARGET).map
	del $(TARGET).sym
	del $(TARGET).err
cleanall:
	del *.bak
	del /q obj\*.*
	del $(TARGET).hex
	del $(TARGET).bin
	del $(TARGET).lst
	del $(TARGET).map
	del $(TARGET).sym
	del $(TARGET).err