/*
 * svc-runner -- Hollow Industries "service launcher"
 *
 * Shipped with file capability  cap_setuid+ep  so it could drop into the
 * unprivileged 'svc' account before launching a worker. Whoever wrote it used
 * the capability to call setuid(0) FIRST (to become root so it can then drop),
 * but then hands control to a command named in the SVC_CMD environment
 * variable -- which the caller controls.
 *
 * setuid(0) + an attacker-chosen command = a root shell.
 *
 * Usage:  SVC_CMD=/bin/bash svc-runner
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(void) {
    /* cap_setuid lets an unprivileged caller become uid 0 */
    if (setuid(0) != 0) {
        perror("setuid");
        return 1;
    }
    const char *cmd = getenv("SVC_CMD");
    if (!cmd)
        cmd = "/usr/bin/id";          /* default "health check" */
    return system(cmd);               /* runs as root */
}
