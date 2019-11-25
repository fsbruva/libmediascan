use strict;

use Config;
use ExtUtils::MakeMaker qw(WriteMakefile);
use File::Spec::Functions;
use Getopt::Long;

my (@INC, @LDDLFLAGS, @LIBPATH, @LIBS, @CPPFLAGS, @check);
my ($FFMPEG, $LMS, $EXIF, $JPEG, $PNG, $GIF, $BDB, $MYEXTLIB, $LMSLA, $LMSLIBDEP, $BZ2, $INTL, $ICONV);

my ($help, $omit_intl, $jumbo_lib, $make_bin, $bdb_inc, $bdb_lib, $cc_lib_path);
my ($exif_inc, $exif_lib, $ffmpeg_inc, $ffmpeg_lib, $gif_inc, $gif_lib, $jpeg_inc, $jpeg_lib);
my ($lms_inc, $lms_lib, $png_inc, $png_lib);
my $static;

my $DEFINES = '-O2 ';
$DEFINES .= ' -Wall' unless $^O =~ /sun|solaris/i;
$DEFINES .= ' -Wno-unused-value -Wno-format-security' unless $^O =~ /sun|solaris/i;
$DEFINES .= ' -D "HAVE_CONFIG_H"' if $^O =~ /Win32/i;

my $result = GetOptions(
    "help|h"                 => \$help,
    "omit-intl"              => \$omit_intl,
    "use-jumbo"              => \$jumbo_lib,
    "use-make=s"             => \$make_bin,
    "with-bdb-includes=s"    => \$bdb_inc,
    "with-bdb-libs=s"        => \$bdb_lib,
    "with-exif-includes=s"   => \$exif_inc,
    "with-exif-libs=s"       => \$exif_lib,
    "with-ffmpeg-includes=s" => \$ffmpeg_inc,
    "with-ffmpeg-libs=s"     => \$ffmpeg_lib,
    "with-CC-lib-path=s"     => \$cc_lib_path,
    "with-gif-includes=s"    => \$gif_inc,
    "with-gif-libs=s"        => \$gif_lib,
    "with-jpeg-includes=s"   => \$jpeg_inc,
    "with-jpeg-libs=s"       => \$jpeg_lib,
    "with-lms-includes=s"    => \$lms_inc,
    "with-lms-libs=s"        => \$lms_lib,
    "with-png-includes=s"    => \$png_inc,
    "with-png-libs=s"        => \$png_lib,
    "with-static"            => \$static,
);

if ($help || !$result) {
    print STDERR <<END;
Usage: perl Makefile.PL [options]

Configure Media::Scan module.

Options:
    --omit-intl               Do not link the module with the intl library
    --use-jumbo               Library for libmediascan is one giant archive
    --use-make                Type of make to be used by perl (make, dmake, nmake, etc)
    --with-bdb-includes       Path to directory containing BerkeleyDB's db.h
    --with-bdb-libs           Path to directory containing libdb
    --with-CC-lib-path        String of lib paths for compiler libraries ("-L/foo/lib -L/bar/lib" )
    --with-exif-includes      Path to directory containing libexif/exif-data.h
    --with-exif-libs          Path to directory containing libexif
    --with-ffmpeg-includes    Path to directory containing libavformat/avformat.h
    --with-ffmpeg-libs        Path to directory containing libavformat/libavcodec/libavutil/libswscale
    --with-gif-includes       Path to directory containing gif_lib.h
    --with-gif-libs           Path to directory containing libgif
    --with-jpeg-includes      Path to directory containing jpeglib.h
    --with-jpeg-libs          Path to directory containing libjpeg
    --with-lms-includes       Path to directory containing libmediascan.h
    --with-lms-libs           Path to directory containing libmediascan
    --with-png-includes       Path to directory containing png.h
    --with-png-libs           Path to directory containing libpng
    --with-static             Statically link the module with all libraries

Note: The lms-includes variable is checked first, and if successful, will
be re-used as an option for all subsequent checks. Therefore, any headers
located in the same location do not require explicit declaration.

END

    exit 0;
}

# Specify default include locations
@check = qw(/usr/include /usr/local/include /opt/local/include) unless $^O =~ /Win32/i;

if ( $^O =~ /Win32/i ) {
    if (!(defined $ENV{MSYSTEM}) || !($ENV{MSYSTEM} =~ /MINGW/ )){
        die "Only MinGW builds are supported for Windows.\nPlease read README.win32 for instructions on building on Windows\n";
    }
    # The MINGW_PREFIX variable should either be mingw32 or mingw64
    if ((defined $ENV{MINGW_PREFIX}) || ($ENV{MINGW_PREFIX} =~ /mingw/i )){
        unshift @check, "$ENV{MINGW_PREFIX}/include";
        unshift @INC, '-I' . "$ENV{MINGW_PREFIX}/include";
        unshift @LIBPATH, "-L$ENV{MINGW_PREFIX}/lib";
        # The MINGW_CHOST variable will either be x86_64-w64-mingw32 or i686-w64-mingw32
        if ((defined $ENV{MINGW_CHOST}) || ($ENV{MINGW_CHOST} =~ /w64-mingw32/i )) {
            unshift @check, "$ENV{MINGW_PREFIX}/$ENV{MINGW_CHOST}/include";
            unshift @INC, '-I' . "$ENV{MINGW_PREFIX}/$ENV{MINGW_CHOST}/include";
            unshift @LIBPATH, "-L$ENV{MINGW_PREFIX}/$ENV{MINGW_CHOST}/lib";
        }
        else {
            print "WARNING: Could not detect MINGW_CHOST in environment.\nPlease read README.win32 for instructions on building on Windows\n";
        }
    }
    else {
        print "WARNING: Could not detect MINGW_PREFIX in environment.\nPlease read README.win32 for instructions on building on Windows\n";
    }
    $static = 1;    # Only static on Windows (for now)
}

# Add any additional lib paths necessary for compilation
if ((defined $cc_lib_path) && ($cc_lib_path ne '' ) ) {
    unshift @LIBPATH, split / /, $cc_lib_path;
}

# Check in environment-supplied locations before standard ones
unshift @check, split /:/, $ENV{INCLUDE};

# Look for libmediascan
for my $incdir ( $lms_inc, @check ) {
    if ( $incdir && -e catfile($incdir, 'libmediascan.h') ) {
        $LMS = 1;
        $lms_inc = $incdir;

        unshift @INC, '-I' . $lms_inc;
        # If this is our first run through the loop, it's with the supplied lms_inc. We'll keep looking there.
        unshift @check , $lms_inc if ( $_ == 0 );
        # An explicit location for lms has been supplied
        if ($lms_lib) {
            unshift @LIBPATH, '-L' . $lms_lib;
        }
        # Building a static library - we want the lib, but can adapt if we only have the include
        if ($static) {
            if ($lms_lib) {
                $MYEXTLIB .= $lms_lib . '/' . 'libmediascan$(LIB_EXT) ' unless ($jumbo_lib) ;
                $MYEXTLIB .= $lms_lib . '/' . 'libmediascan.lib ' if ($jumbo_lib) ;
            }
            else {
                $MYEXTLIB .= $lms_inc . '/../lib/libmediascan$(LIB_EXT) ' unless ($jumbo_lib);
                $MYEXTLIB .= $lms_lib . '/../lib/libmediascan.lib ' if ($jumbo_lib) ;
            }
        }
        else {
            # We're going to attempt dynamic linking
            unshift @LIBS, '-lmediascan';
        }

        print "Using libmediascan header from $lms_inc\n";
        last;
    }
}

if ( !$LMS ) {
    # XXX make a CPAN module version that includes lms as a subdir?
    die "libmediascan not found, please install it and try again. Checked for libmediascan.h in: " . join(", ", $lms_inc, @check) . "\n";
}

if ( ($jumbo_lib) ) {
    # This build attempt has everything in giant libmediascan.lib and doesn't need other libraries
    goto MAKEFILE;
}

# Look for libmediascan's .la file to help with dependency management
for my $incdir ( $lms_inc, @check ) {
    if ( $incdir && -e catfile($incdir, '/../lib/libmediascan.la') ) {
        $lms_inc = $incdir;

        open my $fh, '<:encoding(UTF-8)', catfile($incdir, '/../lib/libmediascan.la') or die;
        while (my $line = <$fh>) {
            if ($line =~ /dependency_libs=/) {
                # We found the dependency libs line. We need to know about some of the optional libraries,
                # particularly bz2, intl, and iconv.
                $LMSLA = 1;
                # Trim the dependency_libs=' (17) from the front, and the trailing ' and space (-2)
                $LMSLIBDEP = substr $line, 17, -2;
                my @words = split / /, $LMSLIBDEP;
                foreach  ( @words ) {
                    if ( $_ eq '-lbz2' ) {
                        $BZ2 = 1;
                    }
                    elsif  ( $_ eq '-lintl' ) {
                        $INTL = 1;
                    }
                    elsif ( $_ eq '-liconv' ) {
                        $ICONV = 1;
                    }
                }
            }
        }
        print "Using libmediascan lib archive from " . catfile($incdir, '/../lib/libmediascan.la') . "\n";
        last;
    }
}

# Look for ffmpeg
for my $incdir ( $ffmpeg_inc, @check ) {
    if ( $incdir && -e catfile($incdir, 'libavformat', 'avformat.h') ) {
        $FFMPEG = 1;
        $ffmpeg_inc = $incdir;

        unshift @INC, '-I' . $ffmpeg_inc;
        if ($ffmpeg_lib) {
            unshift @LIBPATH, '-L' . $ffmpeg_lib;
        }

        if ($static) {
            if ($ffmpeg_lib) {
                $MYEXTLIB .= $ffmpeg_lib . '/' . 'libavformat$(LIB_EXT) ';
                $MYEXTLIB .= $ffmpeg_lib . '/' . 'libavcodec$(LIB_EXT) ';
                $MYEXTLIB .= $ffmpeg_lib . '/' . 'libswscale$(LIB_EXT) ';
                $MYEXTLIB .= $ffmpeg_lib . '/' . 'libavutil$(LIB_EXT) ';
            }
            else {
                $MYEXTLIB .= $ffmpeg_inc . '/../lib/libavformat$(LIB_EXT) ';
                $MYEXTLIB .= $ffmpeg_inc . '/../lib/libavcodec$(LIB_EXT) ';
                $MYEXTLIB .= $ffmpeg_inc . '/../lib/libswscale$(LIB_EXT) ';
                $MYEXTLIB .= $ffmpeg_inc . '/../lib/libavutil$(LIB_EXT) ';
            }

            push @LIBS, '-lm -lz';
            push @LIBS, '-lbz2' if ( $BZ2 || (!$LMSLA) ) ;
        }
        else {
            push @LIBS, '-lavformat -lavcodec -lm -lz -lswscale -lavutil';
            # If we don't have the .la file, assume we need bz2
            push @LIBS, '-lbz2' if ( $BZ2 || (!$LMSLA) ) ;
        }

        print "Using ffmpeg from $ffmpeg_inc\n";
        last;
    }
}

if ( !$FFMPEG ) {
    die "FFmpeg not found, please install it and try again. Checked for libavformat/avformat.h in: " . join(", ", $ffmpeg_inc, @check) . "\n";
}

# Look for libexif
for my $incdir ( $exif_inc, @check ) {
    if ( $incdir && -e catfile($incdir, 'libexif', 'exif-data.h') ) {
        $EXIF = 1;
        $exif_inc = $incdir;

        unshift @INC, '-I' . $exif_inc;
        if ($exif_lib) {
            unshift @LIBPATH, '-L' . $exif_lib;
        }

        if ($static) {
            if ($exif_lib) {
                $MYEXTLIB .= $exif_lib . '/' . 'libexif$(LIB_EXT) ';
            }
            else {
                $MYEXTLIB .= $exif_inc . '/../lib/libexif$(LIB_EXT) ';
            }
        }
        else {
            push @LIBS, '-lexif';
        }

        if (!$omit_intl) {
            # If we don't have the .la file, assume we need intl
            push @LIBS, '-lintl' if ( $INTL || (!$LMSLA)); # XXX only if logging is used for exif
            push @LIBS, '-liconv' if ( $ICONV && $LMSLA ); # Only add -liconv if we know we need it
        }

        print "Using libexif from $exif_inc\n";
        last;
    }
}

if ( !$EXIF ) {
    die "libexif not found, please install it and try again. Checked for libexif/exif-data.h in: " . join(", ", $exif_inc, @check) . "\n";
}

# Look for libjpeg
for my $incdir ( $jpeg_inc, @check ) {
    if ( $incdir && -e catfile($incdir, 'jpeglib.h') ) {
        $JPEG = 1;
        $jpeg_inc = $incdir;

        unshift @INC, '-I' . $jpeg_inc;
        if ($jpeg_lib) {
            unshift @LIBPATH, '-L' . $jpeg_lib;
        }

        if ($static) {
            if ($jpeg_lib) {
                $MYEXTLIB .= $jpeg_lib . '/' . 'libjpeg$(LIB_EXT) ';
            }
            else {
                $MYEXTLIB .= $jpeg_inc . '/../lib/libjpeg$(LIB_EXT) ';
            }
        }
        else {
            push @LIBS, '-ljpeg';
        }

        print "Using libjpeg from $jpeg_inc\n";
        last;
    }
}

if ( !$JPEG ) {
    die "libjpeg not found, please install it and try again. Checked for jpeglib.h in: " . join(", ", $jpeg_inc, @check) . "\n";
}

# Look for libpng
for my $incdir ( $png_inc, @check ) {
    if ( $incdir && -e catfile($incdir, 'png.h') ) {
        $PNG = 1;
        $png_inc = $incdir;

        unshift @INC, '-I' . $png_inc;
        if ($png_lib) {
            unshift @LIBPATH, '-L' . $png_lib;
        }

        if ($static) {
            if ($png_lib) {
                $MYEXTLIB .= $png_lib . '/' . 'libpng$(LIB_EXT) ';
            }
            else {
                $MYEXTLIB .= $png_inc . '/../lib/libpng$(LIB_EXT) ';
            }
        }
        else {
            push @LIBS, '-lpng';
        }

        print "Using libpng from $png_inc\n";
        last;
    }
}

if ( !$PNG ) {
    die "libpng not found, please install it and try again. Checked for png.h in: " . join(", ", $png_inc, @check) . "\n";
}

# Look for giflib
for my $incdir ( $gif_inc, @check ) {
    if ( $incdir && -e catfile($incdir, 'gif_lib.h') ) {
        $GIF = 1;
        $gif_inc = $incdir;

        unshift @INC, '-I' . $gif_inc;
        if ($gif_lib) {
            unshift @LIBPATH, '-L' . $gif_lib;
        }

        if ($static) {
            if ($gif_lib) {
                $MYEXTLIB .= $gif_lib . '/' . "libgif\$(LIB_EXT) ";
            }
            else {
                $MYEXTLIB .= $gif_inc . "/../lib/libgif\$(LIB_EXT) ";
            }
        }
        else {
            push @LIBS, "-lgif";
        }

        print "Using libgif from $gif_inc\n";
        last;
    }
}

if ( !$GIF ) {
    die "libgif not found, please install it and try again. Checked for gif_lib.h in: " . join(", ", $gif_inc, @check) . "\n";
}

# Look for bdb
for my $incdir ( $bdb_inc, @check ) {
    if ( $incdir && -e catfile($incdir, 'db.h') ) {
        $BDB = 1;
        $bdb_inc = $incdir;

        unshift @INC, '-I' . $bdb_inc;
        if ($bdb_lib) {
            unshift @LIBPATH, '-L' . $bdb_lib;
        }

        if ($static) {
            if ($bdb_lib) {
                $MYEXTLIB .= $bdb_lib . '/' . 'libdb$(LIB_EXT) ';
            }
            else {
                $MYEXTLIB .= $bdb_inc . '/../lib/libdb$(LIB_EXT) ';
            }
        }
        else {
            push @LIBS, '-ldb';
        }

        print "Using BerkeleyDB libdb from $bdb_inc\n";
        last;
    }
}

if ( !$BDB ) {
    die "BerkeleyDB not found, please install it and try again. Checked for db.h in: " . join(", ", $bdb_inc, @check) . "\n";
}

if ( $^O =~ /sun|solaris/i ) {
    my $perlarchpath = $Config{archlib} . '/CORE';
    unshift @LIBPATH, '-L' . $perlarchpath;
    my $extralibs = '-lsocket -lperl';
    unshift @LIBS, $extralibs;
}

if ( $^O =~ /Win32/i ) {
    # The perl from MinGW has quite a few default libs, but we also need these ones
    push @LIBS, '-lshlwapi -lwinpthread -lbcrypt -lmingwex -lmingw32 -lmsvcrt -lgcc';
    # MinGW's Perl for x86_64 automatically includes the static link instruction, but the i686 Perl doesn't.
    # We'll include just in case, because it will fail final linking if we don't.
    unshift @LDDLFLAGS, '-dll -nodefaultlibs -fPIC -static-libgcc -static-libstdc++';
    unshift @CPPFLAGS, '-D__MSVCRT_VERSION__=0x0601';
 }

push @LDDLFLAGS, $Config{lddlflags};
unshift @LDDLFLAGS, '-Wl,-Bsymbolic' unless $^O =~ /sun|solaris|Darwin/i;


MAKEFILE:

if ( $^O =~ /Win32/i ) {
    *MY::postamble = sub {};
    $MYEXTLIB .= " ";
}

my $xs_files  = join(' ', glob 'xs/*.xs');

my %opts = (
    NAME              => 'Media::Scan',
    VERSION_FROM      => 'lib/Media/Scan.pm',
    PREREQ_PM         => {
        'Test::Warn' => 0,
    },
    ABSTRACT          => 'Library for scanning audio/video/image file metadata',
    AUTHOR            => 'Andy Grundman <andy@hybridized.org>',
    INC               => join(' ', @INC),
    LDDLFLAGS         => join(' ', @LDDLFLAGS),
    LIBS              => [ join(' ', @LIBPATH, @LIBS) ],
    DEFINE            => $DEFINES,
    MYEXTLIB          => $MYEXTLIB,
    depend            => { 'Scan.c' => "$xs_files" },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/andygrundman/libmediascan.git',
                web  => 'https://github.com/andygrundman/libmediascan',
            },
        },
    },
    MIN_PERL_VERSION => 5.008,
    LICENSE => 'gpl_2',
);

}

WriteMakefile(%opts);
