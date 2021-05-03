local memory, movie, utime, callback, set_timer_timeout = memory, movie, utime, callback, set_timer_timeout

local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")
local Promise = dofile(base.."/promise.lua")
callback.register('timer', function()
    Promise.update()
    set_timer_timeout(1)
end)
set_timer_timeout(1)
local game = dofile(base.."/game.lua")(Promise)
local util = dofile(base.."/util.lua")(Promise)

game.registerHandlers()

game.findPreferredExit():next(function(exit)
    io.stderr:write(util.table_to_string(exit))
    io.stderr:write('\n')
end)