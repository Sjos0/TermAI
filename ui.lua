local ui = {}
local renderer = require("renderer")
local c = {
  reset="\27[0m", bold="\27[1m", dim="\27[2m",
  white="\27[38;5;255m", gray="\27[38;5;245m",
  green="\27[38;5;114m", yellow="\27[38;5;220m", red="\27[38;5;203m",
  cyan="\27[38;5;80m", orange="\27[38;5;208m", blue="\27[38;5;39m",
  bg="\27[48;5;234m", bg_user="\27[48;5;236m",
  clear="\27[K", cls="\27[2J\27[H"
}
local utf8 = require("utf8")
local W
local TMPDIR = os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp"
local _spin_sh = TMPDIR.."/ta_spin.sh"
local _spin_pid = TMPDIR.."/ta_pid"
local _anim_start = nil
local _s = {}

-- ── Helpers ────────────────────────────────────────────────────────────────

local function tw()
  if W then return W end
  local f=io.popen("stty size 2>/dev/null")
  if f then local s=f:read("*a");f:close();local _,w=s:match("(%d+)%s+(%d+)");W=tonumber(w) or 80
  else W=80 end
  return W
end
local function strip(s) return (s:gsub("\27%[[0-9;]*m","")) end
local function wlen(s)
  s=strip(s or ""); local n=0
  for _,cp in utf8.codes(s) do
    n=n+(((cp>=0x1100 and cp<=0x115f) or cp>=0x2e80 or cp>0x1f000) and 2 or 1)
  end
  return n
end

-- Quebra um parágrafo em linhas sem cortar palavras ao meio
local function wrap_para(para, w)
  local out, line = {}, ""
  for word in (para.." "):gmatch("(%S+)%s*") do
    local candidate = line=="" and word or line.." "..word
    if wlen(candidate) > w then
      if line ~= "" then out[#out+1] = line end
      line = word
    else
      line = candidate
    end
  end
  if line ~= "" then out[#out+1] = line end
  if #out == 0 then out[#out+1] = "" end
  return out
end

-- wrap simples (compatível com user_msg)
local function wrap(t, w)
  return wrap_para(t, w)
end

-- ── Header / Erase ────────────────────────────────────────────────────────

function ui.header(m)
  io.write(c.cls..c.bg)
  local f = io.open("banner.txt", "r")
  if f then
    local lines = {}
    local max_w = 0
    for line in f:lines() do
      table.insert(lines, line)
      if #line > max_w then max_w = #line end
    end
    f:close()

    local term_w = tw()
    local box_w = max_w + 4
    local pad_left = math.max(0, math.floor((term_w - box_w) / 2))
    local margin = string.rep(" ", pad_left)

    -- Borda Superior
    io.write("\n"..margin.. c.dim.. c.white.. "╭".. string.rep("─", box_w - 2).. "╮\n".. c.reset)

    -- Conteúdo com Gradiente (Azul Claro para Azul Escuro)
    for i, line in ipairs(lines) do
      local ratio = (#lines > 1) and ((i - 1) / (#lines - 1)) or 0
      -- Matemática do Gradiente Azul
      local r = math.floor(60 + (0 - 60) * ratio)
      local g = math.floor(180 + (40 - 180) * ratio)
      local b = math.floor(255 + (150 - 255) * ratio)
      local color = string.format("\27[38;2;%d;%d;%dm", r, g, b)

      local padded = line.. string.rep(" ", max_w - #line)
      io.write(margin.. c.dim.. c.white.. "│ ".. c.reset.. color.. c.bold.. padded.. c.reset.. c.dim.. c.white.. " │\n".. c.reset)
    end
    -- Borda Inferior
    io.write(margin.. c.dim.. c.white.. "╰".. string.rep("─", box_w - 2).. "╯\n".. c.reset)
  end

  -- Rodapé do Banner (Diretório esquerdo, Modelo direito)
  local pwd = os.getenv("PWD") or ""
  pwd = pwd:gsub(os.getenv("HOME") or "", "~")
  local left_txt = pwd
  local right_txt = m
  local spaces = tw() - #left_txt - #right_txt
  if spaces < 1 then spaces = 1 end
  io.write(c.green.. left_txt.. string.rep(" ", spaces).. c.cyan.. right_txt.. c.reset.. "\n\n")

  -- Menu de Dicas
  io.write(c.dim.. c.white.. " Dicas para começar:\n".. c.reset)
  io.write(c.gray.. " 1. Faça perguntas, edite arquivos ou rode comandos.\n")
  io.write(" 2. Seja específico para que eu possa usar minhas ferramentas nativas.\n")
  io.write(" 3. Seus arquivos em workspace/ moldam a minha identidade e memória.\n".. c.reset.. "\n")
end

function ui.erase_input(raw)
  local w=tw()
  local linhas=math.max(1,math.ceil((2+#raw)/w))
  for _=1,linhas do io.write("\27[1A\27[2K") end
end

-- ── Mensagens ─────────────────────────────────────────────────────────────

function ui.user_msg(t)
  t=renderer.render(t)
  local w=tw()
  for i,ln in ipairs(wrap(t,w-4)) do
    local prefix=i==1 and "> " or " "
    local str = prefix..ln
    local pad = string.rep(" ", math.max(0, w - wlen(str)))
    io.write(c.bg_user..str..pad..c.reset.."\n")
  end
  io.write("\n")
end

-- Exibe mensagem da IA respeitando parágrafos e sem cortar palavras
function ui.ai_msg(t)
  t = renderer.render(t)
  local w = tw() - 4
  local first_line = true

  for para in (t.."\n"):gmatch("([^\n]*)\n") do
    local trimmed = para:match("^%s*(.-)%s*$")
    if trimmed == "" then
      -- linha em branco: preserva separação de parágrafo
      io.write("\n")
    else
      local lines = wrap_para(trimmed, w)
      for i, ln in ipairs(lines) do
        if first_line and i == 1 then
          io.write(c.white.."⬤ "..ln.."\n")
          first_line = false
        else
          io.write(" "..ln.."\n")
        end
      end
    end
  end

  io.write("\n"); io.flush()
end

-- stream com efeito de digitação suave
function ui.ai_msg_stream(t)
  t = renderer.render(t)
  local w = tw() - 4
  local first_line = true

  for para in (t.."\n"):gmatch("([^\n]*)\n") do
    local trimmed = para:match("^%s*(.-)%s*$")
    if trimmed == "" then
      io.write("\n")
    else
      local lines = wrap_para(trimmed, w)
      for i, ln in ipairs(lines) do
        if first_line and i == 1 then
          io.write(c.white.."⬤ "..c.reset)
          first_line = false
        else
          io.write(" ")
        end
        local word_count = 0
        for word in ln:gmatch("%S+%s*") do
          io.write(word)
          io.flush()
          word_count = word_count + 1
          -- Pequeno delay a cada 2 palavras para o stream ficar fluido
          if word_count % 2 == 0 then os.execute("sleep 0.02") end
        end
        io.write("\n")
      end
    end
  end
  io.write("\n"); io.flush()
end

-- ── Tool blocks ────────────────────────────────────────────────────────────

local MAX_TOOL_LINES=4

function ui.tool_start(cmd)
  io.write(c.yellow.."⬤ "..c.reset..c.bold.."Tool"..c.reset
   .."("..c.cyan..cmd..c.reset..")\n")
  io.flush()
end

function ui.tool_end(cmd,out,ok)
  io.write("\27[1A\27[2K")
  local dot=ok and c.green or c.red
  io.write(dot.."⬤ "..c.reset..c.bold.."Tool"..c.reset
   .."("..c.cyan..cmd..c.reset..")\n")
  local lines={}
  for ln in (out.."\n"):gmatch("([^\n]*)\n") do
    if ln~="" then lines[#lines+1]=ln end
  end
  if #lines==0 then lines={"[sem saída]"} end
  local visible=math.min(#lines,MAX_TOOL_LINES)
  for i=1,visible do
    local prefix=i==visible and " └─ " or " │ "
    io.write(c.gray..prefix..c.white..lines[i]:sub(1,tw()-8)..c.reset.."\n")
  end
  if #lines>MAX_TOOL_LINES then
    io.write(c.gray.." └─ "..c.dim.."... ("
     ..(#lines-MAX_TOOL_LINES).." linhas)"..c.reset.."\n")
  end
  io.write("\n"); io.flush()
end

-- ── Spinner ────────────────────────────────────────────────────────────────

function ui.kill_spinner()
  os.execute("kill $(cat ".._spin_pid.." 2>/dev/null) 2>/dev/null"
   .."; rm -f ".._spin_pid.." ".._spin_sh)
  io.write("\r\27[K"); io.flush()
end

function ui.start_thinking()
  _anim_start = os.time()
  local f = io.open(_spin_sh,"w")
  f:write("#!/bin/sh\ni=0;s=0;c=0\nwhile true;do\n")
  f:write("case $i in\n")
  f:write("0)x='⠋';;1)x='⠙';;2)x='⠹';;3)x='⠸';;4)x='⠼';;\n")
  f:write("5)x='⠴';;6)x='⠦';;7)x='⠧';;8)x='⠇';;9)x='⠏';;esac\n")
  f:write("printf '\\r\\033[33m%s\\033[0m \\033[1mPensando...\\033[0m"
   .." \\033[90m(%ds)\\033[0m\\033[K' \"$x\" \"$s\"\n")
  f:write("sleep 0.1\n")
  f:write("c=$((c+1));[ $((c%10)) -eq 0 ] && s=$((s+1))\n")
  f:write("i=$(( (i+1)%10 ))\ndone\n")
  f:close()
  os.execute("sh ".._spin_sh.." & echo $! > ".._spin_pid)
  io.flush()
end

function ui.stop_thinking()
  local elapsed=os.time()-(_anim_start or os.time())
  ui.kill_spinner(); _anim_start=nil
  return elapsed
end

-- ── Streaming — acumula tudo, exibe depois ────────────────────────────────

function ui.stream_start()
  _s = { full="", started=false }
end

function ui.stream_token(tok)
  _s.full = _s.full.. tok
  if not _s.started then
    ui.kill_spinner()
    _s.started = true
  end
end

function ui.stream_end()
  return _s.full
end

-- ── Misc ───────────────────────────────────────────────────────────────────

function ui.agent_limit(n)
  io.write(c.yellow.." ⚠ limite de "..n.." iterações atingido\n"..c.reset)
end
function ui.divider()
  io.write(c.gray..string.rep("─",tw())..c.reset.."\n")
end
function ui.footer(a,b,elapsed)
  local t=elapsed and
    string.format(" | \27[38;5;80m⏱ %ds\27[0m\27[38;5;245m",elapsed) or ""
  io.write(c.gray..("tokens: %d/%d (%.1f%%)"):format(a,b,a/b*100)
   ..t.." | gw: connected"..c.reset.."\n")
end
function ui.loading(t) io.write("\r"..c.gray..t..c.clear..c.reset);io.flush() end
function ui.clear_loading() io.write("\r\27[K");io.flush() end
return ui
