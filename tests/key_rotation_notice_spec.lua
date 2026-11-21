package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local retry = require("ui.spinner.retry")
local writes = {}
local old_write, old_flush = io.write, io.flush
io.write = function(value) writes[#writes + 1] = tostring(value) end
io.flush = function() end

retry.show_key_rotation("openrouter\27[31m\27[2J", 1, 2, 3)
local rendered = table.concat(writes)
local pass = rendered:find("openrouter", 1, true) ~= nil
  and rendered:find("chave 1 falhou", 1, true) ~= nil
  and rendered:find("chave 2/3", 1, true) ~= nil
  and rendered:find("\27[2J", 1, true) == nil
  and rendered:find("\27[31m", 1, true) == nil
retry.clear_retry_lines()
local cleared = table.concat(writes):find("\27[J", 1, true) ~= nil
io.write, io.flush = old_write, old_flush

print(pass and "PASS rotation notice renders provider and indices"
  or "FAIL rotation notice content")
print(cleared and "PASS rotation notice participates in retry cleanup"
  or "FAIL rotation notice cleanup")
if not (pass and cleared) then os.exit(1) end
