package.path = "./?.lua;./?/init.lua;" .. package.path
local core = require("ui.core")

-- Naive/old implementation of strip
local function old_strip(s)
  return (s:gsub("\27%[[0-9;]*m", ""))
end

-- Prepare test data
local clean_strings = {
  "hello",
  "world",
  "TermAI",
  "This is a longer paragraph without any escape sequences in it.",
  "local core = require('ui.core')",
  "pnpm test",
  "poda_mecanica"
}

local colored_strings = {
  "\27[31mhello\27[0m",
  "\27[1mworld\27[0m",
  "\27[38;5;220m[pasted_text#1 + 5 linha(s)]\27[39m",
  "\27[38;5;71m✓\27[0m",
}

local iterations = 100000

print("=== Running Benchmark for core.strip ===")

-- 1. Benchmark clean strings
do
  local start_time = os.clock()
  for i = 1, iterations do
    for _, s in ipairs(clean_strings) do
      local _ = old_strip(s)
    end
  end
  local end_time = os.clock()
  local old_duration = end_time - start_time

  start_time = os.clock()
  for i = 1, iterations do
    for _, s in ipairs(clean_strings) do
      local _ = core.strip(s)
    end
  end
  end_time = os.clock()
  local new_duration = end_time - start_time

  print(string.format("Clean Strings (no ESC) - %d iterations:", iterations))
  print(string.format("  Old strip (gsub): %.4fs", old_duration))
  print(string.format("  New strip (find): %.4fs", new_duration))
  local speedup = (old_duration - new_duration) / old_duration * 100
  print(string.format("  Speedup: %.2f%% faster", speedup))
end

-- 2. Benchmark colored strings
do
  local start_time = os.clock()
  for i = 1, iterations do
    for _, s in ipairs(colored_strings) do
      local _ = old_strip(s)
    end
  end
  local end_time = os.clock()
  local old_duration = end_time - start_time

  start_time = os.clock()
  for i = 1, iterations do
    for _, s in ipairs(colored_strings) do
      local _ = core.strip(s)
    end
  end
  end_time = os.clock()
  local new_duration = end_time - start_time

  print(string.format("Colored Strings (with ESC) - %d iterations:", iterations))
  print(string.format("  Old strip (gsub): %.4fs", old_duration))
  print(string.format("  New strip (find + gsub): %.4fs", new_duration))
end

print("=== Benchmark completed ===")
