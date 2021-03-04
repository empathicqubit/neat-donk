util = require "util"

FG_COLOR = 0x00ffffff
BG_COLOR = 0x99000000
TILEDATA_POINTER = 0x7e0098
TILE_SIZE = 32
TILE_RADIUS = 4
SPRITE_BASE = 0x7e0de2
SOLID_LESS_THAN = 0x7e00a0
DIDDY_X_VELOCITY = 0x7e0e02
DIDDY_Y_VELOCITY = 0x7e0e06
DIXIE_X_VELOCITY = 0x7e0e60
DIXIE_Y_VELOCITY = 0x7e0e64
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

function text(x, y, msg)
    gui.text(x, y, msg, FG_COLOR, BG_COLOR)
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
    return {
        base_addr = string.format("%04x", base_addr),
        control = memory.readword(base_addr),
        draworder = memory.readword(base_addr + 0x02),
        x = memory.readword(base_addr + 0x06),
        y = memory.readword(base_addr + 0x0a),
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
    local partyTileOffset = tile_offset_calculation(partyX, partyY, vertical)

    local stats = string.format([[
%s camera %d,%d
Vertical: %s
Tile offset: %04x
]], direction, cameraX, cameraY, vertical, partyTileOffset)

    text(guiWidth - 200, guiHeight - 60, stats)

    text((partyX - 256 - cameraX) * 2, (partyY - 256 - cameraY) * 2 + 20, "Party")

    local sprites = {}
    for idx = 0,22,1 do
        local base_addr = idx * 94 + SPRITE_BASE

        local sprite = get_sprite(base_addr)

        sprites[idx] = sprite

        if sprite.control == 0 then
            goto continue
        end

        local spriteScreenX = (sprite.x - 256 - cameraX) * 2
        local spriteScreenY = (sprite.y - 256 - cameraY) * 2

        local sprcolor = BG_COLOR
        if detailsidx == idx then
            sprcolor = 0x00ff0000
        end
        gui.text(spriteScreenX, spriteScreenY, sprite.control..","..sprite.animnum..","..sprite.attr, FG_COLOR, sprcolor)

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
            gui.text((i * TILE_SIZE - cameraX) * 2, halfHeight, tostring(i), FG_COLOR, BG_COLOR)
        end

        local cameraTileY = math.floor(cameraY / TILE_SIZE)
        gui.line(halfWidth, 0, halfWidth, guiHeight, BG_COLOR)
        for i = cameraTileY, cameraTileY + guiHeight / TILE_SIZE / 2,1 do
            gui.text(halfWidth, (i * TILE_SIZE - cameraY) * 2, tostring(i), FG_COLOR, BG_COLOR)
        end
    end

    local tilePtr = memory.readhword(TILEDATA_POINTER)

    for x = -TILE_RADIUS, TILE_RADIUS, 1 do
        for y = -TILE_RADIUS, TILE_RADIUS, 1 do
            local tileX = math.floor((partyX + x * TILE_SIZE) / TILE_SIZE) * TILE_SIZE
            local tileY = math.floor((partyY + y * TILE_SIZE) / TILE_SIZE) * TILE_SIZE

            local offset = tile_offset_calculation(tileX, tileY, vertical)

            local tile = memory.readword(tilePtr + offset)

            if not tile_is_solid(tileX, tileY, tile, offset) then
                goto continue
            end

            local screenX = (tileX - 256 - cameraX) * 2 
            local screenY = (tileY - 256 - cameraY) * 2
            if screenX < 0 or screenX > guiWidth or
                screenY < 0 or screenY > guiHeight then
                goto continue
            end

            gui.text(screenX, screenY, string.format("%04x\n%02x", offset & 0xffff, tile), FG_COLOR, 0x66888800)

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

-- 0xb5c94d
function tile_is_solid(x, y, tileVal, tileOffset)
    local origTileVal = tileVal

    if tileVal == 0 or tileOffset == 0 then
        return false
    end

    if questionable_tiles then
        return true
    end

    local a2 = x & 0x1f

    if tileVal & 0x4000 ~= 0 then
        a2 = (a2 ~ 0x1f) & 0xffff
    end

    tileVal = tileVal & 0x3fff

    local solidLessThan = memory.readword(SOLID_LESS_THAN)

    if tileVal >= solidLessThan then
        return false
    end

    tileVal = (tileVal << 2) & 0xffff

    if a2 & 0x10 ~= 0 then
        tileVal = tileVal + 2
    end

    local tileMeta = memory.readword(memory.readword(0x7e009c) + tileVal)

    if tileMeta & 0x8000 ~=0 then
        a2 = (a2 ~ 0x000f) & 0xffff
    end

    if tileMeta & tileVal & 0x2000 ~= 0 then
        tileMeta = (tileMeta ~ 0x8000) & 0xffff
    end

    tileMeta = tileMeta & 0x00ff

    if tileMeta == 0 then
        return false
    end

    tileMeta = (tileMeta << 1) & 0xffff

    -- FIXME further tests?

    return true
end

-- Logic from 0xb5c3e1, 0xb5c414, 0xb5c82c
function tile_offset_calculation (x, y, vertical)
    local partyX = x - 256
    local partyY = y - 256

    if not vertical then
        if partyY < 0 then
            partyY = 0
        elseif partyY >= 0x1ff then
            partyY = 0x1ff
        end

        partyY = (((~partyY) & 0xffff) + 1) & 0x1e0

        partyX = partyX & 0xffe0

        partyY = ((partyY ~ 0x1e0) & 0xffff) >> 4

        return partyY + partyX
    else
        partyY = (((~partyY) & 0xffff) + 1) & 0xffe0

        partyX = (partyX & 0xffe0) >> 4

        partyY = (((partyY ~ 0xffe0) & 0xffff) << 1) & 0xffff

        return partyY + partyX
    end
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