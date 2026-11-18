/*
 * vault-write -- Hollow Industries "safe config writer"
 *
 * Shipped with file capability  cap_dac_override+ep  so the ops team could
 * update protected config files without being root. The capability lets this
 * process bypass file read/write permission checks -- so it can clobber ANY
 * file on the box, including /etc/sudoers.d and /etc/passwd.
 *
 * It does nothing to validate the path. Point it at a root-owned file and it
 * appends your stdin straight onto the end of it. That is the whole bug.
 *
 * Appending to an EXISTING root-owned file (e.g. /etc/sudoers, /etc/passwd)
 * keeps the file owned by root -- so the entry you add is trusted.
 *
 * Usage:  vault-write <path>      (content comes from stdin, appended)
 */
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s <path>\n", argv[0]);
        return 2;
    }
    FILE *f = fopen(argv[1], "a");   /* cap_dac_override bypasses the DAC check */
    if (!f) { perror("fopen"); return 1; }

    int c;
    while ((c = fgetc(stdin)) != EOF)
        fputc(c, f);

    fclose(f);
    return 0;
}
