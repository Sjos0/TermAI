-- commands/config_cli/ui_utils.lua
-- Utilitarios de UI: cores, separadores, helpers de input e formatacao.
local config_mod = require("config")
local M = {}

local R  = "\27[0m";  local B  = "\27[1m"
local G  = "\27[38;5;114m"; local RE = "\27[38;5;203m"
local GR = "\27[38;5;245m"; local CY = "\27[38;5;80m"
local DM = "\27[2m";        local YL = "\27[38;5;220m"

local core = require("ui.core")
local largura = require("ui.largura")
-- Réguas responsivas (#331): função, não valor — core.tw() é lido a cada uso,
-- então girar o celular já muda o separador. `prefixo`/`usado` é o que já
-- ocupou a linha; a régua encolhe o quanto precisar para não estourar tw.
local function SEP(usado)    return core.regua(45, usado or 2) end
local function SEP2(prefixo) return core.regua(30, require("ui.largura").colunas(prefixo or "")) end

local function rdl(prompt)
  io.write(CY.."  "..prompt..": "..R); io.flush()
  local ok, v = pcall(io.read)
  return ok and v or nil
end

local function cancel(s) return not s or s=="" or s=="0" end

local function row(label, val)
  local limite = math.max(12, core.tw() - 4)
  local prefixo = "  " .. tostring(label) .. " "
  local texto = tostring(val)
  local disponivel = limite - largura.colunas(prefixo)
  if disponivel >= 8 then
    local linhas = largura.quebrar(texto, disponivel)
    io.write(GR .. prefixo .. R .. (linhas[1] or "") .. "\n")
    for i = 2, #linhas do
      io.write(string.rep(" ", largura.colunas(prefixo)) .. linhas[i] .. "\n")
    end
    return
  end

  local rotulo = largura.quebrar(tostring(label), math.max(1, limite - 2))
  for _, linha in ipairs(rotulo) do
    io.write(GR .. "  " .. linha .. R .. "\n")
  end
  local linhas = largura.quebrar(texto, math.max(8, limite - 4))
  for _, linha in ipairs(linhas) do io.write("    " .. linha .. "\n") end
end

local function option(number, title, description)
  local prefixo = "  " .. tostring(number) .. ". "
  local limite = math.max(12, core.tw() - 4)
  local linhas = largura.quebrar(title, math.max(8, limite - largura.colunas(prefixo)))
  io.write(prefixo .. (linhas[1] or "") .. "\n")
  for i = 2, #linhas do io.write("     " .. linhas[i] .. "\n") end
  if not description or description == "" then return end
  local descricao = largura.quebrar(description, math.max(8, limite - 6))
  for _, linha in ipairs(descricao) do
    io.write("      " .. DM .. linha .. R .. "\n")
  end
end

local function hdr(title)
  io.write("\27[2J\27[H")
  io.write("\n"..B..CY.."  "..title..R.."\n"..GR.."  "..SEP()..R.."\n\n")
end

local function pause()
  io.write(GR.."\n  Pressione Enter para continuar..."..R); pcall(io.read)
end

local function fmt_k(n)
  if n >= 1000000 then return string.format("%.1fM", n/1e6)
  elseif n >= 1000 then return string.format("%.1fK", n/1000)
  else return tostring(n) end
end

local function get_cfg()
  local cfg = config_mod.load() or {}
  cfg.agents = cfg.agents or {}
  cfg.agents.defaults = cfg.agents.defaults or {}
  return cfg
end

M.R  = R;  M.B  = B;  M.G  = G;  M.RE = RE
M.GR = GR; M.CY = CY; M.DM = DM; M.YL = YL
M.SEP     = SEP
M.SEP2    = SEP2
M.rdl     = rdl
M.cancel  = cancel
M.row     = row
M.option  = option
M.hdr     = hdr
M.pause   = pause
M.fmt_k   = fmt_k
M.get_cfg = get_cfg

return M
