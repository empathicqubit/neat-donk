print(string.hex(bit.compose(0xef, 0xbe)))
local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")
local game = dofile(base.."/game.lua")

function on_input()
end