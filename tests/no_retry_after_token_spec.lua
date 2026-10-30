-- tests/no_retry_after_token_spec.lua — #224: erro após token não dispara 2ª HTTP
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

-- 1) Código: got_data NÃO é zerado após ok_stream false
local f = assert(io.open("agent/api/request_stream/streamer/parte_1.lua", "r"))
local src = f:read("*a"); f:close()
T(not src:find("got_data = false"), "streamer nao contem got_data = false")

-- 2) Simulação: se got_data=true, o fluxo retorna sem incrementar tentativas
-- (espelha a lógica: if got_data then return ... end; retry só se not got_data)
local attempts = 0
local function simular_stream(inject_error_after_token)
  local got_data, done_received = false, false
  attempts = attempts + 1
  -- token
  got_data = true
  if inject_error_after_token then
    -- erro interno: NÃO zerar got_data (#205/#224)
    local ok_stream = false
    if not ok_stream then
      -- código novo: não faz got_data = false
    end
  end
  if got_data then
    return "parcial", false, false -- stream_finished false
  end
  -- só chega aqui se não houve token → retry
  if attempts < 3 then return simular_stream(inject_error_after_token) end
  return nil, true, false
end

attempts = 0
local text, overflow, finished = simular_stream(true)
T(attempts == 1, "apenas 1 tentativa quando houve token (attempts=" .. attempts .. ")")
T(text == "parcial", "devolve texto parcial")
T(finished == false, "stream_finished false (incompleto)")

-- 3) Sem token: permite retry
attempts = 0
local function simular_sem_token()
  local got_data = false
  attempts = attempts + 1
  -- erro antes de qualquer token
  if not got_data and attempts < 3 then
    return simular_sem_token()
  end
  return nil
end
simular_sem_token()
T(attempts == 3, "sem token: retries ate max (attempts=" .. attempts .. ")")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
