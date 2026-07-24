-- session/store.lua — Gerenciador de persistência de sessões (Padrão Fachada).
local M = {}

-- Mantém a compatibilidade de exposição estática do diretório
local common = require("session.store.common")
M.SESSIONS_DIR = common.SESSIONS_DIR

-- Carrega submódulos especializados de domínio
local index  = require("session.store.index")
local reader = require("session.store.reader")
local writer = require("session.store.writer")

-- Reexporta a API mapeando idêntico ao contrato anterior
M.ensure_dir                = index.ensure_dir
M.load_index                = index.load_index
M.save_index                = index.save_index

M.read_entries              = reader.read_entries
M.read_active_entries       = reader.read_active_entries
M.read_messages             = reader.read_messages

M.append_entry              = writer.append_entry
M.write_header              = writer.write_header
M.append_message            = writer.append_message
M.delete_file               = writer.delete_file
M.list_transcript_files     = writer.list_transcript_files
M.rewrite_compacted_session = writer.rewrite_compacted_session

return M
