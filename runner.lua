local mem = require "mem"
local gui, input, movie, settings, exec, callback, set_timer_timeout, memory, bsnes = gui, input, movie, settings, exec, callback, set_timer_timeout, memory, bsnes

local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")
local Promise = nil

local config = dofile(base.."/config.lua")
local game = nil
local mathFunctions = dofile(base.."/mathFunctions.lua")
local util = dofile(base.."/util.lua")()

local Inputs = config.InputSize+1
local Outputs = #config.ButtonNames

local guiWidth = 0 
local guiHeight = 0

local function message(_M, msg, color)
    if color == nil then
        color = 0x00009900
    end

    for i=#_M.onMessageHandler,1,-1 do
        _M.onMessageHandler[i](msg, color)
    end
end

local netPicture = nil
local genomeCtx = gui.renderctx.new(470, 200)
local function displayGenome(genome)
    genomeCtx:set()
    genomeCtx:clear()
    gui.solidrectangle(0, 0, 470, 200, 0x99606060)
	local network = genome.network
	local cells = {}
	local i = 1
	local cell = {}
	for dy=-config.BoxRadius,config.BoxRadius do
		for dx=-config.BoxRadius,config.BoxRadius do
			cell = {}
			cell.x = 50+5*dx
			cell.y = 70+5*dy
			cell.value = network.neurons[i].value
			cells[i] = cell
			i = i + 1
		end
	end
	local biasCell = {}
	biasCell.x = 80
	biasCell.y = 110
	biasCell.value = network.neurons[Inputs].value
	cells[Inputs] = biasCell
	
	for o = 1,Outputs do
        if o == 4 then
            goto continue
        end

		cell = {}
		cell.x = 400
		cell.y = 20 + 14 * o
		cell.value = network.neurons[config.NeatConfig.MaxNodes + o].value
		cells[config.NeatConfig.MaxNodes+o] = cell
		local color
		if cell.value > 0 then
			color = 0x000000FF
		else
			color = 0x00ffffff
		end
		gui.text(403, 10+14*o, config.ButtonNames[o], color, 0xff000000)
        ::continue::
	end
	
	for n,neuron in pairs(network.neurons) do
		cell = {}
		if n > Inputs and n <= config.NeatConfig.MaxNodes then
			cell.x = 140
			cell.y = 40
			cell.value = neuron.value
			cells[n] = cell
		end
	end
	
	for n=1,4 do
		for _,gene in pairs(genome.genes) do
			if gene.enabled then
				local c1 = cells[gene.into]
				local c2 = cells[gene.out]
                if c1 == nil then
                    c1 = {
                        x = 0,
                        y = 0,
                    }
                end
                if c2 == nil then
                    c2 = {
                        x = 0,
                        y = 0,
                    }
                end
				if gene.into > Inputs and gene.into <= config.NeatConfig.MaxNodes then
					c1.x = 0.75*c1.x + 0.25*c2.x
					if c1.x >= c2.x then
						c1.x = c1.x - 40
					end
					if c1.x < 90 then
						c1.x = 90
					end
					
					if c1.x > 220 then
						c1.x = 220
					end
					c1.y = 0.75*c1.y + 0.25*c2.y
					
				end
				if gene.out > Inputs and gene.out <= config.NeatConfig.MaxNodes then
					c2.x = 0.25*c1.x + 0.75*c2.x
					if c1.x >= c2.x then
						c2.x = c2.x + 40
					end
					if c2.x < 90 then
						c2.x = 90
					end
					if c2.x > 220 then
						c2.x = 220
					end
					c2.y = 0.25*c1.y + 0.75*c2.y
				end
			end
		end
	end
	
	gui.rectangle(
        50-config.BoxRadius*5-3,
        70-config.BoxRadius*5-3,
        config.BoxRadius*10+5,
        config.BoxRadius*10+5,
        2,
        0xFF000000, 
        0x00808080
    )
	for n,cell in pairs(cells) do
		if n > Inputs or cell.value ~= 0 then
			local color = math.floor((cell.value+1)/2*256)
			if color > 255 then color = 255 end
			if color < 0 then color = 0 end
			local alpha = 0x50000000
			if cell.value == 0 then
				alpha = 0xFF000000
			end
			color = alpha + color*0x10000 + color*0x100 + color
			gui.rectangle(
                math.floor(cell.x-5),
                math.floor(cell.y-5),
                5,
                5,
                1,
                0x00,
                color
            )
		end
	end
	for _,gene in pairs(genome.genes) do
		if true then
			local c1 = cells[gene.into]
			local c2 = cells[gene.out]
            if(c1 == nil) then
                c1 = {
                    x = 0,
                    y = 0,
                }
            end
            if(c2 == nil) then
                c2 = {
                    x = 0,
                    y = 0,
                }
            end
			local alpha = 0x20000000
			if c1.value == 0 then
				alpha = 0xA0000000
			end
			
			local color = 0x80-math.floor(math.abs(mathFunctions.sigmoid(gene.weight))*0x80)
			if gene.weight > 0 then 
				color = alpha + 0x8000 + 0x10000*color
			else
				color = alpha + 0x800000 + 0x100*color
			end
			gui.line(
                math.floor(c1.x+1), 
                math.floor(c1.y), 
                math.floor(c2.x-3),
                math.floor(c2.y),
                color
            )
		end
	end
	
	gui.rectangle(
        49,
        71,
        2,
        7,
        0x00000000,
        0x00FF0000
    )

    local pos = 100
    for mutation,rate in pairs(genome.mutationRates) do
        gui.text(100, pos, mutation .. ": " .. rate, 0x00ffffff, 0xff000000)

        pos = pos + 14
    end
	netPicture = genomeCtx:render()
    gui.renderctx.setnull()
end

local buttons = nil
local buttonCtx = gui.renderctx.new(500, 70)
local function displayButtons(_M)
    buttonCtx:set()
    buttonCtx:clear()

    gui.rectangle(0, 0, 500, 70, 1, 0x000000000, 0x33990099)
    local startStop = ""
    -- FIXME this won't work I think???
    if config.Running then
        startStop = "Stop"
    else
        startStop = "Start"
    end
    gui.text(5, 2, "[1] "..startStop)

    --gui.text(130, 2, "[4] Play Top")

    gui.text(240, 2, "[6] Save")


    gui.text(320, 2, "[8] Load")
    gui.text(400, 2, "[9] Restart")

    local insert = ""
    local confirm = "[Tab] Type in filename"
    if _M.inputmode then
        insert = "_"
        confirm = "[Tab] Confirm filename"
    end

    gui.text(5, 29, "..."..config.NeatConfig.SaveFile:sub(-55)..insert)

    gui.text(5, 50, confirm)

	buttons = buttonCtx:render()
    gui.renderctx.setnull()
end

local function getDistanceTraversed(areaInfos)
    local distanceTraversed = 0
    for _,areaInfo in pairs(areaInfos) do
        for i=1,#areaInfo.waypoints,1 do
            local waypoint = areaInfo.waypoints[i]
            distanceTraversed = distanceTraversed + (waypoint.startDistance - waypoint.shortest)
        end
    end
    return distanceTraversed
end

local formCtx = nil
local form = nil
local function displayForm(_M)
    if config.NeatConfig.ShowInterface == false or #_M.onRenderFormHandler == 0 then
        return
    end

    if form ~= nil and _M.drawFrame % 10 ~= 0 then
        gui.renderctx.setnull()
        for i=#_M.onRenderFormHandler,1,-1 do
            _M.onRenderFormHandler[i](form)
        end
        return
    end

	formCtx:set()
    formCtx:clear()
	gui.rectangle(0, 0, 500, guiHeight, 1, 0x00ffffff, 0xbb000000)
	--gui.circle(game.screenX-84, game.screenY-84, 192 / 2, 1, 0x50000000) 
    
    local distanceTraversed = getDistanceTraversed(_M.areaInfo)
    local goalX = 0
    local goalY = 0
    local areaInfo = _M.areaInfo[_M.currentArea]
    if areaInfo ~= nil then
        goalX = areaInfo.preferredExit.x
        goalY = areaInfo.preferredExit.y
    end

	gui.text(5, 5, string.format([[
Generation: %4d Species: %4d Genome: %4d

Timeout: %4d Max: %6d

Bananas: %4d Coins: %3d Damage: %3d Current area: %04x
KONG: %7d Lives: %3d Powerup: %2d Traveled: %8d
Krem: %7d Bumps: %3d Goal Offset: %8d, %7d
]],
    _M.currentGenerationIndex, _M.currentSpecies.id, _M.currentGenomeIndex,
    _M.timeout, math.floor(_M.maxFitness),
    _M.totalBananas, game.getCoins() - _M.startCoins, _M.partyHitCounter, _M.currentArea,
    game.getKong() - _M.startKong, game.getLives(), _M.powerUpCounter, distanceTraversed,
    game.getKremCoins() - _M.startKrem, _M.bumps, goalX - game.partyX, goalY - game.partyY
))

    displayButtons(_M)
    formCtx:set()
    buttons:draw(5, 130)

	if netPicture ~= nil then
		netPicture:draw(5, 200)
	end

    form = formCtx:render()
	gui.renderctx.setnull()

    for i=#_M.onRenderFormHandler,1,-1 do
        _M.onRenderFormHandler[i](form)
    end
end

local function painting(_M)
    guiWidth, guiHeight = gui.resolution()
    if formCtx == nil then
        formCtx = gui.renderctx.new(500, guiHeight)
    end
    _M.drawFrame = _M.drawFrame + 1
    displayForm(_M)
end

local function evaluateNetwork(_M, network, inputs, inputDeltas)
	table.insert(inputs, 1)
	table.insert(inputDeltas,99)
	if #inputs ~= Inputs then
		message(_M, "Incorrect number of neural network inputs.", 0x00990000)
		return {}
	end

	for i=1,Inputs do
		network.neurons[i].value = inputs[i] * inputDeltas[i]
	end
	
	for _,neuron in pairs(network.neurons) do
		local sum = 0
		for j = 1,#neuron.incoming do
			local incoming = neuron.incoming[j]
			local other = network.neurons[incoming.into]
			sum = sum + incoming.weight * other.value
		end
		
		if #neuron.incoming > 0 then
			neuron.value = mathFunctions.sigmoid(sum)
		end
	end
	
	local outputs = {}
	for o=1,Outputs do
        if o == 4 then
            goto continue
        end

		local button = o - 1
		if network.neurons[config.NeatConfig.MaxNodes+o].value > 0 then
			outputs[button] = true
		else
			outputs[button] = false
		end

        ::continue::
	end
	
	return outputs
end

local controller = {}
local function updateController()
    for b=0,#config.ButtonNames - 1,1 do
        if controller[b] then
            input.set(0, b, 1)
        else
            input.set(0, b, 0)
        end
    end
end

local frame = 0
local lastFrame = 0

local function evaluateCurrent(_M, inputs, inputDeltas)
	local genome = _M.currentSpecies.genomes[_M.currentGenomeIndex]
	
	controller = evaluateNetwork(_M, genome.network, inputs, inputDeltas)

	if controller[6] and controller[7] then
		controller[6] = false
		controller[7] = false
	end
	if controller[4] and controller[5] then
		controller[4] = false
		controller[5] = false
	end
end

local function fitnessAlreadyMeasured(_M)
	local genome = _M.currentSpecies.genomes[_M.currentGenomeIndex]
	
	return genome.fitness ~= 0
end

local function newNeuron()
	local neuron = {}
	neuron.incoming = {}
	neuron.value = 0.0
	--neuron.dw = 1
	return neuron
end

local function generateNetwork(genome)
	local network = {}
	network.neurons = {}
	
	for i=1,Inputs do
		network.neurons[i] = newNeuron()
	end
	
	for o=1,Outputs do
        if o == 4 then
            goto continue
        end

        network.neurons[config.NeatConfig.MaxNodes+o] = newNeuron()

        ::continue::
	end
	
	table.sort(genome.genes, function (a,b)
		return (a.out < b.out)
	end)
	for i=1,#genome.genes do
		local gene = genome.genes[i]
		if gene.enabled then
			if network.neurons[gene.out] == nil then
				network.neurons[gene.out] = newNeuron()
			end
			local neuron = network.neurons[gene.out]
			table.insert(neuron.incoming, gene)
			if network.neurons[gene.into] == nil then
				network.neurons[gene.into] = newNeuron()
			end
		end
	end

	genome.network = network
end

local beginRewindState = nil
local function rewind()
    return game.rewind(beginRewindState):next(function()
        frame = 0
        lastFrame = 0
    end)
end

local function initializeRun(_M)
    settings.set_speed("turbo")
    -- XXX Does this actually work or only affects new VM loads?
    settings.set('lua-maxmem', 1024)
    local enableSound = 'on'
    if config.NeatConfig.DisableSound then
        enableSound = 'off'
    end
    exec('enable-sound '..enableSound)
    gui.subframe_update(false)

    return rewind():next(function()
        bsnes.enablelayer(0, 0, true)
        bsnes.enablelayer(0, 1, false)
        bsnes.enablelayer(1, 0, false)
        bsnes.enablelayer(1, 1, false)
        bsnes.enablelayer(2, 0, false)
        bsnes.enablelayer(2, 1, false)
        bsnes.enablelayer(3, 0, false)
        bsnes.enablelayer(3, 1, false)
        bsnes.enablelayer(4, 0, true)
        bsnes.enablelayer(4, 1, true)
        bsnes.enablelayer(4, 2, true)
        bsnes.enablelayer(4, 3, true)

        if config.StartPowerup ~= nil then
            game.writePowerup(config.StartPowerup)
        end
        _M.currentFrame = 0
        _M.timeout = config.NeatConfig.TimeoutConstant
        -- Kill the run if we go back to the map screen
        game.onceMapLoaded(function()
            _M.timeout = -100000
        end)
        _M.bumps = 0
        -- Penalize player for collisions that do not result in enemy deaths
        game.onEmptyHit(function()
            _M.bumps = _M.bumps + 1
        end)
        game.clearJoypad()
        _M.startKong = game.getKong()
        _M.totalBananas = 0
        _M.lastBananas = game.getBananas()
        _M.startKrem = game.getKremCoins()
        _M.lastKrem = _M.startKrem
        _M.startCoins = game.getCoins()
        _M.startLives = game.getLives()
        _M.partyHitCounter = 0
        _M.powerUpCounter = 0
        _M.powerUpBefore = game.getBoth()
        _M.currentArea = game.getCurrentArea()
        _M.lastArea = _M.currentArea

        for _,areaInfo in pairs(_M.areaInfo) do
            for i=1,#areaInfo.waypoints,1 do
                local waypoint = areaInfo.waypoints[i]
                waypoint.shortest = waypoint.startDistance
            end
        end

        local genome = _M.currentSpecies.genomes[_M.currentGenomeIndex]
        generateNetwork(genome)

        local inputs, inputDeltas = game.getInputs()
        evaluateCurrent(_M, inputs, inputDeltas)
    end)
end

local function mainLoop(_M, genome)
    return game.advanceFrame():next(function()
        local nextArea = game.getCurrentArea()
        if nextArea ~= _M.lastArea then
            _M.lastArea = nextArea
            game.onceAreaLoaded(function()
                message(_M, 'Loaded area '..nextArea)
                _M.timeout = _M.timeout + 60 * 5
                _M.currentArea = nextArea
                _M.lastArea = _M.currentArea
            end)
        elseif _M.currentArea == _M.lastArea and _M.areaInfo[_M.currentArea] == nil then
            message(_M, 'Searching for the main exit in this area')
            return game.findPreferredExit():next(function(preferredExit)
                local areaInfo = {
                    preferredExit = preferredExit,
                    waypoints = game.getWaypoints(preferredExit.x, preferredExit.y),
                }
                table.insert(areaInfo.waypoints, 1, preferredExit)

                for i=#areaInfo.waypoints,1,-1 do
                    local waypoint = areaInfo.waypoints[i]
                    if waypoint.y > game.partyY + mem.size.tile * 7 then
                        message(_M, string.format('Skipped waypoint %d,%d', waypoint.x, waypoint.y), 0x00ffff00)
                        table.remove(areaInfo.waypoints, i)
                        goto continue
                    end
                    local startDistance = math.floor(math.sqrt((waypoint.y - game.partyY) ^ 2 + (waypoint.x - game.partyX) ^ 2))
                    waypoint.startDistance = startDistance
                    waypoint.shortest = startDistance
                    ::continue::
                end

                message(_M, string.format('Found %d waypoints', #areaInfo.waypoints))

                _M.areaInfo[_M.currentArea] = areaInfo
            end)
        end
    end):next(function()
        if lastFrame + 1 ~= frame then
            message(_M, string.format("We missed %d frames", frame - lastFrame), 0x00ff0000)
        end
        lastFrame = frame

        if genome ~= nil then
            _M.currentFrame = _M.currentFrame + 1
        end

        genome = _M.currentSpecies.genomes[_M.currentGenomeIndex]

        if _M.drawFrame % 10 == 0 then
            displayGenome(genome)
        end
        
        game.getPositions()
        local timeoutConst = config.NeatConfig.TimeoutConstant

        local fell = game.fell()
        if (fell or game.diedFromHit()) and _M.timeout > 0 then
            _M.timeout = 0
        end

        if _M.currentFrame % 5 == 0 then
            local sprites = game.getSprites()
            local inputs, inputDeltas = game.getInputs(sprites)
            if game.bonusScreenDisplayed(inputs) and _M.timeout > -1000 and _M.timeout < timeoutConst then
                _M.timeout = timeoutConst
            end

            evaluateCurrent(_M, inputs, inputDeltas)
        end

        local areaInfo = _M.areaInfo[_M.currentArea]
        if areaInfo ~= nil and game.partyY ~= 0 and game.partyX ~= 0 then
            for i=1,#areaInfo.waypoints,1 do
                local waypoint = areaInfo.waypoints[i]
                local dist = math.floor(math.sqrt((waypoint.y - game.partyY) ^ 2 + (waypoint.x - game.partyX) ^ 2))
                if dist < waypoint.shortest then
                    waypoint.shortest = dist
                    if _M.timeout < timeoutConst then
                        _M.timeout = timeoutConst
                    end
                end
            end
        end
        
        local hitTimer = game.getHitTimer(_M.lastBoth)
        
        if hitTimer > 0 then
            _M.partyHitCounter = _M.partyHitCounter + 1
            --message(_M, "party took damage, hit counter: " .. _M.partyHitCounter)
        end
        
        local powerUp = game.getBoth()
        _M.lastBoth = powerUp
        if powerUp > 0 then
            if powerUp ~= _M.powerUpBefore then
                _M.powerUpCounter = _M.powerUpCounter + 1
                _M.powerUpBefore = powerUp
            end
        end

        local krem = game.getKremCoins() - _M.startKrem
        if krem > _M.lastKrem then
            message(_M, string.format("Kremcoin grabbed: %d", _M.timeout), 0x00009900)
            _M.lastKrem = krem
            _M.timeout = _M.timeout + 60 * 10
        end

        local currentBananas = game.getBananas()
        local moreBananas = currentBananas - _M.lastBananas
        if moreBananas > 0 then
            _M.totalBananas = _M.totalBananas + moreBananas
        end
        _M.lastBananas = currentBananas
        
        _M.timeout = _M.timeout - 1

        if lastFrame ~= frame then
            message(_M, string.format("We missed %d frames", frame - lastFrame), 0x00990000)
        end

        -- Continue if we haven't timed out
        local timeoutBonus = _M.currentFrame / 4
        if _M.timeout + timeoutBonus > 0 then
            return mainLoop(_M, genome)
        end
        
        -- Timeout calculations beyond this point
        -- Manipulating the timeout value won't have
        -- any effect
        local coins = game.getCoins() - _M.startCoins
        local kong = game.getKong()

        message(_M, string.format("Bananas: %d, coins: %d, Krem: %d,  KONG: %d", _M.totalBananas, coins, krem, kong))

        local bananaCoinsFitness = (krem * 100) + (kong * 60) + (_M.totalBananas * 50) + (coins * 0.2)
        if (_M.totalBananas + coins) > 0 then 
            message(_M, "Bananas, Coins, KONG added " .. bananaCoinsFitness .. " fitness")
        end

        local hitPenalty = _M.partyHitCounter * 100
        local bumpPenalty = _M.bumps * 100
        local powerUpBonus = _M.powerUpCounter * 100

        local distanceTraversed = getDistanceTraversed(_M.areaInfo) - _M.currentFrame / 2

        local fitness = bananaCoinsFitness - bumpPenalty - hitPenalty + powerUpBonus + distanceTraversed

        if fell then
            fitness = fitness / 10
            message(_M, "Fall penalty 1/10")
        end

        local lives = game.getLives()

        if _M.startLives < lives then
            local extraLiveBonus = (lives - _M.startLives)*1000
            fitness = fitness + extraLiveBonus
            message(_M, "Extra live bonus added " .. extraLiveBonus)
        end

        local sprites = game.getSprites()
        -- FIXME We should test this before we time out
        if game.getGoalHit(sprites) then
            fitness = fitness + 1000
            message(_M, string.format("LEVEL WON! Fitness: %d", fitness), 0x0000ff00)
        end

        if fitness == 0 then
            fitness = -1
        end
        genome.fitness = fitness
        
        if _M.maxFitness == nil or fitness > _M.maxFitness then
            _M.maxFitness = fitness
        end

        if _M.genomeCallback ~= nil then
            _M.genomeCallback(genome, _M.currentGenomeIndex)
        end
        
        message(_M, string.format("Gen %d species %d genome %d fitness: %d", _M.currentGenerationIndex, _M.currentSpecies.id, _M.currentGenomeIndex, math.floor(fitness)))
        _M.currentGenomeIndex = 1
        while fitnessAlreadyMeasured(_M) do
            _M.currentGenomeIndex = _M.currentGenomeIndex + 1
            if _M.currentGenomeIndex > #_M.currentSpecies.genomes then
                game.unregisterHandlers()
                for i=#_M.dereg,1,-1 do
                    local d = table.remove(_M.dereg, i)
                    callback.unregister(d[1], d[2])
                end

                input.keyhook("1", false)
                input.keyhook("4", false)
                input.keyhook("6", false)
                input.keyhook("8", false)
                input.keyhook("9", false)
                input.keyhook("tab", false)

                return _M.maxFitness
            end
        end

        return initializeRun(_M):next(function()
            return mainLoop(_M, genome)
        end)
    end)
end

local function register(_M, name, func)
    callback.register(name, func)
    _M.dereg[#_M.dereg+1] = { name, func }
end

local function save(_M)
    for i=#_M.onSaveHandler,1,-1 do
        _M.onSaveHandler[i](_M.saveLoadFile)
    end

    message(_M, "Will be saved once all currently active threads finish", 0x00990000)
end

local function onSave(_M, handler)
    table.insert(_M.onSaveHandler, handler)
end

local function load(_M)
    for i=#_M.onLoadHandler,1,-1 do
        _M.onLoadHandler[i](_M.saveLoadFile)
    end

    message(_M, "Will be loaded once all currently active threads finish", 0x00990000)
end

local function onLoad(_M, handler)
    table.insert(_M.onLoadHandler, handler)
end

local function reset(_M)
    for i=#_M.onResetHandler,1,-1 do
        _M.onResetHandler[i]()
    end

    message(_M, "Will be reset once all currently active threads finish", 0x00990000)
end

local function onReset(_M, handler)
    table.insert(_M.onResetHandler, handler)
end

local function keyhook (_M, key, state)
    if state.value == 1 then
        if key == "tab" then
            _M.inputmode = not _M.inputmode
            _M.helddown = key
        elseif _M.inputmode then
            return
        elseif key == "1" then
            _M.helddown = key
            config.Running = not config.Running
        elseif key == "4" then
            -- FIXME Should be handled similarly to other events
            _M.helddown = key
            pool.requestTop()
        elseif key == "6" then
            _M.helddown = key
            save(_M)
        elseif key == "8" then
            _M.helddown = key
            load(_M)
        elseif key == "9" then
            _M.helddown = key
            reset(_M)
        end
    elseif state.value == 0 then
        _M.helddown = nil
    end
end

local function saveLoadInput(_M)
    local inputs = input.raw()
    if not _M.inputmode then
        -- FIXME
        _M.saveLoadFile = config.NeatConfig.SaveFile
        return
    end
    if _M.helddown == nil then
        local mapping = {
            backslash = "\\",
            colon = ":",
            comma = ",",
            exclaim = "!",
            dollar = "$",
            hash = "#",
            caret = "^",
            ampersand = "&",
            asterisk = "*",
            leftparen = "(",
            rightparen = ")",
            less = "<",
            greater = ">",
            quote = "'",
            quotedbl = "\"",
            semicolon = ";",
            slash = "/",
            question = "?",
            leftcurly = "{",
            leftbracket = "[",
            rightcurly = "}",
            rightbracket = "]",
            pipe = "|",
            tilde = "~",
            underscore = "_",
            at = "@",
            period = ".",
            equals = "=",
            plus = "+",
        }
        for k,v in pairs(inputs) do
            if v["type"] ~= "key" or v["value"] ~= 1 then
                goto continue
            end
            if k == "back" then
                config.NeatConfig.SaveFile = config.NeatConfig.SaveFile:sub(1, #config.NeatConfig.SaveFile-1)
                _M.helddown = k
                goto continue
            end
            local m = k
            if mapping[k] ~= nil then
                m = mapping[k]
            end
            if #m ~= 1 then
                goto continue
            end
            config.NeatConfig.SaveFile = config.NeatConfig.SaveFile..m
            _M.helddown = k
            ::continue::
        end
    elseif _M.helddown ~= nil and inputs[_M.helddown]["value"] ~= 1 then
        _M.helddown = nil
    end
end

local function run(_M, species, generationIdx, genomeCallback)
    if beginRewindState == nil then
        beginRewindState = movie.to_rewind(config.NeatConfig.Filename)
    end
    game.registerHandlers()

    _M.currentGenerationIndex = generationIdx
    _M.currentSpecies = species
    _M.currentGenomeIndex = 1
    _M.genomeCallback = genomeCallback
    register(_M, 'paint', function()
        painting(_M)
    end)
    register(_M, 'input', function()
        frame = frame + 1
        updateController()
        saveLoadInput(_M)
    end)
    register(_M, 'keyhook', function(key, state)
        keyhook(_M, key, state)
    end)

    input.keyhook("1", true)
    input.keyhook("4", true)
    input.keyhook("6", true)
    input.keyhook("8", true)
    input.keyhook("9", true)
    input.keyhook("tab", true)

    return initializeRun(_M):next(function()
        return mainLoop(_M)
    end)
end

local function onMessage(_M, handler)
    table.insert(_M.onMessageHandler, handler)
end

local function onRenderForm(_M, handler)
    table.insert(_M.onRenderFormHandler, handler)
end

return function(promise)
    Promise = promise
    if game == nil then
        game = dofile(base.."/game.lua")(Promise)
    end
    local _M = {
        currentGenerationIndex = 1,
        currentSpecies = nil,
        genomeCallback = nil,
        currentGenomeIndex = 1,
        currentFrame = 0,
        drawFrame = 0,
        maxFitness = nil,

        dereg = {},
        inputmode = false,
        helddown = nil,
        saveLoadFile = config.NeatConfig.SaveLoadFile,

        timeout = 0,
        bumps = 0,
        startKong = 0,
        lastBananas = 0,
        totalBananas = 0,
        startKrem = 0,
        lastKrem = 0,
        startCoins = 0,
        startLives = 0,
        partyHitCounter = 0,
        powerUpCounter = 0,
        powerUpBefore = 0,
        currentArea = 0,
        lastArea = 0,
        areaInfo = {},
        lastBoth = 0,

        onMessageHandler = {},
        onSaveHandler = {},
        onLoadHandler = {},
        onResetHandler = {},
        onRenderFormHandler = {},
    }

    _M.onRenderForm = function(handler)
        onRenderForm(_M, handler)
    end

    _M.onMessage = function(handler)
        onMessage(_M, handler)
    end

    _M.onSave = function(handler)
        onSave(_M, handler)
    end

    _M.onLoad = function(handler)
        onLoad(_M, handler)
    end

    _M.onReset = function(handler)
        onReset(_M, handler)
    end

    _M.run = function(species, generationIdx, genomeCallback)
        return run(_M, species, generationIdx, genomeCallback)
    end

    return _M
end