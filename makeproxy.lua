local base = string.gsub(@@LUA_SCRIPT_FILENAME@@, "(.*[/\\])(.*)", "%1")

local util = dofile(base.."/util.lua")

local CFILE = util.luaenv.."/luaproxy.c" -- Name of the C file for the proxy DLL
local SYMBOLS = util.luaenv.."/luasymbols.h" -- Name of the file of Lua symbols
local LUADLL = util.luaenv.."/lua/lib/lua52.dll" -- Name of a real Lua DLL (to get exported symbols)

----------------------------------------------------------------------
return function()
    local cfile = assert(io.open(CFILE, "w"))
    cfile:write [=[
    #include <windows.h>

    static struct {
    #define SYMBOL(name) FARPROC name;
    #include "luasymbols.h"
    #undef SYMBOL
    }
    s_funcs;

    /* Macro for defining a proxy function.
    This is a direct jump (single "jmp" assembly instruction"),
    preserving stack and return address.
    The following uses MSVC inline assembly which may not be
    portable with other compilers.
    */

    #define SYMBOL(name) \
    void __declspec(dllexport,naked) name() { __asm { jmp s_funcs.name } }
    #include "luasymbols.h"
    #undef SYMBOL

    BOOL APIENTRY
    DllMain(HANDLE module, DWORD reason, LPVOID reserved)
    {
        HANDLE h = GetModuleHandle(NULL);
    #define SYMBOL(name) s_funcs.name = GetProcAddress(h, #name);
    #include "luasymbols.h"
    #undef SYMBOL
        return TRUE;
    }
    ]=]
    cfile:close()

    local pexportstar = util.luaenv.."/pexports.tar.xz"

    util.downloadFile('https://downloads.sourceforge.net/project/mingw/MinGW/Extension/pexports/pexports-0.47/pexports-0.47-mingw32-bin.tar.xz', pexportstar)
    util.unzip(pexportstar, util.luaenv)

    local pexports = util.luaenv.."/bin/pexports.exe"

    local symbols = util.doCmd('"'..pexports..'" "'..LUADLL..'"', base)
    local symfile = io.open(SYMBOLS, "w")
    for sym in symbols:lines() do
        -- Skip the LIBRARY and EXPORTS lines
        local start = sym:sub(1,3)
        if start ~= "LIB" and start ~= "EXP" then
        symfile:write("SYMBOL("..sym..")\n")
        end
    end
    symbols:close()
    symfile:close()

    local hostArch = os.getenv('PROCESSOR_ARCHITECTURE'):gsub("AMD", "x")

    local arch = ""
    if hostArch == 'x86' then
        arch = 'x86'
    else
        arch = 'x64_x86'
    end

    local vswhere = util.luaenv..'/vswhere.exe'
    util.downloadFile('https://github.com/microsoft/vswhere/releases/download/2.8.4/vswhere.exe', vswhere)

    local poppet = util.doCmd('"'..vswhere..'" -products "*" -latest -property installationPath', util.luaenv)
    local vsPath = poppet:read("*l")
    poppet:read("*a")
    poppet:close()

    print("Visual Studio Installation path: "..vsPath)

    local poppet = util.doCmd([[powershell "(Get-ChildItem -Recurse ']]..vsPath..[[' -Filter 'vcvarsall.bat').FullName"]])
    local vcvarsallPath = poppet:read("*l")
    poppet:close()

    print("vcvarsall.bat Path: "..vcvarsallPath)

    poppet = util.doCmd(
        '"'..vcvarsallPath..'" '..arch..' 2>&1 && "cl.exe" /O2 /LD /GS- "'..
            CFILE..'" /link /out:"'..
            util.luaenv..'/lua52.dll" /nodefaultlib /entry:DllMain kernel32.lib 2>&1',
        base,
        {
            VSCMD_ARG_HOST_ARCH = hostArch,
            VSCMD_ARG_TGT_ARCH = 'x86'
        }
    )

    print(poppet:read("*a"))
    poppet:close()
end