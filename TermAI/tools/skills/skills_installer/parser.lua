local M = {}

-- Estrutura retornada por M.parse:
-- {
--   subcommand = "npx",
--   source = "@pacote" | "skills" | url,
--   operation = "install" | "add" | "update",
--   url = "https://github.com/..." | nil,
--   skills = {"nome1", "nome2"},
--   flags = { global = true, agent = nil, update = false }
-- }

function M.parse(args)
  local result = {
    subcommand = "npx",
    source = nil,
    operation = "install",
    url = nil,
    skills = {},
    flags = { global = true, agent = nil, update = false },
  }

  local i = 1
  local function next_arg()
    i = i + 1
    return args[i]
  end

  -- Pular "npx" se presente
  if args[i] == "npx" or args[i] == "skills" then i = i + 1 end

  -- Fonte: primeiro arg relevante
  local src = args[i]
  if not src then return result end

  if src == "skills" then
    result.source = "skills"
    local op = next_arg()
    if op == "add" then
      result.operation = "add"
      local url = next_arg()
      if url then result.url = url end
    end
  elseif src:sub(1, 1) == "@" then
    result.source = src
    result.operation = "install"
  elseif src:match("^https?://") then
    result.source = src
    result.url = src
    result.operation = "add"
  else
    result.source = src
  end

  -- Parsear resto dos args
  while i <= #args do
    local a = args[i]
    if a == "--skill" then
      i = i + 1
      while i <= #args and args[i]:sub(1, 2) ~= "--" do
        result.skills[#result.skills + 1] = args[i]
        i = i + 1
      end
    elseif a == "--update" then
      i = i + 1
      result.flags.update = true
    elseif a == "--g" or a == "--global" then
      result.flags.global = true
      result.flags.agent = nil
      i = i + 1
    elseif a == "--ag" then
      result.flags.global = false
      i = i + 1
      result.flags.agent = args[i]
    elseif a == "install" then
      i = i + 1
      result.operation = "install"
    else
      i = i + 1
    end
  end

  return result
end

return M