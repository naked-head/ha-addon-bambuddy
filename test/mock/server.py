import json
from http.server import BaseHTTPRequestHandler, HTTPServer

OPTIONS = json.load(open("/mock/options.json"))

# Port mapping as the Supervisor reports it under "network" in
# /addons/self/info, which is where bashio::addon.port looks. Optional on
# purpose: this mock is shared, and an App that never calls addon.port mounts
# no file and gets an empty mapping, exactly as before.
try:
    NETWORK = json.load(open("/mock/network.json"))
except FileNotFoundError:
    NETWORK = {}


class H(BaseHTTPRequestHandler):
    def _send(self, data):
        b = json.dumps({"result": "ok", "data": data}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        p = self.path
        if p.startswith("/addons/self/options/config"):
            self._send(OPTIONS)
        elif p.startswith("/info"):
            self._send({"timezone": "Europe/Rome", "supervisor": "test", "homeassistant": "2026.7.0"})
        elif p.startswith("/core/info"):
            self._send({"version": "2026.7.0"})
        elif p.startswith("/addons/self/info"):
            self._send({"slug": "bambuddy", "options": OPTIONS, "network": NETWORK})
        else:
            self._send({})

    def log_message(self, *a):
        pass


HTTPServer(("0.0.0.0", 80), H).serve_forever()