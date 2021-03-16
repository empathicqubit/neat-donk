--Notes here
local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*/)(.*)", "%1")

local mathFunctions = dofile(base.."/mathFunctions.lua")
local config = dofile(base.."/config.lua")
local spritelist = dofile(base.."/spritelist.lua")
local util = dofile(base.."/util.lua")
local _M = {}

spritelist.InitSpriteList()
spritelist.InitExtSpriteList()

KREMCOINS = 0x7e08cc
TILE_SIZE = 32
ENEMY_SIZE = 64
TILE_COLLISION_MATH_POINTER = 0x7e17b2
SPRITE_BASE = 0x7e0de2
VERTICAL_POINTER = 0xc414
TILEDATA_POINTER = 0x7e0098
HAVE_BOTH = 0x7e08c2
CAMERA_X = 0x7e17ba
CAMERA_Y = 0x7e17c0
LEAD_CHAR = 0x7e08a4
PARTY_X = 0x7e0a2a
PARTY_Y = 0x7e0a2c
SOLID_LESS_THAN = 0x7e00a0
KONG_LETTERS = 0x7e0902
MATH_LIVES = 0x7e08be
DISPLAY_LIVES = 0x7e0c0
MAIN_AREA_NUMBER = 0x7e08a8
CURRENT_AREA_NUMBER = 0x7e08c8

function _M.getPositions()
    leader = memory.readword(LEAD_CHAR)
    tilePtr = memory.readhword(TILEDATA_POINTER)
    vertical = memory.readword(TILE_COLLISION_MATH_POINTER) == VERTICAL_POINTER
	partyX = memory.readword(PARTY_X)
	partyY = memory.readword(PARTY_Y)
		
	cameraX = memory.readword(CAMERA_X)
	cameraY = memory.readword(CAMERA_Y)
		
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

function _M.getKremCoins()
    local krem = memory.readword(KREMCOINS)
    return krem
end

function _M.getGoalHit()
    local sprites = _M.getSprites()
    for i=1,#sprites,1 do
        local sprite = sprites[i]
        if sprite.control ~= 0x0164 then
            goto continue
        end
        -- Check if the goal barrel is moving up
        if sprite.velocityY < 0 then
            return true
        end
        ::continue::
    end

    return false
end

function _M.getKong()
    local kong = memory.readword(KONG_LETTERS)
    return bit.popcount(kong)
end

function _M.getLives()
	local lives = memory.readsbyte(0x7e08be) + 1
	return lives
end

function _M.writeLives(lives)
	memory.writebyte(0x7e08be, lives - 1)
	memory.writebyte(0x7e08c0, lives - 1)
end

function _M.getBoth()
    -- FIXME consider invincibility barrels
    local both = memory.readword(HAVE_BOTH)
	return bit.band(both, 0x4000)
end

function _M.getVelocityY()
    local sprite = _M.getSprite(leader)
    if sprite == nil then
        return 1900
    end
    return sprite.velocityY
end

function _M.getVelocityX()
    local sprite = _M.getSprite(leader)
    if sprite == nil then
        return 1900
    end
    return sprite.velocityX
end

function _M.writePowerup(powerup)
        return
	-- memory.writebyte(0x0019, powerup)
end


function _M.getHit(alreadyHit)
        return not alreadyHit and memory.readword(MATH_LIVES) < memory.readword(DISPLAY_LIVES)
end

function _M.getHitTimer(lastBoth)
	return (memory.readsbyte(DISPLAY_LIVES) - memory.readsbyte(MATH_LIVES))
        + lastBoth - _M.getBoth()
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

function _M.getCurrentArea()
    return memory.readword(CURRENT_AREA_NUMBER)
end

function _M.getJumpHeight()
    local sprite = _M.getSprite(leader)
    if sprite == nil then
        return 0
    end
    return sprite.jumpHeight
end

function _M.getSprite(idx)
    local base_addr = idx * 94 + SPRITE_BASE

    local control = memory.readword(base_addr)

    if control == 0 then
        return nil
    end

    local x = memory.readword(base_addr + 0x06)
    local y = memory.readword(base_addr + 0x0a)
    local sprite = {
        control = control,
        screenX = x - 256 - cameraX - 256,
        screenY = y - 256 - cameraY - 256,
        jumpHeight = memory.readword(base_addr + 0x0e),
        velocityX = memory.readsword(base_addr + 0x20),
        velocityY = memory.readsword(base_addr + 0x24),
        x = x,
        y = y,
        good = spritelist.Sprites[control]
    }

    if sprite.good == nil then
        sprite.good = -1
    end

    return sprite
end

function _M.getSprites()
    local sprites = {}
    for idx = 2,22,1 do
        local sprite = _M.getSprite(idx)
        if sprite == nil then
            goto continue
        end

        sprites[#sprites+1] = sprite
        ::continue::
    end
		
	return sprites
end

-- Currently only for single bananas since they don't
-- count as regular computed sprites
function _M.getExtendedSprites()
    local oam = memory2.OAM:readregion(0x00, 0x220)
    local sprites = _M.getSprites()
    local extended = {}

    for idx=0,0x200/4-1,1 do
        local twoBits = bit.band(bit.lrshift(oam[0x201 + math.floor(idx / 4)], ((idx % 4) * 2)), 0x03)
        local flags = oam[idx * 4 + 4]
        local tile = oam[idx * 4 + 3]
        local screenSprite = {
            x = math.floor(oam[idx * 4 + 1] * ((-1) ^ bit.band(twoBits, 0x01))),
            y = oam[idx * 4 + 2],
            good = spritelist.extSprites[tile]
        }
        if bit.band(flags, 0x21) == 0x00 then
            goto continue
        end

        if screenSprite.good == nil then
            screenSprite.good = 0
        end

        -- Hide the interface icons
        if screenSprite.x < 0 or screenSprite.y < TILE_SIZE then
            goto continue
        end

        -- Hide sprites near computed sprites
        for s=1,#sprites,1 do
            local sprite = sprites[s]
            if screenSprite.x > sprite.screenX - ENEMY_SIZE and screenSprite.x < sprite.screenX + ENEMY_SIZE / 2 and
                screenSprite.y > sprite.screenY - ENEMY_SIZE and screenSprite.y < sprite.screenY then
                goto continue
            end
            ::nextsprite::
        end

        extended[#extended+1] = screenSprite
        ::continue::
    end

	return extended
end

callcount = 0
function _M.getInputs()
	_M.getPositions()
	
	local sprites = _M.getSprites()
	local extended = _M.getExtendedSprites()
	
	local inputs = {}
	local inputDeltaDistance = {}
	
    for dy = -config.BoxRadius, config.BoxRadius, 1 do
        for dx = -config.BoxRadius, config.BoxRadius, 1 do
			inputs[#inputs+1] = 0
			inputDeltaDistance[#inputDeltaDistance+1] = 1
			
			tile = _M.getTile(dx, dy)
			if tile == 1 then
                if _M.getTile(dx, dy-1) == 1 then
                    inputs[#inputs] = -1
                else
                    inputs[#inputs] = 1
                end
            elseif tile == 0 and _M.getTile(dx + 1, dy) == 1 and _M.getTile(dx + 1, dy - 1) == 1 then
                inputs[#inputs] = -1
			end
			
			for i = 1,#sprites do
                local sprite = sprites[i]
				local distx = math.abs(sprite.x - (partyX+dx*TILE_SIZE))
				local disty = math.abs(sprite.y - (partyY+dy*TILE_SIZE))
                local dist = math.sqrt((distx * distx) + (disty * disty))
				if dist <= TILE_SIZE * 1.25 then
					inputs[#inputs] = sprite.good
					
					if dist > TILE_SIZE then
						inputDeltaDistance[#inputDeltaDistance] = mathFunctions.squashDistance(dist)
					end
				end
                ::continue::
			end

 			for i = 1,#extended do
				local distx = math.abs(extended[i]["x"]+cameraX - (partyX+dx*TILE_SIZE))
				local disty = math.abs(extended[i]["y"]+cameraY - (partyY+dy*TILE_SIZE))
				if distx < TILE_SIZE / 2 and disty < TILE_SIZE / 2 then
					
					inputs[#inputs] = extended[i]["good"]
					local dist = math.sqrt((distx * distx) + (disty * disty))
					if dist > TILE_SIZE / 2 then
						inputDeltaDistance[#inputDeltaDistance] = mathFunctions.squashDistance(dist)
					end
				end
			end
		end
	end
	
	return inputs, inputDeltaDistance
end

function _M.clearJoypad()
	for b = 1,#config.ButtonNames do
		input.set(0, b - 1, 0)
	end
end

local areaLoadedQueue = {}
function _M.onceAreaLoaded(handler)
    table.insert(areaLoadedQueue, handler)
end

local mapLoadedQueue = {}
function _M.onceMapLoaded(handler)
    -- TODO For now we only want one at a time
    mapLoadedQueue = {}
    table.insert(mapLoadedQueue, handler)
end

function processAreaLoad()
    for i=#areaLoadedQueue,1,-1 do
        table.remove(areaLoadedQueue, i)()
    end
end

function processMapLoad()
    for i=#mapLoadedQueue,1,-1 do
        table.remove(mapLoadedQueue, i)()
    end
end

function _M.registerHandlers()
    memory2.BUS:registerwrite(0xb517b2, processAreaLoad)
    memory2.WRAM:registerread(0x06b1, processMapLoad)
end

return _M
