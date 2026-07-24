-- agent/loop/tool_runner/tracker.lua — Rastreamento de modificações no workspace.
local M = {}

function M.track_file(ctx, tool_name, args, success)
  if not success then return end
  if type(args) ~= "table" then return end
  local path = args.path
  if not path or type(path) ~= "string" or path == "" then return end

  ctx.session_files = ctx.session_files or {
    read    = { set = {}, list = {} },
    written = { set = {}, list = {} },
    edited  = { set = {}, list = {} }
  }

  local function add_tracked_file(category, file_path)
    local cat = ctx.session_files[category]
    if cat.set[file_path] then
      for idx, p in ipairs(cat.list) do
        if p == file_path then
          table.remove(cat.list, idx)
          break
        end
      end
      table.insert(cat.list, file_path)
    else
      cat.set[file_path] = true
      table.insert(cat.list, file_path)
      if #cat.list > 10 then
        local oldest = table.remove(cat.list, 1)
        cat.set[oldest] = nil
      end
    end
  end

  if tool_name == "Read" then
    add_tracked_file("read", path)
  elseif tool_name == "Write" then
    add_tracked_file("written", path)
  elseif tool_name == "Edit" then
    add_tracked_file("edited", path)
  end
end

return M
