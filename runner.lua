local gui, input, movie, settings, exec, callback, set_timer_timeout = gui, input, movie, settings, exec, callback, set_timer_timeout

local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")

local Promise = nil

local config = dofile(base.."/config.lua")
local game = dofile(base.."/game.lua")
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

local function advanceFrame(_M)
    local promise = Promise.new()
    table.insert(_M.onFrameAdvancedHandler, promise)
    return promise
end

local function processFrameAdvanced(_M)
    for i=#_M.onFrameAdvancedHandler,1,-1 do
        table.remove(_M.onFrameAdvancedHandler, i):resolve()
    end
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

    gui.text(130, 2, "[4] Play Top")

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

local formCtx = nil
local form = nil
local function displayForm(_M)
    if #_M.onRenderFormHandler == 0 then
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

    local rightmost = _M.rightmost[_M.currentArea]
    if rightmost == nil then
        rightmost = 0
    end

	gui.text(5, 30, "Timeout: " .. _M.timeout)
	gui.text(5, 5, "Generation: " .. _M.currentGenerationIndex)
	gui.text(130, 5, "Species: " .. _M.currentSpecies.id)
	gui.text(230, 5, "Genome: " .. _M.currentGenomeIndex)
	gui.text(130, 30, "Max: " .. math.floor(_M.maxFitness))
	--gui.text(330, 5, "Measured: " .. math.floor(measured/total*100) .. "%")
	gui.text(5, 65, "Bananas: " .. (game.getBananas() - _M.startBananas))
	gui.text(5, 80, "KONG: " .. (game.getKong() - _M.startKong))
    gui.text(5, 95, "Krem: " .. (game.getKremCoins() - _M.startKrem))
	gui.text(130, 65, "Coins: " .. (game.getCoins() - _M.startCoins))
	gui.text(130, 80, "Lives: " .. game.getLives())
    gui.text(130, 95, "Bumps: " .. _M.bumps)
	gui.text(230, 65, "Damage: " .. _M.partyHitCounter)
	gui.text(230, 80, "PowerUp: " .. _M.powerUpCounter)
	gui.text(320, 65, string.format("Current Area: %04x", _M.currentArea))
	gui.text(320, 80, "Rightmost: "..rightmost)

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

local controller = nil
local function evaluateCurrent(_M)
	local genome = _M.currentSpecies.genomes[_M.currentGenomeIndex]
	
	local inputDeltas = {}
	local inputs, inputDeltas = game.getInputs()

	controller = evaluateNetwork(_M, genome.network, inputs, inputDeltas)

	if controller[6] and controller[7] then
		controller[6] = false
		controller[7] = false
	end
	if controller[4] and controller[5] then
		controller[4] = false
		controller[5] = false
	end

    for b=0,#config.ButtonNames - 1,1 do
        if controller[b] then
            input.set(0, b, 1)
        else
            input.set(0, b, 0)
        end
    end
end

local function fitnessAlreadyMeasured(_M)
	local genome = _M.currentSpecies.genomes[_M.currentGenomeIndex]
	
	return genome.fitness ~= 0
end

local rewinds = {}
local rew = movie.to_rewind(config.NeatConfig.Filename)
local function rewind()
    local promise = Promise.new()
    movie.unsafe_rewind(rew)
    table.insert(rewinds, promise)
    return promise
end

local frame = 0
local lastFrame = 0 

local function rewound()
    frame = 0
    lastFrame = 0
    for i=#rewinds,1,-1 do
        local promise = table.remove(rewinds, i)
        promise:resolve()
    end
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


local function initializeRun(_M)
    message(_M, string.format("Total Genomes: %d", #_M.currentSpecies.genomes))

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
        _M.startBananas = game.getBananas()
        _M.startKrem = game.getKremCoins()
        _M.lastKrem = _M.startKrem
        _M.startCoins = game.getCoins()
        _M.startLives = game.getLives()
        _M.partyHitCounter = 0
        _M.powerUpCounter = 0
        _M.powerUpBefore = game.getBoth()
        _M.currentArea = game.getCurrentArea()
        _M.lastArea = _M.currentArea
        _M.rightmost = { [_M.currentArea] = 0 }
        _M.upmost = { [_M.currentArea] = 0 }
        local genome = _M.currentSpecies.genomes[_M.currentGenomeIndex]
        generateNetwork(genome)
        evaluateCurrent(_M)
    end)
end

local function mainLoop(_M, genome)
    return advanceFrame(_M):next(function()
        if lastFrame + 1 ~= frame then
            message(_M, string.format("We missed %d frames", frame - lastFrame), 0x00990000)
        end
        lastFrame = frame

        if genome ~= nil then
            _M.currentFrame = _M.currentFrame + 1
        end

        genome = _M.currentSpecies.genomes[_M.currentGenomeIndex]

        if _M.drawFrame % 10 == 0 then
            displayGenome(genome)
        end
        
        if _M.currentFrame%5 == 0 then
            evaluateCurrent(_M)
        end

        for b=0,#config.ButtonNames - 1,1 do
            if controller[b] then
                input.set(0, b, 1)
            else
                input.set(0, b, 0)
            end
        end

        game.getPositions()
        local timeoutConst = 0
        if game.vertical then
            timeoutConst = config.NeatConfig.TimeoutConstant * 10
        else
            timeoutConst = config.NeatConfig.TimeoutConstant
        end

        -- Don't punish being launched by barrels
        -- FIXME Will this skew mine cart levels?
        if game.getVelocityY() < -2104 then
            message(_M, "BARREL! ".._M.drawFrame, 0x00ffff00)
            if _M.timeout < timeoutConst + 60 * 12 then
                _M.timeout = _M.timeout + 60 * 12
            end
        end

        local nextArea = game.getCurrentArea()
        if nextArea ~= _M.lastArea then
            _M.lastArea = nextArea
            game.onceAreaLoaded(function()
                message(_M, "Loady")
                _M.timeout = _M.timeout + 60 * 5
                _M.currentArea = nextArea
                _M.lastArea = _M.currentArea
                if _M.rightmost[_M.currentArea] == nil then
                    _M.rightmost[_M.currentArea] = 0
                    _M.upmost[_M.currentArea] = 0
                end
            end)
        end

        if not game.vertical then
            if game.partyX > _M.rightmost[_M.currentArea] then
                _M.rightmost[_M.currentArea] = game.partyX
                if _M.timeout < timeoutConst then
                    _M.timeout = timeoutConst
                end
            end
        else
            if game.partyY > _M.upmost[_M.currentArea] then
                _M.upmost[_M.currentArea] = game.partyY
                if _M.timeout < timeoutConst then
                    _M.timeout = timeoutConst
                end
            end
        end
        -- FIXME Measure distance to target / area exit
        -- We might not always be horizontal
        
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
        local bananas = game.getBananas() - _M.startBananas
        local coins = game.getCoins() - _M.startCoins
        local kong = game.getKong()

        message(_M, string.format("Bananas: %d, coins: %d, Krem: %d,  KONG: %d", bananas, coins, krem, kong))

        local bananaCoinsFitness = (krem * 100) + (kong * 60) + (bananas * 50) + (coins * 0.2)
        if (bananas + coins) > 0 then 
            message(_M, "Bananas, Coins, KONG added " .. bananaCoinsFitness .. " fitness")
        end

        local hitPenalty = _M.partyHitCounter * 100
        local bumpPenalty = _M.bumps * 100
        local powerUpBonus = _M.powerUpCounter * 100

        local most = 0
        if not game.vertical then
            for k,v in pairs(_M.rightmost) do
                most = most + v
            end
            most = most - _M.currentFrame / 2
        else
            for k,v in pairs(_M.upmost) do
                most = most + v
            end
            most = most - _M.currentFrame / 2
        end
    
        local fitness = bananaCoinsFitness - bumpPenalty - hitPenalty + powerUpBonus + most + game.getJumpHeight() / 100

        local lives = game.getLives()

        if _M.startLives < lives then
            local extraLiveBonus = (lives - _M.startLives)*1000
            fitness = fitness + extraLiveBonus
            message(_M, "Extra live bonus added " .. extraLiveBonus)
        end

        if game.getGoalHit() then
            fitness = fitness + 1000
            message(_M, string.format("LEVEL WON! Fitness: %d", fitness), 0x0000ff00)
        end
        if fitness == 0 then
            fitness = -1
        end
        genome.fitness = fitness
        
        if fitness > _M.maxFitness then
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

                return
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
            -- FIXME Event inversion
            _M.helddown = key
            pool.run(true)
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
    if helddown == nil then
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
                helddown = k
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
            helddown = k
            ::continue::
        end
    elseif helddown ~= nil and inputs[helddown]["value"] ~= 1 then
        helddown = nil
    end
end

local function run(_M, species, generationIdx, genomeCallback)
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
        processFrameAdvanced(_M)
        saveLoadInput(_M)
    end)
    register(_M, 'keyhook', function(key, state)
        keyhook(_M, key, state)
    end)
    register(_M, 'post_rewind', rewound)

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
    local _M = {
        currentGenerationIndex = 1,
        currentSpecies = nil,
        genomeCallback = nil,
        currentGenomeIndex = 1,
        currentFrame = 0,
        drawFrame = 0,
        maxFitness = 0,

        dereg = {},
        inputmode = false,
        helddown = nil,
        saveLoadFile = config.NeatConfig.SaveLoadFile,

        timeout = 0,
        bumps = 0,
        startKong = 0,
        startBananas = 0,
        startKrem = 0,
        lastKrem = 0,
        startCoins = 0,
        startLives = 0,
        partyHitCounter = 0,
        powerUpCounter = 0,
        powerUpBefore = 0,
        currentArea = 0,
        lastArea = 0,
        rightmost = {},
        upmost = {},
        lastBoth = 0,

        onMessageHandler = {},
        onSaveHandler = {},
        onLoadHandler = {},
        onRenderFormHandler = {},
        onFrameAdvancedHandler = {},

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

    _M.run = function(species, generationIdx, genomeCallback)
        return run(_M, species, generationIdx, genomeCallback)
    end

    return _M
end
