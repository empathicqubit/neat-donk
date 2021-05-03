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

local tmpFileName = tempDir.."/donk_runner_"..
    string.hex(math.floor(random.integer(0, 0xffffffff)))..
    string.hex(math.floor(random.integer(0, 0xffffffff)))

local inputPrefix = tmpFileName..'_input_'
local outputPrefix = tmpFileName..'_output_'

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
    local children = {}
    while #_M.poppets < count do
        local i = #_M.poppets+1
        local outputFileName = outputPrefix..i
        local inputFileName = inputPrefix..i

        local settingsDir = nil
        if util.isWin then
            settingsDir = tempDir.."/donk_runner_settings_"..i
            util.mkdir(settingsDir)
        end

        local envs = {
            RUNNER_INPUT_FILE = inputFileName,
            RUNNER_OUTPUT_FILE = outputFileName,
            APPDATA = settingsDir,
        }

        local child = util.waitForFiles(outputFileName)

        local cmd = '"'.._M.hostProcess..'" "--rom='..config.ROM..'" --unpause "--lua='..base..'/runner-process.lua"'
        local poppet = util.popenCmd(cmd, nil, envs)
        table.insert(_M.poppets, poppet)

        table.insert(children, child)
    end

    return Promise.all(table.unpack(children))
end

return function(promise)
    -- FIXME Should this be a global???
    Promise = promise
    if util == nil then
        util = dofile(base.."/util.lua")(Promise)
    end
    -- FIXME Maybe don't do this in the "constructor"?
    if util.isWin then
        util.downloadFile('https://github.com/watchexec/watchexec/releases/download/1.13.1/watchexec-1.13.1-x86_64-pc-windows-gnu.zip', base..'/watchexec.zip')
        util.unzip(base..'/watchexec.zip', base)
        os.rename(base..'watchexec-1.13.1-x86_64-pc-windows-gnu', base..'/watchexec')
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
            -- Create the input files and output files
            for i=1,#speciesSlice,1 do
                local inputFileName = inputPrefix..i
                local inputFile = io.open(inputFileName, 'a')
                inputFile:close()

                local outputFileName = outputPrefix..i
                local outputFile = io.open(outputFileName, 'a')
                outputFile:close()
            end

            return launchChildren(_M, #speciesSlice)
        end):next(function()
            local outputFileNames = {}
            for i=1,#speciesSlice,1 do
                table.insert(outputFileNames, outputPrefix..i)
            end

            local waiter = util.waitForFiles(outputFileNames, nil, tmpFileName.."_output_*")

            message(_M, 'Setting up child processes')

            for i=1,#speciesSlice,1 do

                local inputFileName = tmpFileName.."_input_"..i
                local inputFile = io.open(inputFileName, 'w')
                inputFile:write(serpent.dump({speciesSlice[i], generationIdx}))
                inputFile:close()
            end

            message(_M, 'Waiting for child processes to finish')

            return waiter
        end):next(function()
            message(_M, 'Child processes finished')

            local finished = 0
            for i=1,#speciesSlice,1 do
                message(_M, "Processing output "..i)
                local outputFileName = tmpFileName..'_output_'..i
                local outputFile = io.open(outputFileName, "r")
                local line = ""
                repeat
                    local ok, obj = serpent.load(line)
                    if not ok then
                        goto continue
                    end

                    if obj == nil then
                        goto continue
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
                        finished = finished + 1
                        if finished == #speciesSlice then
                            outputFile:close()
                            return
                        end
                    end

                    ::continue::
                    line = outputFile:read()
                until(line == "" or line == nil)
            end
            error(string.format("Some processes never finished? Saw %d terminations.", finished))
        end)
    end

    return _M
end
