#include <stdint.h>
typedef int (*NAUDFRead)(void *, uint32_t, void *, uint32_t);
typedef void (*NAUDFExtent)(void *, const char *, int64_t, int64_t);
/* Enumerate Blu-ray stream files. Returns count, or -1 on invalid input. */
__attribute__((visibility("default"))) int nastart_udf_scan(void *context, NAUDFRead read, NAUDFExtent emit);
