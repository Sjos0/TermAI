-- agent/api/summarizer/runner/parte_1.lua — exporta: _kill_curl, _start_curl.
return function(M, N)
  local kill_curl, start_curl = N.kill_curl, N.start_curl


  -- Exportado só para o spec de regressão (#73); não faz parte da API pública.
  M._kill_curl = kill_curl


  M._start_curl = start_curl
end
