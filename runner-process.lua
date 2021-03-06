local gui, utime, callback, set_timer_timeout = gui, utime, callback, set_timer_timeout

local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")

local Promise = dofile(base.."/promise.lua")
-- Only the parent should manage ticks!
callback.register('timer', function()
	Promise.update()
	set_timer_timeout(1)
end)
set_timer_timeout(1)

local Runner = dofile(base.."/runner.lua")
local serpent = dofile(base.."/serpent.lua")
local util = dofile(base.."/util.lua")(Promise)

local statusLine = nil
local statusColor = 0x0000ff00

local species = nil
local speciesId = -1
local generationIndex = nil

local inputPipeName = os.getenv("RUNNER_INPUT_PIPE")
local outputPipeName = os.getenv("RUNNER_OUTPUT_PIPE")

print('Opening input pipe '..inputPipeName)
local inputPipe = util.openReadPipe(inputPipeName)
if inputPipe == nil then
    error('Error opening input file')
end
print('Opened input pipe '..inputPipeName)

print('Opening output file '..outputPipeName)
local outputPipe = util.openReadPipeWriter(outputPipeName)
print('Opened output file '..outputPipeName)

local function writeResponse(object)
    outputPipe:write(serpent.dump(object).."\n")
    outputPipe:flush()
end

local function unblockLoop()
    return util.delay(1000000):next(function()
        outputPipe:write(".\n")
        outputPipe:flush()
        return unblockLoop()
    end)
end

local runner = Runner(Promise)
runner.onMessage(function(msg, color)
    statusLine = msg
    statusColor = color
    print(msg)

    writeResponse({
        type = 'onMessage',
        speciesId = speciesId,
        msg = msg,
        color = color,
    })
end)

runner.onRenderForm(function(form)
    local guiWidth, guiHeight = gui.resolution()
    gui.left_gap(0)  
    gui.top_gap(0)
    gui.bottom_gap(0)
    gui.right_gap(0)
    form:draw(0, 0)

    if statusLine ~= nil then
        gui.rectangle(0, guiHeight - 20, guiWidth, 20, 1, 0x00000000, statusColor)
        gui.text(0, guiHeight - 20, statusLine, 0x00000000)
    end

    -- This isn't passed up to the parent since we're handling the GUI.
end)

runner.onSave(function(filename)
    writeResponse({
        type = 'onSave',
        filename = filename,
        speciesId = speciesId,
    })
end)

runner.onLoad(function(filename)
    writeResponse({
        type = 'onLoad',
        filename = filename,
        speciesId = speciesId,
    })
end)

runner.onReset(function()
    writeResponse({
        type = 'onReset',
        speciesId = speciesId,
    })
end)

local function waitLoop(inputLine)
    return util.promiseWrap(function()
        local ok, inputData = serpent.load(inputLine)

        if not ok or inputData == nil then
            io.stderr:write("Deserialization error\n")
            io.stderr:write(inputLine.."\n")
            return
        end

        print('Received input from master process')

        species = inputData[1]

        speciesId = species.id

        generationIndex = inputData[2]

        print('Running')

        return runner.run(
            species,
            generationIndex,
            function(genome, index)
                writeResponse({
                    type = 'onGenome',
                    genome = genome,
                    genomeIndex = index,
                    speciesId = speciesId,
                })
            end
        ):next(function(maxFitness)
            writeResponse({
                type = 'onFinish',
                maxFitness = maxFitness,
                speciesId = speciesId,
            })
        end)
    end):next(function()
        return inputPipe:read("*l")
    end):next(waitLoop)
end

local sec, usec = utime()
local ts = sec * 1000000 + usec

local waiter = util.promiseWrap(function()
    return inputPipe:read("*l")
end)

writeResponse({ type = 'onInit', ts = ts })

print(string.format('Wrote init to output at %d', ts))

waiter:next(function(inputLine)
    return waitLoop(inputLine)
end):catch(function(error)
    if type(error) == "table" then
        error = "\n"..table.concat(error, "\n")
    end
    print('Runner process error: '..error)
    io.stderr:write('Runner process error: '..error..'\n')
end)