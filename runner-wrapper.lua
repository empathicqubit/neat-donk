local random = random

local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")

local Promise = nil

local util = nil
local config = dofile(base.."/config.lua")
local serpent = dofile(base.."/serpent.lua")
local temps = {
    os.getenv("TMPDIR"),
    os.getenv("TEMP"),
    os.getenv("TEMPDIR"),
    os.getenv("TMP"),
}

local tempDir = "/tmp"
for i=1,#temps,1 do
    local temp = temps[i]
    if temp ~= nil and temp ~= "" then
        tempDir = temps[i]
        break
    end
end

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

        local outputFileName = outputPrefix..i
        local inputPipeName = inputPrefix..i
        local inputFileName = inputPrefix..i
        if util.isWin then
            outputFileName = '\\\\.\\pipe\\'..outputFileName
            inputFileName = '\\\\.\\pipe\\'..inputPipeName
        end

        local settingsDir = nil
        if util.isWin then
            settingsDir = tempDir.."/donk_runner_settings_"..i
            util.mkdir(settingsDir)
        end

        local envs = {
            RUNNER_INPUT_PIPE = inputPipeName,
            RUNNER_OUTPUT_FILE = outputFileName,
            APPDATA = settingsDir,
        }

        local cmd = '"'.._M.hostProcess..'" "--rom='..config.ROM..'" --unpause "--lua='..base..'/runner-process.lua"'
        newOne.process = util.popenCmd(cmd, nil, envs)

        -- Wait for init
        local promise = util.promiseWrap(function()
            newOne.output:read("*l")
            while newOne.input == nil do
                newOne.input = io.open(inputFileName, 'w')
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

    _M.run = function(speciesSlice, generationIdx, genomeCallback)
        local promise = Promise.new()
        promise:resolve()
        return promise:next(function()
            return launchChildren(_M, #speciesSlice)
        end):next(function()
            message(_M, 'Setting up child processes')

            for i=1,#speciesSlice,1 do
                local inputPipe = _M.poppets[i].input
                inputPipe:write(serpent.dump({speciesSlice[i], generationIdx}).."\n")
                inputPipe:flush()
            end

            message(_M, 'Waiting for child processes to finish')

            local function readLoop(outputPipe, line)
                return util.promiseWrap(function()
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
                    elseif obj.type == 'onGenome' then
                        for i=1,#speciesSlice,1 do
                            local s = speciesSlice[i]
                            if s.id == obj.speciesId then
                                s.genomes[obj.genomeIndex] = obj.genome
                                break
                            end
                        end
                        genomeCallback(obj.genome, obj.index)
                    elseif obj.type == 'onFinish' then
                        return true
                    end

                end):next(function(finished)
                    if finished then
                        return
                    end

                    local line = outputPipe:read("*l")
                    return readLoop(outputPipe, line)
                end)
            end

            local waiters = {}
            for i=1,#speciesSlice,1 do
                local waiter = util.promiseWrap(function()
                    local outputPipe = _M.poppets[i].output
                    local line = outputPipe:read("*l")

                    print("Started receiving output from child process "..i)

                    return readLoop(outputPipe, line)
                end)
                table.insert(waiters, waiter)
            end

            return Promise.all(table.unpack(waiters))
        end):next(function()
            message(_M, 'Child processes finished')
        end)
    end

    return _M
end
