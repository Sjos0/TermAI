-- tests/blocos_tentativa_erro_spec.lua — #270: bloco tentativa + bloco erro final.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

package.loaded["ui.core"] = {
  c = {
    reset="\27[0m", gray="\27[38;5;245m", orange="\27[38;5;208m",
    red="\27[38;5;203m", bg_error="\27[48;5;52m", bg="\27[48;5;234m",
  },
  tw = function() return 60 end,
}

local writes = {}
local real_write = io.write
io.write = function(...)
  local s = table.concat({...})
  writes[#writes + 1] = s
  return real_write(...)
end

package.loaded["ui.spinner.retry"] = nil
local retry = require("ui.spinner.retry")
local recovery = require("agent.api.request_stream.recovery")

local function plain_join()
  return table.concat(writes):gsub("\27%[[0-9;:?]*[A-Za-z]", "")
end

-- 1) quatro show_retry → um bloco (só última tentativa)
writes = {}
retry.show_retry(1, 5, "Sem resposta do servidor", 1)
retry.show_retry(2, 5, "Sem resposta do servidor", 2)
retry.show_retry(3, 5, "Sem resposta do servidor", 4)
retry.show_retry(4, 5, "Sem resposta do servidor", 0)
local j = plain_join()
local count = 0
for _ in j:gmatch("Tentativa %d+/%d+") do count = count + 1 end
-- erase sobe; na string concatenada ainda aparecem tentativas antigas no buffer,
-- mas o último card deve ser 4/5 e ter moldura.
T(j:find("Tentativa 4/5", 1, true) ~= nil, "última tentativa 4/5 presente")
T(j:find("┌", 1, true) ~= nil and j:find("└", 1, true) ~= nil, "moldura de bloco presente")
T(j:find("48;5;52", 1, true) ~= nil or table.concat(writes):find("48;5;52", 1, true), "fundo bg_error")

-- 2) show_api_error com recover → mesmo bloco
writes = {}
retry.show_retry(1, 5, "x", 1)
retry.show_api_error("Falha após 5 tentativas — Sem resposta do servidor",
  "[recover] sequência removida: web_search")
local err = plain_join()
T(err:find("%[recover%]", 1) ~= nil, "recover dentro do bloco")
T(err:find("%[ERRO%]", 1) ~= nil, "[ERRO] dentro do bloco")
-- buffer de writes guarda frames anteriores; o card de erro final nao repinta Tentativa
T(err:find("%[ERRO%]", 1) ~= nil and err:find("┌", 1, true) ~= nil, "erro final em moldura")

-- 3) erro longo quebra (não corta com … no meio da mensagem completa)
writes = {}
local long = "HTTP 500: " .. string.rep("upstream timeout detail ", 20)
retry.show_api_error(long, nil)
local long_out = plain_join()
T(long_out:find("upstream timeout detail", 1, true) ~= nil, "erro longo presente")
T(select(2, long_out:gsub("\n", "\n")) >= 3, "erro longo gerou multiplas linhas")

-- 4) recovery retorna texto, não escreve
writes = {}
local msgs = {
  { role = "user", content = "x" },
  { role = "assistant", tool_calls = { { ["function"] = { name = "web_search" } } } },
}
local text = recovery.recover_tool_seq(msgs)
T(text ~= nil and text:find("web_search", 1, true), "recover retorna texto")
T(#writes == 0, "recover nao usa io.write")

-- 5) tw estreito ainda desenha
package.loaded["ui.core"].tw = function() return 40 end
writes = {}
retry.show_retry(1, 3, "motivo bem longo para forcar corte do motivo no meio", 2)
T(#table.concat(writes) > 0, "tw=40 desenha tentativa")
T(plain_join():find("Tentativa 1/3", 1, true), "prefixo Tentativa preservado")

io.write = real_write
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
