-- ui/core/terminal.lua — dimensões do terminal (tw, th) com cache até core.invalidate_size().
return function(core)
  -- ── Dimensões do terminal ──────────────────────────────────────────────────
  local W, H

  function core.invalidate_size()
    W = nil
    H = nil
  end

  function core.tw()
    if W then return W end
    local f = io.popen("stty size 2>/dev/null")
    if f then
      local s = f:read("*a"); f:close()
      local _, w = s:match("(%d+)%s+(%d+)")
      W = tonumber(w) or 80
    else W = 80 end
    return W
  end

  function core.th()
    if H then return H end
    local f = io.popen("stty size 2>/dev/null")
    if f then
      local s = f:read("*a"); f:close()
      local h = s:match("(%d+)%s+%d+")
      H = tonumber(h) or 24
    else H = 24 end
    return H
  end
end
