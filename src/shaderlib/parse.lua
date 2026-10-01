--[[
    Shader file parser (pure text -> descriptor; no love.* calls).

    File format
    -----------
    Metadata lines (anywhere, usually at the top):
        // @name     Chromatic Aberration
        // @category Lens
        // @desc     One-line summary for the library
        // @about    A longer "how it works" note. Repeat @about lines to
        // @about    continue the paragraph.
        // @author   you
        // @scale    0.5          (default render scale for this shader)

    Params are ordinary uniform declarations with an annotation comment:
        uniform float amount; // default=0.5 min=0 max=1 step=0.01 tip="..."
        uniform vec3  tint;   // color default=#ffd9a0
        uniform vec2  center; // xy default=0.5,0.5
        uniform float angle;  // angle default=0
        uniform int   mode;   // enum=Add,Screen default=Add
        uniform bool  radial; // default=true
    The first bare word is a widget hint (color, xy, vec, angle, log, hidden).

    Auto uniforms (iTime, iResolution, iMouse, ...) come from the prelude and
    must not be redeclared. `uniform Image <name>;` declares a texture input
    (another pass's output) and is not a param.

    Multi-pass:
        //@pass bright in=input scale=0.5 format=rgba16f
        //@pass sim in=self persist iterations=8 format=rgba32f
    Code before the first @pass is shared by every pass.

    Includes:
        #include "lib/noise.glsl"
]]

local Params = require("src.params")

local Parse = {}

Parse.AUTO = {
    iTime = true, iTimeDelta = true, iFrame = true, iResolution = true,
    iMouse = true, iTexel = true, iSource = true, iInput = true,
    iFeedback = true, iPrev = true,
}

local TEXTURE_TYPES = { Image = true, sampler2D = true }

local PASS_KEYS = {
    ["in"] = true, scale = true, format = true, persist = true,
    iterations = true, filter = true, wrap = true,
}
local FORMATS = { rgba8 = true, rgba16f = true, rgba32f = true, rg16f = true, rg32f = true, r16f = true, r32f = true }
local FILTERS = { linear = true, nearest = true }
local WRAPS = { clamp = true, ["repeat"] = true, mirroredrepeat = true }

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Split an annotation into {word=...} and {key=..., value=...} tokens.
-- Values may be quoted with " or '.
function Parse.tokenize(s)
    local out = {}
    local pos = 1
    local len = #s
    while pos <= len do
        local _, ws = s:find("^%s*", pos)
        pos = ws + 1
        if pos > len then break end
        local key, after = s:match("^([%w_%-%.]+)=()", pos)
        if key then
            pos = after
            local q = s:sub(pos, pos)
            local val
            if q == '"' or q == "'" then
                local close = s:find(q, pos + 1, true) or (len + 1)
                val = s:sub(pos + 1, close - 1)
                pos = close + 1
            else
                local v, e = s:match("^(%S*)()", pos)
                val, pos = v, e
            end
            out[#out + 1] = { key = key, value = val }
        else
            local w, e = s:match("^(%S+)()", pos)
            out[#out + 1] = { word = w }
            pos = e
        end
    end
    return out
end

-- Convert an annotation value string to a Lua value.
-- Returns value, isHexColor
function Parse.value(str)
    if str == nil then return nil end
    if str == "true" then return true end
    if str == "false" then return false end
    local hex = str:match("^#(%x+)$")
    if hex and (#hex == 3 or #hex == 6 or #hex == 8) then
        if #hex == 3 then hex = hex:gsub(".", "%0%0") end
        local t = {}
        for i = 1, #hex, 2 do
            t[#t + 1] = tonumber(hex:sub(i, i + 1), 16) / 255
        end
        return t, true
    end
    local n = tonumber(str)
    if n then return n end
    if str:find(",") then
        local t, allNum = {}, true
        for part in (str .. ","):gmatch("([^,]*),") do
            local x = tonumber(trim(part))
            if x == nil then allNum = false end
            t[#t + 1] = x or trim(part)
        end
        if allNum then return t end
        return t
    end
    return str
end

local function parseParam(glslType, name, annotation, lineNo, warnings)
    local raw = { name = name, type = glslType }
    if annotation then
        for _, tok in ipairs(Parse.tokenize(annotation)) do
            if tok.word then
                if raw.hint == nil then
                    raw.hint = tok.word
                else
                    table.insert(warnings, { line = lineNo, msg = "ignored word '" .. tok.word .. "'" })
                end
            else
                local k, v = tok.key, tok.value
                if k == "enum" then
                    local opts = {}
                    for o in (v .. ","):gmatch("([^,]*),") do
                        if trim(o) ~= "" then opts[#opts + 1] = trim(o) end
                    end
                    raw.options = opts
                elseif k == "default" then
                    local val, isHex = Parse.value(v)
                    raw.default = val
                    raw.isHex = isHex
                elseif k == "min" or k == "max" or k == "step" then
                    local n = tonumber(v)
                    if n then raw[k] = n
                    else table.insert(warnings, { line = lineNo, msg = k .. " is not a number" }) end
                elseif k == "label" or k == "tip" then
                    raw[k] = v
                else
                    table.insert(warnings, { line = lineNo, msg = "unknown key '" .. k .. "'" })
                end
            end
        end
    else
        table.insert(warnings, { line = lineNo, msg = "uniform '" .. name .. "' has no annotation; using defaults" })
    end
    if raw.options and glslType ~= "int" then
        table.insert(warnings, { line = lineNo, msg = "enum params should be 'int'" })
        raw.options = nil
    end
    -- An enum default given by label ("Screen")
    if raw.options and type(raw.default) == "string" then
        for i, o in ipairs(raw.options) do
            if o == raw.default then raw.default = i - 1 end
        end
    end
    local def = Params.normalize(raw)
    def.line = lineNo
    return def
end

local function parsePassOptions(name, rest, lineNo, warnings)
    local opts = { name = name, scale = 1, iterations = 1 }
    for _, tok in ipairs(Parse.tokenize(rest or "")) do
        if tok.word then
            if tok.word == "persist" then
                opts.persist = true
            else
                table.insert(warnings, { line = lineNo, msg = "unknown pass flag '" .. tok.word .. "'" })
            end
        elseif PASS_KEYS[tok.key] then
            local k, v = tok.key, tok.value
            if k == "in" then
                opts.input = v
            elseif k == "scale" then
                opts.scale = math.max(0.05, math.min(4, tonumber(v) or 1))
            elseif k == "iterations" then
                opts.iterations = math.max(1, math.min(64, math.floor(tonumber(v) or 1)))
            elseif k == "format" then
                if FORMATS[v] then opts.format = v
                else table.insert(warnings, { line = lineNo, msg = "unknown format '" .. v .. "'" }) end
            elseif k == "filter" then
                if FILTERS[v] then opts.filter = v
                else table.insert(warnings, { line = lineNo, msg = "unknown filter '" .. v .. "'" }) end
            elseif k == "wrap" then
                if WRAPS[v] then opts.wrap = v
                else table.insert(warnings, { line = lineNo, msg = "unknown wrap '" .. v .. "'" }) end
            elseif k == "persist" then
                opts.persist = v ~= "false"
            end
        else
            table.insert(warnings, { line = lineNo, msg = "unknown pass key '" .. tostring(tok.key) .. "'" })
        end
    end
    return opts
end

--[[
    Parse a shader file.
      text: file contents
      kind: "source" | "effect" (affects default pass inputs)
    Returns descriptor:
      meta     = { name, category, desc, about, author, scale }
      params   = { def, ... }       (in declaration order)
      textures = { [name] = true }  (uniform Image declarations)
      common   = { {text=, line=} | {include=, line=} ... }
      passes   = { {opts=..., lines={...}} ... }
      warnings = { {line=, msg=} ... }
]]
function Parse.parse(text, kind)
    local desc = {
        meta = {},
        params = {},
        textures = {},
        common = {},
        passes = {},
        warnings = {},
    }
    local warnings = desc.warnings
    local seen = {}
    local about = {}
    local section = desc.common
    local lineNo = 0

    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
    if text:sub(-1) ~= "\n" then text = text .. "\n" end

    for line in text:gmatch("([^\n]*)\n") do
        lineNo = lineNo + 1
        local entry = { text = line, line = lineNo }

        local passName, passRest = line:match("^%s*//%s*@pass%s+([%w_]+)(.*)$")
        if passName then
            local opts = parsePassOptions(passName, passRest, lineNo, warnings)
            local pass = { opts = opts, lines = {}, line = lineNo }
            table.insert(desc.passes, pass)
            section = pass.lines
            entry.text = "" -- keep line numbering, drop directive
        else
            local key, value = line:match("^%s*//%s*@(%a+)%s*(.-)%s*$")
            if key and key ~= "pass" then
                if key == "about" then
                    about[#about + 1] = value
                elseif key == "scale" then
                    desc.meta.scale = tonumber(value)
                else
                    desc.meta[key] = value
                end
            end

            local inc = line:match('^%s*#include%s+"([^"]+)"')
            if inc then
                entry = { include = inc, line = lineNo }
            end

            local qual, gtype, name, rest = line:match("^%s*(%a+)%s+([%w_]+)%s+([%w_]+)%s*;(.*)$")
            if qual == "uniform" or qual == "extern" then
                if Parse.AUTO[name] then
                    table.insert(warnings, { line = lineNo, msg = name .. " is provided automatically; remove this declaration" })
                    entry.text = "// (auto) " .. line
                elseif TEXTURE_TYPES[gtype] then
                    desc.textures[name] = true
                elseif not seen[name] then
                    seen[name] = true
                    local annotation = rest:match("^%s*//(.*)$")
                    local def = parseParam(gtype, name, annotation, lineNo, warnings)
                    if def.kind == "unsupported" then
                        table.insert(warnings, { line = lineNo, msg = "unsupported param type '" .. gtype .. "'" })
                    end
                    table.insert(desc.params, def)
                end
            end
        end

        table.insert(section, entry)
    end

    if #about > 0 then
        desc.meta.about = table.concat(about, " ")
    end
    desc.meta.scale = desc.meta.scale and math.max(0.1, math.min(2, desc.meta.scale)) or 1

    -- Single-pass file: everything is the one pass.
    if #desc.passes == 0 then
        desc.passes[1] = { opts = { name = "main", scale = 1, iterations = 1 }, lines = desc.common, line = 1 }
        desc.common = {}
    end

    -- Resolve default inputs and validate references.
    local names = {}
    for i, pass in ipairs(desc.passes) do
        local o = pass.opts
        if o.input == nil then
            if i == 1 then
                o.input = kind == "source" and "none" or "input"
            else
                o.input = desc.passes[i - 1].opts.name
            end
        end
        if kind == "source" and o.input == "input" then
            o.input = "none"
        end
        if o.input == "self" then
            o.persist = true
        end
        if o.input ~= "input" and o.input ~= "none" and o.input ~= "self" and not names[o.input] then
            table.insert(warnings, { line = pass.line, msg = "pass input '" .. o.input .. "' is not an earlier pass" })
            o.input = i == 1 and (kind == "source" and "none" or "input") or desc.passes[i - 1].opts.name
        end
        if names[o.name] then
            table.insert(warnings, { line = pass.line, msg = "duplicate pass name '" .. o.name .. "'" })
        end
        names[o.name] = true
    end

    desc.meta.name = desc.meta.name or nil
    return desc
end

return Parse
