--[[
    Compile composed GLSL and map errors back to source files.

    LÖVE 11.5 reports validation errors as "Line N: ERROR: ..." where N is the
    1-based line in the exact string we pass (verified on this machine), so a
    composed line map is all we need.
]]

local Compile = {}

-- Returns shader or nil, errors = { {file, line, msg}, ... }
function Compile.compile(code, lineMap, fallbackFile)
    local ok, result = pcall(love.graphics.newShader, code)
    if ok then
        return result, nil
    end
    return nil, Compile.parseErrors(tostring(result), lineMap, fallbackFile)
end

function Compile.parseErrors(message, lineMap, fallbackFile)
    local errors = {}
    local seen = {}
    for raw in (message .. "\n"):gmatch("([^\n]*)\n") do
        local n, msg = raw:match("^%s*Line (%d+):%s*(.*)$")
        if not n then
            n, msg = raw:match("^%s*%d+%((%d+)%)%s*:%s*(.*)$") -- NVIDIA driver style
        end
        if not n then
            n, msg = raw:match("^%s*ERROR:%s*%d+:(%d+):%s*(.*)$") -- Mesa/AMD style
        end
        if n then
            n = tonumber(n)
            msg = msg:gsub("^ERROR:%s*", ""):gsub("%s+$", "")
            if msg ~= "'' : compilation terminated" then
                local loc = lineMap and lineMap[n]
                local key = n .. msg
                if not seen[key] then
                    seen[key] = true
                    table.insert(errors, {
                        file = loc and loc.file or fallbackFile,
                        line = loc and loc.line or n,
                        msg = msg,
                    })
                end
            end
        end
    end
    if #errors == 0 then
        local first = message:gsub("^%s+", ""):gsub("\n.*$", "")
        table.insert(errors, { file = fallbackFile, line = 0, msg = first })
    end
    return errors
end

-- Cached hasUniform lookup for one compiled shader.
function Compile.uniformCache(shader)
    local cache = {}
    return function(name)
        local v = cache[name]
        if v == nil then
            v = shader:hasUniform(name)
            cache[name] = v
        end
        return v
    end
end

return Compile
