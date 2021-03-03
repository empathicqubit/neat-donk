--Notes here
config = require "config"
spritelist = require "spritelist"
local _M = {}

function _M.getPositions()
	partyX = memory.readword(0x7e0a2a) - 256
	partyY = memory.readword(0x7e0a2c) - 256
		
	local cameraX = memory.readword(0x7e17ba) - 256
	local cameraY = memory.readword(0x7e17c0) - 256
		
	_M.screenX = (partyX-cameraX)*2
	_M.screenY = (partyY-cameraY)*2
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

function _M.getTile(dx, dy)
        local partyScreenX = (partyX - cameraX) * 2
        local partyScreenY = (partyY - cameraY) * 2

	x = math.floor((partyX+dx+8)/16)
	y = math.floor((partyY+dy)/16)
		
	return memory.readbyte(0x1C800 + math.floor(x/0x10)*0x1B0 + y*0x10 + x%0x10)
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

function _M.getInputs()
	_M.getPositions()
	
	sprites = _M.getSprites()
	extended = _M.getExtendedSprites()
	
	local inputs = {}
	local inputDeltaDistance = {}
	
	local layer1x = memory.readword(0x7f0000);
	local layer1y = memory.read_s16_le(0x1C);
	
	for dy=-config.BoxRadius*16,config.BoxRadius*16,16 do
		for dx=-config.BoxRadius*16,config.BoxRadius*16,16 do
			inputs[#inputs+1] = 0
			inputDeltaDistance[#inputDeltaDistance+1] = 1
			
			tile = _M.getTile(dx, dy)
			if tile == 1 and partyY+dy < 0x1B0 then
				inputs[#inputs] = 1
			end
			
			for i = 1,#sprites do
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
			end

			for i = 1,#extended do
				distx = math.abs(extended[i]["x"] - (partyX+dx))
				disty = math.abs(extended[i]["y"] - (partyY+dy))
				if distx < 8 and disty < 8 then
					
					--console.writeline(screenX .. "," .. screenY .. " to " .. extended[i]["x"]-layer1x .. "," .. extended[i]["y"]-layer1y) 
					inputs[#inputs] = extended[i]["good"]
					local dist = math.sqrt((distx * distx) + (disty * disty))
					if dist > 8 then
						inputDeltaDistance[#inputDeltaDistance] = mathFunctions.squashDistance(dist)
						--gui.drawLine(screenX, screenY, extended[i]["x"] - layer1x, extended[i]["y"] - layer1y, 0x50000000)
					end
					--if dist > 100 then
						--dw = mathFunctions.squashDistance(dist)
						--console.writeline(dist .. " to " .. dw)
						--gui.drawLine(screenX, screenY, extended[i]["x"] - layer1x, extended[i]["y"] - layer1y, 0x50000000)
					--end
					--inputs[#inputs] = {["value"]=-1, ["dw"]=dw}
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

return _M
