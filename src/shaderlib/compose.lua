--[[
    Compose a pass into final GLSL source plus a line map.

    Output layout:
        #pragma language glsl3         <- must be the very first characters
        <prelude.glsl (+ its includes)>
        <common section (+ includes)>
        <pass section (+ includes)>

    lineMap[n] = { file = "shaders/effects/x.glsl", line = 12 } lets compile
    errors ("Line n: ...") point at the right file and line.
]]

local Compose = {}

local PRELUDE = "shaders/lib/prelude.glsl"
local MAX_DEPTH = 8

-- reader(path) -> text or nil
local function appendLines(out, map, entries, file, reader, included, deps, depth, errors)
    for _, e in ipairs(entries) do
        if e.include then
            local incPath = "shaders/" .. e.include
            if depth >= MAX_DEPTH then
                table.insert(errors, { file = file, line = e.line, msg = "include nesting too deep: " .. e.include })
            elseif not included[incPath] then
                included[incPath] = true
                local text = reader(incPath)
                if text then
                    deps[incPath] = true
                    local sub = Compose.splitLines(text)
                    appendLines(out, map, sub, incPath, reader, included, deps, depth + 1, errors)
                else
                    table.insert(errors, { file = file, line = e.line, msg = "include not found: " .. e.include })
                end
            end
            -- keep a placeholder line so numbering inside this file stays obvious
            out[#out + 1] = "// #include " .. e.include
            map[#out] = { file = file, line = e.line }
        else
            out[#out + 1] = e.text
            map[#out] = { file = file, line = e.line }
        end
    end
end

-- Split raw text into parse-style entries (handling #include lines).
function Compose.splitLines(text)
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
    if text:sub(-1) ~= "\n" then text = text .. "\n" end
    local entries, n = {}, 0
    for line in text:gmatch("([^\n]*)\n") do
        n = n + 1
        local inc = line:match('^%s*#include%s+"([^"]+)"')
        if inc then
            entries[n] = { include = inc, line = n }
        else
            entries[n] = { text = line, line = n }
        end
    end
    return entries
end

--[[
    desc: parse descriptor, pass: one of desc.passes, path: the shader file
    reader: function(path) -> text
    Returns code, lineMap, deps (set of included paths), errors
]]
function Compose.build(desc, pass, path, reader)
    local out, map = { "#pragma language glsl3" }, { { file = PRELUDE, line = 0 } }
    local included, deps, errors = {}, {}, {}

    local prelude = reader(PRELUDE)
    if prelude then
        included[PRELUDE] = true
        deps[PRELUDE] = true
        appendLines(out, map, Compose.splitLines(prelude), PRELUDE, reader, included, deps, 1, errors)
    else
        table.insert(errors, { file = path, line = 0, msg = "missing " .. PRELUDE })
    end

    appendLines(out, map, desc.common, path, reader, included, deps, 0, errors)
    appendLines(out, map, pass.lines, path, reader, included, deps, 0, errors)

    return table.concat(out, "\n") .. "\n", map, deps, errors
end

return Compose
