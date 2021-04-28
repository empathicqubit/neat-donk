local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")

local Promise = dofile(base.."/promise.lua")
local makeproxy = dofile(base.."/makeproxy.lua")
local util = dofile(base.."/util.lua")

--- Echo a command, run it, and display its results
--- @param cmd string The command to execute
--- @param workdir string The working directory
local function doCmd(cmd, workdir)
    local poppet = util.doCmd(cmd, workdir)
    print(poppet:read("*a"))
    poppet:close()
end

--- Timer loop that triggers promises
local function timer()
    Promise.update()
    set_timer_timeout(1)
end

callback.register('timer', timer)
set_timer_timeout(1)

--- Create directory
--- @param dir string Path of directory to create
local function mkdir (dir)
    local poppet = util.mkdir(dir)
    print(poppet:read("*a"))
    poppet:close()
end

local waitKeyDownQueue = {}
--- Triggers on pressing a key, but only once
--- @param key string Key to monitor
--- @return Promise Promise A Promise that resolves when the key is pressed
local function waitKeyDown(key)
    input.keyhook(key, true)

    local item = {
        promise = Promise.new(),
        key = key,
    }
    table.insert(waitKeyDownQueue, item)

    return item.promise
end

local function keyhook(key, state)
    for i=#waitKeyDownQueue,1,-1 do
        local hook = waitKeyDownQueue[i]
        if hook.key == key and state.value == 1 then
            table.remove(waitKeyDownQueue, i).promise:resolve(key)
        end
    end
end

callback.register('keyhook', keyhook)


local luabase = util.luaenv.."/lua"
local luabin = luabase.."/bin"
local lualib = luabase.."/lib"

local luazip = util.luaenv.."/lua.zip"
local lualibzip = util.luaenv.."/lua_lib.zip"

if util.isWin then
    print("Creating luaenv directory...")
    mkdir(util.luaenv)

    local xzzip = util.luaenv..'/xz.zip'
    local xz = util.luaenv..'/xz'

    print("Downloading xz...")
    util.downloadFile("https://tukaani.org/xz/xz-5.2.5-windows.zip", xzzip)
    mkdir(xz)
    util.unzip(xzzip, xz)

    print("Downloading Lua...")
    util.downloadFile("https://downloads.sourceforge.net/project/luabinaries/5.2.4/Tools%20Executables/lua-5.2.4_Win32_bin.zip", luazip)
    util.downloadFile("https://versaweb.dl.sourceforge.net/project/luabinaries/5.2.4/Windows%20Libraries/Dynamic/lua-5.2.4_Win32_dllw6_lib.zip", lualibzip)
    mkdir(luabase)
    mkdir(luabin)
    util.unzip(luazip, luabin)
    util.unzip(lualibzip, luabase)
    mkdir(lualib)
    os.rename(luabase.."/lua52.dll", lualib.."/lua52.dll")

    -- FIXME Linux will still need this tho?
    makeproxy()
else
    -- FIXME
    print('Please install lua and xz manually...')
end