local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")

local Runner = dofile(base.."/runner.lua")
local serpent = dofile(base.."/serpent.lua")
local util = dofile(base.."/util.lua")

local runnerDataFile = io.open(os.getenv("RUNNER_DATA"), 'r')
local runnerData, err = loadstring(runnerDataFile:read('*a'))
runnerDataFile:close()

if err ~= nil then
    print(err)
    return
end

runnerData = runnerData()

local species = runnerData[1]

local speciesId = species.id

local generationIndex = runnerData[2]

local filename = runnerData[3]

local outFile = io.open(filename, "w")

local outContents = {}

local statusLine = nil
local statusColor = 0x0000ff00

local runner = Runner()
runner.onMessage(function(msg, color)
    statusLine = msg
    statusColor = color

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
        outFile:write(table.concat(outContents, "\n"))
        outFile:close()
        exec('quit-emulator')
    end
)
