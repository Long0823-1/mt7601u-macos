# Build the upstream mt7601u driver (unmodified except trace.h stub) against the macOS compat layer.
SRC := ../mt7601u/src
CFLAGS := -MMD -MP -O2 -g -w -fno-strict-aliasing -fms-extensions -DKBUILD_MODNAME='"mt7601u"' -Icompat -Icompat/uapi -I$(SRC) -Ihost
MT := core dma eeprom init mac main mcu phy tx usb util
HOST := ksupport mm_core mlme datapath supplicant sae daemon airport_bridge main mt_glue
SYSHOST := usb_shim crypto net net6 ecp256
OBJ := $(addprefix build/mt_,$(addsuffix .o,$(MT))) $(addprefix build/host_,$(addsuffix .o,$(HOST))) $(addprefix build/sys_,$(addsuffix .o,$(SYSHOST)))

all: mt7601ud
mt7601ud: $(OBJ)
	clang -o $@ $(OBJ) -lpthread -framework CoreFoundation -framework IOKit
build/mt_%.o: $(SRC)/%.c
	clang $(CFLAGS) -include compat/mt_extra.h -c $< -o $@
build/host_%.o: host/%.c
	clang $(CFLAGS) -c $< -o $@
build/sys_%.o: host/%.c
	clang $(CFLAGS) -c $< -o $@
clean:
	rm -f build/*.o build/*.d mt7601ud

-include $(wildcard build/*.d)
