local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")

local util = dofile(base.."/util.lua")
local spritelist = dofile(base.."/spritelist.lua")
local game = dofile(base.."/game.lua")
local config = dofile(base.."/config.lua")

spritelist.InitSpriteList()
spritelist.InitExtSpriteList()

FG_COLOR = 0x00ffffff
BG_COLOR = 0x99000000
ENEMY_SIZE = 64
TILEDATA_POINTER = 0x7e0098
TILE_SIZE = 32
TILE_RADIUS = 5
SPRITE_BASE = 0x7e0de2
SOLID_LESS_THAN = 0x7e00a0
DIDDY_X_VELOCITY = 0x7e0e02
DIDDY_Y_VELOCITY = 0x7e0e06
DIXIE_X_VELOCITY = 0x7e0e60
DIXIE_Y_VELOCITY = 0x7e0e64
STAGE_NUMBER = 0x7e08a8
STAGE_NUMBER_MOVEMENT = 0x7e08c8
CAMERA_X = 0x7e17ba
CAMERA_Y = 0x7e17c0
CAMERA_MODE = 0x7e054f
TILE_COLLISION_MATH_POINTER = 0x7e17b2
VERTICAL_POINTER = 0xc414
PARTY_X = 0x7e0a2a
PARTY_Y = 0x7e0a2c

count = 0
detailsidx = -1
jumping = false
helddown = false
floatmode = false
rulers = true
pokemon = false
pokecount = 0
showhelp = false
locked = false
lockdata = nil
incsprite = 0
questionable_tiles = false

font = gui.font.load(base.."font.font")

function text(x, y, msg, fg, bg)
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

function get_sprite(base_addr)
    local cameraX = memory.readword(CAMERA_X) - 256
    local cameraY = memory.readword(CAMERA_Y) - 256
    local x = memory.readword(base_addr + 0x06)
    local y = memory.readword(base_addr + 0x0a)
    return {
        base_addr = string.format("%04x", base_addr),
        screenX = x - 256 - cameraX,
        screenY = y - 256 - cameraY - TILE_SIZE / 3,
        control = memory.readword(base_addr),
        draworder = memory.readword(base_addr + 0x02),
        x = x,
        y = y,
        jumpheight = memory.readword(base_addr + 0x0e),
        style = memory.readword(base_addr + 0x12),
        currentframe = memory.readword(base_addr + 0x18),
        nextframe = memory.readword(base_addr + 0x1a),
        state = memory.readword(base_addr + 0x1e),
        velox = memory.readsword(base_addr + 0x20),
        veloy = memory.readsword(base_addr + 0x24),
        velomaxx = memory.readsword(base_addr + 0x26),
        velomaxy = memory.readsword(base_addr + 0x2a),
        motion = memory.readword(base_addr + 0x2e),
        attr = memory.readword(base_addr + 0x30),
        animnum = memory.readword(base_addr + 0x36),
        remainingframe = memory.readword(base_addr + 0x38),
        animcontrol = memory.readword(base_addr + 0x3a),
        animreadpos = memory.readword(base_addr + 0x3c),
        animcontrol2 = memory.readword(base_addr + 0x3e),
        animformat = memory.readword(base_addr + 0x40),
        damage1 = memory.readword(base_addr + 0x44),
        damage2 = memory.readword(base_addr + 0x46),
        damage3 = memory.readword(base_addr + 0x48),
        damage4 = memory.readword(base_addr + 0x4a),
        damage5 = memory.readword(base_addr + 0x4c),
        damage6 = memory.readword(base_addr + 0x4e),
        spriteparam = memory.readword(base_addr + 0x58),
    }
end

function sprite_details(idx)
    local base_addr = idx * 94 + SPRITE_BASE

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
        lockdata = memory.readregion(base_addr, 94)
    end

    if lockdata ~= nil and locked then
        memory.writeregion(base_addr, 94, lockdata)
    end

    text(0, 0, "Sprite "..idx..(locked and " (Locked)" or "")..":\n\n"..util.table_to_string(sprite))
end

function on_paint (not_synth)
    count = count + 1

    local guiWidth, guiHeight = gui.resolution()

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
        return
    end

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

    local cameraX = memory.readword(CAMERA_X) - 256
    local cameraY = memory.readword(CAMERA_Y) - 256
    local cameraDir = memory.readbyte(CAMERA_MODE)

    local direction = directions[cameraDir+1]

    local vertical = memory.readword(TILE_COLLISION_MATH_POINTER) == VERTICAL_POINTER

    local partyX = memory.readword(PARTY_X)
    local partyY = memory.readword(PARTY_Y)
    local partyTileOffset = game.tileOffsetCalculation(partyX, partyY, vertical)

    local stats = string.format([[
%s camera %d,%d
Vertical: %s
Tile offset: %04x
Stage number: %04x
Stage (movement): %04x
%s
]], direction, cameraX, cameraY, vertical, partyTileOffset, memory.readword(STAGE_NUMBER), memory.readword(STAGE_NUMBER_MOVEMENT), util.table_to_string(game.getInputs()):gsub("[\\{\\},\n\"]", ""):gsub("-1", "X"):gsub("0", "."):gsub("1", "O"):gsub("(.............)", "%1\n"))

    text(guiWidth - 125, guiHeight - 200, stats)

    text((partyX - 256 - cameraX) * 2, (partyY - 256 - cameraY) * 2 + 20, "Party")

    local sprites = {}
    for idx = 0,22,1 do
        local base_addr = idx * 94 + SPRITE_BASE

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
        if pokemon and spriteScreenX > (guiWidth / 4) and spriteScreenX < (guiWidth / 4) * 3 and spriteScreenY > (guiHeight / 3) and spriteScreenY < guiHeight and not util.file_exists(filename) then
            gui.screenshot(filename)
            pokecount = pokecount + 1
        end
        ::continue::
    end

    if rulers and cameraX >= 0 then
        local halfWidth = math.floor(guiWidth / 2)
        local halfHeight = math.floor(guiHeight / 2)

        local cameraTileX = math.floor(cameraX / TILE_SIZE)
        gui.line(0, halfHeight, guiWidth, halfHeight, BG_COLOR)
        for i = cameraTileX, cameraTileX + guiWidth / TILE_SIZE / 2,1 do
            text((i * TILE_SIZE - cameraX) * 2, halfHeight, tostring(i), FG_COLOR, BG_COLOR)
        end

        local cameraTileY = math.floor(cameraY / TILE_SIZE)
        gui.line(halfWidth, 0, halfWidth, guiHeight, BG_COLOR)
        for i = cameraTileY, cameraTileY + guiHeight / TILE_SIZE / 2,1 do
            text(halfWidth, (i * TILE_SIZE - cameraY) * 2, tostring(i), FG_COLOR, BG_COLOR)
        end
    end

    local tilePtr = memory.readhword(TILEDATA_POINTER)

    for x = -TILE_RADIUS, TILE_RADIUS, 1 do
        for y = -TILE_RADIUS, TILE_RADIUS, 1 do
            local tileX = math.floor((partyX + x * TILE_SIZE) / TILE_SIZE) * TILE_SIZE
            local tileY = math.floor((partyY + y * TILE_SIZE) / TILE_SIZE) * TILE_SIZE

            local offset = game.tileOffsetCalculation(tileX, tileY, vertical)

            local tile = memory.readword(tilePtr + offset)

            if not game.tileIsSolid(tileX, tileY, tile, offset) then
                goto continue
            end

            local screenX = (tileX - 256 - cameraX) * 2 
            local screenY = (tileY - 256 - cameraY) * 2
            if screenX < 0 or screenX > guiWidth or
                screenY < 0 or screenY > guiHeight then
                --goto continue
            end

            text(screenX, screenY, string.format("%04x\n%02x", bit.band(offset, 0xffff), tile), FG_COLOR, 0x66888800)

            ::continue::
        end
    end

    if cameraX >= 0 then
        local oam = memory2.OAM:readregion(0x00, 0x220)

        for idx=0,0x200/4-1,1 do
            local twoBits = bit.band(bit.lrshift(oam[0x201 + math.floor(idx / 4)], ((idx % 4) * 2)), 0x03)
            local screenSprite = {
                x = math.floor(oam[idx * 4 + 1] * ((-1) ^ bit.band(twoBits, 0x01))),
                y = oam[idx * 4 + 2],
                tile = oam[idx * 4 + 3],
                flags = oam[idx * 4 + 4],
            }

            if screenSprite.x < 0 or screenSprite.y > guiHeight / 2 or screenSprite.y < TILE_SIZE then
                goto continue
            end

            for s=1,#sprites,1 do
                local sprite = sprites[s]
                if sprite.control == 0 then
                    goto nextsprite
                end
                if screenSprite.x > sprite.screenX - ENEMY_SIZE and screenSprite.x < sprite.screenX + ENEMY_SIZE / 2 and
                    screenSprite.y > sprite.screenY - ENEMY_SIZE and screenSprite.y < sprite.screenY then
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
end

function on_timer()
    set_timer_timeout(100 * 1000)
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

set_timer_timeout(100 * 1000)
