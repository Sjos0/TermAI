# Referência Ratatui → TermAI (Block)

Fontes consultadas (GitHub `ratatui/ratatui`, branch `main`, 2026-10-30):

- `ratatui-widgets/src/block.rs`
- `ratatui-core/src/symbols/border.rs`

## Mapeamento

| # | Conceito Ratatui | Decisão | Origem | No TermAI |
|---|------------------|---------|--------|-----------|
| 1 | Borders flags (NONE/TOP/BOTTOM/LEFT/RIGHT/ALL combináveis) | **Replicar** | `block.rs` Borders | `ui/widgets/block/borders.lua` |
| 2 | BorderType PLAIN/ROUNDED/DOUBLE/THICK | **Replicar** | `symbols/border.rs` | `ui/widgets/block/symbols.lua` |
| 3 | Estilo/cor só na borda | **Replicar** | `block.rs` border_style | `border_color` em `new` + `render.lua` |
| 4 | Padding left/right/top/bottom | **Replicar** | `block.rs` Padding | `geometry.lua` |
| 5 | `inner(area)` com saturating_sub | **Replicar** | `block.rs` inner | `geometry.lua` |
| 6 | Título na borda superior (opcional) | **Adaptar** (desligado por padrão; nunca nos cantos) | `block.rs` title | `new({title=...})` |
| 7 | Widget trait / buffer de células | **Não replicar** | Ratatui Frame/Buffer | TermAI emite linhas de texto ANSI |
| 8 | Layout constraints (Constraint::*) | **Adaptar** | `layout.rs` | `ui/widgets/layout.lua` `split_equal` / `place` |

## Símbolos (PLAIN escolhido para o rodapé)

| Tipo | TL | TR | BL | BR | H | V |
|------|----|----|----|----|---|---|
| PLAIN | ┌ | ┐ | └ | ┘ | ─ | │ |
| ROUNDED | ╭ | ╮ | ╰ | ╯ | ─ | │ |
| DOUBLE | ╔ | ╗ | ╚ | ╝ | ═ | ║ |
| THICK | ┏ | ┓ | ┗ | ┛ | ━ | ┃ |

## Notas de adaptação

- Ratatui desenha em buffer de células; o TermAI monta **strings de linha** com ANSI e `io.write`.
- Largura visual no TermAI usa `ui/largura.lua` (não `utf8.len`).
- Área sempre passada por parâmetro — sem cache de `tw` entre renders.
