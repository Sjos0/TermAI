# Ambiente: Ubuntu CI e Termux (aparelho)

## Premissa registrada (Samuel, 2026-10-30)

> "Imagine que o Termux funciona da mesma forma que o Ubuntu; se funciona no Ubuntu Linux, deve também funcionar no Termux, porque é um simulador Linux."

Pedido explícito de registro. **Não é regra técnica verdadeira** — ver ressalva abaixo.

## Ressalva técnica

Termux **não é um simulador Linux**. É um userland Linux sobre Android, com diferenças que afetam o TermAI:

| Aspecto | Ubuntu (CI) | Termux |
|---------|-------------|--------|
| libc | glibc | **Bionic** (stdio/EOF e `os.tmpname` diferem) |
| Prefixo | `/usr` | `$PREFIX` (`/data/data/com.termux/files/usr`) |
| `/tmp` | gravável | **sem `/tmp` gravável** — use `$TMPDIR` |
| `stty` / `date` / `curl` | builds distro | builds Termux (flags podem diferir) |
| Processos em background | estáveis | Android pode encerrar |

**Conclusão:** passar no CI Ubuntu é **necessário** e **não suficiente** para o aparelho.

## Política de validação

1. **Toda mudança** deve passar no CI Ubuntu (suíte Lua + PTY).
2. Itens sensíveis a terminal, Bionic, `$PREFIX`, `$TMPDIR` e background ficam na **lista de pendências no aparelho** do relatório de release.
3. Nenhum teste automatizado deve assumir "Termux = Ubuntu" sem nota explícita neste documento.

## Pendências típicas no aparelho

- Exec com ✅/❌ na mesma linha (bolinha amarela).
- Card de retry 1/5…5/5.
- Duas instâncias TUI (spinner/payload).
- Code fence com fundo contínuo.
- Rodapé com moldura (após #250).
- Replay com espaçamento.
