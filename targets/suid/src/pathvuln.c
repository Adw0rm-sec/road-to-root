/* logstats  --  SUID-root binary, PATH-hijack variation
 *
 * It elevates to full root, then runs a helper command by its BARE name.
 * Because the command isn't an absolute path, the shell resolves it through
 * $PATH -- which the caller controls. Drop a fake 'du' early in PATH and it
 * runs as root. (The SUID form of the PATH hijack you did with cron -- but
 * instant: no cron wait.)
 */
#include <stdlib.h>
#include <unistd.h>

int main(void) {
    setuid(0);
    setgid(0);
    /* VULN: 'du' is a bare name -> resolved via $PATH -> hijackable */
    system("du -sh /var/log 2>/dev/null");
    return 0;
}
