-- ui/input/parte_1.lua — exporta: paste_counter, pasted_texts.
return function(M, N)


  -- ── Paste storage (acessível externamente se necessário) ───────────────────
  M.paste_counter = 0

  M.pasted_texts  = {}
end
