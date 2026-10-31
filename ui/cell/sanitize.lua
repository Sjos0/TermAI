-- ui/cell/sanitize.lua — sanitiza linha de ferramenta para o card (puro).
local largura = require("ui.largura")
local M = {}

--- Mantém SGR de texto; descarta SGR de fundo; expande TAB; remove CSI não-SGR, OSC, CR, DEL.
--- Retorna texto limpo e contagem de descartes.
function M.sanitize_line(s)
  s = tostring(s or "")
  local out, discarded, col = {}, 0, 0
  local i, n = 1, #s
  while i <= n do
    local c = s:sub(i, i)
    if c == "\27" then
      -- OSC: ESC ] ... BEL or ST
      local osc = s:sub(i):match("^(\27%][^\27\7]*[\7\27\\])")
      if osc then discarded = discarded + 1; i = i + #osc
      else
        local seq = s:sub(i):match("^(\27%[[0-9;:?]*([A-Za-z]))")
        if seq then
          local letter = seq:sub(-1)
          local params = seq:match("^\27%[([0-9;:?]*)") or ""
          if letter == "m" then
            -- keep text SGR; drop bg-related
            if params == "" or params == "0" then
              out[#out + 1] = "\27[0m"
            else
              local keep = {}
              for p in (params .. ";"):gmatch("([^;]*);") do
                local n = tonumber(p)
                local drop = false
                if n == 0 then -- handled as reset above
                elseif n == 49 or (n and n >= 40 and n <= 47) or (n and n >= 100 and n <= 107) then
                  drop = true
                elseif p:find("^48") or (n == 48) then drop = true
                end
                if not drop and p ~= "" then keep[#keep + 1] = p end
              end
              if #keep > 0 then out[#out + 1] = "\27[" .. table.concat(keep, ";") .. "m" end
            end
          else
            discarded = discarded + 1 -- CSI non-SGR
          end
          i = i + #seq
        else out[#out + 1] = c; i = i + 1 end
      end
    elseif c == "\t" then
      local nsp = 8 - (col % 8)
      out[#out + 1] = string.rep(" ", nsp)
      col = col + nsp
      i = i + 1
    elseif c == "\r" or c == "\127" then
      discarded = discarded + 1
      i = i + 1
    else
      local ok, cp = pcall(utf8.codepoint, s, i)
      if ok and cp then
        local ch = utf8.char(cp)
        out[#out + 1] = ch
        col = col + largura.colunas(ch)
        i = i + #ch
      else out[#out + 1] = c; col = col + 1; i = i + 1 end
    end
  end
  return table.concat(out), discarded
end

return M
