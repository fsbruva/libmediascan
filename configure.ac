#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.69])
AC_INIT([libmediascan],[0.2])
AC_CANONICAL_TARGET
AC_CONFIG_AUX_DIR([.])
AM_INIT_AUTOMAKE([-Wall -Werror subdir-objects])
AM_PROG_AR([ar gar])
LT_PREREQ([2.4])
LT_INIT

AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_SRCDIR([src/mediascan.c])
AC_CONFIG_HEADERS([config.h])

# Checks for programs.
AC_PROG_CC([clang gcc])
AC_PROG_OBJC([gcc objcc objc])
AC_PROG_CXX
AC_PROG_AWK
AC_PROG_CPP
AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_MAKE_SET
AC_CHECK_PROG([have_pkgconfig], [pkg-config], [yes], [no])

# 64-bit file size support
AC_SYS_LARGEFILE

build_darwin=no
build_sun=no
build_linuxbsd=no
build_mingw=no

# Check BerkeleyDB lib and headers (stolen from memcachedb's configure.ac)
bdbdir="/usr/local"
AC_ARG_WITH(bdb,
       [  --with-bdb=PATH         Specify path to BerkeleyDB installation ],
       [
                if test "x$withval" != "xno" ; then
                        bdbdir=$withval
                fi
       ]
)
CFLAGS="-I$bdbdir/include $CFLAGS"

# Checks for libmediascan header files.
AC_CHECK_HEADERS([fcntl.h stdint.h stdlib.h string.h strings.h sys/param.h sys/time.h unistd.h pthread.h wchar.h])
AC_CHECK_HEADERS([db.h], [] ,[AC_MSG_ERROR(cannot find db.h in $bdbdir/include)],[AC_INCLUDES_DEFAULT])

# Checks for typedefs, structures, and compiler characteristics.
AC_C_INLINE
AC_TYPE_INT32_T
AC_TYPE_INT64_T
AC_TYPE_PID_T
AC_TYPE_SIZE_T
AC_TYPE_UINT16_T
AC_TYPE_UINT64_T

# Checks for library functions.
AC_FUNC_MALLOC
AC_FUNC_MMAP
AC_CHECK_FUNCS([gettimeofday memmove memset pow realpath select strcasecmp strchr strdup strerror strncasecmp strrchr strstr])

# Checks for library functions for unix
AC_CHECK_FUNCS([getcwd])

# Checks unique to linux builds
AC_TYPE_SSIZE_T
AC_CHECK_FUNCS([realpath])

# Checks that are unique for WIN32 builds
AC_CHECK_FUNCS([mblen strncasecmp])

# Checks for library functions needed for test.
AC_FUNC_FORK
AC_FUNC_REALLOC
AC_CHECK_FUNCS([regcomp])

#Checks that are isolated to the perl bindings.
AC_CHECK_HEADER_STDBOOL
AC_CHECK_HEADERS([limits.h locale.h])
AC_TYPE_UINT32_T
AC_TYPE_UINT8_T
AC_CHECK_FUNCS([localeconv socket])

case "$target_os" in
    *darwin*)
	build_darwin=yes
	LDFLAGS="-framework CoreFoundation -framework CoreServices -L$bdbdir/lib $LDFLAGS"
        AC_FUNC_LSTAT_FOLLOWS_SLASHED_SYMLINK

	;;
    *solaris*)
	build_sun=yes
	LDFLAGS="-L$bdbdir/lib $LDFLAGS"
	;;
    *linux*|*bsd*)
	build_linuxbsd=yes
	LDFLAGS="-L$bdbdir/lib $LDFLAGS"
	;;
    *msys*)
    AC_MSG_ERROR(Native MSYS builds not supported. Please see the documentation.)
    ;;
    *mingw*)
    # We must use pkg-config with mingw
    if test "x${have_pkgconfig}" = "xno"; then
        AC_MSG_ERROR(Builds on mingw require pkgconfig. Please see the documentation.)
    fi
    build_mingw=yes
    CPPFLAGS="-D__MSVCRT_VERSION__=0x0601 $CPPFLAGS"
    LDFLAGS="-L$bdbdir/lib $LDFLAGS -static-libstdc++ -static-libgcc"
    AC_CHECK_HEADERS([windows.h bcrypt.h],,,
        [[#if HAVE_WINDOWS_H
        # include <windows.h>
        #endif
        ]])
    ;;
esac

AM_CONDITIONAL([DARWIN], [test "$build_darwin" = "yes"])
AM_CONDITIONAL([SUN], [test "$build_sun" = "yes"])
AM_CONDITIONAL([LINUXBSD], [test "$build_linuxbsd" = "yes"])
AM_CONDITIONAL([MINGW], [test "$build_mingw" = "yes"])

# Checks for libraries.
# We should attempt to use pkg-config if we have it.
if test "x${have_pkgconfig}" = "xyes"; then
    # Use pkg-config when available, but fall back to old way, just in case.
    PKG_PROG_PKG_CONFIG()
    PKG_CHECK_MODULES([pthread], [pthread], LIBS="$LIBS $pthhread_LIBS",
        [AC_SEARCH_LIBS([pthread_create], [pthread])
    ])
    PKG_CHECK_MODULES([zlib], [zlib], LIBS="$LIBS $zlib_LIBS",
        [AC_SEARCH_LIBS([zlibVersion], [z],,
            [AC_MSG_ERROR(unable to find libz)])
    ])
    # If bz2 is present, we should use it, because we assume FFmpeg did.
    # However, it should not kill the build.
    PKG_CHECK_MODULES([bzip2], [bzip2], LIBS="$LIBS $bzip2_LIBS",
        [AC_SEARCH_LIBS([BZ2_bzlibVersion], [bz2])
    ])
    PKG_CHECK_MODULES([jpeg], [libjpeg], LIBS="$LIBS $jpeg_LIBS",
        [AC_SEARCH_LIBS([jpeg_read_header], [jpeg],,
            [AC_MSG_ERROR(unable to find libjpeg)])
    ])
    PKG_CHECK_MODULES([png], [libpng], LIBS="$LIBS $png_LIBS",
        [AC_SEARCH_LIBS([png_create_read_struct], [png],,
            [AC_MSG_ERROR(unable to find libpng)])
    ])
    PKG_CHECK_MODULES([gif], [libgif], LIBS="$LIBS $gif_LIBS",
        [AC_SEARCH_LIBS([DGifOpen], [gif],,
            [AC_MSG_ERROR(unable to find libgif)])
    ])
    # If intl is present, we should use it, because we assume exif did.
    # However, it should not kill the build.
    PKG_CHECK_MODULES([iconv], [iconv], LIBS="$LIBS $iconv_LIBS",
        [AC_SEARCH_LIBS([iconv], [iconv])
    ])
    # If intl is present, we should use it, because we assume exif did.
    # However, it should not kill the build.
    PKG_CHECK_MODULES([intl], [libintl], LIBS="$LIBS $intl_LIBS",
        [AC_SEARCH_LIBS([gettext], [intl])
    ])
    PKG_CHECK_MODULES([exif], [libexif], LIBS="$LIBS $exif_LIBS",
        [AC_SEARCH_LIBS([exif_loader_new], [exif],,
            [AC_MSG_ERROR(unable to find libexif)])
    ])
    PKG_CHECK_MODULES([avutil], [libavutil >= 56.31.100], LIBS="$LIBS $avutil_LIBS",
        [AC_SEARCH_LIBS([av_freep], [avutil],,
        [AC_MSG_ERROR(unable to find libavutil)], [-lz])
    ])
    PKG_CHECK_MODULES([avcodec], [libavcodec >= 58.54.100], LIBS="$LIBS $avcodec_LIBS",
        [AC_SEARCH_LIBS([avcodec_version], [avcodec],,
        [AC_MSG_ERROR(unable to find libavcodec)], [-lavutil -lm -lz])
    ])
    PKG_CHECK_MODULES([avformat], [libavformat >= 58.29.100], LIBS="$LIBS $avformat_LIBS",
        [AC_SEARCH_LIBS([avformat_version], [avformat],,
        [AC_MSG_ERROR(unable to find libavformat)], [-lm -lavcodec -lavutil -lz])
    ])
    PKG_CHECK_MODULES([swscale], [libswscale >= 5.5.100], LIBS="$LIBS $swscale_LIBS",
        [AC_SEARCH_LIBS([sws_scale], [swscale],,
        [AC_MSG_ERROR(unable to find libswscale)], [-lavutil -lm])
    ])
    PKG_CHECK_MODULES([db], [libdb],,
        [AC_SEARCH_LIBS([db_create], [db], [], [AC_MSG_ERROR(cannot find libdb in $bdbdir/lib)])
    ])
else
    # Olden ways
    AC_SEARCH_LIBS([pthread_create], [pthread])
    AC_SEARCH_LIBS([zlibVersion], [z],,
        [AC_MSG_ERROR(unable to find libz)
    ])
    AC_SEARCH_LIBS([BZ2_bzlibVersion], [bz2])
    AC_SEARCH_LIBS([jpeg_read_header], [jpeg],,
        [AC_MSG_ERROR(unable to find libjpeg)
    ])
    AC_SEARCH_LIBS([png_create_read_struct], [png],,
        [AC_MSG_ERROR(unable to find libpng)
    ])
    AC_SEARCH_LIBS([DGifOpen], [gif],,
        [AC_MSG_ERROR(unable to find libgif)
    ])
    AC_SEARCH_LIBS([iconv], [iconv]) # Sometimes libintl is built with iconv
    AC_SEARCH_LIBS([gettext], [intl]) # Sometimes exif is built with libintl
    AC_SEARCH_LIBS([exif_loader_new], [exif],,
        [AC_MSG_ERROR(unable to find libexif)
    ])
    AC_SEARCH_LIBS([av_freep], [avutil],,
        [AC_MSG_ERROR(unable to find libavutil)], [-lz]
    )
    AC_SEARCH_LIBS([avcodec_version], [avcodec],,
        [AC_MSG_ERROR(unable to find libavcodec)], [-lavutil -lz]
    )
    AC_SEARCH_LIBS([avformat_version], [avformat],,
        [AC_MSG_ERROR(unable to find libavformat)], [-lavcodec -lavutil -lz]
    )
    AC_SEARCH_LIBS([sws_scale], [swscale],,
        [AC_MSG_ERROR(unable to find libswscale)], [-lavutil]
    )
    AC_SEARCH_LIBS([db_create], [db], [], [AC_MSG_ERROR(cannot find libdb in $bdbdir/lib)])
fi

# Modern giflib doesn't usually use pkg-config, so we should check the lib version manually.
# This is done by checking the version values within the header
have_new_giflib=no
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([
#include <gif_lib.h>
],[
#if GIFLIB_MAJOR < 5 || GIFLIB_MINOR < 1
#error Incompatible giflib version
#endif
])], [have_new_giflib=yes])

if test "x${have_new_giflib}" = "xno"; then
    AC_MSG_ERROR(Builds require giflib API 5.1+. Please see the documentation.)
fi

# If the build (or FFmpeg detection) doesn't use pkg-config, we have to check the version manually.
# This is done by checking the libavutil version values within the version header.
# The other components of FFmpeg are assumed to be of the same vintage.
have_new_ffmpeg=no
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([
#include <libavutil/version.h>
],[
#if LIBAVUTIL_VERSION_MAJOR < 56 || LIBAVUTIL_VERSION_MINOR < 31
#error Incompatible ffmpeg version
#endif
])], [have_new_ffmpeg=yes])

if test "x${have_new_ffmpeg}" = "xno"; then
    AC_MSG_ERROR(Builds require ffmpeg API 4.2.1+. Please see the documentation.)
fi

# Debugging
AC_ARG_ENABLE([debug],
    [AS_HELP_STRING([--enable-debug], [enable debug output @<:@default: no@:>@])],
    [debug=${enableval}], [debug=no])

if test "x${debug}" = xyes; then
    AC_DEFINE([DEBUG], 1, [debug enabled])
fi

AC_CONFIG_FILES([Makefile
                 include/Makefile
                 src/Makefile
                 test/Makefile])
AC_OUTPUT
