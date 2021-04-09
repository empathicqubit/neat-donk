local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")

local Runner = dofile(base.."/runner.lua")
local json = dofile(base.."/dkjson.lua")

local runnerData, pos, err = json.decode(os.getenv("RUNNER_DATA"))
if err ~= nil then
    return
end

local speciesIndex = runnerData[3]

local filename = runnerData[4]

local outFile = io.open(filename, "a")

local outContents = {}

local statusLine = nil
local statusColor = 0x0000ff00

local runner = Runner()
runner.onMessage(function(msg, color)
    statusLine = msg
    statusColor = color

    table.insert(
        outContents,
        json.encode({
            type = 'onMessage',
            speciesIndex = speciesIndex,
            msg = msg,
            color = color,
        })
    )
end)

local guiHeight = 0
local guiWidth = 0
runner.onRenderForm(function(form)
    guiWidth, guiHeight = gui.resolution()
    gui.left_gap(500)  
    gui.top_gap(0)
    gui.bottom_gap(0)
    gui.right_gap(0)
    form:draw(-500, 0)

    if statusLine ~= nil then
        gui.rectangle(-500, guiHeight - 20, 0, 20, 1, 0x00000000, statusColor)
        gui.text(-500, guiHeight - 20, statusLine, 0x00000000)
    end

    -- This isn't passed up to the parent since we're handling the GUI.
end)

runner.onSave(function(filename)
    table.insert(
        outContents,
        json.encode({
            type = 'onSave',
            speciesIndex = speciesIndex,
        })
    )

    message("Will be saved once all currently active threads finish", 0x00990000)
end)

runner.onLoad(function(filename)
    table.insert(
        outContents,
        json.encode({
            type = 'onLoad',
            speciesIndex = speciesIndex,
        })
    )

    message("Will be loaded once all currently active threads finish", 0x00990000)
end)

runner.run(
    runnerData[1],
    runnerData[2],
    speciesIndex,
    function(genome, index)
        table.insert(
            outContents,
            json.encode({
                type = 'onGenome',
                genome = genome,
                genomeIndex = index,
                speciesIndex = speciesIndex,
            })
        )
    end,
    function()
        table.insert(
            outContents,
            json.encode({
                type = 'onFinish',
                speciesIndex = speciesIndex,
            })
        )
        outFile:write(table.concat(outContents, "\n"))
        outFile:close()
        exec('quit-emulator')
    end
)
