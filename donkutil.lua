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
party_tile_offset = 0
party_y_ground = 0

last_called = 0
function set_party_tile_offset (val)
    if party_tile_offset_debounce == val then
        return
    end
    local sec, usec = utime()
    last_called = sec * 1000000 + usec
    party_tile_offset_debounce = val
end

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

    local stats = string.format([[
%s camera %d,%d
Vertical: %s
Tile offset: %04x
]], direction, cameraX, cameraY, vertical, party_tile_offset)

    text(guiWidth - 200, guiHeight - 60, stats)

    local partyX = memory.readword(PARTY_X) - 256
    local partyY = memory.readword(PARTY_Y) - 256

    text((partyX - cameraX) * 2, (partyY - cameraY) * 2 + 20, "Party")

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
    local solidLessThan = memory.readword(SOLID_LESS_THAN)

    for x = -TILE_RADIUS, TILE_RADIUS, 1 do
        for y = -TILE_RADIUS, TILE_RADIUS, 1 do
            local offset = 0
            if vertical then
                offset = party_tile_offset + (y * 24 + x) * 2
            else
                offset = party_tile_offset + (x * 16 + y) * 2
            end

            local tile = memory.readword(tilePtr + offset)

            if tile == 0 or tile >= solidLessThan then
                goto continue
            end

            local tileX = (math.floor(partyX / TILE_SIZE + x) * TILE_SIZE - cameraX)
            local tileY = (math.floor(party_y_ground / TILE_SIZE + y) * TILE_SIZE - cameraY)
            gui.text(tileX * 2, tileY * 2, string.format("%04x,%02x", offset & 0xffff, tile), FG_COLOR, 0x66888800)

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

function tile_retrieval()
    local tile = math.floor(memory.getregister("y") / 2) * 2
    local newX = memory.readword(0x7e00a6)
    local partyX = memory.readword(PARTY_X)
    local oldX = partyX & 0x1f
    local partyY = memory.readword(PARTY_Y)

    if oldX - 5 < newX and newX < oldX + 5 and 
        not jumping and
        memory.readword(0x7e0034) == partyY then
        set_party_tile_offset(tile)
        party_y_ground = partyY - 256
    end
end

function on_timer()
    local sec, usec = utime()
    local now = sec * 1000000 + usec
    if last_called + 100 * 1000 < now then
        party_tile_offset = party_tile_offset_debounce
    end

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
input.keyhook("0", true)

memory2.BUS:registerexec(TILE_RETRIEVAL, tile_retrieval)

set_timer_timeout(100 * 1000)