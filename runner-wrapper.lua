local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")

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
        local trunc = io.open(tmpFileName, 'w')
        trunc:close()

        local poppets = {}
        for i=1,#species,1 do
            local poppet = io.popen("RUNNER_DATA='"..serpent.dump({species[i], generationIdx, speciesIdx + i - 1, tmpFileName}).."' lsnes --rom="..base.."/rom.sfc --unpause --lua="..base.."/runner-process.lua", 'r')
            table.insert(poppets, poppet)
        end

        for i=1,#poppets,1 do
            local poppet = poppets[i]
            poppet:read('*a')
            poppet:close()
        end
        
        local tmpFile = io.open(tmpFileName, "r")
        local line = ""
        repeat
            local obj, err = serpent.load(line)
            if err ~= nil then
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
            line = tmpFile:read()
        until(line == "")
        tmpFile:close()
        local ok, err = os.remove(tmpFileName)
        if err ~= nil then
            message(_M, err)
        elseif ok ~= true then
            message(_M, 'UNSPECIFIED ERROR ON REMOVAL')
        end
    end

    return _M
end
