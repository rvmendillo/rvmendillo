// SPDX-License-Identifier: GPL-2.0-or-later
#include "VMBridge.h"
#include <dlfcn.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
static char rd_error[1024];
const char *rd_vm_error(void) { return rd_error; }
int rd_vm_run(const char *library, const char *directory, const char *log,
              int argc, const char **argv) {
    void *handle = dlopen(library, RTLD_NOW | RTLD_LOCAL);
    if (!handle) { snprintf(rd_error, sizeof(rd_error), "%s", dlerror()); return -1; }
    int (*initialize)(int, const char **, const char **) = dlsym(handle, "qemu_init");
    void (*loop)(void) = dlsym(handle, "qemu_main_loop");
    void (*cleanup)(void) = dlsym(handle, "qemu_cleanup");
    // This is an export in the pinned SE engine, absent in the JIT build.
    if (!dlsym(handle, "tcg_qemu_tb_exec") || !initialize || !loop || !cleanup) {
        snprintf(rd_error, sizeof(rd_error), "The interpreter runtime is incomplete."); return -2;
    }
    if (chdir(directory)) { snprintf(rd_error, sizeof(rd_error), "Cannot open the VM directory."); return -3; }
    int fd = open(log, O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (fd >= 0) { dup2(fd, STDOUT_FILENO); dup2(fd, STDERR_FILENO); close(fd); }
    signal(SIGPIPE, SIG_IGN);
    const char *env[] = {NULL};
    int result = initialize(argc, argv, env);
    if (!result) { loop(); cleanup(); }
    // QEMU is deliberately loaded only once per app process.
    return result;
}
