NAME     := $(shell basename `pwd`)

ASM      := nasm
ASMFLAGS := -felf64
LD       := ld.lld
LDFLAGS  := \
	--gc-sections \
	--build-id=none \
	-z noseparate-code \
	-z now \
	-L/usr/lib64 -lc
STRIP    := strip

all: dyn

dyn: lib$(NAME).so
dyn: LDFLAGS += -shared -e 0 -T $(NAME).ld

exe: main
exe: LDFLAGS += -pie --dynamic-linker=/lib64/ld-linux-x86-64.so.2 -T main.ld

%.o: %.asm
	$(ASM) $(ASMFLAGS) $^ -o "$@"

lib$(NAME).so: $(NAME).o $(LDSCRIPT)
	$(LD) $(LDFLAGS) "$<" -o "$@"
	-$(STRIP) --strip-section-headers $@

main: main.o $(LDSCRIPT)
	$(LD) $(LDFLAGS) "$<" -o "$@"
	-$(STRIP) --strip-section-headers $@

edit:
	vim -c 'set nu et tabstop=4 shiftwidth=4' "$(NAME).asm"

edit_main:
	vim -c 'set nu et tabstop=4 shiftwidth=4' "main.asm"

edit_ld:
	vim -c 'set nu et tabstop=4 shiftwidth=4' "$(NAME).ld"

test: dyn exe
	LD_PRELOAD=$(shell readlink -f ./lib$(NAME).so) ./main

clean:
	-rm -f "lib$(NAME).so" "$(NAME).o" "main" "main.o"

.PHONY: all dyn exe edit edit_main edit_ld test clean
