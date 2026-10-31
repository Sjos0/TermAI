package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/tui_render_spec.lua — Simulação da TUI: cada tool, com argumentos e saídas reais,
-- desenhada por tool_start/tool_end em várias larguras de celular. Regras de exibição:
--   R1. nenhuma linha passa da largura do terminal (em colunas, não bytes);
--   R2. texto sempre UTF-8 válido (nenhum caractere partido);
--   R3. a volta do cursor (ESC[nA) é sempre de 1 linha: o cabeçalho ocupa uma linha só;
--   R4. nenhum \r cru chega à tela;
--   R5. corpo recolhido: no máximo MAX_BODY linhas + a linha "... (N linhas)".
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures, checks = 0, 0
local function check(cond, msg)
  checks = checks + 1
  if not cond then failures = failures + 1; print("FAIL: " .. msg) end
end

local core  = require("ui.core")
local exec  = require("ui.tools_init.executor")
local card  = require("ui.card")
local tools = require("tools")

local real_tw = core.tw
local function capture(fn)
  local buf, orig = {}, io.write
  io.write = function(...) for _, v in ipairs({ ... }) do buf[#buf + 1] = tostring(v) end end
  local ok, err = pcall(fn)
  io.write = orig
  assert(ok, err)
  return table.concat(buf)
end

-- Verifica as regras sobre a saída de um card completo (start + end).
local function check_rules(out, W, label)
  -- R3: cada volta do cursor sobe exatamente 1 linha
  for n in out:gmatch("\27%[(%d+)A") do
    check(tonumber(n) == 1, label .. " R3: volta do cursor de " .. n .. " linha(s), esperado 1")
  end
  local plain = out:gsub("\27%[[%d;]*[A-Za-z]", "")
  -- R4
  check(not plain:find("\r", 1, true), label .. " R4: \\r cru na tela")
  local body_lines = 0
  for line in (plain .. "\n"):gmatch("([^\n]*)\n") do
    if line ~= "" then
      local w = utf8.len(line)
      -- R2
      check(w ~= nil, label .. " R2: UTF-8 inválido em: " .. line:sub(1, 40))
      if w then
        -- R1
        check(w <= W, label .. " R1: linha com " .. w .. " colunas, tela tem " .. W .. ": " .. line:sub(1, 50))
      end
      if line:find("└─", 1, true) or line:find("│", 1, true) then body_lines = body_lines + 1 end
    end
  end
  -- R5: corpo limitado
  check(body_lines <= card.MAX_BODY + 3, label .. " R5: corpo com " .. body_lines .. " linhas, passa do limite recolhido")
end

local WIDTHS = { 40, 50, 54, 80 }
local ARGS = {
  false,                                                      -- sem argumento
  "a.lua",                                                    -- curto
  string.rep("arquivo com acentuação ção ", 12),              -- longo, UTF-8
  "linha um\nlinha dois",                                     -- quebra de linha no argumento
}
local BODIES = {
  "",                                                         -- vazio
  "ok",                                                       -- uma linha
  (function() local t = {} for i = 1, 12 do t[i] = "resultado " .. i end return table.concat(t, "\n") end)(),
  string.rep("resultado com acentuação ção ", 12),            -- uma linha longa, UTF-8
  string.rep("🔥", 80),                                       -- emoji (largura dupla no terminal)
}

local names = {}
for name in pairs(tools.registry) do names[#names + 1] = name end
table.sort(names)
check(#names > 0, "há tools registradas")

for _, W in ipairs(WIDTHS) do
  core.tw = function() return W end
  for _, name in ipairs(names) do
    for ai, arg in ipairs(ARGS) do
      for bi, body in ipairs(BODIES) do
        local cmd = arg and (name .. " | " .. arg) or name
        local out = capture(function()
          exec.tool_start(cmd)
          exec.tool_end(cmd, body, true)
        end)
        check_rules(out, W, string.format("[%s w=%d a=%d b=%d]", name, W, ai, bi))
      end
    end
  end
end

-- Edit com diff: corpo com métricas e linhas longas (é o renderizador especializado).
local EDIT_BODY = "METRICS: added=2, removed=1\n" .. string.rep("+ acentuação ção linha nova ", 6) .. "\n- linha antiga"
for _, W in ipairs(WIDTHS) do
  core.tw = function() return W end
  local cmd = "Edit | src/arquivo_com_nome_comprido_acentuação.lua"
  local out = capture(function() exec.tool_start(cmd); exec.tool_end(cmd, EDIT_BODY, true) end)
  check_rules(out, W, string.format("[Edit diff w=%d]", W))
end

-- Cenário: exec demora, o usuário sai do Termux, o comando estoura o prazo e o resultado chega depois.
for _, W in ipairs(WIDTHS) do
  core.tw = function() return W end
  local cmd = "Exec | sleep 300 && curl -s https://exemplo.invalid/muito/longo/com/acentuação/ção"
  local timeout_out = "[TIMEOUT] comando excedeu 300 s; saída parcial: " .. string.rep("ação ", 40)
  local out = capture(function()
    exec.tool_start(cmd)
    -- (espera em segundo plano: nada é escrito enquanto o usuário está fora)
    exec.tool_end(cmd, timeout_out, false)
  end)
  check_rules(out, W, string.format("[timeout em background w=%d]", W))
  check(out:find("TIMEOUT", 1, true) ~= nil, "timeout w=" .. W .. ": o motivo do timeout aparece no card")
end

core.tw = real_tw
print(string.format("%d checagens, %d falhas", checks, failures))
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
