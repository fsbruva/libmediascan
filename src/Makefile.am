lib_LTLIBRARIES = libmediascan.la

# XXX only include in dist, not install
include_HEADERS = audio.h buffer.h common.h error.h mediascan.h progress.h fixed.h queue.h \
  image.h image_jpeg.h image_png.h image_gif.h image_bmp.h result.h thumb.h thread.h util.h video.h \
  database.h tag.h tag_item.h \
  libdlna/containers.h libdlna/dlna.h libdlna/dlna_internals.h libdlna/profiles.h \
  NSString+SymlinksAndAliases.h

libmediascan_la_SOURCES = audio.c buffer.c database.c error.c \
  image.c image_bmp.c image_gif.c image_jpeg.c image_png.c \
  mediascan.c progress.c result.c tag.c tag_item.c thread.c thumb.c util.c video.c \
  libdlna/audio_aac.c libdlna/audio_ac3.c libdlna/audio_amr.c libdlna/audio_atrac3.c \
  libdlna/audio_g726.c libdlna/audio_lpcm.c libdlna/audio_mp1.c libdlna/audio_mp2.c libdlna/audio_mp3.c \
  libdlna/audio_wma.c libdlna/av_mpeg1.c libdlna/av_mpeg2.c libdlna/av_mpeg4_part10.c \
  libdlna/av_mpeg4_part2.c libdlna/av_wmv9.c libdlna/containers.c libdlna/profiles.c \
  jenkins/lookup3.c

libmediascan_la_CFLAGS = -Wall -I$(top_srcdir)/include $(exif_CFLAGS) $(avutil_CFLAGS) $(swscale_CFLAGS) $(avcodec_CFLAGS) $(avformat_CFLAGS)

libmediascan_la_LDFLAGS = -version-info 0:0:0 $(exif_LIBS) $(avutil_LIBS) $(swscale_LIBS) $(avcodec_LIBS) $(avformat_LIBS)

if LINUXBSD
libmediascan_la_SOURCES += mediascan_unix.c mediascan_linux.c
endif

if SUN
libmediascan_la_SOURCES += mediascan_unix.c mediascan_sun.c
endif

if DARWIN
libmediascan_la_SOURCES += mediascan_unix.c mediascan_macos.m NSString+SymlinksAndAliases.m
libmediascan_la_OBJCFLAGS = $(CFLAGS) -Wall -I$(top_srcdir)/include
endif

if MINGW
#libmediascan_la_SOURCES += mediascan_win32.c win_iconv.c win32_port.c
libmediascan_la_SOURCES += mediascan_win32.c win32_port.c
include_HEADERS += win32config.h
libmediascan_la_LDFLAGS += --whole-archive -no-undefined
endif


