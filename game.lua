--Notes here
local memory, bit, memory2, input, callback, movie = memory, bit, memory2, input, callback, movie

local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")

local Promise = nil

local util = nil
local mathFunctions = dofile(base.."/mathFunctions.lua")
local config = dofile(base.."/config.lua")
local spritelist = dofile(base.."/spritelist.lua")
local mem = dofile(base.."/mem.lua")
local _M = {
    leader = 0,
    tilePtr = 0,
    vertical = false,
	partyX = 0,
	partyY = 0,
	 
	cameraX = 0,
	cameraY = 0,
	 
	screenX = 0,
	screenY = 0,
}

spritelist.InitSpriteList()
spritelist.InitExtSpriteList()

function _M.getPositions()
    _M.leader = memory.readword(mem.addr.leadChar)
    _M.tilePtr = memory.readhword(mem.addr.tiledataPointer)
    _M.vertical = memory.readword(mem.addr.tileCollisionMathPointer) == mem.addr.verticalPointer
	_M.partyX = memory.readword(mem.addr.partyX)
	_M.partyY = memory.readword(mem.addr.partyY)
		
	_M.cameraX = memory.readword(mem.addr.cameraX)
	_M.cameraY = memory.readword(mem.addr.cameraY)
		
	_M.screenX = (_M.partyX-256-_M.cameraX)*2
	_M.screenY = (_M.partyY-256-_M.cameraY)*2
end

function _M.setPartyPosition(x, y)
    memory.writeword(mem.addr.partyX, x)
    memory.writeword(mem.addr.partyY, y)
    _M.setSpritePosition(0, x, y)
    _M.setSpritePosition(1, x, y)
end

function _M.setCameraPosition(x, y)
    memory.writeword(mem.addr.cameraX, x)
    memory.writeword(mem.addr.cameraY, y)
    memory.writeword(mem.addr.cameraX2, x)
    memory.writeword(mem.addr.cameraY2, y)
end

function _M.setSpritePosition(index, x, y)
    local offsets = mem.offset.sprite
    local spriteBase = mem.addr.spriteBase + index * mem.size.sprite
    memory.writeword(spriteBase + offsets.x, x)
    memory.writeword(spriteBase + offsets.y, y)
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
    local krem = memory.readword(mem.addr.kremcoins)
    return krem
end

function _M.getAreaWidth()
    return memory.readword(mem.addr.areaWidth) + 256
end

function _M.getAreaHeight()
    return memory.readword(mem.addr.areaHeight)
end

function _M.getAreaLength()
    return memory.readword(mem.addr.areaLength)
end

local onFrameAdvancedQueue = {}
function _M.advanceFrame()
    local promise = Promise.new()
    table.insert(onFrameAdvancedQueue, promise)
    return promise
end

local function processFrameAdvanced()
    for i=#onFrameAdvancedQueue,1,-1 do
        table.remove(onFrameAdvancedQueue, i):resolve()
    end
end

local onSetRewindQueue = {}
function _M.setRewindPoint()
    local promise = Promise.new()
    table.insert(onSetRewindQueue, promise)
    movie.unsafe_rewind()
    return promise
end

local function processSetRewind(state)
    for i=#onSetRewindQueue,1,-1 do
        table.remove(onSetRewindQueue, i):resolve(state)
    end
end

local onRewindQueue = {}
function _M.rewind(rew)
    local promise = Promise.new()
    movie.unsafe_rewind(rew)
    table.insert(onRewindQueue, promise)
    return promise
end

local function processRewind()
    for i=#onRewindQueue,1,-1 do
        table.remove(onRewindQueue, i):resolve()
    end
end

local function findPreferredExitLoop(frame, searchX, searchY, found, uniqueExits)
    return _M.advanceFrame():next(function()
        frame = frame + 1
        if frame % 2 ~=0 then
            return
        end

        local areaWidth = _M.getAreaWidth()
        memory.writebyte(0x7e19ce, 0x16)
        memory.writebyte(0x7e0e12, 0x99)
        memory.writebyte(0x7e0e70, 0x99)
        local sprites = _M.getSprites()
        for i=1,#sprites,1 do
            local sprite = sprites[i]
            local name = spritelist.SpriteNames[sprite.control]
            if sprite.control == spritelist.GoodSprites.goalTarget or
                sprite.control == spritelist.GoodSprites.areaExit then
                found = true
                uniqueExits[sprite.y * areaWidth + sprite.x] = sprite
            end
        end
        _M.setPartyPosition(searchX, searchY)
        _M.setCameraPosition(searchX, searchY)
        searchX = searchX + 0x100

        if searchX > areaWidth then
            searchX = 0
            searchY = searchY + 0xe0
            if searchY > _M.getAreaHeight() then
                table.sort(uniqueExits, function(a, b)
                    return a.control < b.control
                end)

                -- Return upper right corner if we can't find anything
                if found then
                    for id,sprite in pairs(uniqueExits) do
                        return { x = sprite.x, y = sprite.y }
                    end
                else
                    return { x = areaWidth, y = 0}
                end
            end
        end
    end):next(function(ret)
        if ret == nil then
            return findPreferredExitLoop(frame, searchX, searchY, found, uniqueExits)
        else
            return ret
        end
    end)
end

function _M.findPreferredExit()
    local point = nil
    local result = nil
    return _M.setRewindPoint():next(function(p)
        point = p
        return findPreferredExitLoop(0, 0, 0, false, {})
    end):next(function(r)
        result = r
        return _M.rewind(point)
    end):next(function()
        return result
    end)
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
    local kong = memory.readword(mem.addr.kongLetters)
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
    local both = memory.readword(mem.addr.haveBoth)
	return bit.band(both, 0x4000)
end

function _M.getVelocityY()
    local sprite = _M.getSprite(_M.leader)
    if sprite == nil then
        return 1900
    end
    return sprite.velocityY
end

function _M.getVelocityX()
    local sprite = _M.getSprite(_M.leader)
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
        return not alreadyHit and memory.readword(mem.addr.mathLives) < memory.readword(mem.addr.displayLives)
end

function _M.getHitTimer(lastBoth)
	return (memory.readsbyte(mem.addr.displayLives) - memory.readsbyte(mem.addr.mathLives))
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

    local a2 = bit.band(x, 0x1f)

    if bit.band(tileVal, 0x4000) ~= 0 then
        a2 = bit.band(bit.bxor(a2, 0x1f), 0xffff)
    end

    tileVal = bit.band(tileVal, 0x3fff)

    local solidLessThan = memory.readword(mem.addr.solidLessThan)

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
    local tileX = math.floor((_M.partyX + dx * mem.size.tile) / mem.size.tile) * mem.size.tile
    local tileY = math.floor((_M.partyY + dy * mem.size.tile) / mem.size.tile) * mem.size.tile

    local offset = _M.tileOffsetCalculation(tileX, tileY, _M.vertical)

    local tile = memory.readword(_M.tilePtr + offset)

    if not _M.tileIsSolid(tileX, tileY, tile, offset) then
        return 0
    end

    return 1
end

function _M.getCurrentArea()
    return memory.readword(mem.addr.currentAreaNumber)
end

function _M.getJumpHeight()
    local sprite = _M.getSprite(_M.leader)
    if sprite == nil then
        return 0
    end
    return sprite.jumpHeight
end

function _M.fell()
    local sprite = _M.getSprite(_M.leader)
    if sprite == nil then
        return 0
    end

    return sprite.motion == 0x3b
end

function _M.getSprite(idx)
    local baseAddr = idx * mem.size.sprite + mem.addr.spriteBase
    local spriteData = memory.readregion(baseAddr, mem.size.sprite)

    local offsets = mem.offset.sprite
    local control = util.regionToWord(spriteData, offsets.control)

    if control == 0 then
        return nil
    end

    local x = util.regionToWord(spriteData, offsets.x)
    local y = util.regionToWord(spriteData, offsets.y)
    local sprite = {
        control = control,
        screenX = x - 256 - _M.cameraX - 256,
        screenY = y - 256 - _M.cameraY - 256,
        jumpHeight = util.regionToWord(spriteData, offsets.jumpHeight),
        -- style bits
        -- 0x4000 0: Right facing 1: Flipped
        -- 0x1000 0: Alive 1: Dying
        style = util.regionToWord(spriteData, offsets.style),
        velocityX = util.regionToWord(spriteData, offsets.velocityX),
        velocityY = util.regionToWord(spriteData, offsets.velocityY),
        motion = util.regionToWord(spriteData, offsets.motion),
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
        if screenSprite.x < 0 or screenSprite.y < mem.size.tile then
            goto continue
        end

        -- Hide sprites near computed sprites
        for s=1,#sprites,1 do
            local sprite = sprites[s]
            if screenSprite.x > sprite.screenX - mem.size.enemy and screenSprite.x < sprite.screenX + mem.size.enemy / 2 and
                screenSprite.y > sprite.screenY - mem.size.enemy and screenSprite.y < sprite.screenY then
                goto continue
            end
            ::nextsprite::
        end

        extended[#extended+1] = screenSprite
        ::continue::
    end

	return extended
end

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
			
			local tile = _M.getTile(dx, dy)
			if tile == 1 then
                if inputs[#inputs-config.BoxRadius*2-1] == -1 then
                    inputs[#inputs] = -1
                else
                    local neighbors = 0
                    for ddy=-1,1,1 do
                        for ddx=-1,1,1 do
                            if (ddy == 0 and ddx == 0) or (ddx == 0 and ddy == 1) then
                                goto continue
                            end

                            if _M.getTile(dx+ddx, dy+ddy) == 0 then
                                neighbors = neighbors + 1
                            end

                            ::continue::
                        end
                    end

                    if neighbors >= 3 then 
                        inputs[#inputs] = 1
                    else
                        inputs[#inputs] = -1
                    end
                end
			end
			
			for i = 1,#sprites do
                local sprite = sprites[i]
				local distx = math.abs(sprite.x - (_M.partyX+dx*mem.size.tile))
				local disty = math.abs(sprite.y - (_M.partyY+dy*mem.size.tile))
                local dist = math.sqrt((distx * distx) + (disty * disty))
				if dist <= mem.size.tile * 1.25 then
                    if sprite.good == 0 then
                        goto continue
                    end
					inputs[#inputs] = sprite.good
					
					if dist > mem.size.tile then
						inputDeltaDistance[#inputDeltaDistance] = mathFunctions.squashDistance(dist)
					end
				end
                ::continue::
			end

 			for i = 1,#extended do
				local distx = math.abs(extended[i]["x"]+_M.cameraX - (_M.partyX+dx*mem.size.tile))
				local disty = math.abs(extended[i]["y"]+_M.cameraY - (_M.partyY+dy*mem.size.tile))
				if distx < mem.size.tile / 2 and disty < mem.size.tile / 2 then
					
					inputs[#inputs] = extended[i]["good"]
					local dist = math.sqrt((distx * distx) + (disty * disty))
					if dist > mem.size.tile / 2 then
						inputDeltaDistance[#inputDeltaDistance] = mathFunctions.squashDistance(dist)
					end
				end
			end
		end
	end

	return inputs, inputDeltaDistance
end

function _M.getClimbing()
    local sprite = _M.getSprite(_M.leader)
    if sprite == nil then
        return false
    end
    return sprite.motion >= 0x35 and sprite.motion <= 0x39
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

local emptyHitQueue = {}
function _M.onEmptyHit(handler)
    emptyHitQueue = {}
    table.insert(emptyHitQueue, handler)
end

local function processEmptyHit(addr, val)
    local idx = math.floor((bit.band(addr, 0xffff) - bit.band(mem.addr.spriteBase, 0xffff)) / mem.size.sprite)
    local pow = _M.getSprite(idx)
    if pow == nil or
        pow.control ~= 0x0238 then
        return
    end

    local sprites = _M.getSprites()
    for i=1,#sprites,1 do
        local sprite = sprites[i]
        if bit.band(sprite.style, mem.flag.sprite.dying) ~= 0 and
            sprite.good == -1 then
            return
        end
    end

    for i=#emptyHitQueue,1,-1 do
        emptyHitQueue[i]()
    end
end

local function processAreaLoad()
    for i=#areaLoadedQueue,1,-1 do
        table.remove(areaLoadedQueue, i)()
    end
end

local function processMapLoad()
    for i=#mapLoadedQueue,1,-1 do
        table.remove(mapLoadedQueue, i)()
    end
    areaLoadedQueue = {} -- We clear this because it doesn't make any sense after the map screen loads
end

function _M.bonusScreenDisplayed(inputs)
    local count = 0
    for i=1,#inputs,1 do
        if inputs[i] ~= 0 then
            count = count + 1
        end
    end

    return count < 10
end

local handlers = {}
local function registerHandler(space, regname, addr, callback)
    table.insert(handlers, { 
        
        fn = space[regname](space, addr, callback),
        unregisterFn = space['un'..regname],
        space = space,
        addr = addr,
    })
end

local inputHandler = nil
local setRewindHandler = nil
local rewindHandler = nil
function _M.unregisterHandlers()
    callback.unregister('input', inputHandler)
    callback.unregister('set_rewind', setRewindHandler)
    callback.unregister('post_rewind', rewindHandler)
    inputHandler = nil
    setRewindHandler = nil
    rewindHandler = nil
    for i=#handlers,1,-1 do
        local handler = table.remove(handlers, i)
        handler.unregisterFn(handler.space, handler.addr, handler.fn)
    end
end

function _M.registerHandlers()
    if inputHandler ~= nil then
        error("Only call register handlers once")
    end

    inputHandler = callback.register('input', processFrameAdvanced)
    setRewindHandler = callback.register('set_rewind', processSetRewind)
    rewindHandler = callback.register('post_rewind', processRewind)
    registerHandler(memory2.BUS, 'registerwrite', 0xb517b2, processAreaLoad)
    registerHandler(memory2.WRAM, 'registerwrite', 0x069b, processMapLoad)
    for i=2,22,1 do
        registerHandler(memory2.WRAM, 'registerwrite', bit.band(mem.addr.spriteBase + mem.size.sprite * i, 0xffff), processEmptyHit)
    end
end

return function(promise)
    Promise = promise
    if util == nil then
        util = dofile(base.."/util.lua")(Promise)
    end
    return _M
end