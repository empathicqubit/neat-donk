local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")

local config = dofile(base.."/config.lua")
local serpent = dofile(base.."/serpent.lua")
local tmpFileName = "/tmp/donk_runner_"..tostring(math.floor(random.integer(0, 0xffffffffffffffff))):hex()

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

    _M.run = function(species, generationIdx, speciesIdx, genomeCallback, finishCallback)
        local poppets = {}
        for i=1,#species,1 do
            local outputFileName = tmpFileName..'_output_'..i

            local inputFileName = tmpFileName.."_input_"..i
            local inputFile = io.open(inputFileName, 'w')
            inputFile:write(serpent.dump({species[i], generationIdx, speciesIdx + i - 1, outputFileName}))
            inputFile:close()
            
            local cmd = "RUNNER_DATA=\""..inputFileName.."\" lsnes \"--rom="..config.ROM.."\" --unpause \"--lua="..base.."/runner-process.lua\""
            message(_M, cmd)
            local poppet = io.popen(cmd, 'r')
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
                local obj, err = loadstring(line)
                if err ~= nil then
                    goto continue
                end

                obj = obj()

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
                    species[obj.speciesIndex - speciesIdx + 1].genomes[obj.genomeIndex] = obj.genome
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
