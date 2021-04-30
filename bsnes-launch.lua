local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")
local config = dofile(base.."/config.lua")

-- Breakpoint format: <addr>[-<addr end>][=<value>][:<rwx>[:<source>]]
--     rwx = read / write / execute flags
--     source = cpu, smp, vram, oam, cgram, sa1, sfx, sgb

--bsnes --show-debugger --break-immediately ~/neat-donk/rom.sfc

io.popen('bsnes --show-debugger --break-immediately "'..config.ROM..'"')
