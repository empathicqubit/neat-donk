local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")

local util = dofile(base.."/util.lua")
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

local tmpFileName = tempDir.."donk_runner"

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

return function()
    local _M = {
        onMessageHandler = {},
        onSaveHandler = {},
        onLoadHandler = {},
    }

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

    _M.run = function(species, generationIdx, genomeCallback, finishCallback)
        local poppets = {}
        for i=1,#species,1 do
            local outputFileName = tmpFileName..'_output_'..i

            local inputFileName = tmpFileName.."_input_"..i
            print(inputFileName)
            local inputFile = io.open(inputFileName, 'w')
            inputFile:write(serpent.dump({species[i], generationIdx, outputFileName}))
            inputFile:close()
            
            local proc = "lsnes"
            if util.isWin then
                local checkParent = io.popen('powershell "(Get-WmiObject Win32_Process -Filter ProcessId=$((Get-WmiObject Win32_Process -Filter ProcessId=$((Get-WmiObject Win32_Process -Filter ProcessId=$PID).ParentProcessId)).ParentProcessId)").ExecutablePath')
                proc = checkParent:read("*l")
                checkParent:close()
            else
                -- FIXME Linux
            end
            print(proc)
            local cmd = "\""..proc.."\" \"--rom="..config.ROM.."\" --unpause \"--lua="..base.."/runner-process.lua\""
            local envs = {
                RUNNER_DATA = inputFileName
            }
            if config.NeatConfig.ThreadDontQuit then
                envs.RUNNER_DONT_QUIT = "1"
            end

            local cmdParts = {}
            for k,v in pairs(envs) do
                if util.isWin then
                    table.insert(cmdParts, string.format("set %s=%s &&", k, v))
                else
                    table.insert(cmdParts, string.format("%s='%s'", k, v))
                end
            end
            table.insert(cmdParts, cmd)
            local fullCmd = table.concat(cmdParts, " ")
            message(_M, fullCmd)
            local poppet = io.popen(fullCmd, 'r')
            table.insert(poppets, poppet)
        end

        for i=1,#poppets,1 do
            local poppet = poppets[i]
            poppet:read('*a')
            poppet:close()
        end
        
        for i=1,#species,1 do
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
                    for i=1,#species,1 do
                        local s = species[i]
                        if s.id == obj.speciesId then
                            s.genomes[obj.genomeIndex] = obj.genome
                            break
                        end
                    end
                    genomeCallback(obj.genome, obj.index)
                elseif obj.type == 'onFinish' then
                    finishCallback()
                end

                ::continue::
                line = outputFile:read()
            until(line == "" or line == nil)
            outputFile:close()
        end
    end

    return _M
end
