--[[
    Hot-reload integration test (writes temporary files into shaders/).

        lovec . --fresh --script tests/hot_reload.lua
]]

local FS = require("src.util.fs")
local Registry = require("src.shaderlib.registry")

local SRC = FS.writableSourceDir()
local EFFECT = "shaders/effects/zz_hot_reload_test.glsl"
local LIB = "shaders/lib/zz_hot_reload_lib.glsl"
local ID = "effects/zz_hot_reload_test"

local function write(rel, text)
    local f = assert(io.open(SRC .. "/" .. rel, "wb"))
    f:write(text)
    f:close()
end

local GOOD = [[
// @name Hot Reload Test
// @category Test
uniform float amount; // default=0.5 min=0 max=1
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    return Texel(tex, uv) * amount;
}
]]

local BROKEN = [[
// @name Hot Reload Test
// @category Test
uniform float amount; // default=0.5 min=0 max=1
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 c = Texel(tex, uv).rgb;
    return vec4(c * amount * undefinedThing, 1.0);
}
]]

local WITH_INCLUDE = [[
// @name Hot Reload Test
// @category Test
#include "lib/zz_hot_reload_lib.glsl"
uniform float amount; // default=0.5 min=0 max=1
uniform vec3 tint;    // color default=#ff0000
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    return vec4(helper(Texel(tex, uv).rgb) * tint * amount, 1.0);
}
]]

local LIB_GOOD = "vec3 helper(vec3 c) {\n    return c * 2.0;\n}\n"
local LIB_BROKEN = "vec3 helper(vec3 c) {\n    float x = 1.0\n    return c * 2.0;\n}\n"

local state = {}

return {
    { at = 0.3, check = function(App)
        if not SRC then return false, "source dir is writable" end
        write(EFFECT, GOOD)
        return true, "wrote a new shader file"
    end },
    { at = 3.0, check = function(App)
        local e = Registry.get(ID)
        if not e then return false, "new file discovered by rescan" end
        state.node = App.addEffect(e)
        state.version = e.version
        return e.errors == nil and e.passes ~= nil, "new file discovered and compiled"
    end },

    { at = 3.2, check = function(App) write(EFFECT, BROKEN); return true, "introduced a compile error" end },
    { at = 4.0, check = function(App)
        local e = Registry.get(ID)
        local err = e.errors and e.errors[1]
        return err ~= nil and err.line == 6 and err.file == EFFECT,
            "error mapped to " .. EFFECT .. ":6 (got " .. tostring(err and err.file) .. ":" .. tostring(err and err.line) .. ")"
    end },
    { at = 4.05, check = function(App)
        local e = Registry.get(ID)
        return e.passes ~= nil and e.version == state.version, "last good build keeps rendering"
    end },
    { at = 4.3, shot = "hot_reload_error" },

    { at = 4.5, check = function(App)
        write(LIB, LIB_BROKEN)
        write(EFFECT, WITH_INCLUDE)
        return true, "include a broken library file"
    end },
    { at = 5.3, check = function(App)
        local e = Registry.get(ID)
        local err = e.errors and e.errors[1]
        return err ~= nil and err.file == LIB and err.line == 3,
            "error inside include mapped to " .. LIB .. ":3 (got " .. tostring(err and err.file) .. ":" .. tostring(err and err.line) .. ")"
    end },

    { at = 5.5, check = function(App) write(LIB, LIB_GOOD); return true, "fix the library (only the include changes)" end },
    { at = 6.3, check = function(App)
        local e = Registry.get(ID)
        local hasTint = false
        for _, d in ipairs(e.params) do if d.name == "tint" then hasTint = true end end
        return e.errors == nil and e.version > state.version and hasTint, "include edit triggers reload; new param appears"
    end },
    { at = 6.4, check = function(App)
        local v = state.node.values
        return v.tint ~= nil and v.amount == 0.5, "node values synced after reload"
    end },

    { at = 6.5, check = function(App)
        os.remove(SRC .. "/" .. EFFECT)
        os.remove(SRC .. "/" .. LIB)
        return true, "removed temp files"
    end },
    { at = 9.0, check = function(App)
        local e = Registry.get(ID)
        return e and e.missing == true, "deleted file marked missing"
    end },
    { at = 9.2, quit = true },
}
