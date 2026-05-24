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

exe: .test
exe: LDFLAGS += -pie --dynamic-linker=/lib64/ld-linux-x86-64.so.2 -T test.ld

%.o: %.asm
	$(ASM) $(ASMFLAGS) $^ -o "$@"

lib$(NAME).so: $(NAME).o $(LDSCRIPT)
	$(LD) $(LDFLAGS) "$<" -o "$@"
	-$(STRIP) --strip-section-headers $@

.test: test.o $(LDSCRIPT)
	$(LD) $(LDFLAGS) "$<" -o "$@"
	-$(STRIP) --strip-section-headers $@

edit:
	vim -c 'set nu et tabstop=4 shiftwidth=4' "$(NAME).asm"

edit_test:
	vim -c 'set nu et tabstop=4 shiftwidth=4' "test.asm"

edit_ld:
	vim -c 'set nu et tabstop=4 shiftwidth=4' "$(NAME).ld"

test: dyn exe
	LD_PRELOAD=$(shell readlink -f ./lib$(NAME).so) ./.test

clean:
	-rm -f "lib$(NAME).so" "$(NAME).o" ".test" "test.o"

.PHONY: all dyn exe edit edit_test edit_ld test clean
