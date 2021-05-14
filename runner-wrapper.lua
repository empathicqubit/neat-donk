local random = random

local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")

local Promise = nil

local util = nil
local config = dofile(base.."/config.lua")
local serpent = dofile(base.."/serpent.lua")

local pipePrefix = "donk_runner_"..
    string.hex(math.floor(random.integer(0, 0xffffffff)))..
    string.hex(math.floor(random.integer(0, 0xffffffff)))

local inputPrefix = pipePrefix..'_input_'
local outputPrefix = pipePrefix..'_output_'

local function message(_M, msg, color)
    if color == nil then
        color = 0x00009900
    end

    for i=#_M.onMessageHandler,1,-1 do
        _M.onMessageHandler[i](msg, color)
    end
end

local function save(_M, filename)
    for i=#_M.onSaveHandler,1,-1 do
        _M.onSaveHandler[i](filename)
    end
end

local function onSave(_M, handler)
    table.insert(_M.onSaveHandler, handler)
end

local function load(_M, filename)
    for i=#_M.onLoadHandler,1,-1 do
        _M.onLoadHandler[i](filename)
    end
end

local function onLoad(_M, handler)
    table.insert(_M.onLoadHandler, handler)
end

local function reset(_M)
    for i=#_M.onResetHandler,1,-1 do
        _M.onResetHandler[i]()
    end
end

local function onReset(_M, handler)
    table.insert(_M.onResetHandler, handler)
end

local function onMessage(_M, handler)
    table.insert(_M.onMessageHandler, handler)
end

--- Launches the child processes
---@param _M table The instance
---@param count integer Number of processes needed
---@return Promise Promise A promise that resolves when all the processes are ready
local function launchChildren(_M, count)
    local promises = {}
    for i=#_M.poppets+1,count,1 do
        local newOne = {
            process = nil,
            output = util.openReadPipe(outputPrefix..i),
            input = nil,
        }

        local outputPipeName = outputPrefix..i
        local inputPipeName = inputPrefix..i

        local settingsDir = nil
        if util.isWin then
            settingsDir = util.getTempDir().."/donk_runner_settings_"..i
            util.mkdir(settingsDir)
        end

        local envs = {
            RUNNER_INPUT_PIPE = inputPipeName,
            RUNNER_OUTPUT_PIPE = outputPipeName,
            APPDATA = settingsDir,
        }

        local cmd = '"'.._M.hostProcess..'" "--rom='..config.ROM..'" --unpause "--lua='..base..'/runner-process.lua"'
        newOne.process = util.popenCmd(cmd, nil, envs)

        -- Wait for init
        local promise = util.promiseWrap(function()
            newOne.output:read("*l")
            while newOne.input == nil do
                newOne.input = util.openReadPipeWriter(inputPipeName)
            end
        end)
        table.insert(promises, promise)
        table.insert(_M.poppets, newOne)
    end

    return Promise.all(table.unpack(promises))
end

return function(promise)
    -- FIXME Should this be a global???
    Promise = promise
    if util == nil then
        util = dofile(base.."/util.lua")(Promise)
    end
    -- FIXME Maybe don't do this in the "constructor"?
    if util.isWin then
        util.downloadFile("https://github.com/psmay/windows-named-pipe-utils/releases/download/v0.1.1/build.zip", base.."/namedpipe.zip")
        util.unzip(base.."/namedpipe.zip", base)
        os.rename(base.."/build", "namedpipe")
    end

    local _M = {
        onMessageHandler = {},
        onResetHandler = {},
        onSaveHandler = {},
        onLoadHandler = {},
        poppets = {},
        hostProcess = "lsnes",
    }

    if util.isWin then
        _M.hostProcess = util.scrapeCmd('*l', 'powershell "(Get-WmiObject Win32_Process -Filter ProcessId=$((Get-WmiObject Win32_Process -Filter ProcessId=$((Get-WmiObject Win32_Process -Filter ProcessId=$PID).ParentProcessId)).ParentProcessId)").ExecutablePath')
        if _M.hostProcess == nil or _M.hostProcess == "" then
            _M.hostProcess = "lsnes-bsnes.exe"
        end
    else
        -- FIXME Linux
    end

    _M.onRenderForm = function(handler)
    end

    _M.onMessage = function(handler)
        onMessage(_M, handler)
    end

    _M.message = function(msg, color)
        message(_M, msg, color)
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
        local promise = Promise.new()
        promise:resolve()
        return promise:next(function()
            return launchChildren(_M, config.NeatConfig.Threads)
        end):next(function()
            message(_M, 'Setting up child processes')

            local maxFitness = nil
            local function readLoop(outputPipe)
                return util.promiseWrap(function()
                    return outputPipe:read("*l")
                end):next(function(line)
                    if line == nil or line == "" then
                        util.closeCmd(outputPipe)
                    end

                    local ok, obj = serpent.load(line)
                    if not ok then
                        return false
                    end

                    if obj == nil then
                        return false
                    end

                    if obj.type == 'onMessage' then
                        message(_M, obj.msg, obj.color)
                    elseif obj.type == 'onLoad' then
                        load(_M, obj.filename)
                    elseif obj.type == 'onSave' then
                        save(_M, obj.filename)
                    elseif obj.type == 'onReset' then
                        reset(_M)
                    elseif obj.type == 'onGenome' then
                        for i=1,#species,1 do
                            local s = species[i]
                            if s.id == obj.speciesId then
                                message(_M, string.format('Write Species %d Genome %d', obj.speciesId, obj.genomeIndex))
                                s.genomes[obj.genomeIndex] = obj.genome
                                break
                            end
                        end
                        genomeCallback(obj.genome, obj.index)
                    elseif obj.type == 'onFinish' then
                        if maxFitness == nil or obj.maxFitness > maxFitness then
                            maxFitness = obj.maxFitness
                        end
                        return true
                    end

                end):next(function(finished)
                    if finished then
                        return maxFitness
                    end

                    return readLoop(outputPipe)
                end)
            end

            local waiters = {}
            for t=1,config.NeatConfig.Threads,1 do
                waiters[t] = Promise.new()
                waiters[t]:resolve()
            end

            local currentSpecies = 1
            while currentSpecies < #species do
                for t=1,config.NeatConfig.Threads,1 do
                    local s = species[currentSpecies]
                    if s == nil then
                        break
                    end

                    local inputPipe = _M.poppets[t].input
                    local outputPipe = _M.poppets[t].output
                    waiters[t] = waiters[t]:next(function()
                        inputPipe:write(serpent.dump({s, generationIdx}).."\n")
                        inputPipe:flush()

                        return readLoop(outputPipe)
                    end)
                    currentSpecies = currentSpecies + 1
                end
            end

            message(_M, 'Waiting for child processes to finish')

            return Promise.all(table.unpack(waiters))
        end):next(function(maxFitnesses)
            message(_M, 'Child processes finished')
            local maxestFitness = maxFitnesses[1]
            for i=1,#maxFitnesses,1 do
                local maxFitness = maxFitnesses[i]
                if maxFitness > maxestFitness then
                    maxestFitness = maxFitness
                end
            end
            return maxestFitness
        end)
    end

    return _M
end
