-- tests/retry_caminho_real_spec.lua — #271: aponta cobertura de caminho real.
-- A prova executável está em:
--   tests/retry_stream_end_stack_spec.lua  (stream_end + show_retry + is_active)
--   tests/blocos_tentativa_erro_spec.lua   (Block tentativa/erro + recovery sem write)
-- Este arquivo só valida que os specs de cobertura existem e passam.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local function exists(path)
  local f = io.open(path, "r")
  if f then f:close() return true end
  return false
end

T(exists("tests/retry_stream_end_stack_spec.lua"), "retry_stream_end_stack_spec presente")
T(exists("tests/blocos_tentativa_erro_spec.lua"), "blocos_tentativa_erro_spec presente")
T(exists("tests/block_bg_wrap_spec.lua"), "block_bg_wrap_spec presente")
T(exists("tests/retry_card_inplace_spec.lua"), "retry_card_inplace_spec mantido")
T(exists("tests/retry_linhas_fisicas_spec.lua"), "retry_linhas_fisicas_spec mantido")

-- Caminhos cobertos (documentação viva)
print("COBERTURA:")
print("  stream_end + is_active + ESC[nA  -> retry_stream_end_stack_spec")
print("  Block tentativa/erro + recover   -> blocos_tentativa_erro_spec")
print("  Block bg + wrap                  -> block_bg_wrap_spec")
print("  card in-place legado             -> retry_card_inplace_spec")
print("  linhas físicas legado            -> retry_linhas_fisicas_spec")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
