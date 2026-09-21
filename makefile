CA = ca65
LD = ld65
PY = python

ROM     = idky.sfc
ROMCFG  = rom.cfg
DBGFILE = idky.sfc.dbg
MAPFILE = idky.map

CA_FLAGS = -g

OBJS = \
	build/variables.o \
	build/header.o \
	build/all_assets.o \
	build/main_vn.o \
	build/vn_char.o \
	build/vn_text.o \
	build/main_pf.o \
	build/pf_asc.o \
	build/pf_npc.o

all: $(ROM)

clean:
	rm -r build
	mkdir -p build

# todo: this always rewrites assets even when not necessary.
# that causes many of the other source files to recompile.
assetman:
	$(PY) tools/assetman/assetman.py

build:
	mkdir -p build

# the generated files use .asm, so we're okay!
vpath %.s src/root src/ihyt src/waffle assetgen

$(OBJS): assets

$(ROM): assetman build $(OBJS)
	$(LD) -C $(ROMCFG) -o $(ROM) --mapfile $(MAPFILE) --dbgfile $(DBGFILE) $(OBJS)

build/%.o: %.s | build
	$(CA) $< -o $@ --create-dep $(@:.o=.d) $(INC_FLAGS) $(CA_FLAGS)

build/variables.o  : INC_FLAGS = -I src/waffle
build/header.o     : INC_FLAGS = -I src/waffle
build/all_assets.o : INC_FLAGS = -I src/waffle -I src/root -I src/ihyt -I assetgen
build/main_vn.o    : INC_FLAGS = -I src/waffle -I src/root -I assetgen
build/vn_char.o    : INC_FLAGS = -I src/waffle -I src/root -I assetgen
build/vn_text.o    : INC_FLAGS = -I src/waffle -I src/root -I assetgen
build/main_pf.o    : INC_FLAGS = -I src/waffle -I src/root -I assetgen
build/pf_asc.o     : INC_FLAGS = -I src/waffle -I src/root -I assetgen
build/pf_npc.o     : INC_FLAGS = -I src/waffle -I src/root -I assetgen

-include $(OBJS:.o=.d)