PNGView for MSX
===============

Copyright 2017 Laurens Holst

Project information
-------------------

Shows PNG files on MSX.

Author: Laurens Holst <laurens.nospam@grauw.nl>  
Site: <https://bitbucket.org/grauw/pngview>  
Downloads: <https://bitbucket.org/grauw/pngview/downloads>  
Issues: <https://bitbucket.org/grauw/pngview/issues>  
Support: <http://www.msx.org/forum/msx-talk/software/pngview>  
License: Simplified BSD License


System Requirements
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

Building the project with some of your own modifications is really easy on all
modern desktop platforms. On Mac OS X and Linux, simply invoke `make` to build
the binary and symbol files into the `bin` directory:

    make

Windows users can open the `Makefile` and build by pasting the line in the `all`
target into the Windows command prompt.

To launch the build in openMSX after building, put a copy of `MSXDOS2.SYS` and
`COMMAND2.COM` and some PNG files to test with in the `bin` directory, and then
invoke the `make run` command.

Note that the [glass](https://bitbucket.org/grauw/glass) assembler which is
embedded in the project requires [Java 7](http://java.com/getjava). To check
your Java version, invoke the `java -version` command.
