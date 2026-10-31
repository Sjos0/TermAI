-- ui/tools_init/executor.lua — Motor de orquestração visual e roteamento do ciclo de vida de ferramentas.
local core         = require("ui.core")
local parser       = require("ui.tools_init.parser")
local header       = require("ui.tools_init.header")
local default_body = require("ui.tools_init.default_body")
local edit_body    = require("ui.tools_init.edit_renderer")
local c            = core.c

local M = {}

local function render_result_body(name, out, ok, tw)
  local raw_lines = {}
  for ln in (out .. "\n"):gmatch("([^\n]*)\n") do
    if ln ~= "" then raw_lines[#raw_lines + 1] = ln end
  end
  if #raw_lines == 0 then raw_lines = {"[sem saída]"} end

  if name == "Edit" then
    edit_body.render_edit_body(raw_lines, ok, tw)
  else
    default_body.render_default_body(raw_lines, tw)
  end
end

-- Subagente: a resposta final nunca aparece na TUI. Só uma linha de erro, se falhar.
local function render_subagent_or_body(name, out, ok, tw)
  if name ~= "Subagente" then return render_result_body(name, out, ok, tw) end
  if ok then return end
  local first = ((out or "") .. "\n"):match("^([^\n]*)") or ""
  io.write(c.gray .. " └─ " .. c.red .. header.cut_cols(first, tw - 8) .. c.reset .. "\n")
end

-- Saída parcial de Exec (#176 P2). Altura do card é fixa e previsível:
-- cabeçalho + até MAX_BODY linhas + UMA linha "... (N linhas)" que é reescrita no lugar.
-- live.rows conta as linhas escritas abaixo do cabeçalho, para o redesenho do tool_end.
local live = { rows = 0, n = 0 }

local function live_reset()
  live.rows = 0
  live.n = 0
end

function M.tool_start(cmd)
  require("ui.spinner.rotulo").evento("agent_turn")
  -- Pausa o spinner sh: o printf \\r dele sobrescrevia o card e deixava
  -- a bolinha amarela órfã quando tool_end recalculava o cursor (bug intermitente).
  local TMPDIR = os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp"
  local flag = io.open(TMPDIR .. "/ta_tool_draw.flag", "w")
  if flag then flag:write("1"); flag:close() end
  local name, arg = parser.parse_cmd(cmd)
  header.write_header(c.yellow, name, arg)
  live_reset()
  if name == "Exec" then
    require("tools.exec").on_line = M.tool_chunk
  end
  io.flush()
end

-- Chega uma linha de saída de Exec enquanto o comando roda.
function M.tool_chunk(line)
  local card = require("ui.card")
  local tw   = core.tw()
  live.n = live.n + 1
  if live.n <= card.MAX_BODY then
    local line_exp = select(1, require("ui.cell.sanitize").sanitize_line(line))
    io.write(card.bg_row(c.bg, c.gray, " │ ", c.white, card.cut(line_exp, tw - 8), tw) .. "\n")
    live.rows = live.rows + 1
  else
    local hidden = live.n - card.MAX_BODY
    local txt = "... (" .. hidden .. (hidden == 1 and " linha)" or " linhas)")
    local row = card.bg_row(c.bg, c.gray, " └─ ", c.dim, txt, tw) .. "\n"
    if live.rows == card.MAX_BODY then
      io.write(row)                        -- primeira vez: a linha "..." ainda não existe
      live.rows = live.rows + 1
    else
      io.write("\27[1A\27[2K" .. row)      -- reescreve a linha "..." no mesmo lugar
    end
  end
  io.flush()
end

function M.tool_end(cmd, out, ok)
  local tw        = core.tw()
  local name, arg = parser.parse_cmd(cmd)
  if name == "Exec" then require("tools.exec").on_line = nil end
  -- Cabeçalho é sempre 1 linha (write_header corta). Contar só 1 + live.rows
  -- evita ESC[nA curto/longo e a bolinha amarela residual sob a verde.
  local lines_up = 1 + live.rows
  if name == "Subagente" then
    lines_up = lines_up + require("ui.subagent").finish_lines()
  end
  io.write(string.format("\27[%dA\27[0J", lines_up))
  live_reset()

  local actual_ok = parser.is_edit_success(out, ok)

  header.write_header(actual_ok and c.green or c.red, name, arg)
  render_subagent_or_body(name, out, actual_ok, tw)
  local TMPDIR = os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp"
  os.remove(TMPDIR .. "/ta_tool_draw.flag")
  io.write("\n"); io.flush()
end

function M.tool_replay(cmd, out, ok)
  local tw        = core.tw()
  local name, arg = parser.parse_cmd(cmd)
  if out then
    -- 1. Remove o bloco principal de lembrete do sistema (+ dupla quebra)
    out = out:gsub("\n\n%[SYSTEM: Review your progress.-%]", "")

    -- 2. Remove a linha de autorizacao de seguranca (ANTES do RESOURCE)
    --    Ordem importa: se remover RESOURCE primeiro, o \n antes de
    --    SYSTEM MESSAGE some e o pattern nao casa mais.
    out = out:gsub("\n%[SYSTEM MESSAGE: Security permission for this action was: %S+%]", "")

    -- 3. Remove a linha de metricas de recursos
    out = out:gsub("\n%[RESOURCE METRICS: Execution time: %d+ms%]", "")

    -- 4. Remove os blocos XML de Workspace Attention e TODO Status
    out = out:gsub("\n?<workspace_attention>.-</workspace_attention>", "")
    out = out:gsub("\n?<todo_status>.-</todo_status>", "")
  end
  local actual_ok = ok
  if name == "Edit" then
    actual_ok = parser.is_edit_success(out, ok)
  end
  -- Colapsa linhas em branco extras no corpo (replay não deve "esticar" a sessão).
  if out then
    out = out:gsub("\n\n\n+", "\n\n")
    out = out:match("^(.-)%s*$") or out
  end
  header.write_header(actual_ok and c.green or c.red, name, arg)
  render_subagent_or_body(name, out, actual_ok, tw)
  io.write("\n"); io.flush()
end

return M
