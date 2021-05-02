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

local inputFilePath = os.getenv("RUNNER_INPUT_FILE")
local outputFilePath = os.getenv("RUNNER_OUTPUT_FILE")

local outContents = {}

local statusLine = nil
local statusColor = 0x0000ff00

local species = nil
local speciesId = -1
local generationIndex = nil

local runner = Runner(Promise)
runner.onMessage(function(msg, color)
    statusLine = msg
    statusColor = color
    print(msg)
    table.insert(
        outContents,
        serpent.dump({
            type = 'onMessage',
            speciesId = speciesId,
            msg = msg,
            color = color,
        })
    )
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
    table.insert(
        outContents,
        serpent.dump({
            type = 'onSave',
            filename = filename,
            speciesId = speciesId,
        })
    )
end)

runner.onLoad(function(filename)
    table.insert(
        outContents,
        serpent.dump({
            type = 'onLoad',
            filename = filename,
            speciesId = speciesId,
        })
    )
end)

local function waitLoop()
    local inputData = nil
    local ok = false
    while not ok or inputData == nil or speciesId == inputData[1].id do
        local inputFile = io.open(inputFilePath, 'r')
        ok, inputData = serpent.load(inputFile:read('*a'))
        inputFile:close()

        if not ok then
            print("Deserialization error")
        end
    end

    print('Received input from master process')

    species = inputData[1]

    speciesId = species.id

    generationIndex = inputData[2]

    outContents = {}

    print('Running')

    return runner.run(
        species,
        generationIndex,
        function(genome, index)
            table.insert(
                outContents,
                serpent.dump({
                    type = 'onGenome',
                    genome = genome,
                    genomeIndex = index,
                    speciesId = speciesId,
                })
            )
        end
    ):next(function()
        table.insert(
            outContents,
            serpent.dump({
                type = 'onFinish',
                speciesId = speciesId,
            })
        )

        -- Truncate the input file to reduce the amount of time
        -- wasted if we reopen it too early
        local inputFile = io.open(inputFilePath, "w")
        inputFile:close()

        local waiter = nil
        if util.isWin then
            waiter = Promise.new()
            waiter:resolve()
        else
            waiter = util.waitForFiles(inputFilePath)
        end

        -- Write the result
        local outFile = io.open(outputFilePath, "w")
        outFile:write(table.concat(outContents, "\n"))
        outFile:close()

        return waiter
    end):next(waitLoop)
end

local waiter = nil
if util.isWin then
    waiter = Promise.new()
    waiter:resolve()
else
    waiter = util.waitForFiles(inputFilePath)
end

local sec, usec = utime()
local ts = sec * 1000000 + usec

local outFile = io.open(outputFilePath, "w")
outFile:write(serpent.dump({ type = 'onInit', ts = ts }))
outFile:close()

print(string.format('Wrote init to output at %d', ts))

waiter:next(waitLoop):catch(function(error)
    print('ERROR: '..error)
end)
