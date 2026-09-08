-- providers/google_grounding/response_extractor.lua — Extração de texto, fontes e queries da resposta Interactions API.
local M = {}

--- Extrair texto e fontes de uma resposta Interactions API
-- @param data table Resposta decodificada do JSON
-- @return string, table, table Texto da resposta, lista de fontes {url, title}, queries
function M.extract_response(data)
  local response_text = ""
  local sources = {}
  local queries = {}

  -- Buscar em output_text primeiro (fallback API clássica)
  if data.output_text and data.output_text ~= "" then
    response_text = data.output_text
  end

  -- Buscar em steps (formato Interactions API)
  if data.steps then
    for _, step in ipairs(data.steps) do
      -- thought: raciocínio do modelo (ignorar)
      -- google_search_call: queries executadas
      if step.type == "google_search_call" and step.arguments then
        if step.arguments.queries then
          for _, q in ipairs(step.arguments.queries) do
            queries[#queries + 1] = q
          end
        end
      end

      -- model_output: texto final com annotations
      if step.type == "model_output" and step.content then
        for _, block in ipairs(step.content) do
          -- Texto da resposta
          if block.type == "text" and block.text then
            response_text = response_text .. block.text
          end

          -- Annotations (citações inline)
          if block.annotations then
            for _, ann in ipairs(block.annotations) do
              if ann.type == "url_citation" and ann.url then
                sources[#sources + 1] = {
                  url = ann.url,
                  title = ann.title or ann.url,
                  start = ann.start_index,
                  ["end"] = ann.end_index,
                }
              end
            end
          end
        end
      end
    end
  end

  -- Fallback: grounding_metadata (formato antigo generateContent)
  if #sources == 0 then
    local meta = data.grounding_metadata
    if meta and meta.grounding_chunks then
      for _, chunk in ipairs(meta.grounding_chunks) do
        if chunk.web and chunk.web.uri then
          sources[#sources + 1] = { url = chunk.web.uri, title = chunk.web.title or chunk.web.uri }
        end
      end
    end
    -- camelCase fallback
    if #sources == 0 and meta and meta.groundingChunks then
      for _, chunk in ipairs(meta.groundingChunks) do
        if chunk.web and chunk.web.uri then
          sources[#sources + 1] = { url = chunk.web.uri, title = chunk.web.title or chunk.web.uri }
        end
      end
    end
  end

  return response_text, sources, queries
end

return M
