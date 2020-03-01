PNGView for MSX
===============

Copyright 2017 Laurens Holst

Project information
-------------------

Shows PNG files on MSX.

  * Author: Laurens Holst <laurens@grauw.nl>
  * Site: <http://www.grauw.nl/projects/pngview/>
  * Source: <https://hg.sr.ht/~grauw/pngview>
  * Support: <http://www.msx.org/forum/msx-talk/software/pngview>
  * License: Simplified BSD License

It currently supports PNG files which are stored progressively (most of them),
including those with transparency. Since no scaling is applied to the output, it
works best with images of size 256x212 or smaller. Beware that because it first
decompresses the PNG fully before showing it, it can be very memory hungry.

What remains before making an official release is to:

  * Support PNG “interlaced” storage mode (to be fully spec compliant)
  * Reduce memory requirement to 64K
  * Support screen modes other than screen 8
  * Scale large images (currently shows top left corner)


System requirements
-------------------

  * MSX2, MSX2+ or MSX turboR
  * 128K main RAM
  * 128K video RAM
  * MSX-DOS 2


Usage instructions
------------------

Run PNGView from MSX-DOS 2, specifying the PNG file to show on the command line.

Usage:

    pngview [options] <image.png>

To configure Multi Mente to show PNG files, add the following line to MMRET.DAT:

    .PNG    PNGVIEW $T


Development information
-----------------------

PNGView is free and open source software. If you want to contribute to the
project you are very welcome to. Please contact me at any one of the places
mentioned in the project information section.

You are also free to re-use code for your own projects, provided you abide by
the license terms.

Building the project is easy on all modern desktop platforms. On MacOS and
Linux, simply invoke `make` to build the binary and symbol files into the
`bin` directory:

    make

Windows users can open the `Makefile` and build by pasting the lines in the
`all` target into the Windows command prompt.

To launch the build in openMSX after building, put a copy of `MSXDOS2.SYS` and
`COMMAND2.COM` and some PNG files to test with in the `bin` directory, and then
invoke the `make run` command.

Note that the [glass](http://www.grauw.nl/projects/glass/) assembler which is
embedded in the project requires [Java 8](http://java.com/getjava). To check
your Java version, invoke the `java -version` command.
