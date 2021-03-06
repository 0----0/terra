local ffi = require 'ffi'
-- test that the dynamic library for terra was built correctly
-- by compiling a new program that links against it and running it
terralib.includepath = terralib.terrahome.."/include"
C = terralib.includecstring [[
#include <stdio.h>
#include "terra.h"
]]


terra doerror(L : &C.lua_State)
    C.printf("%s\n",C.luaL_checklstring(L,-1,nil))
end

local thecode = "terra foo() return 1 end print(foo())"

terra main(argc : int, argv : &rawstring)
    var L = C.luaL_newstate();
    C.luaL_openlibs(L);
    if C.terra_init(L) ~= 0 then
        doerror(L)
    end
    if C.terra_loadstring(L,thecode) ~= 0 or C.lua_pcall(L, 0, -1, 0) ~= 0 then
        doerror(L)
    end
    return 0;
end

if ffi.os ~= "Windows" then

    local flags = terralib.newlist {"-L", terralib.terrahome,"-Wl,-rpath,"..terralib.terrahome,"-lterra"}
    if require("ffi").os == "OSX" then
        flags:insertall {"-pagezero_size","10000", "-image_base", "100000000"}
    end

    terralib.saveobj("dynlib",{main = main},flags)

    assert(0 == os.execute("./dynlib"))

else
    local putenv = terralib.externfunction("_putenv", rawstring -> int)
    local flags = {terralib.terrahome.."\\terra.lib",terralib.terrahome.."\\lua51.lib"}
    terralib.saveobj("dynlib.exe",{main = main},flags)
    putenv("Path="..os.getenv("Path")..";"..terralib.terrahome) --make dll search happy
    assert(0 == os.execute(".\\dynlib.exe"))
end