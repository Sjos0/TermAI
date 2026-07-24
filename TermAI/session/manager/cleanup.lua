-- cleanup.lua — Remove sessões inativas conforme política de manutenção.
local state      = require("session.manager.state")
local date_utils = require("session.manager.date_utils")
local store      = require("session.store")
local M = {}

local function cleanup(dry_run)
  local mc          = state._config.maintenance or {}
  local prune_days  = mc.prune_after_days or 30
  local max_entries = mc.max_entries      or 100
  local now         = os.time()
  local prune_secs  = prune_days * 86400
  local removed, kept = {}, {}

  for _, s in ipairs(state._index.sessions) do
    local last = s.last_activity or s.updated_at or s.created_at or ""
    local lt   = date_utils.parse_iso(last)
    local age  = lt and (now - lt) or 0
    if age > prune_secs and s.id ~= state._current then
      removed[#removed + 1] = s
    else
      kept[#kept + 1] = s
    end
  end

  if #kept > max_entries then
    table.sort(kept, function(a, b)
      return (a.last_activity or a.updated_at or "")
           < (b.last_activity or b.updated_at or "")
    end)
    while #kept > max_entries do
      local oldest = table.remove(kept, 1)
      if oldest.id ~= state._current then
        removed[#removed + 1] = oldest
      else break end
    end
  end

  if not dry_run then
    for _, s in ipairs(removed) do
      store.delete_file(s.id)
      for i, idx_s in ipairs(state._index.sessions) do
        if idx_s.id == s.id then
          table.remove(state._index.sessions, i); break
        end
      end
    end
    store.save_index(state._index)
  end

  return removed, kept
end

M.cleanup = cleanup
return M
