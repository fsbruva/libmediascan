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
AM_PROG_CC_C_O
AC_PROG_CXX
AC_PROG_AWK
AC_PROG_CPP
AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_MAKE_SET
AC_PROG_RANLIB

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
    *mingw*)
	build_mingw=yes
	LDFLAGS="-L$bdbdir/lib $LDFLAGS"
        # Need some MINGW libraries. AVUtil uses 'BCryptOpenAlgorithmProvider', needs 'm, user32 and bcrypt'.
        # AVFormat auto-detects sockets, so we need to add 'ws2_32'.
        LIBS="-lm -luser32 -lbcrypt -lws2_32"
        AC_CHECK_HEADERS([windows.h bcrypt.h],,,
        [[#if HAVE_WINDOWS_H
        # include <windows.h>
        #endif
        ]])
#AC_CHECK_LIB([advapi32], [main])
#AC_CHECK_LIB([comctl32], [main])
#AC_CHECK_LIB([comdlg32], [main])
#AC_CHECK_LIB([cunit], [main])
#AC_CHECK_LIB([gdi32], [main])
#AC_CHECK_LIB([kernel32], [main])
#AC_CHECK_LIB([moldname], [main])
#AC_CHECK_LIB([mpr], [main])
#AC_CHECK_LIB([netapi32], [main])
#AC_CHECK_LIB([odbc32], [main])
#AC_CHECK_LIB([odbccp32], [main])
#AC_CHECK_LIB([ole32], [main])
#AC_CHECK_LIB([oleaut32], [main])
#AC_CHECK_LIB([shell32], [main])
#AC_CHECK_LIB([user32], [main])
#AC_CHECK_LIB([uuid], [main])
#AC_CHECK_LIB([version], [main])
#AC_CHECK_LIB([winmm], [main])
#AC_CHECK_LIB([winspool], [main])
#AC_CHECK_LIB([ws2_32], [main])
	;;
esac

AM_CONDITIONAL([DARWIN], [test "$build_darwin" = "yes"])
AM_CONDITIONAL([SUN], [test "$build_sun" = "yes"])
AM_CONDITIONAL([LINUXBSD], [test "$build_linuxbsd" = "yes"])
AM_CONDITIONAL([MINGW], [test "$build_mingw" = "yes"])

# Checks for libraries.
AC_SEARCH_LIBS([pthread_create], [pthread])
AC_SEARCH_LIBS([zlibVersion], [z])
AC_SEARCH_LIBS([jpeg_read_header], [jpeg])
AC_SEARCH_LIBS([png_create_read_struct], [png])
AC_SEARCH_LIBS([DGifOpen], [gif])
AC_SEARCH_LIBS([libiconv], [iconv])
AC_SEARCH_LIBS([gettext], [intl])
AC_SEARCH_LIBS([exif_loader_new], [exif])
AC_SEARCH_LIBS([av_freep], [avutil],,, [-lz])
AC_SEARCH_LIBS([sws_scale], [swscale],,,[-lavutil -lz])
AC_SEARCH_LIBS([avcodec_version], [avcodec],,,[-lavutil -lz])
AC_SEARCH_LIBS([avformat_version], [avformat],,, [-lavcodec -lavutil -lz -lbz2])
AC_CHECK_LIB([db],[db_create], [], [AC_MSG_ERROR(cannot find libdb in $bdbdir/lib)])

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
