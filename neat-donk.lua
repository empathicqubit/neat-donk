--Update to Seth-Bling's MarI/O app

local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*/)(.*)", "%1")

local json = dofile(base.."/dkjson.lua")
local libDeflate = dofile(base.."/LibDeflate.lua")
local config = dofile(base.."/config.lua")
local game = dofile(base.."/game.lua")
local mathFunctions = dofile(base.."/mathFunctions.lua")
local util = dofile(base.."/util.lua")

loadRequested = false
saveRequested = false
lastBoth = 0
form = nil
netPicture = nil
runInitialized = {}
frameAdvanced = {}

saveLoadFile = config.NeatConfig.SaveFile
statusLine = nil
statusColor = 0x0000ff00

Inputs = config.InputSize+1
Outputs = #config.ButtonNames

function newInnovation()
	pool.innovation = pool.innovation + 1
	return pool.innovation
end

function newPool()
	local pool = {}
	pool.species = {}
	pool.generation = 0
	pool.innovation = Outputs
	pool.currentSpecies = 1
	pool.currentGenome = 1
	pool.currentFrame = 0
	pool.maxFitness = 0
	
	return pool
end

function newSpecies()
	local species = {}
	species.topFitness = 0
	species.staleness = 0
	species.genomes = {}
	species.averageFitness = 0
	
	return species
end

function newGenome()
	local genome = {}
	genome.genes = {}
	genome.fitness = 0
	genome.adjustedFitness = 0
	genome.network = {}
	genome.maxneuron = 0
	genome.globalRank = 0
	genome.mutationRates = {}
	genome.mutationRates["connections"] = config.NeatConfig.MutateConnectionsChance
	genome.mutationRates["link"] = config.NeatConfig.LinkMutationChance
	genome.mutationRates["bias"] = config.NeatConfig.BiasMutationChance
	genome.mutationRates["node"] = config.NeatConfig.NodeMutationChance
	genome.mutationRates["enable"] = config.NeatConfig.EnableMutationChance
	genome.mutationRates["disable"] = config.NeatConfig.DisableMutationChance
	genome.mutationRates["step"] = config.NeatConfig.StepSize
	
	return genome
end

function copyGenome(genome)
	local genome2 = newGenome()
	for g=1,#genome.genes do
		table.insert(genome2.genes, copyGene(genome.genes[g]))
	end
	genome2.maxneuron = genome.maxneuron
	genome2.mutationRates["connections"] = genome.mutationRates["connections"]
	genome2.mutationRates["link"] = genome.mutationRates["link"]
	genome2.mutationRates["bias"] = genome.mutationRates["bias"]
	genome2.mutationRates["node"] = genome.mutationRates["node"]
	genome2.mutationRates["enable"] = genome.mutationRates["enable"]
	genome2.mutationRates["disable"] = genome.mutationRates["disable"]
	
	return genome2
end

function basicGenome()
	local genome = newGenome()
	local innovation = 1

	genome.maxneuron = Inputs
	mutate(genome)
	
	return genome
end

function newGene()
	local gene = {}
	gene.into = 0
	gene.out = 0
	gene.weight = 0.0
	gene.enabled = true
	gene.innovation = 0
	
	return gene
end

function copyGene(gene)
	local gene2 = newGene()
	gene2.into = gene.into
	gene2.out = gene.out
	gene2.weight = gene.weight
	gene2.enabled = gene.enabled
	gene2.innovation = gene.innovation
	
	return gene2
end

function newNeuron()
	local neuron = {}
	neuron.incoming = {}
	neuron.value = 0.0
	--neuron.dw = 1
	return neuron
end

function generateNetwork(genome)
	local network = {}
	network.neurons = {}
	
	for i=1,Inputs do
		network.neurons[i] = newNeuron()
	end
	
	for o=1,Outputs do
		network.neurons[config.NeatConfig.MaxNodes+o] = newNeuron()
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

function evaluateNetwork(network, inputs, inputDeltas)
	table.insert(inputs, 1)
	table.insert(inputDeltas,99)
	if #inputs ~= Inputs then
		print("Incorrect number of neural network inputs.")
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
		local button = o - 1
		if network.neurons[config.NeatConfig.MaxNodes+o].value > 0 then
			outputs[button] = true
		else
			outputs[button] = false
		end
	end
	
	return outputs
end

function crossover(g1, g2)
	-- Make sure g1 is the higher fitness genome
	if g2.fitness > g1.fitness then
		tempg = g1
		g1 = g2
		g2 = tempg
	end

	local child = newGenome()
	
	local innovations2 = {}
	for i=1,#g2.genes do
		local gene = g2.genes[i]
		innovations2[gene.innovation] = gene
	end
	
	for i=1,#g1.genes do
		local gene1 = g1.genes[i]
		local gene2 = innovations2[gene1.innovation]
		if gene2 ~= nil and math.random(2) == 1 and gene2.enabled then
			table.insert(child.genes, copyGene(gene2))
		else
			table.insert(child.genes, copyGene(gene1))
		end
	end
	
	child.maxneuron = math.max(g1.maxneuron,g2.maxneuron)
	
	for mutation,rate in pairs(g1.mutationRates) do
		child.mutationRates[mutation] = rate
	end
	
	return child
end

function randomNeuron(genes, nonInput)
	local neurons = {}
	if not nonInput then
		for i=1,Inputs do
			neurons[i] = true
		end
	end
	for o=1,Outputs do
		neurons[config.NeatConfig.MaxNodes+o] = true
	end
	for i=1,#genes do
		if (not nonInput) or genes[i].into > Inputs then
			neurons[genes[i].into] = true
		end
		if (not nonInput) or genes[i].out > Inputs then
			neurons[genes[i].out] = true
		end
	end

	local count = 0
	for _,_ in pairs(neurons) do
		count = count + 1
	end
	local n = math.random(1, count)
	
	for k,v in pairs(neurons) do
		n = n-1
		if n == 0 then
			return k
		end
	end
	
	return 0
end

function containsLink(genes, link)
	for i=1,#genes do
		local gene = genes[i]
		if gene.into == link.into and gene.out == link.out then
			return true
		end
	end
end

function pointMutate(genome)
	local step = genome.mutationRates["step"]
	
	for i=1,#genome.genes do
		local gene = genome.genes[i]
		if math.random() < config.NeatConfig.PerturbChance then
			gene.weight = gene.weight + math.random() * step*2 - step
		else
			gene.weight = math.random()*4-2
		end
	end
end

function linkMutate(genome, forceBias)
	local neuron1 = randomNeuron(genome.genes, false)
	local neuron2 = randomNeuron(genome.genes, true)
	 
	local newLink = newGene()
	if neuron1 <= Inputs and neuron2 <= Inputs then
		--Both input nodes
		return
	end
	if neuron2 <= Inputs then
		-- Swap output and input
		local temp = neuron1
		neuron1 = neuron2
		neuron2 = temp
	end

	newLink.into = neuron1
	newLink.out = neuron2
	if forceBias then
		newLink.into = Inputs
	end
	
	if containsLink(genome.genes, newLink) then
		return
	end
	newLink.innovation = newInnovation()
	newLink.weight = math.random()*4-2
	
	table.insert(genome.genes, newLink)
end

function nodeMutate(genome)
	if #genome.genes == 0 then
		return
	end

	genome.maxneuron = genome.maxneuron + 1

	local gene = genome.genes[math.random(1,#genome.genes)]
	if not gene.enabled then
		return
	end
	gene.enabled = false
	
	local gene1 = copyGene(gene)
	gene1.out = genome.maxneuron
	gene1.weight = 1.0
	gene1.innovation = newInnovation()
	gene1.enabled = true
	table.insert(genome.genes, gene1)
	
	local gene2 = copyGene(gene)
	gene2.into = genome.maxneuron
	gene2.innovation = newInnovation()
	gene2.enabled = true
	table.insert(genome.genes, gene2)
end

function enableDisableMutate(genome, enable)
	local candidates = {}
	for _,gene in pairs(genome.genes) do
		if gene.enabled == not enable then
			table.insert(candidates, gene)
		end
	end
	
	if #candidates == 0 then
		return
	end
	
	local gene = candidates[math.random(1,#candidates)]
	gene.enabled = not gene.enabled
end

function mutate(genome)
	for mutation,rate in pairs(genome.mutationRates) do
		if math.random(1,2) == 1 then
			genome.mutationRates[mutation] = 0.95*rate
		else
			genome.mutationRates[mutation] = 1.05263*rate
		end
	end

	if math.random() < genome.mutationRates["connections"] then
		pointMutate(genome)
	end
	
	local p = genome.mutationRates["link"]
	while p > 0 do
		if math.random() < p then
			linkMutate(genome, false)
		end
		p = p - 1
	end

	p = genome.mutationRates["bias"]
	while p > 0 do
		if math.random() < p then
			linkMutate(genome, true)
		end
		p = p - 1
	end
	
	p = genome.mutationRates["node"]
	while p > 0 do
		if math.random() < p then
			nodeMutate(genome)
		end
		p = p - 1
	end
	
	p = genome.mutationRates["enable"]
	while p > 0 do
		if math.random() < p then
			enableDisableMutate(genome, true)
		end
		p = p - 1
	end

	p = genome.mutationRates["disable"]
	while p > 0 do
		if math.random() < p then
			enableDisableMutate(genome, false)
		end
		p = p - 1
	end
end

function disjoint(genes1, genes2)
	local i1 = {}
	for i = 1,#genes1 do
		local gene = genes1[i]
		i1[gene.innovation] = true
	end

	local i2 = {}
	for i = 1,#genes2 do
		local gene = genes2[i]
		i2[gene.innovation] = true
	end
	
	local disjointGenes = 0
	for i = 1,#genes1 do
		local gene = genes1[i]
		if not i2[gene.innovation] then
			disjointGenes = disjointGenes+1
		end
	end
	
	for i = 1,#genes2 do
		local gene = genes2[i]
		if not i1[gene.innovation] then
			disjointGenes = disjointGenes+1
		end
	end
	
	local n = math.max(#genes1, #genes2)
	
	return disjointGenes / n
end

function weights(genes1, genes2)
	local i2 = {}
	for i = 1,#genes2 do
		local gene = genes2[i]
		i2[gene.innovation] = gene
	end

	local sum = 0
	local coincident = 0
	for i = 1,#genes1 do
		local gene = genes1[i]
		if i2[gene.innovation] ~= nil then
			local gene2 = i2[gene.innovation]
			sum = sum + math.abs(gene.weight - gene2.weight)
			coincident = coincident + 1
		end
	end
	
	return sum / coincident
end
	
function sameSpecies(genome1, genome2)
	local dd = config.NeatConfig.DeltaDisjoint*disjoint(genome1.genes, genome2.genes)
	local dw = config.NeatConfig.DeltaWeights*weights(genome1.genes, genome2.genes) 
	return dd + dw < config.NeatConfig.DeltaThreshold
end

function rankGlobally()
	local global = {}
	for s = 1,#pool.species do
		local species = pool.species[s]
		for g = 1,#species.genomes do
			table.insert(global, species.genomes[g])
		end
	end
	table.sort(global, function (a,b)
		return (a.fitness < b.fitness)
	end)
	
	for g=1,#global do
		global[g].globalRank = g
	end
end

function calculateAverageFitness(species)
	local total = 0
	
	for g=1,#species.genomes do
		local genome = species.genomes[g]
		total = total + genome.globalRank
	end
	
	species.averageFitness = total / #species.genomes
end

function totalAverageFitness()
	local total = 0
	for s = 1,#pool.species do
		local species = pool.species[s]
		total = total + species.averageFitness
	end

	return total
end

function cullSpecies(cutToOne)
	for s = 1,#pool.species do
		local species = pool.species[s]
		
		table.sort(species.genomes, function (a,b)
			return (a.fitness > b.fitness)
		end)
		
		local remaining = math.ceil(#species.genomes/2)
		if cutToOne then
			remaining = 1
		end
		while #species.genomes > remaining do
			table.remove(species.genomes)
		end
	end
end

function breedChild(species)
	local child = {}
	if math.random() < config.NeatConfig.CrossoverChance then
		g1 = species.genomes[math.random(1, #species.genomes)]
		g2 = species.genomes[math.random(1, #species.genomes)]
		child = crossover(g1, g2)
	else
		g = species.genomes[math.random(1, #species.genomes)]
		child = copyGenome(g)
	end
	
	mutate(child)
	
	return child
end

function removeStaleSpecies()
	local survived = {}

	for s = 1,#pool.species do
		local species = pool.species[s]
		
		table.sort(species.genomes, function (a,b)
			return (a.fitness > b.fitness)
		end)
		
		if species.genomes[1].fitness > species.topFitness then
			species.topFitness = species.genomes[1].fitness
			species.staleness = 0
		else
			species.staleness = species.staleness + 1
		end
		if species.staleness < config.NeatConfig.StaleSpecies or species.topFitness >= pool.maxFitness then
			table.insert(survived, species)
		end
	end

	pool.species = survived
end

function removeWeakSpecies()
	local survived = {}

	local sum = totalAverageFitness()
	for s = 1,#pool.species do
		local species = pool.species[s]
		breed = math.floor(species.averageFitness / sum * config.NeatConfig.Population)
		if breed >= 1 then
			table.insert(survived, species)
		end
	end

	pool.species = survived
end


function addToSpecies(child)
	local foundSpecies = false
	for s=1,#pool.species do
		local species = pool.species[s]
		if not foundSpecies and sameSpecies(child, species.genomes[1]) then
			table.insert(species.genomes, child)
			foundSpecies = true
		end
	end
	
	if not foundSpecies then
		local childSpecies = newSpecies()
		table.insert(childSpecies.genomes, child)
		table.insert(pool.species, childSpecies)
	end
end

function newGeneration()
	cullSpecies(false) -- Cull the bottom half of each species
	rankGlobally()
	removeStaleSpecies()
	rankGlobally()
	for s = 1,#pool.species do
		local species = pool.species[s]
		calculateAverageFitness(species)
	end
	removeWeakSpecies()
	local sum = totalAverageFitness()
	local children = {}
	for s = 1,#pool.species do
		local species = pool.species[s]
		breed = math.floor(species.averageFitness / sum * config.NeatConfig.Population) - 1
		for i=1,breed do
			table.insert(children, breedChild(species))
		end
	end
	cullSpecies(true) -- Cull all but the top member of each species
	while #children + #pool.species < config.NeatConfig.Population do
		local species = pool.species[math.random(1, #pool.species)]
		table.insert(children, breedChild(species))
	end
	for c=1,#children do
		local child = children[c]
		addToSpecies(child)
	end
	
	pool.generation = pool.generation + 1
	
	writeFile(saveLoadFile .. ".gen" .. pool.generation .. ".pool")
end
	
function initializePool(after)
	pool = newPool()

	for i=1,config.NeatConfig.Population do
		basic = basicGenome()
		addToSpecies(basic)
	end

	initializeRun(after)
end

function on_timer()
    if config.StartPowerup ~= NIL then
        game.writePowerup(config.StartPowerup)
    end
    pool.currentFrame = 0
    timeout = config.NeatConfig.TimeoutConstant
    game.clearJoypad()
    startKong = game.getKong()
    startBananas = game.getBananas()
    startKrem = game.getKremCoins()
    startCoins = game.getCoins()
    startLives = game.getLives()
    partyHitCounter = 0
    powerUpCounter = 0
    powerUpBefore = game.getBoth()
    currentArea = game.getCurrentArea()
    lastArea = currentArea
    rightmost = { [currentArea] = 0 }
    upmost = { [currentArea] = 0 }
    local species = pool.species[pool.currentSpecies]
    local genome = species.genomes[pool.currentGenome]
    generateNetwork(genome)
    evaluateCurrent()
    for i=#runInitialized,1,-1 do
        table.remove(runInitialized, i)()
    end
end

local rew = movie.to_rewind(config.NeatConfig.Filename)

function on_post_rewind()
    set_timer_timeout(1)
end

function on_video()
    gui.kill_frame()
end

function initializeRun(after)
    settings.set_speed("turbo")
    gui.subframe_update(false)
    table.insert(runInitialized, after)
    movie.unsafe_rewind(rew)
end

function evaluateCurrent()
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	
	local inputDeltas = {}
	inputs, inputDeltas = game.getInputs()
	
	controller = evaluateNetwork(genome.network, inputs, inputDeltas)

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

function on_input()
    for i=#frameAdvanced,1,-1 do
        table.remove(frameAdvanced, i)()
    end
end

function advanceFrame(after)
    table.insert(frameAdvanced, after)
    --exec("+advance-frame")
end

function mainLoop (species, genome)
    advanceFrame(function()
        if loadRequested then
            loadRequested = false
            loadPool(mainLoop)
            return
        end

        if saveRequested then
            saveRequested = false
            savePool()
        end

        if not config.Running then
            mainLoop(species, genome)
            return
        end

        if species ~= nil and genome ~= nil then
            local measured = 0
            local total = 0
            for _,species in pairs(pool.species) do
                for _,genome in pairs(species.genomes) do
                    total = total + 1
                    if genome.fitness ~= 0 then
                        measured = measured + 1
                    end
                end
            end
            
            pool.currentFrame = pool.currentFrame + 1
        end

        species = pool.species[pool.currentSpecies]
        genome = species.genomes[pool.currentGenome]

        if frame % 10 == 0 then
            if not pcall(function()
                displayGenome(genome)
            end) then
            print("Could not render genome graph")
            end
        end
        
        if pool.currentFrame%5 == 0 then
            evaluateCurrent()
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
        if vertical then
            timeoutConst = config.NeatConfig.TimeoutConstant * 10
        else
            timeoutConst = config.NeatConfig.TimeoutConstant
        end

        -- Don't punish being launched by barrels
        -- FIXME Will this skew mine cart levels?
        if game.getVelocityY() < -1850 then
            timeout = timeoutConst + 60 * 2
        end

        local nextArea = game.getCurrentArea()
        if nextArea ~= lastArea then
            lastArea = nextArea
            game.onceAreaLoaded(function()
                timeout = timeoutConst + 60 * 2
                currentArea = nextArea
                lastArea = currentArea
                if rightmost[currentArea] == nil then
                    rightmost[currentArea] = 0
                    upmost[currentArea] = 0
                end
            end)
        end

        if not vertical then
            if partyX > rightmost[currentArea] then
                rightmost[currentArea] = partyX
                timeout = timeoutConst
            end
        else
            if partyY > upmost[currentArea] then
                upmost[currentArea] = partyY
                timeout = timeoutConst
            end
        end
        -- FIXME Measure distance to target / area exit
        -- We might not always be horizontal
        
        local hitTimer = game.getHitTimer(lastBoth)
        
        if hitTimer > 0 then
            partyHitCounter = partyHitCounter + 1
            --print("party took damage, hit counter: " .. partyHitCounter)
        end
        
        powerUp = game.getBoth()
        lastBoth = powerUp
        if powerUp > 0 then
            if powerUp ~= powerUpBefore then
                powerUpCounter = powerUpCounter+1
                powerUpBefore = powerUp
            end
        end

        local lives = game.getLives()

        timeout = timeout - 1
        
        local timeoutBonus = pool.currentFrame / 4
        if timeout + timeoutBonus <= 0 then
        
            local bananas = game.getBananas() - startBananas
            local coins = game.getCoins() - startCoins
            local krem = game.getKremCoins() - startKrem
            local kong = game.getKong()
            
            print(string.format("Bananas: %d, coins: %d, Krem: %d,  KONG: %d", bananas, coins, krem, kong))

            local bananaCoinsFitness = (krem * 100) + (kong * 60) + (bananas * 50) + (coins * 0.2)
            if (bananas + coins) > 0 then 
                print("Bananas, Coins, KONG added " .. bananaCoinsFitness .. " fitness")
            end
            
            local hitPenalty = partyHitCounter * 100
            local powerUpBonus = powerUpCounter * 100

            local most = 0
            if not vertical then
                for k,v in pairs(rightmost) do
                    most = most + v
                end
                most = most - pool.currentFrame / 2
            else
                for k,v in pairs(upmost) do
                    most = most + v
                end
                most = most - pool.currentFrame / 2
            end

        
            local fitness = bananaCoinsFitness - hitPenalty + powerUpBonus + most + game.getJumpHeight() / 100

            if startLives < lives then
                local ExtraLiveBonus = (lives - startLives)*1000
                fitness = fitness + ExtraLiveBonus
                print("ExtraLiveBonus added " .. ExtraLiveBonus)
            end

            -- FIXME sus
            --[[
            if rightmost > 4816 then
                fitness = fitness + 1000
                print("!!!!!!Beat level!!!!!!!")
            end
            -- ]]
            if fitness == 0 then
                fitness = -1
            end
            genome.fitness = fitness
            
            if fitness > pool.maxFitness then
                pool.maxFitness = fitness
                writeFile(saveLoadFile .. ".gen" .. pool.generation .. ".pool")
            end
            
            print("Gen " .. pool.generation .. " species " .. pool.currentSpecies .. " genome " .. pool.currentGenome .. " fitness: " .. fitness)
            pool.currentSpecies = 1
            pool.currentGenome = 1
            while fitnessAlreadyMeasured() do
                nextGenome()
            end
            initializeRun(function() 
                mainLoop(species, genome)
            end)
            return
        end

        mainLoop(species, genome)
    end)
end

function bytes(x)
    local b4=x%256  x=(x-x%256)/256
    local b3=x%256  x=(x-x%256)/256
    local b2=x%256  x=(x-x%256)/256
    local b1=x%256  x=(x-x%256)/256
    return string.char(b1,b2,b3,b4)
end

function writeFile(filename)
    local file = io.open(filename, "w")
    local json = json.encode(pool)
    local zlib = libDeflate:CompressDeflate(json)
    file:write("\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x00")
    file:write(zlib)
    file:write(string.char(0,0,0,0))
    file:write(bytes(#json % (2^32)))
    file:close()
    return
end

function nextGenome()
	pool.currentGenome = pool.currentGenome + 1
	if pool.currentGenome > #pool.species[pool.currentSpecies].genomes then
		pool.currentGenome = 1
		pool.currentSpecies = pool.currentSpecies+1
		if pool.currentSpecies > #pool.species then
			newGeneration()
			pool.currentSpecies = 1
		end
	end
end

function fitnessAlreadyMeasured()
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	
	return genome.fitness ~= 0
end

function savePool()
	local filename = saveLoadFile
	writeFile(filename)
    statusLine = string.format("Saved \"%s\"!", filename:sub(#filename - 50))
    statusColor = 0x00009900
end

function mysplit(inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={} ; i=1
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                t[i] = str
                i = i + 1
        end
        return t
end

function loadFile(filename, after)
		print("Loading pool from " .. filename)
        local file = io.open(filename, "r")
        if file == nil then
            statusLine = "File could not be loaded"
            statusColor = 0x00990000
            return
        end
        local contents = file:read("*all")
        local obj, pos, err = json.decode(libDeflate:DecompressDeflate(contents:sub(11, #contents - 8)))
        if err ~= nil then
            statusLine = string.format("Error parsing: %s", err)
            statusColor = 0x00990000
            return
        end

        pool = obj

        while fitnessAlreadyMeasured() do
                nextGenome()
        end
        initializeRun(function()
            pool.currentFrame = pool.currentFrame + 1
            statusLine = "Pool loaded."
            statusColor = 0x0000ff00
            after()
        end)
end

function loadPool(after)
	loadFile(saveLoadFile, after)
end

function playTop()
	local maxfitness = 0
	local maxs, maxg
	for s,species in pairs(pool.species) do
		for g,genome in pairs(species.genomes) do
			if genome.fitness > maxfitness then
				maxfitness = genome.fitness
				maxs = s
				maxg = g
			end
		end
	end
	
	pool.currentSpecies = maxs
	pool.currentGenome = maxg
	pool.maxFitness = maxfitness
	initializeRun(function()
        pool.currentFrame = pool.currentFrame + 1
    end)
end

function on_quit()
end

if pool == nil then
	initializePool(function() 
        writeFile(config.PoolDir.."temp.pool")
        mainLoop()
    end)
else
    writeFile(config.PoolDir.."temp.pool")
    mainLoop()
end

buttons = nil
buttonCtx = gui.renderctx.new(500, 50)
function displayButtons()
    buttonCtx:set()
    buttonCtx:clear()

    gui.rectangle(0, 0, 500, 50, 1, 0x000000000, 0x00990099)
    gui.text(5, 29, "..."..config.NeatConfig.SaveFile:sub(#config.NeatConfig.SaveFile - 55))
    local startStop = ""
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

	buttons = buttonCtx:render()
    gui.renderctx.setnull()
end

genomeCtx = gui.renderctx.new(470, 200)
function displayGenome(genome)
    genomeCtx:set()
    genomeCtx:clear()
    gui.solidrectangle(0, 0, 470, 200, 0x00606060)
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
		cell = {}
		cell.x = 400
		cell.y = 20 + 14 * o
		cell.value = network.neurons[config.NeatConfig.MaxNodes + o].value
		cells[config.NeatConfig.MaxNodes+o] = cell
		local color
		if cell.value > 0 then
			color = 0x000000FF
		else
			color = 0x00000000
		end
		gui.text(403, 10+14*o, config.ButtonNames[o], color, 0xff000000)
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
        gui.text(100, pos, mutation .. ": " .. rate, 0x00000000, 0xff000000)

        pos = pos + 14
    end
	netPicture = genomeCtx:render()
    gui.renderctx.setnull()
end

formCtx = nil
function displayForm()
	formCtx:set()
    formCtx:clear()
	gui.rectangle(0, 0, 500, guiHeight, 1, 0x00ffffff, 0x00000000)
	gui.circle(game.screenX-84, game.screenY-84, 192 / 2, 1, 0x50000000) 

	--gui.text(5, 30, "Fitness: " .. math.floor(rightmost - (pool.currentFrame) / 2 - (timeout + timeoutBonus)*2/3))
	gui.text(5, 5, "Generation: " .. pool.generation)
	gui.text(130, 5, "Species: " .. pool.currentSpecies)
	gui.text(230, 5, "Genome: " .. pool.currentGenome)
	gui.text(130, 30, "Max: " .. math.floor(pool.maxFitness))
	--gui.text(330, 5, "Measured: " .. math.floor(measured/total*100) .. "%")
	gui.text(5, 65, "Bananas: " .. (game.getBananas() - startBananas))
	gui.text(5, 80, "KONG: " .. (game.getKong() - startKong))
    gui.text(5, 95, "Krem: " .. (game.getKremCoins() - startKrem))
	gui.text(130, 65, "Coins: " .. (game.getCoins() - startCoins))
	gui.text(130, 80, "Lives: " .. game.getLives())
	gui.text(230, 65, "Damage: " .. partyHitCounter)
	gui.text(230, 80, "PowerUp: " .. powerUpCounter)
	gui.text(320, 65, string.format("Current Area: %04x", currentArea))
	gui.text(320, 80, "Rightmost: "..rightmost[currentArea])

    displayButtons()
    formCtx:set()
    buttons:draw(5, 130)

	if netPicture ~= nil then
		netPicture:draw(5, 200)
	end

    if statusLine ~= nil then
        gui.rectangle(0, guiHeight - 20, 500, 20, 1, 0x00000000, statusColor)
        gui.text(0, guiHeight - 20, statusLine, 0x00000000)
    end
    form = formCtx:render()
	gui.renderctx.setnull()
end

frame = 0
function on_paint()
    guiWidth, guiHeight = gui.resolution()
    if formCtx == nil then
        formCtx = gui.renderctx.new(500, guiHeight)
    end
    frame = frame + 1
    gui.left_gap(500)
    gui.top_gap(0)
    gui.bottom_gap(0)
    gui.right_gap(0)
    if frame % 10 == 0 then
        displayForm()
    end
    gui.renderctx.setnull()
    if form ~= nil then
        form:draw(-500, 0)
    end
end

helddown = false
function on_keyhook (key, state)
    if not helddown and state.value == 1 then
        if key == "1" then
            helddown = true
            config.Running = not config.Running
        elseif key == "4" then
            helddown = true
            playTop()
        elseif key == "6" then
            helddown = true
            saveRequested = true
        elseif key == "8" then
            helddown = true
            loadRequested = true
        elseif key == "9" then
            helddown = true
            initializePool()
        end
    elseif state.value == 0 then
        helddown = false
    end
end

input.keyhook("1", true)
input.keyhook("4", true)
input.keyhook("6", true)
input.keyhook("8", true)
input.keyhook("9", true)

