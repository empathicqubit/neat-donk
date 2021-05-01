local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1").."/.."

local util = dofile(base.."/util.lua")()
local config = dofile(base.."/config.lua")
local mem = dofile(base.."/mem.lua")

local function text(text)
    io.stderr:write(text)
    io.stderr:write('\n')
    print(text)
end

local function help()
    text([[
Syntax: BSNES_LAUNCHER_ARGS='<arguments>' lsnes --lua=]]..base..[[/bsnes-launcher.lua

--sprite-startindex=<number>    Which sprite to start at. Can be a value from 0-22

Sprite breakpoint arguments:
These will create breakpoints for all sprite slots with properties matching the
given pattern.
]])
    for propName,_ in pairs(mem.offset.sprite) do
        text('--sprite-'..propName..'<Breakpoint format>')
    end

text([[

Breakpoint format: --<switchname>[=<value>][:<rwx>]
    rwx = read / write / execute flags

For example, --sprite-x:r would match any reads of any sprite X position
--sprite-x>10:w would match any writes of any sprite X position greater 
than 0x10 (16). Omitting the rwx will create the breakpoints with the values
specified but they will not trigger until you enable them manually.

Example:
    Matching values of the goalpost sprites in Pirate Panic:

        LSNES_HIDE_MESSAGES=1 \
        LSNES_HIDE_STATUSPANEL=1 \
        BSNES_LAUNCHER_ARGS='--sprite-startindex=2 --sprite-control=160:w --sprite-control=164:w --sprite-control=16c:w --sprite-control=168:w --sprite-x=1c3c:w --sprite-x=1c48:w --sprite-x=1c5d:w --sprite-y=ff63:w --sprite-y=ff8f:w' \
        lsnes --lua=tools/bsnes-launcher.lua

    Note that ff is included in some values since bsnes-plus can only match one
    byte at a time, so sometimes has false positives on those bytes since the true
    value is not unique enough.
]])
end

local bps = {}

--- Add breakpoint switch
---@param switchName string The name of the switch, without dashes
---@param source string address space
---@param startAddress integer The start address
---@param arg string The argument to test
---@param valWidth integer byte size of value - defaults to 2
---@param addrWidth integer byte size of address - defaults to 3
local function bpSwitch(switchName, source, startAddress, arg, valWidth, addrWidth)
    if addrWidth == nil then
        addrWidth = 3
    end
    if valWidth == nil then
        valWidth = 2
    end
    if arg:sub(1, #switchName+2) == '--'..switchName then
        local op, valHex, rwx = arg:sub(#switchName+3):match('^([><=]*)([0-9a-fA-F]*):?([rwxRWX]*)$')
        local valPad = ''
        if valHex ~= '' then
            local val = tonumber(valHex, 16)
            valPad = string.format('%0'..(valWidth*2)..'x', val)
        end
        local fmt = '%0'..(addrWidth*2)..'x%s%s:%s:%s'
        if valWidth == 2 then
            -- SNES is LE!
            local valLeast = valPad:sub(3, 4)
            local valMost = valPad:sub(1, 2)
            local opLeast = ''
            local opMost = ''

            -- FIXME This is surely wrong but better than nothing?
            if op == '>' then
                opLeast = '>'
                opMost = '>='
            elseif op == '=' then
                opLeast = '='
                opMost = '='
            elseif op == '<' then
                opLeast = '<'
                opMost = '<='
            elseif op == '<=' then
                opLeast = '<='
                opMost = '<='
            elseif op == '>=' then
                opLeast = '>='
                opMost = '>='
            else
                valLeast = ''
                valMost = ''
            end
            table.insert(bps, string.format(fmt, startAddress, opLeast, valLeast, rwx, source))
            table.insert(bps, string.format(fmt, startAddress + 1, opMost, valMost, rwx, source))
        elseif valWidth == 1 then
            table.insert(bps, string.format(fmt, startAddress, op, valPad, rwx, source))
        end
    end
end

local count = 0
local startIndex = 0
for arg in os.getenv('BSNES_LAUNCHER_ARGS'):gmatch('[^ ]+') do
    if arg:sub(1,20) == '--sprite-startindex=' then
        startIndex = tonumber(arg:sub(21))
    end
    count = count + 1
    for propName,offset in pairs(mem.offset.sprite) do
        for i=startIndex,22,1 do
            local startAddress = mem.addr.spriteBase + mem.size.sprite * i + offset
            bpSwitch('sprite-'..propName, 'cpu', startAddress, arg)
        end
    end
end

local cmdFmt = 'bsnes %s--show-debugger "%s"'

local bpArgs = ''
local withoutBps = string.format(cmdFmt, bpArgs, config.ROM)
if #bps > 0 then
    bpArgs = '-b "'..table.concat(bps, '" -b "')..'" '
end
local withBps = string.format(cmdFmt, bpArgs, config.ROM)

if count == 0 then
    text('====================')
    help()
end

text('====================')

text('Note that you will need to turn off breakpoint saving for this app to work correctly.')
text('')
text(withBps)
text('====================')

while true do
    text('Starting without breakpoints first. Save your state where you want with F2, then quit to load with breakpoints enabled')
    util.doCmd(withoutBps)
    text('Starting with breakpoints enabled. Load your state with F4')
    util.doCmd(withBps)
end
