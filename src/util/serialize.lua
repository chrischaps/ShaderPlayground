--[[
    Lua table literal serializer / sandboxed loader.

    Presets are stored as `return { ... }` files: no parser to maintain,
    comments allowed, and sorted keys keep diffs clean in git.
]]

local Serialize = {}

local function isIdentifier(s)
    return type(s) == "string" and s:match("^[%a_][%w_]*$") ~= nil
end

local function isArray(t)
    local n = #t
    for k in pairs(t) do
        if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then
            return false
        end
    end
    return true
end

local function formatNumber(n)
    if n ~= n then return "0" end -- NaN guard
    if n == math.floor(n) and math.abs(n) < 1e15 then
        return string.format("%d", n)
    end
    local s = string.format("%.6g", n)
    return s
end

local function sortKeys(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return ta < tb end
    return a < b
end

local function write(value, indent, out)
    local t = type(value)
    if t == "number" then
        out[#out + 1] = formatNumber(value)
    elseif t == "string" then
        out[#out + 1] = string.format("%q", value)
    elseif t == "boolean" then
        out[#out + 1] = tostring(value)
    elseif t == "table" then
        if next(value) == nil then
            out[#out + 1] = "{}"
            return
        end
        if isArray(value) then
            -- Short arrays of scalars stay on one line ({1, 0.5, 0.2})
            local simple = #value <= 4
            for _, v in ipairs(value) do
                if type(v) == "table" then simple = false end
            end
            if simple then
                out[#out + 1] = "{"
                for i, v in ipairs(value) do
                    if i > 1 then out[#out + 1] = ", " end
                    write(v, indent, out)
                end
                out[#out + 1] = "}"
                return
            end
            out[#out + 1] = "{\n"
            for _, v in ipairs(value) do
                out[#out + 1] = indent .. "    "
                write(v, indent .. "    ", out)
                out[#out + 1] = ",\n"
            end
            out[#out + 1] = indent .. "}"
            return
        end
        local keys = {}
        for k in pairs(value) do keys[#keys + 1] = k end
        table.sort(keys, sortKeys)
        out[#out + 1] = "{\n"
        for _, k in ipairs(keys) do
            out[#out + 1] = indent .. "    "
            if isIdentifier(k) then
                out[#out + 1] = k
            else
                out[#out + 1] = "["
                write(k, indent, out)
                out[#out + 1] = "]"
            end
            out[#out + 1] = " = "
            write(value[k], indent .. "    ", out)
            out[#out + 1] = ",\n"
        end
        out[#out + 1] = indent .. "}"
    else
        out[#out + 1] = "nil"
    end
end

function Serialize.encode(value, header)
    local out = {}
    if header then out[#out + 1] = header .. "\n" end
    out[#out + 1] = "return "
    write(value, "", out)
    out[#out + 1] = "\n"
    return table.concat(out)
end

-- Load a table literal in an empty environment. Rejects bytecode.
function Serialize.decode(text, chunkname)
    if type(text) ~= "string" then return nil, "no data" end
    if text:byte(1) == 27 then return nil, "binary chunks are not allowed" end
    local fn, err = loadstring(text, chunkname or "=preset")
    if not fn then return nil, err end
    setfenv(fn, {})
    local ok, result = pcall(fn)
    if not ok then return nil, result end
    if type(result) ~= "table" then return nil, "preset did not return a table" end
    return result
end

function Serialize.deepCopy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = Serialize.deepCopy(x) end
    return t
end

return Serialize
