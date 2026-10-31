-- ui/core/terminal.lua — dimensões do terminal (tw, th) e régua responsiva.
--
-- FALLBACK ÚNICO (issue #331): o número 80 aparece SÓ aqui. Quando o
-- `stty size` não responde (pipe fechado, saída não-TTY, sandbox do Android
-- sem ioctl) a largura real é desconhecida, e 80 é o padrão histórico de
-- terminal — o menor valor que não quebra os layouts de card/bloco.
-- Nenhum outro módulo escreve largura fixa: todos perguntam a core.tw(),
-- que é lido a cada renderização (com core.invalidate_size() na virada).
return function(core)
  local W, H

  core.TW_FALLBACK = 80   -- largura usada quando a real é desconhecida
  core.TH_FALLBACK = 24   -- altura usada quando a real é desconhecida
  core.TW_MIN      = 20   -- guarda de sanidade (não é largura de tela):
                          -- abaixo disso as contas de redesenho ficam absurdas.

  function core.invalidate_size()
    W = nil
    H = nil
  end

  function core.tw()
    if W then return W end
    W = core.TW_FALLBACK
    local f = io.popen("stty size 2>/dev/null")
    if f then
      local s = f:read("*a"); f:close()
      -- `stty size` pode não responder (pipe, saída não-TTY, sandbox sem ioctl):
      -- sem match, tonumber(nil) devolve nil e o fallback acima permanece.
      -- NUNCA usar select()/múltiplos retornos aqui: sem match, select()
      -- devolve zero valores e tonumber() explodiria sem argumentos.
      local w = tonumber(s:match("%d+%s+(%d+)"))
      if w and w > 0 then W = w end
    end
    return W
  end

  function core.th()
    if H then return H end
    H = core.TH_FALLBACK
    local f = io.popen("stty size 2>/dev/null")
    if f then
      local s = f:read("*a"); f:close()
      -- Mesma guarda de core.tw(): sem match, fica o fallback (TH_FALLBACK).
      local h = tonumber(s:match("(%d+)%s+%d+"))
      if h and h > 0 then H = h end
    end
    return H
  end

  -- Separador horizontal responsivo (#331).
  -- teto  = tamanho desejado em tela larga (mantém o visual de hoje);
  -- usado = colunas já ocupadas na linha (prefixo), para a régua encolher e a
  --         linha inteira caber em tw. Nada é congelado: core.tw() é lido
  --         a cada chamada, então girar o celular já muda o separador.
  function core.regua(teto, usado)
    teto  = tonumber(teto)  or core.tw()
    usado = tonumber(usado) or 0
    return string.rep("─", math.max(0, math.min(teto, core.tw() - 2 - usado)))
  end
end
