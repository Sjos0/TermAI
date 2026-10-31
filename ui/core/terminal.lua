-- ui/core/terminal.lua — dimensões do terminal (tw, th) e régua responsiva.
--
-- FALLBACK ÚNICO (issue #331): o número 80 aparece SÓ aqui. Quando o
-- `stty size` não responde (pipe fechado, saída não-TTY, sandbox do Android
-- sem ioctl) a largura real é desconhecida, e 80 é o padrão histórico de
-- terminal — o menor valor que não quebra os layouts de card/bloco.
-- Nenhum outro módulo escreve largura fixa: todos perguntam a core.tw().
--
-- Cache com TTL de 2 s em tempo de parede (#335/#341): os.time() avança
-- enquanto o processo espera a rede; os.clock() (CPU) não. Girar o celular
-- durante a resposta atualiza a largura no próximo card sem tecla.
return function(core)
  local W, H
  local W_at, H_at = 0, 0
  local TTL <const> = 2

  core.TW_FALLBACK = 80
  core.TH_FALLBACK = 24
  core.TW_MIN      = 20

  function core.invalidate_size()
    W, H = nil, nil
    W_at, H_at = 0, 0
  end

  local function now()
    return os.time()
  end

  local function read_stty()
    local f = io.popen("stty size 2>/dev/null")
    if not f then return nil, nil end
    local s = f:read("*a"); f:close()
    local h = tonumber(s:match("(%d+)%s+%d+"))
    local w = tonumber(s:match("%d+%s+(%d+)"))
    return w, h
  end

  function core.tw()
    local t = now()
    if W and (t - W_at) < TTL then return W end
    W = core.TW_FALLBACK
    local w = select(1, read_stty())
    if w and w > 0 then W = w end
    W_at = t
    return W
  end

  function core.th()
    local t = now()
    if H and (t - H_at) < TTL then return H end
    H = core.TH_FALLBACK
    local h = select(2, read_stty())
    if h and h > 0 then H = h end
    H_at = t
    return H
  end

  function core.regua(teto, usado)
    teto  = tonumber(teto)  or core.tw()
    usado = tonumber(usado) or 0
    return string.rep("─", math.max(0, math.min(teto, core.tw() - 2 - usado)))
  end
end
