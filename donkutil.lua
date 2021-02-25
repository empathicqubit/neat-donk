count = 0
detailsidx = -1
helddown = false
floatmode = false
pokemon = false
pokecount = 0
showhelp = false
locked = false
lockdata = nil
incsprite = 0
fgcolor = 0x00ffffff
bgcolor = 0x99000000
function table_to_string(tbl)
    local result = "{"
    local keys = {}
    for k in pairs(tbl) do 
        table.insert(keys, k)
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local v = tbl[k]
        if type(v) == "number" and v == 0 then
            goto continue
        end

        -- Check the key type (ignore any numerical keys - assume its an array)
        if type(k) == "string" then
            result = result.."[\""..k.."\"]".."="
        end

        -- Check the value type
        if type(v) == "table" then
            result = result..table_to_string(v)
        elseif type(v) == "boolean" then
            result = result..tostring(v)
        else
            result = result.."\""..v.."\""
        end
        result = result..",\n"
        ::continue::
    end
    -- Remove leading commas from the result
    if result ~= "" then
        result = result:sub(1, result:len()-1)
    end
    return result.."}"
end

function on_keyhook (key, state)
    if not helddown and state["value"] == 1 then
        if key == "1" and not locked then
            helddown = true
            detailsidx = detailsidx - 1
            if detailsidx < -1 then
                detailsidx = 20
            end
        elseif key == "2" and not locked then
            helddown = true
            detailsidx = detailsidx + 1
            if detailsidx > 20 then
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
        elseif key == "0" then
            showhelp = true
        end
    elseif state["value"] == 0 then
        helddown = false
        showhelp = false
    end
end

function on_input (subframe)
    if floatmode then
        memory.writebyte(0x7e19ce, 0x16)
        memory.writebyte(0x7e0e12, 0x99)
        memory.writebyte(0x7e0e70, 0x99)
        if input.get(0, 6) == 1 then
            memory.writeword(0x7e0e02, -0x5ff)
            memory.writeword(0x7e0e60, -0x5ff)

            memory.writeword(0x7e0e06, 0)
            memory.writeword(0x7e0e64, 0)
        elseif input.get(0, 7) == 1 then
            memory.writeword(0x7e0e02, 0x5ff)
            memory.writeword(0x7e0e60, 0x5ff)

            memory.writeword(0x7e0e06, 0)
            memory.writeword(0x7e0e64, 0)
        end

        if input.get(0, 4) == 1 then
            memory.writeword(0x7e0e06, -0x05ff)
            memory.writeword(0x7e0e64, -0x05ff)
        elseif input.get(0, 5) == 1 then
            memory.writeword(0x7e0e06, 0x5ff)
            memory.writeword(0x7e0e64, 0x5ff)
        end
    end
end

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function get_sprite(base_addr)
    return {
        ["control"] = memory.readword(base_addr),
        ["draworder"] = memory.readword(base_addr + 0x02),
        ["x"] = memory.readword(base_addr + 0x06),
        ["y"] = memory.readword(base_addr + 0x0a),
        ["jumpheight"] = memory.readword(base_addr + 0x0e),
        ["style"] = memory.readword(base_addr + 0x12),
        ["currentframe"] = memory.readword(base_addr + 0x18),
        ["nextframe"] = memory.readword(base_addr + 0x1a),
        ["state"] = memory.readword(base_addr + 0x1e),
        ["velox"] = memory.readsword(base_addr + 0x20),
        ["veloy"] = memory.readsword(base_addr + 0x24),
        ["velomaxx"] = memory.readsword(base_addr + 0x26),
        ["velomaxy"] = memory.readsword(base_addr + 0x2a),
        ["motion"] = memory.readword(base_addr + 0x2e),
        ["attr"] = memory.readword(base_addr + 0x30),
        ["animnum"] = memory.readword(base_addr + 0x36),
        ["remainingframe"] = memory.readword(base_addr + 0x38),
        ["animcontrol"] = memory.readword(base_addr + 0x3a),
        ["animreadpos"] = memory.readword(base_addr + 0x3c),
        ["animcontrol2"] = memory.readword(base_addr + 0x3e),
        ["animformat"] = memory.readword(base_addr + 0x40),
        ["damage1"] = memory.readword(base_addr + 0x44),
        ["damage2"] = memory.readword(base_addr + 0x46),
        ["damage3"] = memory.readword(base_addr + 0x48),
        ["damage4"] = memory.readword(base_addr + 0x4a),
        ["damage5"] = memory.readword(base_addr + 0x4c),
        ["damage6"] = memory.readword(base_addr + 0x4e),
        ["spriteparam"] = memory.readword(base_addr + 0x58),
    }
end

function sprite_details(idx)
    local base_addr = idx * 94 + 0x7e0e9e

    local sprite = get_sprite(base_addr)

    if sprite["control"] == 0 then
        gui.text(0, 0, "Sprite "..idx.." (Empty)", fgcolor, bgcolor)
        incsprite = 0
        locked = false
        lockdata = nil
        return
    end

    if incsprite ~= 0 then
        memory.writeword(base_addr + 0x36, sprite["animnum"] + incsprite)

        lockdata = nil
        incsprite = 0
    end

    if locked and lockdata == nil then
        lockdata = memory.readregion(base_addr, 94)
    end

    if lockdata ~= nil and locked then
        memory.writeregion(base_addr, 94, lockdata)
    end

    gui.text(0, 0, "Sprite "..idx..(locked and " (Locked)" or "")..":\n\n"..table_to_string(sprite), fgcolor, bgcolor)
end

function on_paint (not_synth)
    count = count + 1

    local guiWidth, guiHeight = gui.resolution()

    if showhelp then
        gui.text(0, 0, [[
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
]], fgcolor, bgcolor)
        return
    end

    gui.text(guiWidth - 75, 0, "Help [0]", fgcolor, bgcolor)

    local stats = ""

    if pokemon then
        stats = stats.."Pokemon: "..pokecount.."\n"
    end

    if floatmode then
        stats = stats.."Float on\n"
    end

    gui.text(0, guiHeight - 40, stats, fgcolor, bgcolor)

    stats = stats.."\nPokemon: "..pokecount

    local cameraX = memory.readword(0x7e17ba) - 256
    local cameraY = memory.readword(0x7e17c0) - 256

    local partyScreenX = (memory.readword(0x7e0a2a) - 256 - cameraX) * 2
    local partyScreenY = (memory.readword(0x7e0a2c) - 256 - cameraY) * 2

    if detailsidx ~= -1 then
        sprite_details(detailsidx)
    else
        gui.text(0, 0, "[1] <- Sprite Details Off -> [2]", fgcolor, bgcolor)
    end

    gui.text(guiWidth - 200, guiHeight - 20, "Camera: "..tostring(cameraX)..","..tostring(cameraY), fgcolor, bgcolor)

    gui.text(partyScreenX, partyScreenY, "Party", fgcolor, bgcolor)

    local sprites = {}
    for idx = 0,20,1 do
        local base_addr = idx * 94 + 0x7e0e9e

        local sprite = get_sprite(base_addr)

        sprites[idx] = sprite

        if sprite["control"] == 0 then
            goto continue
        end

        local spriteScreenX = (sprite["x"] - 256 - cameraX) * 2
        local spriteScreenY = (sprite["y"] - 256 - cameraY) * 2

        local sprcolor = bgcolor
        if detailsidx == idx then
            sprcolor = 0x00ff0000
        end
        gui.text(spriteScreenX, spriteScreenY, sprite["animnum"]..","..sprite["attr"], fgcolor, sprcolor)

        local filename = os.getenv("HOME").."/neat-donk/catchem/"..sprite["animnum"]..","..sprite["attr"]..".png"
        if pokemon and spriteScreenX > (guiWidth / 4) and spriteScreenX < (guiWidth / 4) * 3 and spriteScreenY > (guiHeight / 3) and spriteScreenY < guiHeight and not file_exists(filename) then
            gui.screenshot(filename)
            pokecount = pokecount + 1
        end
        ::continue::
    end
end

input.keyhook("1", true)
input.keyhook("2", true)
input.keyhook("3", true)
input.keyhook("4", true)
input.keyhook("5", true)
input.keyhook("6", true)
input.keyhook("7", true)
input.keyhook("0", true)