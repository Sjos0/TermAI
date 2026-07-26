local state         = require("ui.thinking_parser.state")
local constants     = require("ui.thinking_parser.constants")
local decode        = require("ui.thinking_parser.decode")
local tag_finder    = require("ui.thinking_parser.tag_finder")
local buf_utils     = require("ui.thinking_parser.buffer")
local depth_tracker = require("ui.thinking_parser.depth_tracker")

local OPEN_TOOL      = constants.OPEN_TOOL
local CLOSE_TOOL     = constants.CLOSE_TOOL
local OPEN_THINKING  = constants.OPEN_THINKING
local MATCHING_CLOSE = constants.MATCHING_CLOSE

local decode_entities     = decode.decode_entities
local find_first          = tag_finder.find_first
local find_any            = tag_finder.find_any
local safe_release        = buf_utils.safe_release
local find_matching_close = depth_tracker.find_matching_close

local M = {}

function M.feed(tok, stream_reasoning, stream_token)
  state.buf = state.buf .. decode_entities(tok)

  while #state.buf > 0 do

    -- ── CONTENT ──────────────────────────────────────────────────────
    if state.mode == "content" then
      local ts, te       = find_first(state.buf, OPEN_TOOL)
      local hs, he, htag = find_any(state.buf, OPEN_THINKING)

      local s, e, which, found
      if ts and (not hs or ts <= hs) then
        s, e, which, found = ts, te, "tool",     OPEN_TOOL
      elseif hs then
        s, e, which, found = hs, he, "thinking", htag
      end

      if s then
        local before = state.buf:sub(1, s - 1)
        if before ~= "" then stream_token(before) end
        state.buf = state.buf:sub(e + 1)
        if which == "tool" then
          stream_token(OPEN_TOOL)
          depth_tracker.reset()
          state.mode = "tool"
        else
          state.mode   = "thinking"
          state.opener = found
        end
      else
        local watch = { OPEN_TOOL }
        for _, v in ipairs(OPEN_THINKING) do watch[#watch+1] = v end
        local rel = safe_release(state.buf, watch)
        if rel > 0 then
          stream_token(state.buf:sub(1, rel))
          state.buf = state.buf:sub(rel + 1)
        end
        break
      end

    -- ── THINKING ─────────────────────────────────────────────────────
    elseif state.mode == "thinking" then
      local close = MATCHING_CLOSE[state.opener] or "</think>"
      local s     = state.buf:find(close, 1, true)
      if s then
        local e = s + #close - 1
        local before = state.buf:sub(1, s - 1)
        if before ~= "" then stream_reasoning(before) end
        state.buf    = state.buf:sub(e + 1)
        state.mode   = "content"
        state.opener = nil
      else
        local rel = safe_release(state.buf, { close })
        if rel > 0 then
          stream_reasoning(state.buf:sub(1, rel))
          state.buf = state.buf:sub(rel + 1)
        end
        break
      end

    -- ── TOOL ─────────────────────────────────────────────────────────
    -- Depth tracking: so sai quando encontra o </tool> que fecha o bloco
    -- EXTERNO (depth chega a 0).
    --
    -- REGRA CRITICA: Se find_matching_close retornar nil, NAO liberamos
    -- nada via safe_release. Aguardamos mais tokens com o _buf intacto.
    --
    -- Por que? safe_release poderia liberar um <tool> interno antes do
    -- seu </tool> chegar. No proximo token, find_matching_close veria o
    -- </tool> interno como se fosse o externo (depth ficaria errado),
    -- saindo prematuramente do modo tool e corrompendo o bloco.
    elseif state.mode == "tool" then
      local found_s = find_matching_close(state.buf)
      if found_s then
        local e = found_s + #CLOSE_TOOL - 1
        local before = state.buf:sub(1, found_s - 1)
        if before ~= "" then stream_token(before) end
        stream_token(CLOSE_TOOL)
        state.buf  = state.buf:sub(e + 1)
        state.mode = "content"
      else
        -- </tool> correspondente ainda nao chegou.
        -- Aguarda proximos tokens com _buf intacto.
        break
      end
    end

  end
end

return M
