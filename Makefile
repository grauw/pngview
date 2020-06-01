COPY_TARGET = /Volumes/MSXDOS2

all:
	mkdir -p bin
	java -jar tools/glass.jar -I gen -I lib/neonlib/src -I lib/gunzip/src src/COM.asm bin/pngview.com bin/pngview.sym

dist: all
	rm -f bin/pngview.zip
	zip -j bin/pngview.zip bin/pngview.com README.md LICENSE

copy: all
	cp bin/pngview.com $(COPY_TARGET)/
	diskutil umountDisk `mount | grep $(COPY_TARGET) | cut -d" " -f 1`

run: all
	openmsx -machine Panasonic_FS-A1GT -ext ide -ext ram1mb -script openmsx.tcl

run2: all
	openmsx -machine Philips_NMS_8245 -ext ide -ext ram4mb -script openmsx.tcl
