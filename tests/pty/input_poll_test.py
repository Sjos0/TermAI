#!/usr/bin/env python3
"""Testa o polling do ui/input.lua num pseudo-terminal real.

Cenários:
  wake    — sem teclas: o laço de idle deve acordar (retorna wake=true) com buffer vazio.
  partial — com texto digitado e sem Enter: NÃO acorda; depois do Enter devolve o texto.
  type    — tecla + Enter: devolve o texto digitado, sem wake.
"""
import os, pty, re, select, subprocess, sys, time

PATTERN = re.compile(rb"RESULT=([^|\r\n]*)\|(true|false)\|ticks=(\d+)")
failures = 0

def run(mode, keys):
    master, slave = pty.openpty()
    import fcntl, termios, struct
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))  # terminal 80x24
    proc = subprocess.Popen(["lua5.4", "tests/pty/input_poll_harness.lua", mode],
                            stdin=slave, stdout=slave, stderr=slave, close_fds=True)
    os.close(slave)
    out = b""
    def drain(seconds):
        nonlocal out
        end = time.time() + seconds
        while time.time() < end:
            r, _, _ = select.select([master], [], [], 0.1)
            if r:
                try:
                    out += os.read(master, 4096)
                except OSError:
                    return
    drain(0.6)
    for delay, data in keys:
        drain(delay)
        os.write(master, data)
    drain(3.0)
    try:
        proc.wait(timeout=10)
    except subprocess.TimeoutExpired:
        proc.kill()
    drain(0.2)
    m = PATTERN.search(out)
    return m, out

def check(cond, msg):
    global failures
    print(("OK:   " if cond else "FAIL: ") + msg)
    if not cond:
        failures += 1

# 1) Sem teclas: deve acordar.
m, out = run("wake", [])
check(m is not None and m.group(2) == b"true", "sem teclas, com buffer vazio: acorda (wake=true)")
if m is None:
    print("      saída:", out[-400:])

# 2) Tecla + Enter: devolve o texto, sem acordar.
m, out = run("type", [(0.3, b"h"), (0.2, b"i"), (0.2, b"\r")])
check(m is not None and m.group(1) == b"hi" and m.group(2) == b"false",
      "digitar 'hi' + Enter devolve 'hi' sem acordar")
if m is None:
    print("      saída:", out[-400:])

# 3) Texto parcial: não acorda enquanto há texto; Enter devolve o texto.
m, out = run("partial", [(0.0, b"a"), (2.5, b"\r")])  # texto antes do 1º ciclo ocioso
check(m is not None and m.group(1) == b"a" and m.group(2) == b"false",
      "texto parcial não acorda; Enter devolve 'a'")
if m is None:
    print("      saída:", out[-400:])

print("\nFALHAS:", failures)
sys.exit(1 if failures else 0)
