local memory, movie, utime, callback, set_timer_timeout, input, gui, exec, settings = memory, movie, utime, callback, set_timer_timeout, input, gui, exec, settings

local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")
local Promise = dofile(base.."/promise.lua")
callback.register('timer', function()
    Promise.update()
    set_timer_timeout(1)
end)
set_timer_timeout(1)
local game = dofile(base.."/game.lua")(Promise)
local util = dofile(base.."/util.lua")(Promise)
local serpent = dofile(base.."/serpent.lua")

game.registerHandlers()
game.getPositions()
