#ifndef REYDROID_VM_BRIDGE_H
#define REYDROID_VM_BRIDGE_H
// Runs the already-signed UTM SE interpreter. Never creates executable memory.
int rd_vm_run(const char *library, const char *directory, const char *log,
              int argc, const char **argv);
const char *rd_vm_error(void);
#endif
