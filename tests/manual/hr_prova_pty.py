#!/usr/bin/env python3
"""Prova no caminho real (#324): PTY ao vivo + replay, medindo a linha horizontal.

Ao vivo: gera a resposta e mede a linha num pseudo-terminal de largura fixa,
onde core.tw() lê o tamanho real via stty.
Replay: reenvia uma resposta gravada (fixtures/resposta_final.md) ao renderer.

Uso (na raiz do repo):  python3 tests/manual/hr_prova_pty.py
Sai com 0 se todas as larguras (40/50/80) baterem ao vivo e no replay.
"""
import fcntl, os, pty, struct, subprocess, sys, termios

SCRIPT  = "tests/manual/hr_prova_caminho.lua"
FIXTURE = "tests/manual/fixtures/resposta_final.md"


def run(cols, fixture=None):
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, cols, 0, 0))
    cmd = ["lua5.4", SCRIPT] + ([fixture] if fixture else [])
    p = subprocess.Popen(cmd, stdin=slave, stdout=slave, stderr=slave, close_fds=True)
    os.close(slave)
    out = b""
    while True:
        try:
            data = os.read(master, 4096)
        except OSError:
            break
        if not data:
            break
        out += data
    p.wait()
    os.close(master)
    return out.decode("utf-8", "replace")


def check(cols, fixture, label):
    txt = run(cols, fixture)
    tw = hr = None
    for line in txt.splitlines():
        if line.startswith("TW="):
            tw = int(line[3:])
        elif line.startswith("HR_LARGURA="):
            hr = int(line[11:])
    ok = (tw == cols and hr == cols)
    print("%s  %-9s cols=%d -> TW=%s HR_LARGURA=%s" %
          ("OK  " if ok else "FAIL", label, cols, tw, hr))
    return ok


def main():
    ok = True
    print("== AO VIVO (PTY real, core.tw() via stty) ==")
    for cols in (40, 50, 80):
        ok = check(cols, None, "ao_vivo") and ok
    print("== REPLAY (resposta gravada reenviada ao renderer) ==")
    for cols in (40, 50, 80):
        ok = check(cols, FIXTURE, "replay") and ok
    print("RESULTADO:", "PASS" if ok else "FAIL")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()