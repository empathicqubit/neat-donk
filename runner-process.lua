local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")

local Promise = dofile(base.."/promise.lua")

local Runner = dofile(base.."/runner.lua")
local serpent = dofile(base.."/serpent.lua")
local util = dofile(base.."/util.lua")

local inputFilePath = os.getenv("RUNNER_INPUT_FILE")
local outputFilePath = os.getenv("RUNNER_OUTPUT_FILE")

local first = false

local outContents = {}

local statusLine = nil
local statusColor = 0x0000ff00

local species = nil
local speciesId = -1
local generationIndex = nil

local runner = Runner()
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

local guiHeight = 0
local guiWidth = 0
runner.onRenderForm(function(form)
    guiWidth, guiHeight = gui.resolution()
    gui.left_gap(0)  
    gui.top_gap(0)
    gui.bottom_gap(0)
    gui.right_gap(0)
    form:draw(0, 0)

    if statusLine ~= nil then
        gui.rectangle(0, guiHeight - 20, 0, 20, 1, 0x00000000, statusColor)
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

local waiter = util.waitForChange(inputFilePath)

local function waitLoop()
    if not first then
        local sec, usec = utime()
        local ts = sec * 1000000 + usec

        local outFile = io.open(outputFilePath, "w")
        outFile:write(serpent.dump({ type = 'onInit', ts = ts }))
        outFile:close()

        print(string.format('Wrote init to output at %d', ts))

        first = true
    end

    print('Waiting for input from master process')

    waiter:read("*a")
    util.closeCmd(waiter)

    print('Received input from master process')

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

    species = inputData[1]

    speciesId = species.id

    generationIndex = inputData[2]

    outContents = {}

    print('Running')

    runner.run(
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
        end,
        function()
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

            waiter = util.waitForChange(inputFilePath)

            -- Write the result
            local outFile = io.open(outputFilePath, "w")
            outFile:write(table.concat(outContents, "\n"))
            outFile:close()

            waitLoop()
        end
    )
end

waitLoop()