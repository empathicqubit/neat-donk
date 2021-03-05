--Notes here
config = require "config"
spritelist = require "spritelist"
local _M = {}

TILE_SIZE = 32
TILE_COLLISION_MATH_POINTER = 0x7e17b2
VERTICAL_POINTER = 0xc414
TILEDATA_POINTER = 0x7e0098
CAMERA_X = 0x7e17ba
CAMERA_Y = 0x7e17c0
PARTY_X = 0x7e0a2a
PARTY_Y = 0x7e0a2c
SOLID_LESS_THAN = 0x7e00a0

function _M.getPositions()
    tilePtr = memory.readhword(TILEDATA_POINTER)
    vertical = memory.readword(TILE_COLLISION_MATH_POINTER) == VERTICAL_POINTER
	partyX = memory.readword(PARTY_X)
	partyY = memory.readword(PARTY_Y)
		
	local cameraX = memory.readword(CAMERA_X) - 256
	local cameraY = memory.readword(CAMERA_Y) - 256
		
	_M.screenX = (partyX-256-cameraX)*2
	_M.screenY = (partyY-256-cameraY)*2
end

function _M.getBananas()
	local bananas = memory.readword(0x7e08bc)
	return bananas
end

function _M.getCoins()
        local coins = memory.readword(0x7e08ca)
        return coins
end

function _M.getLives()
	local lives = memory.readsbyte(0x7e08be) + 1
	return lives
end

function _M.writeLives(lives)
	memory.writebyte(0x7e08be, lives - 1)
	memory.writebyte(0x7e08c0, lives - 1)
end

function _M.getPowerup()
	return 0
end

function _M.writePowerup(powerup)
        return
	-- memory.writebyte(0x0019, powerup)
end


function _M.getHit(alreadyHit)
        return not alreadyHit and memory.readbyte(0x7e08be) < memory.readbyte(0x7e08c0)
end

function _M.getHitTimer()
	return memory.readbyte(0x7e08c0) - memory.readbyte(0x7e08be)
end

-- Logic from 0xb5c3e1, 0xb5c414, 0xb5c82c
function _M.tileOffsetCalculation (x, y, vertical)
    local newX = x - 256
    local newY = y - 256

    if not vertical then
        if newY < 0 then
            newY = 0
        elseif newY >= 0x1ff then
            newY = 0x1ff
        end

        newY = bit.band(bit.band(bit.bnot(newY), 0xffff) + 1, 0x1e0)

        newX = bit.band(newX, 0xffe0)

        newY = bit.lrshift(bit.band(bit.bxor(newY, 0x1e0), 0xffff), 4)

        return newY + newX
    else
        newY = bit.band(bit.band(bit.bnot(newY), 0xffff) + 1, 0xffe0)

        newX = bit.lrshift(bit.band(newX, 0xffe0), 4)

        newY = bit.band(bit.lshift(bit.band(bit.bxor(newY, 0xffe0), 0xffff), 1), 0xffff)

        return newY + newX
    end
end

-- 0xb5c94d
function _M.tileIsSolid(x, y, tileVal, tileOffset)
    local origTileVal = tileVal

    if tileVal == 0 or tileOffset == 0 then
        return false
    end

    if questionable_tiles then
        return true
    end

    local a2 = bit.band(x, 0x1f)

    if bit.band(tileVal, 0x4000) ~= 0 then
        a2 = bit.band(bit.bxor(a2, 0x1f), 0xffff)
    end

    tileVal = bit.band(tileVal, 0x3fff)

    local solidLessThan = memory.readword(SOLID_LESS_THAN)

    if tileVal >= solidLessThan then
        return false
    end

    tileVal = bit.band(bit.lshift(tileVal, 2), 0xffff)

    if bit.band(a2, 0x10) ~= 0 then
        tileVal = tileVal + 2
    end

    local tileMeta = memory.readword(memory.readword(0x7e009c) + tileVal)

    if bit.band(tileMeta, 0x8000) ~=0 then
        a2 = bit.band(bit.bxor(a2, 0x000f), 0xffff)
    end

    if bit.band(tileMeta, tileVal, 0x2000) ~= 0 then
        tileMeta = bit.band(bit.bxor(tileMeta, 0x8000), 0xffff)
    end

    tileMeta = bit.band(tileMeta, 0x00ff)

    if tileMeta == 0 then
        return false
    end

    tileMeta = bit.band(bit.bxor(tileMeta, 1), 0xffff)

    -- FIXME further tests?

    return true
end

function _M.getTile(dx, dy)
    local tileX = math.floor((partyX + dx * TILE_SIZE) / TILE_SIZE) * TILE_SIZE
    local tileY = math.floor((partyY + dy * TILE_SIZE) / TILE_SIZE) * TILE_SIZE

    local offset = _M.tileOffsetCalculation(tileX, tileY, vertical)

    local tile = memory.readword(tilePtr + offset)

    if not _M.tileIsSolid(tileX, tileY, tile, offset) then
        return 0
    end

    return 1
end

function _M.getSprites()
	local sprites = {}
	for slot=0,11 do
		local status = memory.readbyte(0x14C8+slot)
		if status ~= 0 then
			spritex = memory.readbyte(0xE4+slot) + memory.readbyte(0x14E0+slot)*256
			spritey = memory.readbyte(0xD8+slot) + memory.readbyte(0x14D4+slot)*256
			sprites[#sprites+1] = {["x"]=spritex, ["y"]=spritey, ["good"] = spritelist.Sprites[memory.readbyte(0x009e + slot) + 1]}
		end
	end		
		
	return sprites
end

function _M.getExtendedSprites()
	local extended = {}
	for slot=0,11 do
		local number = memory.readbyte(0x170B+slot)
		if number ~= 0 then
			spritex = memory.readbyte(0x171F+slot) + memory.readbyte(0x1733+slot)*256
			spritey = memory.readbyte(0x1715+slot) + memory.readbyte(0x1729+slot)*256
			extended[#extended+1] = {["x"]=spritex, ["y"]=spritey, ["good"]  =  spritelist.extSprites[memory.readbyte(0x170B + slot) + 1]}
		end
	end		
		
	return extended
end

callcount = 0
function _M.getInputs()
	_M.getPositions()
	
	-- sprites = _M.getSprites()
	-- extended = _M.getExtendedSprites()
	
	local inputs = {}
	local inputDeltaDistance = {}
	
    for dy = -config.BoxRadius, config.BoxRadius, 1 do
        for dx = -config.BoxRadius, config.BoxRadius, 1 do
			inputs[#inputs+1] = 0
			inputDeltaDistance[#inputDeltaDistance+1] = 1
			
			tile = _M.getTile(dx, dy)
			if tile == 1 --[[and partyY+dy < 0x1B0]] then
				inputs[#inputs] = 1
			end
			
--[[ 			for i = 1,#sprites do
				distx = math.abs(sprites[i]["x"] - (partyX+dx))
				disty = math.abs(sprites[i]["y"] - (partyY+dy))
				if distx <= 8 and disty <= 8 then
					inputs[#inputs] = sprites[i]["good"]
					
					local dist = math.sqrt((distx * distx) + (disty * disty))
					if dist > 8 then
						inputDeltaDistance[#inputDeltaDistance] = mathFunctions.squashDistance(dist)
						--gui.drawLine(screenX, screenY, sprites[i]["x"] - layer1x, sprites[i]["y"] - layer1y, 0x50000000)
					end
				end
			end ]]

--[[ 			for i = 1,#extended do
				distx = math.abs(extended[i]["x"] - (partyX+dx))
				disty = math.abs(extended[i]["y"] - (partyY+dy))
				if distx < 8 and disty < 8 then
					
					--print(screenX .. "," .. screenY .. " to " .. extended[i]["x"]-layer1x .. "," .. extended[i]["y"]-layer1y) 
					inputs[#inputs] = extended[i]["good"]
					local dist = math.sqrt((distx * distx) + (disty * disty))
					if dist > 8 then
						inputDeltaDistance[#inputDeltaDistance] = mathFunctions.squashDistance(dist)
						--gui.drawLine(screenX, screenY, extended[i]["x"] - layer1x, extended[i]["y"] - layer1y, 0x50000000)
					end
					--if dist > 100 then
						--dw = mathFunctions.squashDistance(dist)
						--print(dist .. " to " .. dw)
						--gui.drawLine(screenX, screenY, extended[i]["x"] - layer1x, extended[i]["y"] - layer1y, 0x50000000)
					--end
					--inputs[#inputs] = {["value"]=-1, ["dw"]=dw}
				end
			end ]]
		end
	end
	
	return inputs, inputDeltaDistance
end

function _M.clearJoypad()
	for b = 1,#config.ButtonNames do
		input.set(0, b - 1, 0)
	end
end

return _M
