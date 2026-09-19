import http.server
import os
import sys
import mimetypes

PORT = 8080
DIRECTORY = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "web")

mimetypes.init()
mimetypes.add_type('application/wasm', '.wasm')
mimetypes.add_type('application/javascript', '.js')
mimetypes.add_type('application/json', '.json')

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

    def log_message(self, format, *args):
        # Concise logging
        sys.stderr.write(f"[{self.log_date_time_string()}] {format % args}\n")

if __name__ == '__main__':
    server_address = ('', PORT)
    try:
        httpd = http.server.ThreadingHTTPServer(server_address, CustomHandler)
        print(f"CineAI web app running at http://localhost:{PORT} and http://127.0.0.1:{PORT}", flush=True)
        httpd.serve_forever()
    except Exception as e:
        print(f"Server error: {e}", file=sys.stderr)
