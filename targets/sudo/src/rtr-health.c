/* rtr-health -- a tiny "system check" binary used by Chapter 03 Station C.
 *
 * It does nothing privileged on its own. Its only role is to be a non-SUID,
 * dynamically-linked binary that admins allow a user to run via sudo, so an
 * operator can demonstrate that env_keep += "LD_PRELOAD" lets an attacker's
 * .so run as root at load time (via __attribute__((constructor))).
 */
#include <stdio.h>

int main(void) {
    printf("rtr-health: system OK\n");
    return 0;
}
