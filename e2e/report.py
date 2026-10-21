#!/usr/bin/env python3
"""e2e/report.py — Resume os relatórios do e2e (smoke, subagentes, RAM) e publica um commit status.

Uso: report.py <pasta_out>            -> markdown no stdout (GITHUB_STEP_SUMMARY)
     report.py <pasta_out> --status   -> também publica commit status (context e2e-kilo)
"""
import json, os, re, sys, urllib.request

def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return None

def peak_rss_kb(ps_log):
    """Maior RSS (KB) somado por amostra de 'ps' dos processos lua5.4."""
    try:
        per_sample = {}
        with open(ps_log) as f:
            for line in f:
                m = re.match(r"^(\d+)\s+\d+\s+(\d+)\s+lua", line)
                if m:
                    per_sample[m.group(1)] = per_sample.get(m.group(1), 0) + int(m.group(2))
        return max(per_sample.values()) if per_sample else None
    except FileNotFoundError:
        return None

def main():
    out = sys.argv[1]
    publish = "--status" in sys.argv
    smoke = load(os.path.join(out, "smoke.json"))
    subs = load(os.path.join(out, "subagents.json"))
    peak_ps = peak_rss_kb(os.path.join(out, "ram_ps.log"))

    smoke_ok = bool(smoke and smoke.get("passed"))
    subs_ok = bool(subs and subs.get("passed"))
    runs = (subs or {}).get("runs", [])
    done = sum(1 for r in runs if r.get("status") == "completed" and r.get("token_ok"))

    lines = [
        "## e2e Kilo (kilo-auto/free)",
        "",
        f"- Smoke do modelo: **{'OK' if smoke_ok else 'FALHOU'}** (exit={smoke and smoke.get('exit_code')})",
        f"- Subagentes: **{'OK' if subs_ok else 'FALHARAM'}** ({done}/{len(runs)} concluídos com token correto)",
        f"- Simultâneos observados: {(subs or {}).get('max_running_observed')}",
        f"- RAM: maior RSS de um filho {(subs or {}).get('max_child_rss_kb')} KB; pico somado (ps lua5.4) {peak_ps} KB",
        "",
        "| run | agente | status | token | duração (s) | início da resposta |",
        "|---|---|---|---|---|---|",
    ]
    for r in runs:
        head = (r.get("result_head") or "").replace("|", "\\|").replace("\n", " ")
        lines.append(f"| {r.get('label')} | {r.get('agent')} | {r.get('status')} | "
                     f"{'ok' if r.get('token_ok') else 'faltou'} | {r.get('duration_s')} | {head[:60]} |")
    orch = load(os.path.join(out, "orchestrator.json"))
    if orch:
        lines += ["", f"- Orquestrador (não bloqueante): **{'OK' if orch.get('passed') else 'não confirmado'}** "
                  f"(resposta={orch.get('orchestrator_answer_ok')}, subagentes criados={orch.get('spawned')}, "
                  f"concluído com token={orch.get('sub_completed_ok')})"]
    markdown = "\n".join(lines) + "\n"
    print(markdown)

    if publish:
        state = "success" if (smoke_ok and subs_ok) else "failure"
        orch_state = ("ok" if orch.get("passed") else
                      f"nao(resp{int(bool(orch.get('orchestrator_answer_ok')))}"
                      f",spawn{orch.get('spawned')},sub{int(bool(orch.get('sub_completed_ok')))})") if orch else "sem"
        desc = (f"smoke={'ok' if smoke_ok else 'falhou'} subs={done}/{len(runs)} "
                f"simul={(subs or {}).get('max_running_observed')} "
                f"rss_filho={(subs or {}).get('max_child_rss_kb')}kB orq={orch_state}")[:140]
        repo, sha = os.environ["GITHUB_REPOSITORY"], os.environ["GITHUB_SHA"]
        req = urllib.request.Request(
            f"https://api.github.com/repos/{repo}/statuses/{sha}",
            data=json.dumps({"state": state, "context": "e2e-kilo", "description": desc}).encode(),
            headers={"Authorization": "token " + os.environ["GITHUB_TOKEN"],
                     "Accept": "application/vnd.github+json", "Content-Type": "application/json"},
            method="POST")
        with urllib.request.urlopen(req, timeout=30) as resp:
            print(f"commit status publicado: {resp.status} ({state})")

if __name__ == "__main__":
    main()
