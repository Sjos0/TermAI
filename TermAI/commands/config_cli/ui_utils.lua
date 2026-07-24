-- commands/config_cli/ui_utils.lua
-- Utilitarios de UI: cores, separadores, helpers de input e formatacao.
local config_mod = require("config")
local M = {}

local R  = "\27[0m";  local B  = "\27[1m"
local G  = "\27[38;5;114m"; local RE = "\27[38;5;203m"
local GR = "\27[38;5;245m"; local CY = "\27[38;5;80m"
local DM = "\27[2m";        local YL = "\27[38;5;220m"

local SEP  = string.rep("─", 45)
local SEP2 = string.rep("─", 30)

local function rdl(prompt)
  io.write(CY.."  "..prompt..": "..R); io.flush()
  local ok, v = pcall(io.read)
  return ok and v or nil
end

local function cancel(s) return not s or s=="" or s=="0" end

local function row(label, val)
  io.write(string.format("  %s%-22s%s %s\n", GR, label, R, tostring(val)))
end

local function hdr(title)
  io.write("\27[2J\27[H")
  io.write("\n"..B..CY.."  "..title..R.."\n"..GR.."  "..SEP..R.."\n\n")
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
M.hdr     = hdr
M.pause   = pause
M.fmt_k   = fmt_k
M.get_cfg = get_cfg

return M
