--[[
    Filesystem helpers

    love.filesystem can read from both the source directory and the save
    directory, but can only write to the save directory. When we run unfused
    from a source folder we write project files (presets) straight into the
    source tree with io.open so they can live in git.
]]

local FS = {}

function FS.read(path)
    local data = love.filesystem.read(path)
    return data
end

function FS.exists(path)
    return love.filesystem.getInfo(path) ~= nil
end

function FS.stat(path)
    local info = love.filesystem.getInfo(path)
    if not info then return nil end
    return info.modtime or 0, info.size or 0
end

-- List files in a directory (non-recursive) with the given extension, sorted.
function FS.list(dir, ext)
    local out = {}
    if not love.filesystem.getInfo(dir, "directory") then return out end
    for _, item in ipairs(love.filesystem.getDirectoryItems(dir)) do
        if not ext or item:sub(-#ext) == ext then
            local info = love.filesystem.getInfo(dir .. "/" .. item, "file")
            if info then table.insert(out, item) end
        end
    end
    table.sort(out)
    return out
end

-- Absolute path of the source directory when it can be written with io.open.
function FS.writableSourceDir()
    if love.filesystem.isFused() then return nil end
    local src = love.filesystem.getSource()
    if not src or src:match("%.love$") then return nil end
    return src
end

local function mkdirs(path)
    -- Best-effort recursive mkdir for an absolute path, Windows or POSIX.
    local sep = package.config:sub(1, 1)
    local native = path:gsub("[/\\]", sep)
    if sep == "\\" then
        os.execute('if not exist "' .. native .. '" mkdir "' .. native .. '" >nul 2>nul')
    else
        os.execute('mkdir -p "' .. native .. '"')
    end
end

-- Write a project file. Prefers the source tree (so it's tracked in git),
-- falls back to the save directory. Returns the location written, or nil+err.
function FS.writeProject(relPath, data)
    local src = FS.writableSourceDir()
    if src then
        local full = src .. "/" .. relPath
        local f = io.open(full, "wb")
        if not f then
            mkdirs(full:match("^(.*)[/\\]"))
            f = io.open(full, "wb")
        end
        if f then
            f:write(data)
            f:close()
            return full
        end
    end
    local dir = relPath:match("^(.*)/")
    if dir then love.filesystem.createDirectory(dir) end
    local ok, err = love.filesystem.write(relPath, data)
    if not ok then return nil, err end
    return love.filesystem.getSaveDirectory() .. "/" .. relPath
end

-- Absolute path for something in the save directory.
function FS.savePath(relPath)
    return love.filesystem.getSaveDirectory() .. "/" .. relPath
end

-- Absolute path for a file that love.filesystem can see (source or save dir).
function FS.realPath(relPath)
    local dir = love.filesystem.getRealDirectory(relPath)
    if not dir then return nil end
    return dir .. "/" .. relPath
end

function FS.openInOS(absPath)
    if not absPath then return false end
    return love.system.openURL("file:///" .. absPath:gsub("\\", "/"))
end

return FS
