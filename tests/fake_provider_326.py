#!/usr/bin/env python3
"""fake_provider_326.py — provedor falso local para a issue #326.

Escuta APENAS em 127.0.0.1 (loopback; sem rede externa e sem chave de API).
O SO escolhe a porta livre e ela é gravada em --portfile, para o teste Lua
não depender de porta fixa (evita conflito com um servidor esquecido).
Cada requisição recebida é registrada em --log, com tamanho do corpo,
número de mensagens, número de ferramentas e validade do JSON.

Modos (--mode):
  readmiss  -> 1a requisição pede Read de arquivo inexistente; 2a devolve
               [FLUSH_DONE] (cenário b da issue #326)
  http400s  -> HTTP 400 com status numérico no corpo (should_retry não repete)
  empty     -> HTTP 200 sem corpo (produz "Sem resposta do servidor")

Uso: python3 tests/fake_provider_326.py --mode readmiss \
        --log /tmp/fp.log --portfile /tmp/fp.port
"""
import argparse
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

MODE = "readmiss"
LOG = "fake326.log"
REQS = 0


def log(line):
    with open(LOG, "a") as f:
        f.write(line + "\n")


def sse(chunk):
    return ("data: " + json.dumps(chunk, ensure_ascii=False) + "\n\n").encode()


def delta(content=None, tool_calls=None):
    d = {}
    if content is not None:
        d["content"] = content
    if tool_calls is not None:
        d["tool_calls"] = tool_calls
    return sse({"choices": [{"index": 0, "delta": d}]})


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):
        pass

    def do_POST(self):
        global REQS
        REQS += 1
        n = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(n).decode("utf-8", "replace")

        nmsg, tools, valid = "?", "?", False
        try:
            body = json.loads(raw)
            valid = True
            nmsg = len(body.get("messages", []))
            tools = len(body.get("tools", []) or [])
        except Exception as e:
            log(f"REQ{REQS} JSON_INVALIDO={e} bytes={len(raw)}")
        log(f"REQ{REQS} modo={MODE} bytes={len(raw)} msgs={nmsg} "
            f"tools={tools} json_valido={valid}")

        if MODE == "http400s":
            payload = json.dumps(
                {"error": {"message": "Bad Request", "status": 400}}).encode()
            self.send_response(400)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return

        if MODE == "empty":
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Transfer-Encoding", "chunked")
        self.end_headers()

        def w(b):
            self.wfile.write(("%X\r\n" % len(b)).encode() + b + b"\r\n")
            self.wfile.flush()

        w(sse({"choices": [{"index": 0, "delta": {"role": "assistant"}}]}))
        if MODE == "readmiss" and REQS == 1:
            tc = {"index": 0, "id": "call_read_1", "type": "function",
                  "function": {"name": "Read",
                               "arguments": json.dumps(
                                   {"path": "memory/1999-01-01.md"})}}
            w(delta(tool_calls=[tc]))
        else:
            w(delta(content="Protocolo concluido.\n[FLUSH_DONE]"))
        w(b"data: [DONE]\n\n")
        w(b"")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", default="readmiss")
    ap.add_argument("--log", default="fake326.log")
    ap.add_argument("--portfile", required=True)
    a = ap.parse_args()
    MODE, LOG = a.mode, a.log
    open(LOG, "w").close()
    srv = HTTPServer(("127.0.0.1", 0), Handler)
    with open(a.portfile, "w") as f:
        f.write(str(srv.server_address[1]))
    log(f"servidor iniciado modo={MODE} porta={srv.server_address[1]}")
    srv.serve_forever()
