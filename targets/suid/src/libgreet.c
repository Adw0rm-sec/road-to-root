/* libgreet.so -- the LEGITIMATE plugin that the 'report' tool loads at runtime.
 *
 * It lives in /opt/lab/lib, which the 'report' binary trusts via a baked-in
 * RPATH. The only problem is that directory is world-writable... (see report.c)
 */
#include <stdio.h>

void greet(void) {
    printf("[report] plugin loaded; generating nightly report...\n");
}
