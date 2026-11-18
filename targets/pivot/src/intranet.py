#!/usr/bin/env python3
"""
Hollow Relay -- internal "diagnostics" service.

Bound to 127.0.0.1 only and started as ROOT by the entrypoint. The admins
treated loopback-only as a security boundary and never bothered to sanitise
input -- the /ping endpoint splices the `host` parameter straight into a shell
command. Reach it through an SSH tunnel and that is command execution as root.

    GET /            -> help text
    GET /ping?host=X -> runs:  ping -c1 -W1 <X>   (as root, via /bin/sh)
"""
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        u = urlparse(self.path)
        if u.path == "/ping":
            host = parse_qs(u.query).get("host", [""])[0]
            # THE BUG: raw concatenation into a shell command, run as root.
            cmd = "ping -c1 -W1 " + host
            out = subprocess.run(
                cmd, shell=True, capture_output=True, text=True
            )
            body = "Running: {}\n{}{}".format(cmd, out.stdout, out.stderr)
            self._send(200, body)
        else:
            self._send(
                200,
                "Hollow Relay intranet diagnostics.\n"
                "Try: /ping?host=127.0.0.1\n",
            )

    def _send(self, code, body):
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(body.encode())

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", 8080), Handler).serve_forever()
