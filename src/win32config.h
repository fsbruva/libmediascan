#ifndef CONFIG_H
#define CONFIG_H

#ifdef _MSC_VER
#undef inline
#define inline __inline
#endif

void croak(char *fmt, ...);

#endif