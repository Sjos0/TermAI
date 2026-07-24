-- tools/error_feedback/init.lua -- Fachada do sistema de feedback de erros.
local M = {}

local validator = require("tools.error_feedback.validator")
local feedback  = require("tools.error_feedback.feedback")
local post_exec = require("tools.error_feedback.post_exec")
local fuzzy     = require("tools.error_feedback.fuzzy_match")
local whitelist = require("tools.error_feedback.tool_whitelist")

function M.detect_malformed_xml(text)
  return validator.detect_malformed_xml(text)
end

function M.generate_feedback(errors)
  return feedback.generate(errors)
end

function M.find_closest(input, candidates)
  return fuzzy.find_closest(input, candidates)
end

function M.post_exec_analyze(tool_name, arg, result)
  return post_exec.analyze(tool_name, arg, result)
end

function M.accepts_empty_arg(tool_name)
  return whitelist.accepts_empty_arg(tool_name)
end

return M
