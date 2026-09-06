#include "include/NastartUDF.h"
#include "udfread.h"
#include "blockinput.h"
#include <string.h>
#include <stdio.h>
typedef struct { udfread_block_input input; void *context; NAUDFRead read; } Input;
static int read_blocks(udfread_block_input *base, uint32_t lba, void *buf, uint32_t count, int flags) {
    Input *i = (Input *)base;
    return i->read(i->context, lba, buf, count);
}
int nastart_udf_scan(void *context, NAUDFRead read, NAUDFExtent emit) {
    Input input = {{NULL, read_blocks, NULL}, context, read};
    udfread *udf = udfread_init();
    if (!udf) return -1;
    if (udfread_open_input(udf, &input.input) < 0) { udfread_close(udf); return -1; }
    UDFDIR *dir = udfread_opendir(udf, "/BDMV/STREAM");
    if (!dir) { udfread_close(udf); return -1; }
    struct udfread_dirent ent;
    int count = 0;
    while (count < 5000 && udfread_readdir(dir, &ent)) {
        const char *ext = strrchr(ent.d_name, '.');
        if (ent.d_type != UDF_DT_REG || !ext || strcasecmp(ext, ".m2ts")) continue;
        char path[1024];
        if (snprintf(path, sizeof(path), "/BDMV/STREAM/%s", ent.d_name) >= sizeof(path)) continue;
        UDFFILE *file = udfread_file_open(udf, path);
        if (!file) continue;
        int64_t size = udfread_file_size(file), remaining = size;
        uint32_t block = 0;
        int64_t start = -1, length = 0;
        while (remaining > 0) {
            uint32_t lba = udfread_file_lba(file, block++);
            if (!lba) { udfread_file_close(file); udfread_closedir(dir); udfread_close(udf); return -1; }
            int64_t offset = (int64_t)lba * 2048;
            int64_t bytes = remaining < 2048 ? remaining : 2048;
            if (length && start + length != offset) { emit(context, path, start, length); length = 0; }
            if (!length) start = offset;
            length += bytes;
            remaining -= bytes;
        }
        if (length) { emit(context, path, start, length); count++; }
        udfread_file_close(file);
    }
    udfread_closedir(dir);
    udfread_close(udf);
    return count;
}
