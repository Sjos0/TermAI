-- tools/editor/edit_engine/multi_edit.lua — Orquestracao de multiplas edicoes.
-- Conteudo original congelado, ordem reversa, overlap, validacao previa.
-- Copiado do OpenClaw: multi-edit com atomicidade.
-- Autor: Ameno | Data: 2026-05-30 | Refatoracao editor-lua
-- Fix Bug#15: patches "lines" usam posicao direta; matcher/validator intocados.


local M = {}

local N = require("tools.editor.edit_engine.multi_edit.nucleo")(M)
require("tools.editor.edit_engine.multi_edit.parte_1")(M, N)

return M
