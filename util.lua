local utime, bit, callback, exec = utime, bit, callback, exec

local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")

local Promise = nil

local _M = {}

_M.isWin = package.config:sub(1, 1) == '\\'

--- Converts a function into a promise.
--- Useful for decoupling code from the original event it was fired in.
---@param next function The function to resolve on the next tick
---@return Promise Promise A promise that returns the value of the next function
function _M.promiseWrap(next)
    local promise = Promise.new()
    promise:resolve()
    return promise:next(next)
end

--- Wait for a specified amount of time. Note that this is dependent on the
--- timer timeout getting set elsewhere in the code, probably in the Promise
--- handler setup
---@param delayUsec number Number of microseconds to wait
---@return Promise Promise A promise that resolves when the time has elapsed
function _M.delay(delayUsec)
    return Promise.new(function(res, rej)
        local sec, usec = utime()
        local start = sec * 1000000 + usec
        local finish = start
        local unTimer = nil
        local function onTimer()
            sec, usec = utime()
            finish = sec * 1000000 + usec
            if finish - start >= delayUsec then
                callback.unregister('timer', unTimer)
                res()
            end
        end
        unTimer = callback.register('timer', onTimer)
    end)
end

function _M.loadAndStart(romFile)
    return Promise.new(function(res, rej)
        local unPaint = nil
        local paint = 0
        local function onPaint()
            paint = paint + 1

            _M.promiseWrap(function()
                if paint == 1 then
                    exec('pause-emulator')
                elseif paint > 1 then
                    callback.unregister('paint', unPaint)
                    res()
                end
            end)
        end
        unPaint = callback.register('paint', onPaint)

        exec('load-rom '..romFile)
    end)
end

function _M.getTempDir()
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

    return tempDir
end

--- Echo a command, run it, and return the file handle
--- @param cmd string The command to execute
--- @param workdir string The working directory
--- @param env table The environment variables
function _M.popenCmd(cmd, workdir, env)
    local cmdParts = {}
    if workdir ~= nil then
        if _M.isWin then
            table.insert(cmdParts, 'cd /d "'..workdir..'" &&')
        else
            table.insert(cmdParts, 'cd "'..workdir..'" &&')
        end
    end
    if env ~= nil then
        for k,v in pairs(env) do
            if _M.isWin then
                table.insert(cmdParts, string.format("set %s=%s&&", k, v))
            else
                table.insert(cmdParts, string.format("%s='%s'", k, v))
            end
        end
    end
    table.insert(cmdParts, cmd)
    local fullCmd = table.concat(cmdParts, " ")
    print(fullCmd)

--[[     local dummy = "/dev/null"
    if isWin then
        dummy = "NUL"
    end
    return io.open(dummy, 'r') ]]
    return io.popen(fullCmd, 'r')
end

--- Echo a command, run it, and handle any errors
--- @return string string The stdout
function _M.doCmd(...)
    return _M.scrapeCmd('*a', ...)
end

function _M.openReadPipe(name)
    if _M.isWin then
        local cmd = 'cd /d "'..base..'" && "'..base..'/namedpipe/createAndReadPipe.exe" "'..name..'"'
        print(cmd)
        return io.popen(cmd, 'r')
    else
        return io.popen("socat 'UNIX-LISTEN:".._M.getTempDir().."/"..name.."' -", 'r')
    end
end

function _M.openReadPipeWriter(name)
    local writer = nil
    while writer == nil do
        if _M.isWin then
            writer = io.open('\\\\.\\pipe\\'..name, 'w')
        else
            writer = io.popen("socat 'UNIX-CONNECT:".._M.getTempDir().."/"..name.."' -", 'w')
        end
    end

    return writer
end

--- Download a url
--- @param url string URI of resource to download
--- @param dest string File to save resource to
function _M.downloadFile (url, dest)
    return _M.doCmd('curl -sL "'..url..'" > "'..dest..'" || wget -qO- "'..url..'" > "'..dest..'"')
end

--- Unzip a ZIP file with unzip or tar
--- @param zipfile string The ZIP file path
--- @param dest string Where to unzip the ZIP file. Beware ZIP bombs.
function _M.unzip (zipfile, dest)
    return _M.doCmd('tar -xvf "'..zipfile..'" 2>&1 || unzip -n "'..zipfile..'" -d "'..dest..
        '" 2>&1', dest)
end

--- Create a directory
--- @return string dir The directory to create
function _M.mkdir(dir)
    if _M.isWin then
        return _M.doCmd('if not exist "'..dir..'" mkdir "'..dir..'"')
    else
        return _M.doCmd("mkdir '"..dir.."'")
    end
end

--- Run a command and get the output
--- @param formats table|string|number List or single io.read() specifier
--- @return table table List of results based on read specifiers
function _M.scrapeCmd(formats, ...)
    local poppet = _M.popenCmd(...)
    local outputs = nil
    if type(formats) ~= 'table' then
        outputs = poppet:read(formats)
    else
        outputs = {}
        for i=1,#formats,1 do
            table.insert(outputs, poppet:read(formats[i]))
        end
    end
    _M.closeCmd(poppet)
    return outputs
end

--- Check the command's exit code and throw a Lua error if it isn't right
--- @param handle file* The handle of the command
function _M.closeCmd(handle)
    local ok, state, code = handle:close()
    if state ~= "exit" then
        return
    end
    if code ~= 0 then
        error(string.format("The last command failed: %s %d", state, code))
    end
end

function _M.table_to_string(tbl)
    local result = "{"
    local keys = {}
    for k in pairs(tbl) do 
        table.insert(keys, k)
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local v = tbl[k]
        if type(v) == "number" and v == 0 then
            --goto continue
        end

        -- Check the key type (ignore any numerical keys - assume its an array)
        if type(k) == "string" then
            result = result.."[\""..k.."\"]".."="
        end

        -- Check the value type
        if type(v) == "table" then
            result = result.._M.table_to_string(v)
        elseif type(v) == "boolean" then
            result = result..tostring(v)
        elseif type(v) == "number" and v >= 0 then
            result = result..string.format("%x", v)
        else
            result = result.."\""..v.."\""
        end
        result = result..",\n"
        ::continue::
    end
    -- Remove leading commas from the result
    if result ~= "" then
        result = result:sub(1, result:len()-1)
    end
    return result.."}"
end

function _M.file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function _M.nearestColor(needle, colors)
	local opacity = bit.band(needle, 0xff000000)
	local needle = {
		r = bit.lrshift(bit.band(needle, 0x00ff0000), 4),
		g = bit.lrshift(bit.band(needle, 0x0000ff00), 2),
		b = bit.band(needle, 0x000000ff),
	}
	local minDistanceSq = 0x7fffffff
	local value = nil
	for name,color in pairs(colors) do
		local distanceSq = (
			math.pow(needle.r - color.r, 2) +
			math.pow(needle.g - color.g, 2) +
			math.pow(needle.b - color.b, 2)
		)
		if distanceSq < minDistanceSq then
			minDistanceSq = distanceSq
			value = name
		end
        if value == nil then
            value = name
        end
	end

	return value
end

function _M.regionToWord(region, offset)
    return bit.compose(region[offset], region[offset + 1])
end

function _M.regionToSWord(region, offset)
    local unsigned = _M.regionToWord(region, offset)
    local base = bit.band(unsigned, 0x7fff)
    local sign = bit.lrshift(unsigned, 15)
    -- There is a more mathematical way to do this but whatever
    if sign == 1 then
        return base-0x8000
    else
        return base
    end
end

return function(promise)
    Promise = promise
    return _M
end