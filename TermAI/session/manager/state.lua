-- state.lua — Estado compartilhado do gerenciador de sessões.
-- O cache do require() garante que todos os módulos compartilhem
-- a mesma instância desta tabela (padrão singleton em Lua).
local M = {}
M._index   = nil  -- índice de sessões carregado do store
M._current = nil  -- ID da sessão ativa
M._config  = {}   -- configuração injetada por M.init
return M
