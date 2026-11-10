/* report  --  SUID-root binary, shared-object / writable-library variation
 *
 * It elevates to full root, then calls greet(), which is NOT in this binary --
 * it lives in libgreet.so. The dynamic loader finds libgreet.so using the RPATH
 * baked into this executable at compile time, which points at /opt/lab/lib.
 *
 * THE BUG: /opt/lab/lib is world-writable. Any user can replace libgreet.so with
 * their own, and 'report' will load and run it as root.
 *
 * Why not just LD_PRELOAD? Because the dynamic loader runs SUID binaries in
 * "secure-execution mode" (AT_SECURE=1) and IGNORES LD_PRELOAD / LD_LIBRARY_PATH
 * from the environment. But a DT_RPATH compiled into the binary IS honored -- so
 * a writable RPATH directory is the real, exploitable mistake.
 */
#include <unistd.h>

void greet(void);   /* resolved at runtime from libgreet.so in /opt/lab/lib */

int main(void) {
    setuid(0);
    setgid(0);
    greet();
    return 0;
}
