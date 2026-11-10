/* logreader  --  SUID-root binary, command-injection variation
 *
 * It elevates to root, then builds a shell command by pasting user input
 * straight into a string and handing it to system(). No sanitising, so a
 * ';' or '$()' in the argument runs your own command as root.
 */
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

int main(int argc, char **argv) {
    setuid(0);
    setgid(0);
    if (argc < 2) {
        printf("usage: %s <logfile>\n", argv[0]);
        return 1;
    }
    char cmd[512];
    /* VULN: argv[1] concatenated into a shell command with no sanitising */
    snprintf(cmd, sizeof(cmd), "/bin/cat /var/log/%s", argv[1]);
    system(cmd);
    return 0;
}
