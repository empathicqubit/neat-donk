local _M = {}

_M.isWin = package.config:sub(1, 1) == '\\'

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
        error("The last command failed")
    end
end

function _M.waitForChange(filename, count)
    if count == nil then
        count = 1
    end

    if _M.isWin then
        local sec, usec = utime()
        print(string.format('Starting watching file at %d', sec * 1000000 + usec))

        return _M.popenCmd([[powershell "$filename = ']]..filename..
        [[' ; $targetCount = ]]..count..[[ ; $count = 0 ; Register-ObjectEvent (New-Object IO.FileSystemWatcher (Split-Path $filename), (Split-Path -Leaf $filename) -Property @{ IncludeSubdirectories = $false ; NotifyFilter =  [IO.NotifyFilters]'FileName, LastWrite'}) -EventName Changed -SourceIdentifier RunnerDataChanged -Action { $count += 1 ; if ( $count -ge $targetCount ) { [Environment]::Exit(0) } } ; while($true) { Start-Sleep -Milliseconds 1 }"]])
    else
        error("Not implemented")
        -- FIXME Linux
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

return _M
