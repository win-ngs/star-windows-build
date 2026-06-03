STAR_DIR       := STAR
BUILD_ROOT     := build
BUILD_STAR     := $(BUILD_ROOT)/STAR
BUILD_STARLONG := $(BUILD_ROOT)/STARlong
DIST_DIR       := dist

COMMON_EXTRA := -DSHM_NORESERVE=0

.PHONY: all star starlong dist clean

all: dist

star:
	rm -rf $(BUILD_STAR)
	mkdir -p $(BUILD_ROOT)
	cp -a $(STAR_DIR) $(BUILD_STAR)
	sed -i 's/-std=c++11/-std=gnu++11/g' $(BUILD_STAR)/source/Makefile
	$(MAKE) -C $(BUILD_STAR)/source STAR CXXFLAGSextra="$(COMMON_EXTRA)"

starlong:
	rm -rf $(BUILD_STARLONG)
	mkdir -p $(BUILD_ROOT)
	cp -a $(STAR_DIR) $(BUILD_STARLONG)
	sed -i 's/-std=c++11/-std=gnu++11/g' $(BUILD_STARLONG)/source/Makefile
	$(MAKE) -C $(BUILD_STARLONG)/source STARlong CXXFLAGSextra="$(COMMON_EXTRA)"

dist: star starlong
	rm -rf $(DIST_DIR)
	mkdir -p $(DIST_DIR)
	cp $(BUILD_STAR)/source/STAR.exe $(DIST_DIR)/
	cp $(BUILD_STARLONG)/source/STARlong.exe $(DIST_DIR)/

clean:
	rm -rf $(BUILD_ROOT) $(DIST_DIR)
