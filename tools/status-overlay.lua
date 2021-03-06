local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1").."/.."

local set_timer_timeout, memory, memory2, gui, input, bit, callback = set_timer_timeout, memory, memory2, gui, input, bit, callback

local warn = '========== The ROM must be running before running this script'
io.stderr:write(warn)
print(warn)

local Promise = dofile(base.."/promise.lua")
callback.register('timer', function()
    Promise.update()
    set_timer_timeout(1)
end)
set_timer_timeout(1)
local util = dofile(base.."/util.lua")(Promise)
local mem = dofile(base.."/mem.lua")
local spritelist = dofile(base.."/spritelist.lua")
local game = dofile(base.."/game.lua")(Promise)

spritelist.InitSpriteList()
spritelist.InitExtSpriteList()

game.registerHandlers()

local CAMERA_MODE = 0x7e054f
local DIDDY_X_VELOCITY = 0x7e0e02
local DIDDY_Y_VELOCITY = 0x7e0e06
local DIXIE_X_VELOCITY = 0x7e0e60
local DIXIE_Y_VELOCITY = 0x7e0e64
local FG_COLOR = 0x00ffffff
local BG_COLOR = 0x99000000
local TILE_RADIUS = 5

local frame = 0
local detailsidx = -1
local jumping = false
local helddown = false
local floatmode = false
local rulers = true
local pokemon = false
local pokecount = 0
local showhelp = false
local locked = false
local lockdata = nil
local incsprite = 0
local questionable_tiles = false

local font = gui.font.load(base.."/font.font")

local function text(x, y, msg, fg, bg)
    if fg == nil then
        fg = FG_COLOR
    end
    if bg == nil then
        bg = BG_COLOR
    end
    font(x, y, msg, fg, bg)
end

function on_keyhook (key, state)
    if not helddown and state.value == 1 then
        if key == "1" and not locked then
            helddown = true
            detailsidx = detailsidx - 1
            if detailsidx < -1 then
                detailsidx = 22
            end
        elseif key == "2" and not locked then
            helddown = true
            detailsidx = detailsidx + 1
            if detailsidx > 22 then
                detailsidx = -1 
            end
        elseif key == "3" then
            helddown = true
            incsprite = -1
        elseif key == "4" then
            helddown = true
            incsprite = 1
        elseif key == "5" then
            helddown = true
            if not locked then
                locked = true
            else
                locked = false 
                lockdata = nil
            end
        elseif key == "6" then
            helddown = true
            pokemon = not pokemon
        elseif key == "7" then
            helddown = true
            floatmode = not floatmode
        elseif key == "8" then
            helddown = true
            rulers = not rulers
        elseif key == "9" then
            helddown = true
            questionable_tiles = not questionable_tiles
        elseif key == "0" then
            showhelp = true
        end
    elseif state.value == 0 then
        helddown = false
        showhelp = false
    end
end

function on_input (subframe)
    jumping = input.get(0,0) ~= 0

    if floatmode then
        memory.writebyte(0x7e19ce, 0x16)
        memory.writebyte(0x7e0e12, 0x99)
        memory.writebyte(0x7e0e70, 0x99)
        if input.get(0, 6) == 1 then
            memory.writeword(DIDDY_X_VELOCITY, -0x5ff)
            memory.writeword(DIXIE_X_VELOCITY, -0x5ff)

            memory.writeword(DIDDY_Y_VELOCITY, 0)
            memory.writeword(DIXIE_Y_VELOCITY, 0)
        elseif input.get(0, 7) == 1 then
            memory.writeword(DIDDY_X_VELOCITY, 0x5ff)
            memory.writeword(DIXIE_X_VELOCITY, 0x5ff)

            memory.writeword(DIDDY_Y_VELOCITY, 0)
            memory.writeword(DIXIE_Y_VELOCITY, 0)
        end

        if input.get(0, 4) == 1 then
            memory.writeword(DIDDY_Y_VELOCITY, -0x05ff)
            memory.writeword(DIXIE_Y_VELOCITY, -0x05ff)
        elseif input.get(0, 5) == 1 then
            memory.writeword(DIDDY_Y_VELOCITY, 0x5ff)
            memory.writeword(DIXIE_Y_VELOCITY, 0x5ff)
        end
    end
end

local function get_sprite(baseAddr)
    local spriteData = memory.readregion(baseAddr, mem.size.sprite)
    local offsets = mem.offset.sprite
    local x = util.regionToWord(spriteData, offsets.x)
    local y = util.regionToWord(spriteData, offsets.y)
    return {
        base_addr = string.format("%04x", baseAddr),
        screenX = x - game.cameraX,
        screenY = y - game.cameraY - mem.size.tile / 3,
        control = util.regionToWord(spriteData, offsets.control),
        draworder = util.regionToWord(spriteData, 0x02),
        x = x,
        y = y,
        jumpHeight = util.regionToWord(spriteData, offsets.jumpHeight),
        style = util.regionToWord(spriteData, offsets.style),
        currentframe = util.regionToWord(spriteData, 0x18),
        nextframe = util.regionToWord(spriteData, 0x1a),
        state = util.regionToWord(spriteData, 0x1e),
        velocityX = util.regionToSWord(spriteData, offsets.velocityX),
        velocityY = util.regionToSWord(spriteData, offsets.velocityY),
        velomaxx = util.regionToSWord(spriteData, 0x26),
        velomaxy = util.regionToSWord(spriteData, 0x2a),
        motion = util.regionToWord(spriteData, offsets.motion),
        attr = util.regionToWord(spriteData, 0x30),
        animnum = util.regionToWord(spriteData, 0x36),
        remainingframe = util.regionToWord(spriteData, 0x38),
        animcontrol = util.regionToWord(spriteData, 0x3a),
        animreadpos = util.regionToWord(spriteData, 0x3c),
        animcontrol2 = util.regionToWord(spriteData, 0x3e),
        animformat = util.regionToWord(spriteData, 0x40),
        damage1 = util.regionToWord(spriteData, 0x44),
        damage2 = util.regionToWord(spriteData, 0x46),
        damage3 = util.regionToWord(spriteData, 0x48),
        damage4 = util.regionToWord(spriteData, 0x4a),
        damage5 = util.regionToWord(spriteData, 0x4c),
        damage6 = util.regionToWord(spriteData, 0x4e),
        spriteparam = util.regionToWord(spriteData, 0x58),
    }
end

local function sprite_details(idx)
    local base_addr = idx * mem.size.sprite + mem.addr.spriteBase

    local sprite = get_sprite(base_addr)

    if sprite.control == 0 then
        text(0, 0, "Sprite "..idx.." (Empty)")
        incsprite = 0
        locked = false
        lockdata = nil
        return
    end

    if incsprite ~= 0 then
        memory.writeword(base_addr + 0x36, sprite.animnum + incsprite)

        lockdata = nil
        incsprite = 0
    end

    if locked and lockdata == nil then
        lockdata = memory.readregion(base_addr, mem.size.sprite)
    end

    if lockdata ~= nil and locked then
        memory.writeregion(base_addr, mem.size.sprite, lockdata)
    end

    text(0, 0, "Sprite "..idx..(locked and " (Locked)" or "")..":\n\n"..util.table_to_string(sprite))
end

local waypoints = {}
local overlayCtx = nil
local overlay = nil
local function renderOverlay(guiWidth, guiHeight)
    overlayCtx:set()
    overlayCtx:clear()

    if showhelp then
        text(0, 0, [[
Keyboard Help
===============

Sprite Details:

[1] Next sprite slot
[2] Previous sprite slot
[3] Change to next sprite animation
[4] Change to previous sprite animation
[5] Lock current sprite

[6] Enable / Disable Pokemon mode (take screenshots of enemies)
[7] Enable / Disable float mode (fly with up/down)
[8] Enable / Disable stage tile rulers
[9] Enable / Disable hidden tiles
]])
        overlay = overlayCtx:render()
        gui.renderctx.setnull()
        return
    end

    game.getPositions()

    local toggles = ""

    if pokemon then
        toggles = toggles..string.format("Pokemon: %d\n", pokecount)
    end

    if floatmode then
        toggles = toggles.."Float on\n"
    end


    if questionable_tiles then
        toggles = toggles.."All tiles on\n"
    end

    text(0, guiHeight - 40, toggles)

    local directions = {
        "Standard",
        "Blur",
        "Up"
    }

    local cameraDir = memory.readbyte(CAMERA_MODE)

    local direction = directions[cameraDir+1]

    local partyTileOffset = game.tileOffsetCalculation(game.partyX, game.partyY, game.vertical)

    local stats = string.format([[
%s camera %d,%d
Vertical: %s
Tile offset: %04x
Main area: %04x
Current area: %04x
%s
]], direction, game.cameraX, game.cameraY, game.vertical, partyTileOffset, memory.readword(mem.addr.mainAreaNumber), memory.readword(mem.addr.currentAreaNumber), util.table_to_string(game.getInputs()):gsub("[\\{\\},\n\"]", ""):gsub("-1", "X"):gsub("0", "."):gsub("1", "O"):gsub("(.............)", "%1\n"))

    text(guiWidth - 125, guiHeight - 200, stats)

    text((game.partyX - game.cameraX) * 2, (game.partyY - game.cameraY) * 2 + 20, "Party")

    local sprites = {}
    for idx = 0,22,1 do
        local base_addr = idx * mem.size.sprite + mem.addr.spriteBase

        local sprite = get_sprite(base_addr)

        sprites[idx] = sprite

        if sprite.control == 0 then
            goto continue
        end

        local sprcolor = BG_COLOR
        if detailsidx == idx then
            sprcolor = 0x00ff0000
        elseif spritelist.Sprites[sprite.control] == -1 then
            sprcolor = 0x66990000
        elseif spritelist.Sprites[sprite.control] == 1 then
            sprcolor = 0x66009900
        end

        text(sprite.screenX * 2, sprite.screenY * 2, string.format("%04x, %04x, %04x", sprite.control, sprite.animnum, sprite.attr), FG_COLOR, sprcolor)

        local filename = os.getenv("HOME").."/neat-donk/catchem/"..sprite.animnum..","..sprite.attr..".png"
        if pokemon and sprite.screenX > (guiWidth / 4) and sprite.screenY < (guiWidth / 4) * 3 and sprite.screenY > (guiHeight / 3) and sprite.screenY < guiHeight and not util.file_exists(filename) then
            gui.screenshot(filename)
            pokecount = pokecount + 1
        end
        ::continue::
    end

    for i=1,#waypoints,1 do
        local screenX = (waypoints[i].x - game.cameraX) * 2
        local screenY = (waypoints[i].y - game.cameraY) * 2

        if screenX > guiWidth - mem.size.tile * 2 then
            screenX = guiWidth - mem.size.tile * 2
        end

        if screenY > guiHeight then
            screenY = guiHeight - 20
        end

        if screenX < 0 then
            screenX = 0
        end

        if screenY < 0 then
            screenY = 0
        end

        text(screenX, screenY, "WAYPOINT "..i)
    end

    text(guiWidth / 2, guiHeight - 20, "WAYPOINTS: "..#waypoints)

    if rulers and game.cameraX >= 0 then
        local halfWidth = math.floor(guiWidth / 2)
        local halfHeight = math.floor(guiHeight / 2)

        local cameraTileX = math.floor(game.cameraX / mem.size.tile)
        gui.line(0, halfHeight, guiWidth, halfHeight, BG_COLOR)
        for i = cameraTileX, cameraTileX + guiWidth / mem.size.tile / 2,1 do
            text((i * mem.size.tile - game.cameraX) * 2, halfHeight, tostring(i), FG_COLOR, BG_COLOR)
        end

        local cameraTileY = math.floor(game.cameraY / mem.size.tile)
        gui.line(halfWidth, 0, halfWidth, guiHeight, BG_COLOR)
        for i = cameraTileY, cameraTileY + guiHeight / mem.size.tile / 2,1 do
            text(halfWidth, (i * mem.size.tile - game.cameraY) * 2, tostring(i), FG_COLOR, BG_COLOR)
        end
    end

    local tilePtr = memory.readhword(mem.addr.tiledataPointer)

    for x = -TILE_RADIUS, TILE_RADIUS, 1 do
        for y = -TILE_RADIUS, TILE_RADIUS, 1 do
            local tileX = math.floor((game.partyX + x * mem.size.tile) / mem.size.tile) * mem.size.tile
            local tileY = math.floor((game.partyY + y * mem.size.tile) / mem.size.tile) * mem.size.tile

            local offset = game.tileOffsetCalculation(tileX, tileY, game.vertical)

            local tile = memory.readword(tilePtr + offset)

            if not game.tileIsSolid(tileX, tileY, tile, offset) then
                goto continue
            end

            local screenX = (tileX - 256 - game.cameraX) * 2 
            local screenY = (tileY - 256 - game.cameraY) * 2
            if screenX < 0 or screenX > guiWidth or
                screenY < 0 or screenY > guiHeight then
                --goto continue
            end

            text(screenX, screenY, string.format("%04x\n%02x", bit.band(offset, 0xffff), tile), FG_COLOR, 0x66888800)

            ::continue::
        end
    end

    if game.cameraX >= 0 then
        local oam = memory2.OAM:readregion(0x00, 0x220)

        for idx=0,0x200/4-1,1 do
            local twoBits = bit.band(bit.lrshift(oam[0x201 + math.floor(idx / 4)], ((idx % 4) * 2)), 0x03)
            local screenSprite = {
                x = math.floor(oam[idx * 4 + 1] * ((-1) ^ bit.band(twoBits, 0x01))),
                y = oam[idx * 4 + 2],
                tile = oam[idx * 4 + 3],
                flags = oam[idx * 4 + 4],
            }

            if screenSprite.x < 0 or screenSprite.y > guiHeight / 2 or screenSprite.y < mem.size.tile then
                goto continue
            end

            for s=1,#sprites,1 do
                local sprite = sprites[s]
                if sprite.control == 0 then
                    goto nextsprite
                end
                if screenSprite.x > sprite.screenX - mem.size.enemy and screenSprite.x < sprite.screenX + mem.size.enemy / 2 and
                    screenSprite.y > sprite.screenY - mem.size.enemy and screenSprite.y < sprite.screenY then
                    goto continue
                end
                ::nextsprite::
            end

            if bit.band(screenSprite.flags, 0x21) ~= 0x00 and screenSprite.tile >= 224 and screenSprite.tile <= 238 then
                text(screenSprite.x * 2, screenSprite.y * 2, screenSprite.tile, 0x00000000, 0x00ffff00)
            end

            ::continue::
        end
    end

    if detailsidx ~= -1 then
        sprite_details(detailsidx)
    else
        text(0, 20, "[1] <- Sprite Details Off -> [2]")
    end

    text(guiWidth - 125, 20, "Help [Hold 0]")

	overlay = overlayCtx:render()
    gui.renderctx.setnull()
end

function on_paint (not_synth)
    frame = frame + 1

    local guiWidth, guiHeight = gui.resolution()
    if overlayCtx == nil then
        overlayCtx = gui.renderctx.new(guiWidth, guiHeight)
    end

    if frame % 3 == 0 then
        renderOverlay(guiWidth, guiHeight)
    end

    if overlay ~= nil then
        overlay:draw(0, 0)
    end
end

input.keyhook("1", true)
input.keyhook("2", true)
input.keyhook("3", true)
input.keyhook("4", true)
input.keyhook("5", true)
input.keyhook("6", true)
input.keyhook("7", true)
input.keyhook("8", true)
input.keyhook("9", true)
input.keyhook("0", true)

game.findPreferredExit():next(function(preferredExit)
    return game.getWaypoints(preferredExit.x, preferredExit.y)
end):next(function(w)
    waypoints = w
end)

-- fe0a58 crate: near bunch and klomp on barrels
-- fe0a58: Crate X position
-- fe0a60: Crate Y position

-- fe0a70 bunch: near crate and klomp on barrels
-- fe0a70: X position
-- fe0a72: Y position