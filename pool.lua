local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")

local config = dofile(base.."/config.lua")
local util = dofile(base.."/util.lua")
local serpent = dofile(base.."/serpent.lua")
local libDeflate = dofile(base.."/LibDeflate.lua")

local hasThreads = 
	not util.isWin and
		config.NeatConfig.Threads > 1
local Runner = nil
if hasThreads then
    Runner = dofile(base.."/runner-wrapper.lua")
else
    Runner = dofile(base.."/runner.lua")
end

local Inputs = config.InputSize+1
local Outputs = #config.ButtonNames

local _M = {
    saveLoadFile = config.NeatConfig.SaveFile,
    onMessageHandler = {},
    onRenderFormHandler = {},
}

local pool = nil

local function message(msg, color)
    if color == nil then
        color = 0x00009900
    end

    for i=#_M.onMessageHandler,1,-1 do
        _M.onMessageHandler[i](msg, color)
    end
end

local function newGenome()
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

local function randomNeuron(genes, nonInput)
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

local function newGene()
	local gene = {}
	gene.into = 0
	gene.out = 0
	gene.weight = 0.0
	gene.enabled = true
	gene.innovation = 0
	
	return gene
end

local function containsLink(genes, link)
	for i=1,#genes do
		local gene = genes[i]
		if gene.into == link.into and gene.out == link.out then
			return true
		end
	end
end

local function newInnovation()
	pool.innovation = pool.innovation + 1
	return pool.innovation
end

local function linkMutate(genome, forceBias)
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

local function copyGene(gene)
	local gene2 = newGene()
	gene2.into = gene.into
	gene2.out = gene.out
	gene2.weight = gene.weight
	gene2.enabled = gene.enabled
	gene2.innovation = gene.innovation
	
	return gene2
end

local function nodeMutate(genome)
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

local function pointMutate(genome)
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

local function enableDisableMutate(genome, enable)
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

local function mutate(genome)
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

local function basicGenome()
	local genome = newGenome()
	local innovation = 1

	genome.maxneuron = Inputs
	mutate(genome)
	
	return genome
end

local function newPool()
	local pool = {}
    pool.speciesId = 1
	pool.species = {}
	pool.generation = 0
	pool.innovation = Outputs
	pool.maxFitness = 0
	
	return pool
end

local function newSpecies()
	local species = {}
    species.id = pool.speciesId
    pool.speciesId = pool.speciesId + 1
	species.topFitness = 0
	species.staleness = 0
	species.genomes = {}
	species.averageFitness = 0
	
	return species
end

local function disjoint(genes1, genes2)
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

local function weights(genes1, genes2)
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

local function sameSpecies(genome1, genome2)
	local dd = config.NeatConfig.DeltaDisjoint*disjoint(genome1.genes, genome2.genes)
	local dw = config.NeatConfig.DeltaWeights*weights(genome1.genes, genome2.genes) 
	return dd + dw < config.NeatConfig.DeltaThreshold
end

local function addToSpecies(child)
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

local function initializePool(after)
	pool = newPool()

	for i=1,config.NeatConfig.Population do
		basic = basicGenome()
		addToSpecies(basic)
	end

    after()
end

local function bytes(x)
    local b4=x%256  x=(x-x%256)/256
    local b3=x%256  x=(x-x%256)/256
    local b2=x%256  x=(x-x%256)/256
    local b1=x%256  x=(x-x%256)/256
    return string.char(b1,b2,b3,b4)
end

local function writeFile(filename)
    local file = io.open(filename, "w")
    local dump = serpent.dump(pool)
    local zlib = libDeflate:CompressDeflate(dump)
    file:write("\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x00")
    file:write(zlib)
    file:write(string.char(0,0,0,0))
    file:write(bytes(#dump % (2^32)))
    file:close()
    return
end

-- FIXME Save/load mechanism has to be rethought with items running in parallel
local function loadFile(filename, after)
    message("Loading pool from " .. filename, 0x00999900)
    local file = io.open(filename, "r")
    if file == nil then
        message("File could not be loaded", 0x00990000)
        return
    end
    local contents = file:read("*all")
    local ok, obj = serpent.load(libDeflate:DecompressDeflate(contents:sub(11, #contents - 8)))
    if not ok then
        message("Error parsing pool file", 0x00990000)
        return
    end

    pool = obj
end

local function savePool()
	local filename = _M.saveLoadFile
	writeFile(filename)
    message(string.format("Saved \"%s\"!", filename:sub(#filename - 50)), 0x00009900)
end

local function loadPool(after)
	loadFile(_M.saveLoadFile, after)
    after()
end

local function processRenderForm(form)
    for i=#_M.onRenderFormHandler,1,-1 do
        _M.onRenderFormHandler[i](form)
    end
end

local function copyGenome(genome)
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

local function crossover(g1, g2)
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

local function rankGlobally()
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

local function calculateAverageFitness(species)
	local total = 0
	
	for g=1,#species.genomes do
		local genome = species.genomes[g]
		total = total + genome.globalRank
	end
	
	species.averageFitness = total / #species.genomes
end

local function totalAverageFitness()
	local total = 0
	for s = 1,#pool.species do
		local species = pool.species[s]
		total = total + species.averageFitness
	end

	return total
end

local function cullSpecies(cutToOne)
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

local function breedChild(species)
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

local function removeStaleSpecies()
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

local function removeWeakSpecies()
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

local function newGeneration()
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

    table.sort(pool.species, function(a,b)
        return (#a.genomes < #b.genomes)
    end)
	
	pool.generation = pool.generation + 1
	
	writeFile(_M.saveLoadFile .. ".gen" .. pool.generation .. ".pool")
end

local runner = Runner()
runner.onMessage(function(msg, color)
	message(msg, color)
end)
runner.onSave(function(filename)
	_M.requestSave(filename)
end)
runner.onLoad(function(filename)
	_M.requestLoad(filename)
end)
runner.onRenderForm(function(form)
	processRenderForm(form)
end)

local playTop = nil
local topRequested = false

local loadRequested = false
local saveRequested = false
local function mainLoop(currentSpecies)
    if loadRequested then
        loadRequested = false
        loadPool(mainLoop)
        return
    end

    if saveRequested then
        saveRequested = false
        savePool()
    end

    if topRequested then
        topRequested = false
        playTop()
        return
    end

    if not config.Running then
        -- FIXME Tick?
    end

    if currentSpecies == nil then
        currentSpecies = 1
    end

    local slice = pool.species[currentSpecies]
    if hasThreads then
        slice = {}
        for i=currentSpecies, currentSpecies + config.NeatConfig.Threads - 1, 1 do
            if pool.species[i] == nil then
                break
            end

            table.insert(slice, pool.species[i])
        end
    end
    local finished = 0
    runner.run(
        slice, 
        pool.generation, 
        function()
            -- Genome callback
        end,
        function()
            if hasThreads then
                finished = finished + 1
                if finished ~= #slice then
                    return
                end
                currentSpecies = currentSpecies + #slice
            else
                currentSpecies = currentSpecies + 1
            end

            if currentSpecies > #pool.species then
                newGeneration()
                currentSpecies = 1
            end
            mainLoop(currentSpecies)
        end
    )
end

playTop = function()
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
	
    -- FIXME genome
    mainLoop(maxs)
end

function _M.requestLoad(filename)
    _M.saveLoadFile = filename
    loadRequested = true
end

function _M.requestSave(filename)
    _M.saveLoadFile = filename
    saveRequested = true
end

function _M.onMessage(handler)
    table.insert(_M.onMessageHandler, handler)
end

function _M.onRenderForm(handler)
    table.insert(_M.onRenderFormHandler, handler)
end

function _M.requestTop()
    topRequested = true
end

function _M.run(reset)
    if pool == nil or reset == true then
        initializePool(function() 
            writeFile(config.PoolDir.."temp.pool")
            mainLoop()
        end)
    else
        writeFile(config.PoolDir.."temp.pool")
        mainLoop()
    end
end

return _M
