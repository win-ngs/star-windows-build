STAR_DIR       := STAR
BUILD_ROOT     := build
BUILD_STAR     := $(BUILD_ROOT)/STAR
BUILD_STARLONG := $(BUILD_ROOT)/STARlong
BINARY_DIR     := win_x86_64

COMMON_EXTRA := -DSHM_NORESERVE=0
BUILD_PLACE ?= WinNGS

.PHONY: all star starlong binaries clean

all: binaries

star:
	rm -rf $(BUILD_STAR)
	mkdir -p $(BUILD_ROOT)
	cp -a $(STAR_DIR) $(BUILD_STAR)
	sed -i 's/-std=c++11/-std=gnu++11/g' $(BUILD_STAR)/source/Makefile
	$(MAKE) -C $(BUILD_STAR)/source STAR \
		CXXFLAGSextra="$(COMMON_EXTRA)" \
		BUILD_PLACE="$(BUILD_PLACE)"

starlong:
	rm -rf $(BUILD_STARLONG)
	mkdir -p $(BUILD_ROOT)
	cp -a $(STAR_DIR) $(BUILD_STARLONG)
	sed -i 's/-std=c++11/-std=gnu++11/g' $(BUILD_STARLONG)/source/Makefile
	$(MAKE) -C $(BUILD_STARLONG)/source STARlong \
		CXXFLAGSextra="$(COMMON_EXTRA)" \
		BUILD_PLACE="$(BUILD_PLACE)"

binaries: star starlong
	rm -rf $(BINARY_DIR)
	mkdir -p $(BINARY_DIR)
	cp $(BUILD_STAR)/source/STAR.exe $(BINARY_DIR)/
	cp $(BUILD_STARLONG)/source/STARlong.exe $(BINARY_DIR)/

clean:
	rm -rf $(BUILD_ROOT) $(BINARY_DIR)
