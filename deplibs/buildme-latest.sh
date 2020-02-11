#!/usr/bin/env bash
#
# $Id$
#
# Filename: buildme-latest.sh
# Description:
#   This script builds all dependency libraries for libmediascan, the library
#   itself, and then the binary Perl module. It builds a statically linked version.
#       It first parses the input values for any custom parameters. Then it checks
#       to ensure all necessary prerequites are present on the the system.
#
#  This script differs from the other buildme.sh script in that it is intended
#  to be run at regular intervals, to check libmediascan against the most recent
#  versions of the dependency libraries. This will permit catching regressions and
#  API/ABI changes early.
#
#   See the README.md for supported OSes and build notes/preparations.
#
# Parameters:
#    lmsbase    Optional string containing the path to the desired installation
#               directory. The default location is within the build/arch directory,
#               but this parameter may be used to place the Perl modules directly
#               within an existing Logitech Media Server installation folder.
#
#    jobs       Optional integer to be passed through to make. The default is
#               one, for safety. Increasing this value can speed builds.
#
#    perlbin    Optional string containing the location to a custom Perl binary.
#               This overrides default behavior of searching the PATH for Perl.
#
#    alldeps    Flag indicating that the build should build all dependencies,
#               rather than use any from host (only applies to MinGW).
#
#    loud       Flag indicating that the build should not be quiet during the
#               configure step. This allows debugging runs in Travis-ci by
#               enabling this flag for the build step within a custom .travis.yml
#               config on the webgui. This prevents excessive commits done just
#               to bisect failed builds.
#
################################################################################
# Initial values prior to argument parsing
# Require modules to pass tests
RUN_TESTS=1
USE_HINTS=1
CLEAN=1
NUM_MAKE_JOBS=1
ALL_DEPS=0
USE_DMAKE=0
QUIET_FLAG="--quiet"

function usage {
    cat <<EOF
$0 [args] [target]
-h            this help
-c            do not run make clean
-i <lmsbase>  install modules in lmsbase directory
-j <jobs>     set number of processes for make (default: 1)
-p <perlbin > set custom perl binary (other than one in PATH)
-t            do not run tests
-a            build all dependencies, skip native (MinGW only)
-l            conduct cacophonous configure (non-quiet build)

target: make target - if not specified all will be built

EOF
}

while getopts hacli:j:p:t opt; do
  case $opt in
  a)
      ALL_DEPS=1
      ;;
  c)
      CLEAN=0
      ;;
  l)
      QUIET_FLAG=""
      ;;
  i)
      LMSBASEDIR=$OPTARG
      ;;
  j)
      NUM_MAKE_JOBS=$OPTARG
      ;;
  p)
      CUSTOM_PERL=$OPTARG
      ;;
  t)
      RUN_TESTS=0
      ;;
  h)
      usage
      exit
      ;;
  *)
      echo "invalid argument"
      usage
      exit 1
      ;;
  esac
done

shift $((OPTIND - 1))

echo "RUN_TESTS:$RUN_TESTS CLEAN:$CLEAN USE_HINTS:$USE_HINTS target ${1-all}"

OS=`uname`
MACHINE=`uname -m`

if [[ "$OS" != "Linux" && "$OS" != "Darwin" && "$OS" != "FreeBSD" && "$OS" != "SunOS" && !( "$OS" =~ ^MINGW.*$ ) ]]; then
    echo "Unsupported platform: $OS, please submit a patch or provide us with access to a development system."
    exit
fi

# Set default values prior to potential overwrite
# Check to see if CC and CXX are already defined
if [[ ! -z "$CC" ]]; then
    GCC="$CC"
else
    # Take a guess
    GCC=gcc
fi
if [[ ! -z "$CXX" ]]; then
    GXX="$CXX"
else
    GXX=g++
fi

# Set default values prior to potential overwrite
CFLAGS_COMMON="-w -fPIC"
CXXFLAGS_COMMON="-w -fPIC"
LDFLAGS_COMMON="-w -fPIC"

# Support a newer make if available, needed on ReadyNAS
if [ -x /usr/local/bin/make ]; then
    MAKE_BIN=/usr/local/bin/make
else
    MAKE_BIN=/usr/bin/make
fi

# Assume we use the same make for C/C++ as for Perl module
PERL_MAKE=$MAKE_BIN

# Try to use the version of Perl in PATH, or the CLI supplied
if [ "$PERL_BIN" = "" -o "$CUSTOM_PERL" != "" ]; then
    if [ "$CUSTOM_PERL" = "" ]; then
        PERL_BIN=`which perl`
        PERL_VERSION=`perl -MConfig -le '$Config{version} =~ /(\d+.\d+)\./; print $1'`
    else
        PERL_BIN=$CUSTOM_PERL
        PERL_VERSION=`$CUSTOM_PERL -MConfig -le '$Config{version} =~ /(\d+.\d+)\./; print $1'`
    fi
    if [[ "$PERL_VERSION" =~ ^5\.[0-9]+$ ]]; then
        PERL_MINOR_VER=`echo "$PERL_VERSION" | sed 's/.*\.//g'`
    else
        echo "Failed to find supported Perl version for '$PERL_BIN'"
        exit
    fi
fi

# We have found Perl, so get system arch, according to Perl
RAW_ARCH=`$PERL_BIN -MConfig -le 'print $Config{archname}'`
# Strip out extra -gnu on Linux for use within this build script
ARCH=`echo $RAW_ARCH | sed 's/gnu-//' | sed 's/^i[3456]86-/i386-/' | sed 's/armv.*?-/arm-/' `

echo "Building for $OS / $ARCH"
echo "Building with Perl 5.$PERL_MINOR_VER at $PERL_BIN"

# Build dirs
BUILD=$PWD/build

# Perform necessary customizations per OS.
case "$OS" in
    FreeBSD)
       # This script uses the following precedence for FreeBSD:
       # 1. Environment values for CC/CXX/CPP (checks if $CC is already defined)
       # 2. Values defined in /etc/make.conf, or
       # 3. Stock build chain
        BSD_MAJOR_VER=`uname -r | sed 's/\..*//g'`
        BSD_MINOR_VER=`uname -r | sed 's/.*\.//g'`
        if [ -f "/etc/make.conf" ]; then
            MAKE_CC=`grep ^CC= /etc/make.conf | grep -v CCACHE | grep -v \# | sed 's#CC=##g'`
            MAKE_CXX=`grep ^CXX= /etc/make.conf | grep -v CCACHE | grep -v \# | sed 's#CXX=##g'`
            MAKE_CPP=`grep ^CPP= /etc/make.conf | grep -v CCACHE | grep -v \# | sed 's#CPP=##g'`
        fi
        if [[ ! -z "$CC" ]]; then
            GCC="$CC"
        elif [[ ! -z "$MAKE_CC" ]]; then
            GCC="$MAKE_CC"
        elif [ $BSD_MAJOR_VER -ge 10 ]; then
            # FreeBSD started using clang as the default compiler starting with 10.
            GCC=cc
        else
            GCC=gcc
        fi
        if [[ ! -z "$CXX" ]]; then
            GXX="$CXX"
        elif [[ ! -z "$MAKE_CXX" ]]; then
            GXX="$MAKE_CXX"
        elif [ $BSD_MAJOR_VER -ge 10 ]; then
            # FreeBSD started using clang++ as the default compiler starting with 10.
            GXX=c++
        else
            GXX=g++
        fi
        if [[ ! -z "$CPP" ]]; then
            GPP="$CPP"
        elif [[ ! -z "$MAKE_CPP" ]]; then
            GPP="$MAKE_CPP"
        else
            GPP=cpp
        fi
        # Ensure the environment makes use of the desired/specified compilers and
        # pre-processor
        export CC=$GCC
        export CXX=$GXX
        export CPP=$GPP

        if [ ! -x /usr/local/bin/gmake ]; then
            echo "ERROR: Please install GNU make (gmake)"
            exit
        fi
        MAKE_BIN=/usr/local/bin/gmake
        PERL_MAKE=$MAKE_BIN

    for i in libz ; do
            #On FreeBSD flag -r should be used, there is no -p
            if ! ( /sbin/ldconfig -r | grep -q "${i}.so" ) ; then
                echo "$i not found - please install it"
            exit 1
        fi
    done
    for hdr in "zlib.h"; do
        if [ -z "$(find /usr/include/ -name ${hdr} -print)" ]; then
            echo "$hdr not found - please install appropriate development package"
            exit 1
        fi
    done
    ;;
    SunOS)
        if [ ! -x /usr/bin/gmake ]; then
            echo "ERROR: Please install GNU make (gmake)"
            exit
        fi
        MAKE_BIN=/usr/bin/gmake
        PERL_MAKE=$MAKE_BIN
        # On Solaris, both i386 and x64 version of Perl exist.
        # If it is i386, and Perl uses 64 bit integers, then an additional flag is needed.
        if [[ "$ARCH" =~ ^.*-64int$ ]]; then
            CFLAGS_COMMON="-m32 $CFLAGS_COMMON"
            CXXFLAGS_COMMON="-m32 $CXXFLAGS_COMMON"
            LDFLAGS_COMMON="-m32 $LDFLAGS_COMMON"
        elif [[ "$ARCH" =~ ^.*-64$ ]]; then
            CFLAGS_COMMON="-m64 $CFLAGS_COMMON"
            CXXFLAGS_COMMON="-m64 $CXXFLAGS_COMMON"
            LDFLAGS_COMMON="-m64 $LDFLAGS_COMMON"
        fi
    ;;
    Linux)
        for i in libz ; do
            if ! /sbin/ldconfig -p | grep -q "${i}.so" ; then
                echo "$i not found - please install it"
            exit 1
        fi
    done
    for hdr in "zlib.h"; do
        if [ -z "$(find /usr/include/ -name ${hdr} -print)" ]; then
            echo "$hdr not found - please install appropriate development package"
            exit 1
        fi
    done
    ;;
    Darwin)
        # figure out macOS version and customize SDK options (do not care about patch ver)
        MACOS_VER_STR=`/usr/bin/sw_vers -productVersion |  sed "s#\ *)\ *##g" | sed 's/\.[0-9]*$//g'`

        # This transforms the OS ver into a 4 digit number with leading zeros for the
        # Darwin version, e.g., 10.6 --> 1006, 10.12 --> 1012.
        MACOS_VER=`echo "$MACOS_VER_STR" | sed -e 's/\.\([0-9][0-9]\)/\1/g' -e 's/\.\([0-9]\)/0\1/g' -e 's/^[0-9]\{3\}$/&00/'`

        if [ "$MACOS_VER" -eq 1005 ]; then
            # Leopard, build for i386/ppc with support back to 10.4
            MACOS_ARCH="-arch i386 -arch ppc"
            MACOS_FLAGS="-isysroot /Developer/SDKs/MacOSX10.4u.sdk -mmacosx-version-min=10.4"
        elif [ "$MACOS_VER" -eq 1006 ]; then
            # Snow Leopard, build for x86_64/i386 with support back to 10.5
            MACOS_ARCH="-arch x86_64 -arch i386"
            MACOS_FLAGS="-isysroot /Developer/SDKs/MacOSX10.5.sdk -mmacosx-version-min=10.5"
        elif [ "$MACOS_VER" -eq 1007 ]; then
            # Lion, build for x86_64 with support back to 10.6
            MACOS_ARCH="-arch x86_64"
            MACOS_FLAGS="-isysroot /Developer/SDKs/MacOSX10.6.sdk -mmacosx-version-min=10.6"
        elif [ "$MACOS_VER" -ge 1009 ]; then
            MACOS_ARCH="-arch x86_64"
            MACOS_FLAGS="-mmacosx-version-min=10.9"
        else
            echo "Unsupported Mac OS version."
            exit 1
        fi
        CFLAGS_COMMON="$CFLAGS_COMMON $MACOS_ARCH $MACOS_FLAGS"
        CXXFLAGS_COMMON="$CXXFLAGS_COMMON $MACOS_ARCH $MACOS_FLAGS"
        LDFLAGS_COMMON="$LDFLAGS_COMMON $MACOS_ARCH $MACOS_FLAGS"
    ;;
    MINGW*)
        # Since we might build the i686 version using msys64, we might 
        BUILD=$BUILD/$MINGW_CHOST

        # Only keep the part we care about, to avoid using globs for OS matches
        OS=MINGW
        # Figure out if we're using ActiveState Perl (which requires dmake)

        if ( $PERL_BIN -v | grep -q "ActiveState" ) ; then
            # We'll need to make sure we have dmake, since ActiveState requires it
            if [ -z "$(pacman -Qi $MINGW_PACKAGE_PREFIX-dmake )" ] ; then
                echo "ActiveState Perl requires ${MINGW_PACKAGE_PREFIX}-dmake - please install it"
                exit 1
            fi
            USE_DMAKE=1
        fi

        # Check to see we have all our generic pre-requisites installed
        for i in gettext-devel patch pkg-config rsync ; do
            if [ -z "$(pacman -Qi ${i} )" ]; then
                echo "$i not found - please install it"
                exit 1
            fi
        done
        # Check to see we have all our arch specific build pre-requisites installed
        for i in make gcc SDL2 nasm gettext libtool dlfcn diffutils ; do
            PAC_NAME="${MINGW_PACKAGE_PREFIX}-${i}"
            if [ -z "$( pacman -Qi ${PAC_NAME} )" ]; then
                echo "$PAC_NAME not found - please install it"
                exit 1
            fi
        done
        MAKE_BIN=mingw32-make
        # MinGW's gcc libs are in a directory named the gcc numeric version, which
        # is extremely likely to change. Thus, this deep magic asks the compiler
        # where its libgcc file is, then later passes that directory the Makefile.PL
        # so Perl can find the necessary libs.
        GCC_DIR=$(dirname -- `gcc --print-libgcc-file-name`)

        CFLAGS_COMMON="-DUNICODE -D_UNICODE -DWIN32 -Wall -fPIC -I${MSYSTEM_PREFIX}/include -I${MSYSTEM_PREFIX}/${MINGW_CHOST}/include -I/usr/include "
        CXXFLAGS_COMMON="-DUNICODE -D_UNICODE -DWIN32 -Wall -fPIC -I${MSYSTEM_PREFIX}/include -I${MSYSTEM_PREFIX}/${MINGW_CHOST}/include -I/usr/include"
        LDFLAGS_COMMON="-DWIN32 -Wall -fPIC -L${MSYSTEM_PREFIX}/lib -L${MSYSTEM_PREFIX}/${MINGW_CHOST}/lib -L/usr/lib"

        # Figure out if we're using MinGW32 or MinGW64
        if [[ "$MSYSTEM" == "MINGW64" ]] ; then
            CFLAGS_COMMON="-DWIN64 ${CFLAGS_COMMON}"
            CXXFLAGS_COMMON="-DWIN64 ${CXXFLAGS_COMMON}"
            LDFLAGS_COMMON="-DWIN64 ${LDFLAGS_COMMON}"
        fi

        # Check if we're going to be building all the prereq's
        if [[ $ALL_DEPS == 0 ]] ; then
            # Check for the stock prereq's
            for i in libexif libpng giflib libjpeg-turbo; do
                PAC_NAME="${MINGW_PACKAGE_PREFIX}-${i}"
                if [ -z "$( pacman -Qi ${PAC_NAME} )" ]; then
                    echo "$PAC_NAME not found - please install it"
                    exit 1
                fi
            done
        fi

    ;;
esac

# Export the OS specific values
PERL_BASE=$BUILD/5.$PERL_MINOR_VER
PERL_ARCH=$BUILD/arch/5.$PERL_MINOR_VER
export MAKE=$MAKE_BIN
export CFLAGS_COMMON=$CFLAGS_COMMON
export CXXFLAGS_COMMON=$CXXFLAGS_COMMON
export LDFLAGS_COMMON=$LDFLAGS_COMMON

# Check for other pre-requisites
for i in $GCC $GXX $MAKE nasm rsync cmake ; do
    if ! [ -x "$(command -v $i)" ] ; then
        echo "$i not found - please install it"
        exit 1
    fi
done

if [ -n "$(find /usr/lib/ -maxdepth 1 -name '*libungif*' -print)" ] ; then
    echo "ON SOME PLATFORMS (Ubuntu/Debian at least) THE ABOVE LIBRARIES MAY NEED TO BE TEMPORARILY REMOVED TO ALLOW THE BUILD TO WORK"
fi

echo "Looks like your compiler is $GCC"
$GCC --version

# This method works for FreeBSD, with "normal" installs of GCC and clang.
CC_TYPE=`$GCC --version | head -1`

# Determine compiler type and version
CC_IS_CLANG=false
CC_IS_GCC=false
# Heavy wizardry begins here
# This uses bash globbing for the If statement
if [[ "$CC_TYPE" =~ ^.*clang.*$ ]]; then
    CLANG_MAJOR=`echo "#include <stdio.h>" | "$GCC" -xc -dM -E - | grep '#define __clang_major' | sed 's/.*__\ //g'`
    CLANG_MINOR=`echo "#include <stdio.h>" | "$GCC" -xc -dM -E - | grep '#define __clang_minor' | sed 's/.*__\ //g'`
    CLANG_PATCH=`echo "#include <stdio.h>" | "$GCC" -xc -dM -E - | grep '#define __clang_patchlevel' | sed 's/.*__\ //g'`
    CC_VERSION=`echo "$CLANG_MAJOR"."$CLANG_MINOR"."$CLANG_PATCH" | sed "s#\ *)\ *##g" | sed -e 's/\.\([0-9][0-9]\)/\1/g' -e 's/\.\([0-9]\)/0\1/g' -e 's/^[0-9]\{3,4\}$/&00/'`
    CC_IS_CLANG=true
elif [[ "$CC_TYPE" =~ ^.*gcc.*$ || "$CC_TYPE" =~ ^.*GCC.*$ ]]; then
    CC_IS_GCC=true
    CC_VERSION=`$GCC -dumpfullversion -dumpversion | sed "s#\ *)\ *##g" | sed -e 's/\.\([0-9][0-9]\)/\1/g' -e 's/\.\([0-9]\)/0\1/g' -e 's/^[0-9]\{3,4\}$/&00/'`
else
    echo "********************************************** ERROR ***************************************"
    echo "*"
    echo "*    You're not using GCC or clang. Somebody's playing a prank on me."
    echo "*    Cowardly choosing to abandon build."
    echo "*"
    echo "********************************************************************************************"
    exit 1
fi

if [[ "$CC_IS_GCC" == true && "$CC_VERSION" -lt 40200 ]]; then
    echo "********************************************** ERROR ****************************************"
    echo "*"
    echo "*    It looks like you're using GCC earlier than 4.2,"
    echo "*    Cowardly choosing to abandon build."
    echo "*    This is because modern ICU requires -std=c99"
    echo "*"
    echo "********************************************************************************************"
    exit 1
fi

if [[ "$CC_IS_CLANG" == true && "$CC_VERSION" -lt 30000 ]]; then
    echo "********************************************** ERROR ****************************************"
    echo "*"
    echo "*    It looks like you're using clang earlier than 3.0,"
    echo "*    Cowardly choosing to abandon build."
    echo "*    This is because modern ICU requires -std=c99"
    echo "*"
    echo "********************************************************************************************"
    exit 1
fi

if [[ ! -z `echo "#include <iostream>" | "$GXX" -xc++ -dM -E - | grep LIBCPP_VERSION` ]]; then
    GCC_LIBCPP=true
elif [[ ! -z `echo "#include <iostream>" | "$GXX" -xc++ -dM -E - | grep __GLIBCXX__` ]]; then
    GCC_LIBCPP=false
else
    echo "********************************************** NOTICE **************************************"
    echo "*"
    echo "*    Doesn't seem you're using libc++ or lc++ as your c++ library."
    echo "*    I will assume you're using the GCC stack, and that DBD needs -lstdc++."
    echo "*"
    echo "********************************************************************************************"
    GCC_LIBCPP=false
fi

#  Clean up
if [ $CLEAN -eq 1 ]; then
    rm -rf $BUILD/arch
fi

mkdir -p $PERL_ARCH

# $1 = args
# $2 = file
function tar_wrapper {
    echo "tar $1 $2"
    tar $1 "$2"
    echo "tar done"
}

function build_all {
    build Media::Scan
}

function build {
    case "$1" in
        Media::Scan)
            build_ffmpeg
            build_libexif
            build_libjpeg
            build_libpng
            build_giflib
            build_bdb
            cd ..

            # build libmediascan
            # Early macOS versions did not link library correctly libjpeg due to
            # missing x86_64 in libjpeg.dylib, Perl linked OK because it used libjpeg.a
            # Correct linking confirmed with macOS 10.10 and up.
            if [ $CLEAN != 0 ]; then
                $MAKE clean
            fi
            CFLAGS="-I$BUILD/include $CFLAGS_COMMON -O3" \
            LDFLAGS="-L$BUILD/lib $LDFLAGS_COMMON -O3" \
            OBJCFLAGS="-L$BUILD/lib $CFLAGS_COMMON -O3" \
            PKG_CONFIG="pkg-config --static" \
            PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$BUILD/lib/pkgconfig:$MINGW_PREFIX/lib/pkgconfig" \
                ./configure --prefix=$BUILD --with-bdb=$BUILD --disable-shared --disable-dependency-tracking
            $MAKE
            if [ $? != 0 ]; then
                echo "make failed"
                exit $?
            fi
            $MAKE install

            # build Media::Scan
            cd bindings/perl

            # LMS will re-use the lms-include location for all other libs/headers
            MSOPTS="--with-static --with-lms-includes=$BUILD/include"

            # MinGW's libgcc and libstdc++ aren't with the other libs - need to explicitly pass it
            if [[ "$OS" == "MINGW" ]]; then
                MSOPTS="$MSOPTS --with-CC-lib-path=$GCC_DIR"
            fi

            # If we're using ActiveState Perl, then we need to use dmake instead
            if [[ "$OS" == "MINGW" && $USE_DMAKE == 1 ]]; then
                PERL_MAKE=dmake
            else
                PERL_MAKE=$MAKE
            fi

            MSOPTS="${MSOPTS} --use-make=${PERL_MAKE}"

            # FreeBSD and macOS don't have GNU gettext in the base. This only prevents exif logging.
            if [[ "$OS" == "FreeBSD" || "$OS" == "Darwin" ]]; then
                MSOPTS="${MSOPTS} --omit-intl"
            fi

            if [ $PERL_BIN ]; then
                export PERL5LIB=$PERL_BASE/lib/perl5
                $PERL_BIN Makefile.PL $MSOPTS INSTALL_BASE=$PERL_BASE
                $PERL_MAKE
                if [ $? != 0 ]; then
                    echo "make failed, aborting"
                    exit $?
                fi
                # XXX hack until regular test works
                $PERL_BIN -Iblib/lib -Iblib/arch t/01use.t
                if [ $? != 0 ]; then
                    echo "make test failed, aborting"
                    exit $?
                fi
                $PERL_MAKE install
                if [ $CLEAN -eq 1 ]; then
                    $PERL_MAKE clean
                fi
            fi

            cd ../../..
            ;;
    esac
}

function build_libexif {
    if [[ "$OS" == "MINGW" && $ALL_DEPS == 0 ]]; then
        return
    fi

    # build libexif
    cd /tmp
    git clone --depth 1 https://github.com/libexif/libexif.git
    cd libexif
    autoreconf -i

    CFLAGS="$CFLAGS_COMMON -O3" \
    LDFLAGS="$LDFLAGS_COMMON -O3" \
        ./configure $QUIET_FLAG --prefix=$BUILD \
        --disable-dependency-tracking --enable-static --disable-shared
    $MAKE -j $NUM_MAKE_JOBS
    if [ $? != 0 ]; then
        echo "make failed"
        exit $?
    fi
    $MAKE install

    cd ..
    rm -rf libexif
    cd $BUILD/../
}

function build_libjpeg {
    if [[ ( "$OS" == "MINGW" && $ALL_DEPS == 0 ) ]]; then
        return
    fi

    cd /tmp
    git clone --depth 1 https://github.com/libjpeg-turbo/libjpeg-turbo.git


    # build libjpeg-turbo on x86 platforms
    if [ "$OS" = "Darwin" ]; then
        cd libjpeg-turbo
        # Disable features we don't need
        patch -p0 < $BUILD/../libjpeg-turbo-jmorecfg.h.patch

        CMAKE_OSX_ARCH=""
        if [ "$MACOS_VER" -gt 1006 ]; then
            # Build x86_64 versions of turbo - 64 bit OS was introduced in 10.6
            CMAKE_OSX_ARCH="x86_64"
        elif [ "$MACOS_VER" -eq 1006 ]; then
            CMAKE_OSX_ARCH="i386;x86_64"
        elif [ "$MACOS_VER" -eq 1005 ]; then
            # We only need to build the ppc binaries for for macOS 10.5.
            CMAKE_OSX_ARCH="ppc;i386"
        fi

        mkdir _build
        cd _build
        # Build it!
        CFLAGS="-O3 $MACOS_FLAGS" \
        CXXFLAGS="-O3 $MACOS_FLAGS" \
        LDFLAGS="$MACOS_FLAGS" \
        cmake -G"Unix Makefiles" -DCMAKE_OSX_ARCHITECTURES=$CMAKE_OSX_ARCH -DCMAKE_INSTALL_PREFIX=$BUILD -DENABLE_SHARED=0 -DWITH_TURBOJPEG=0 /tmp/libjpeg-turbo
        $MAKE -j $NUM_MAKE_JOBS
        if [ $? != 0 ]; then
            echo "macOS make failed"
            exit $?
        fi
        $MAKE install
        cd $BUILD/..

    elif [[ "$ARCH" =~ ^(i86pc-solaris).*$ || "$OS" == "Linux" || "$OS" == "FreeBSD" ]]; then
        cd libjpeg-turbo
        # Disable features we don't need
        patch -p0 < $BUILD/../libjpeg-turbo-jmorecfg.h.patch
        # build libjpeg-turbo
        mkdir _build
        cd _build

        # Early clang has problems with AltiVec on powerpc when using cmake, so disable SIMD optimizations
        JPEG_SIMD_FLAG=1
        if [[ "$CC_IS_CLANG" == true && "$CC_VERSION" -lt 50000 && "$ARCH" =~ ^(powerpc64le-linux).*$ ]]; then
            JPEG_SIMD_FLAG=0
        fi


        CFLAGS="$CFLAGS_COMMON" CXXFLAGS="$CXXFLAGS_COMMON" LDFLAGS="$LDFLAGS_COMMON" \
        cmake -G"Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$BUILD -DENABLE_SHARED=0 -DWITH_TURBOJPEG=0 -DWITH_SIMD=$JPEG_SIMD_FLAG /tmp/libjpeg-turbo
        echo Makefile
        $MAKE -j $NUM_MAKE_JOBS
        if [ $? != 0 ]; then
            echo "make failed"
            exit $?
        fi

        $MAKE install
        cd $BUILD/..

    # build libjpeg v8 on other platforms
    # Not sure what we mean by "other platforms" here.
    else
        cd $BUILD/..
        tar_wrapper zxf jpegsrc.v8b.tar.gz
        cd jpeg-8b
        . ../update-config.sh
        # Disable features we don't need
        cp -fv ../libjpeg-jmorecfg.h jmorecfg.h

        CFLAGS="$CFLAGS_COMMON -O3" \
        LDFLAGS="$LDFLAGS_COMMON -O3" \
            ./configure $QUIET_FLAG --prefix=$BUILD \
            --disable-dependency-tracking
        $MAKE -j $NUM_MAKE_JOBS
        if [ $? != 0 ]; then
            echo "make failed"
            exit $?
        fi
        $MAKE install
        cd ..
    fi

    rm -rf jpeg-8b
    rm -rf /tmp/libjpeg-turbo
}

function build_libpng {
    if [[ ( "$OS" == "MINGW" && $ALL_DEPS == 0 ) ]]; then
        return
    fi

    # Fetch the sources
    git clone --depth 1 https://git.code.sf.net/p/libpng/code /tmp/libpng-code

    # Disable features we don't need

    # build libpng
    mkdir /tmp/libpng-code/_build
    cd /tmp/libpng-code/_build

    # Early clang has problems with AltiVec on powerpc, so disable HW optimizations
    PNG_OPTM_FLAG="ON"
    if [[ "$CC_IS_CLANG" == true && "$CC_VERSION" -lt 50000 && "$ARCH" =~ ^(powerpc64le-linux).*$ ]]; then
        PNG_OPTM_FLAG="OFF"
    fi


    CFLAGS="$CFLAGS_COMMON -O3" \
    CPPFLAGS="$CFLAGS_COMMON -O3" \
    LDFLAGS="$LDFLAGS_COMMON -O3" \
    cmake -G"Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$BUILD -DPNG_SHARED=0 -DPNG_HARDWARE_OPTIMIZATIONS=$PNG_OPTM_FLAG -DDFA_XTRA=$BUILD/../libpng-pngusr.dfa /tmp/libpng-code
    $MAKE -j $NUM_MAKE_JOBS
    if [ $? != 0 ]; then
        echo "make failed"
        exit $?
    fi
    $MAKE install
    cd $BUILD/..

    rm -rf /tmp/libpng-code
}

function build_giflib {
    if [[ "$OS" == "MINGW" && $ALL_DEPS == 0 ]]; then
        return
    fi

    if [[ -f $BUILD/include/gif_lib.h ]]; then
        # Determine the version of the last-built giflib
        GIF_MAJOR=`grep 'GIFLIB_MAJOR' $BUILD/include/gif_lib.h | sed 's/.*_MAJOR\ //g'`
        if [ ! -z $GIF_MAJOR ]; then
            GIF_MINOR=`grep 'GIFLIB_MINOR' $BUILD/include/gif_lib.h | sed 's/.*_MINOR\ //g'`
            GIF_RELEASE=`grep 'GIFLIB_RELEASE' $BUILD/include/gif_lib.h | sed 's/.*_RELEASE\ //g'`
            GIF_VERSION=`echo "$GIF_MAJOR"."$GIF_MINOR"."$GIF_RELEASE" | sed "s#\ *)\ *##g" | \
                        sed -e 's/\.\([0-9][0-9]\)/\1/g' -e 's/\.\([0-9]\)/0\1/g' -e 's/^[0-9]\{3,4\}$/&00/'`
            # Only skip the build if it's using the right version
            if [ $GIF_VERSION -ge 50104 ]; then
                return
            fi
        fi
    fi

    # build giflib
    git clone --depth 1 https://git.code.sf.net/p/giflib/code /tmp/giflib-code
    cd /tmp/giflib-code

    # Upstream has stripped out the previous autotools-based build system and their
    # Makefile doesn't work on macOS. See https://sourceforge.net/p/giflib/bugs/133/
    patch -p0 < $BUILD/../giflib-Makefile.patch

    # GIFLIB maintainer abandoned automake tools, and hardcoded the prefix /usr/local
    sed -i.old "s#^PREFIX.*#PREFIX\ =\ $BUILD#g" Makefile
    # We need to omit some lines from the install-lib rule, because libgif.so isn't built
    sed -i.old '135,137d' Makefile

    CC=$GCC \
    CFLAGS="$CFLAGS_COMMON -O3" \
    LDFLAGS="$LDFLAGS_COMMON -O3" \
    $MAKE -j $NUM_MAKE_JOBS libgif.a

    if [ $? != 0 ]; then
        echo "make failed"
        exit $?
    fi
    $MAKE install-lib
    $MAKE install-include
    cd $BUILD/..

    rm -rf /tmp/giflib-code
}

function build_ffmpeg {

    # build ffmpeg, enabling only the things libmediascan uses
    echo "build ffmpeg"
    git clone --depth 1 https://github.com/FFmpeg/FFmpeg.git /tmp/ffmpeg
    cd /tmp/ffmpeg

    echo "Configuring FFmpeg..."

    # x86: Disable all but the lowend MMX ASM
    # ARM: Disable all
    # PPC: Disable AltiVec
    FFOPTS="--prefix=$BUILD --disable-ffmpeg --disable-ffplay --disable-ffprobe \
        --disable-avdevice --enable-pic \
        --disable-amd3dnow --disable-amd3dnowext --disable-avx \
        --disable-armv5te --disable-armv6 --disable-armv6t2 --disable-mmi --disable-neon \
        --disable-altivec \
        --enable-zlib --disable-bzlib \
        --disable-everything --disable-iconv --enable-swscale \
        --enable-decoder=h264 --enable-decoder=mpeg1video --enable-decoder=mpeg2video \
        --enable-decoder=mpeg4 --enable-decoder=msmpeg4v1 --enable-decoder=msmpeg4v2 \
        --enable-decoder=msmpeg4v3 --enable-decoder=vp6f --enable-decoder=vp8 \
        --enable-decoder=wmv1 --enable-decoder=wmv2 --enable-decoder=wmv3 --enable-decoder=rawvideo \
        --enable-decoder=mjpeg --enable-decoder=mjpegb --enable-decoder=vc1 \
        --enable-decoder=aac --enable-decoder=ac3 --enable-decoder=dca --enable-decoder=mp3 \
        --enable-decoder=mp2 --enable-decoder=vorbis --enable-decoder=wmapro --enable-decoder=wmav1 --enable-decoder=flv \
        --enable-decoder=wmav2 --enable-decoder=wmavoice \
        --enable-decoder=pcm_dvd --enable-decoder=pcm_s16be --enable-decoder=pcm_s16le \
        --enable-decoder=pcm_s24be --enable-decoder=pcm_s24le \
        --enable-decoder=ass --enable-decoder=dvbsub --enable-decoder=dvdsub --enable-decoder=pgssub --enable-decoder=xsub \
        --enable-parser=aac --enable-parser=ac3 --enable-parser=dca --enable-parser=h264 --enable-parser=mjpeg \
        --enable-parser=mpeg4video --enable-parser=mpegaudio --enable-parser=mpegvideo --enable-parser=vc1 \
        --enable-demuxer=asf --enable-demuxer=avi --enable-demuxer=flv --enable-demuxer=h264 \
        --enable-demuxer=matroska --enable-demuxer=mov --enable-demuxer=mpegps --enable-demuxer=mpegts --enable-demuxer=mpegvideo \
        --enable-protocol=file --cc=$GCC --cxx=$GXX \
        --enable-static --disable-shared --disable-programs --disable-doc $QUIET_FLAG"

    if [ "$MACHINE" = "padre" ]; then
        FFOPTS="${FFOPTS} --arch=sparc"
    fi

    # ASM doesn't work right on x86_64
    # XXX test --arch options on Linux
    if [[ "$ARCH" =~ ^(amd64-freebsd|x86_64-linux|i86pc-solaris).*$ ]]; then
        FFOPTS="${FFOPTS} --disable-mmx"
    fi

    # FreeBSD amd64 needs arch option
    if [[ "$ARCH" =~ ^amd64-freebsd.*$ ]]; then
        FFOPTS="${FFOPTS} --arch=x86"
        # FFMPEG has known issues with GCC 4.2. See: https://trac.ffmpeg.org/ticket/3970
        if [[ "$CC_IS_GCC" == true && "$CC_VERSION" -ge 40200 && "$CC_VERSION" -lt 40300 ]]; then
            FFOPTS="${FFOPTS} --disable-asm"
        fi
    fi

    # SunOS and Illumos have problems compiling libmediascan with ASM. So disable it for ffmpeg.
    if [ "$OS" = "SunOS" ]; then
        FFOPTS="${FFOPTS} --disable-asm"
    fi

    # MinGW needs some extra flags set
    if [[ "$OS" == "MINGW" ]]; then
        # The FFMpeg configure script redefines mingw64 as mingw32, so just make it mingw32
        FFOPTS="${FFOPTS} --target-os=mingw32 --arch=${MSYSTEM_CARCH%%-*}"
    fi

    if [ "$OS" = "Darwin" ]; then
        # Build 64-bit fork
        if [ "$MACOS_VER" -ge 1006 ]; then
            # Build x86_64 versions of turbo - 64 bit OS was introduced in 10.6
            CFLAGS="-arch x86_64 -O3 -fPIC $MACOS_FLAGS" \
            LDFLAGS="-arch x86_64 -O3 -fPIC $MACOS_FLAGS" \
                ./configure $FFOPTS --arch=x86_64

            $MAKE -j $NUM_MAKE_JOBS
            if [ $? != 0 ]; then
                echo "64-bit ffmpeg make failed"
                exit $?
            fi

            if [ "$MACOS_VER" -eq 1006 ]; then
                # Prep for fork merging - 10.6 requires universal i386/x64 binaries
                cp -fv libavcodec/libavcodec.a libavcodec-x86_64.a
                cp -fv libavformat/libavformat.a libavformat-x86_64.a
                cp -fv libavutil/libavutil.a libavutil-x86_64.a
                cp -fv libswscale/libswscale.a libswscale-x86_64.a
            else
                cp -fv libavcodec/libavcodec.a libavcodec.a
                cp -fv libavformat/libavformat.a libavformat.a
                cp -fv libavutil/libavutil.a libavutil.a
                cp -fv libswscale/libswscale.a libswscale.a
            fi
        fi

        # Build 32-bit fork (all macOS versions less than 10.7)
        # All versions since 10.7 are 64-bit only
        if [ "$MACOS_VER" -lt 1007 ]; then
            $MAKE clean
            CFLAGS="-arch i386 -O3 $MACOS_FLAGS" \
            LDFLAGS="-arch i386 -O3 $MACOS_FLAGS" \
                ./configure $FFOPTS --arch=x86_32

            $MAKE -j $NUM_MAKE_JOBS
            if [ $? != 0 ]; then
                echo "32-bit ffmpeg make failed"
                exit $?
            fi

            cp -fv libavcodec/libavcodec.a libavcodec-i386.a
            cp -fv libavformat/libavformat.a libavformat-i386.a
            cp -fv libavutil/libavutil.a libavutil-i386.a
            cp -fv libswscale/libswscale.a libswscale-i386.a
        fi

        # We only need to build the ppc fork for macOS 10.5
        if [ "$MACOS_VER" -eq 1005 ]; then
            $MAKE clean
            CFLAGS="-arch ppc -O3 $MACOS_FLAGS" \
            LDFLAGS="-arch ppc -O3 $MACOS_FLAGS" \
                ./configure $FFOPTS --arch=ppc --disable-altivec

            $MAKE -j $NUM_MAKE_JOBS
            if [ $? != 0 ]; then
                echo "ppc ffmpeg make failed"
                exit $?
            fi

            cp -fv libavcodec/libavcodec.a libavcodec-ppc.a
            cp -fv libavformat/libavformat.a libavformat-ppc.a
            cp -fv libavutil/libavutil.a libavutil-ppc.a
            cp -fv libswscale/libswscale.a libswscale-ppc.a
        fi

        # Combine the forks (if necessary). macOS 10.7 and onwards do not need
        # universal binaries.
        if [ "$MACOS_VER" -eq 1005 ]; then
            lipo -create libavcodec-i386.a libavcodec-ppc.a -output libavcodec.a
            lipo -create libavformat-i386.a libavformat-ppc.a -output libavformat.a
            lipo -create libavutil-i386.a libavutil-ppc.a -output libavutil.a
            lipo -create libswscale-i386.a libswscale-ppc.a -output libswscale.a
        elif [ "$MACOS_VER" -lt 1007 ]; then
            lipo -create libavcodec-x86_64.a libavcodec-i386.a -output libavcodec.a
            lipo -create libavformat-x86_64.a libavformat-i386.a -output libavformat.a
            lipo -create libavutil-x86_64.a libavutil-i386.a -output libavutil.a
            lipo -create libswscale-x86_64.a libswscale-i386.a -output libswscale.a
        fi

        # Install and replace libs with versions we built
        $MAKE install
        cp -f libavcodec.a $BUILD/lib/libavcodec.a
        cp -f libavformat.a $BUILD/lib/libavformat.a
        cp -f libavutil.a $BUILD/lib/libavutil.a
        cp -f libswscale.a $BUILD/lib/libswscale.a

    else
        CFLAGS="$CFLAGS_COMMON -O3" \
        LDFLAGS="$LDFLAGS_COMMON -O3" \
            ./configure $FFOPTS

        $MAKE -j $NUM_MAKE_JOBS
        if [ $? != 0 ]; then
            echo "make failed"
            exit $?
        fi
        $MAKE install
    fi
    # Starting with 4.1, we copy the release to ease last-built version detection

    cd $BUILD/..
    rm -rf /tmp/ffmpeg
}

function build_bdb {

    # --enable-posixmutexes is needed to build on ReadyNAS Sparc.
    MUTEX=""
    if [ "$MACHINE" = "padre" ]; then
      MUTEX="--enable-posixmutexes"
    fi

    MINGW_FLAGS=""
    # TARGET flags are necessary so we can manage MinGW
    if [[ "$OS" == "MINGW" ]]; then
        MINGW_FLAGS="--enable-mingw --build=${MINGW_CHOST} --host=${MINGW_CHOST} --target=${MINGW_CHOST}"
    fi

    # build bdb
    DB_PREFIX="db-6.2.38"
    tar_wrapper zxf $DB_PREFIX.tar.gz
    cd $DB_PREFIX/dist
    #. ../../update-config.sh
    cd ../build_unix

    CFLAGS="$CFLAGS_COMMON -O3" \
    LDFLAGS="$CFLAGS_COMMON -O3 " \
        ../dist/configure $QUIET_FLAG --prefix=$BUILD $MUTEX $MINGW_FLAGS \
        --with-cryptography=no -disable-hash --disable-queue --disable-replication --disable-statistics --disable-verify \
        --disable-dependency-tracking --disable-shared --enable-static --enable-smallbuild
    $MAKE -j $NUM_MAKE_JOBS
    if [ $? != 0 ]; then
        echo "make failed"
        exit $?
    fi
    $MAKE install_include install_lib
    cd ../..

    rm -rf $DB_PREFIX
}

# Build a single module if requested, or all
if [ $1 ]; then
    echo "building only $1"
    build $1
else
    build_all
fi

# Reset PERL5LIB
export PERL5LIB=

if [ "$OS" = 'Darwin' ]; then
    # strip -S on all bundle files
    find $BUILD -name '*.bundle' -exec chmod u+w {} \;
    find $BUILD -name '*.bundle' -exec strip -S {} \;
elif [ "$OS" = 'Linux' -o "$OS" = "FreeBSD" ]; then
    # strip all so files
    find $BUILD -name '*.so' -exec chmod u+w {} \;
    find $BUILD -name '*.so' -exec strip {} \;
fi

# clean out useless .bs/.packlist files, etc
find $BUILD -name '*.bs' -exec rm -f {} \;
find $BUILD -name '*.packlist' -exec rm -f {} \;

# create our directory structure
# rsync is used to avoid copying non-binary modules or other extra stuff
mkdir -p $PERL_ARCH/$ARCH
rsync -amv --include='*/' --include='*.so' --include='*.bundle' --include='autosplit.ix' --include='*.pm' --include='*.al' --exclude='*' $PERL_BASE/lib/perl5/$RAW_ARCH $PERL_ARCH/
rsync -amv --exclude=$RAW_ARCH --include='*/' --include='*.so' --include='*.bundle' --include='autosplit.ix' --include='*.pm' --include='*.al' --exclude='*' $PERL_BASE/lib/perl5/ $PERL_ARCH/$ARCH/

if [ $LMSBASEDIR ]; then
    if [ ! -d $LMSBASEDIR/CPAN/arch/5.$PERL_MINOR_VER/$ARCH ]; then
        mkdir -p $LMSBASEDIR/CPAN/arch/5.$PERL_MINOR_VER/$ARCH
    fi
    rsync -amv --include='*/' --include='*' $PERL_ARCH/$ARCH/ $LMSBASEDIR/CPAN/arch/5.$PERL_MINOR_VER/$ARCH/
fi

# could remove rest of build data, but let's leave it around in case
#rm -rf $PERL_BASE
#rm -rf $PERL_ARCH
#rm -rf $BUILD/bin $BUILD/etc $BUILD/include $BUILD/lib $BUILD/man $BUILD/share $BUILD/var
