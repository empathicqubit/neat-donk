--Update to Seth-Bling's MarI/O app

local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")

local game = dofile(base.."/game.lua")
local config = dofile(base.."/config.lua")
local pool = dofile(base.."/pool.lua")
local util = dofile(base.."/util.lua")

local statusLine = nil
local statusColor = 0x0000ff00

pool.onMessage(function(msg, color)
    print(msg)
    statusLine = msg
    statusColor = color
end)

local guiHeight = 0
local guiWidth = 0
pool.onRenderForm(function(form)
    guiWidth, guiHeight = gui.resolution()
    gui.left_gap(500)  
    gui.top_gap(0)
    gui.bottom_gap(0)
    gui.right_gap(0)
    form:draw(-500, 0)

    if statusLine ~= nil then
        gui.rectangle(-500, guiHeight - 20, 0, 20, 1, 0x00000000, statusColor)
        gui.text(-500, guiHeight - 20, statusLine, 0x00000000)
    end
end)
pool.run()

function on_post_load()
    print("HELLO LOAD")
end
