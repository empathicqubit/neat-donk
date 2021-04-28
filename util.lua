local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")

local _M = {}

_M.isWin = package.config:sub(1,1) == "\\"
_M.luaenv = base.."/luaenv"

--- Echo a command, run it, and return the file handle
--- @param cmd string The command to execute
--- @param workdir string The working directory
function _M.doCmd(cmd, workdir, env)
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
    return io.popen(fullCmd, 'r')
end

--- Create directory
--- @param dir string Path of directory to create
function _M.mkdir (dir)
    return _M.doCmd('mkdir "'..dir..'" 2>&1')
end

--- Unzip a ZIP file with unzip or tar
--- @param zipfile string The ZIP file path
--- @param dest string Where to unzip the ZIP file. Beware ZIP bombs.
function _M.unzip (zipfile, dest)
    local xzPath = 'xz'
    if _M.isWin then
        xzPath = _M.luaenv..'/xz/bin_i686-sse2/xz.exe'
    end
    
    local poppet = nil
    if zipfile:sub(-3):upper() == '.XZ' then
        poppet = _M.doCmd('"'..xzPath..'" -d "'..zipfile..'"', dest)
        print(poppet:read("*a"))
        poppet:close()
        zipfile = zipfile:sub(1, -3)
        print(zipfile)
    end

    poppet = _M.doCmd('unzip "'..zipfile..'" -d "'..dest..
    '" 2>&1 || tar -C "'..dest..'" -xvf "'..zipfile..
    '" 2>&1', nil)
    print(poppet:read("*a"))
    poppet:close()
end

--- Download a url
--- @param url string URI of resource to download
--- @param dest string File to save resource to
function _M.downloadFile (url, dest)
    local poppet = _M.doCmd('curl -sL "'..url..'" > "'..dest..'" || wget -qO- "'..url..'" > "'..dest..'"')
    print(poppet:read("*a"))
    poppet:close()
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
