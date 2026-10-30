-- tests/tamanho_150_spec.lua — #226: nenhum .lua fora de lib/ e tests/ > 150 linhas
-- lib/ é excluído (ex.: lib/json.lua = rxi/json, terceiros).
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local h = io.popen("git ls-files '*.lua'")
local bad = {}
for path in h:lines() do
  if path:match("^lib/") or path:match("^tests/") then goto continue end
  local n = 0
  for _ in io.lines(path) do n = n + 1 end
  if n > 150 then bad[#bad + 1] = string.format("%s (%d)", path, n) end
  ::continue::
end
h:close()
T(#bad == 0, "todos <=150 fora lib/tests" .. (#bad > 0 and (": " .. table.concat(bad, ", ")) or ""))
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
