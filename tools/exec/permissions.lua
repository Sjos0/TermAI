-- tools/exec/permissions.lua — Fachada do gerenciador de permissões e regras do TermAI
-- Refatorado a partir do monólito de 309 linhas (Issue #26).
-- Apenas importa submódulos e reexporta a API pública. Zero lógica aqui.
local matcher = require("tools.exec.permissions.matcher")
local session = require("tools.exec.permissions.session")
local denial  = require("tools.exec.permissions.denial")
local rules   = require("tools.exec.permissions.rules")
local check   = require("tools.exec.permissions.check")

local M = {}

-- Matching
M.wildcard_to_pattern = matcher.wildcard_to_pattern
M.matches_rule        = matcher.matches_rule

-- Sessão (ferramentas)
M.get_session_status = session.get_status
M.set_session_status = session.set_status

-- Denial tracking
M.increment_denial = denial.increment
M.get_denial_count = denial.get_count
M.reset_denials    = denial.reset

-- Regras allow/deny
M.add_rule    = rules.add
M.remove_rule = rules.remove

-- Modo + verificação
M.get_mode       = check.get_mode
M.set_mode       = check.set_mode
M.command_exists = check.command_exists
M.check          = check.check

return M
