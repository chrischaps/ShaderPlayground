--[[
    Image library: bundled images in assets/images plus anything dropped onto
    the window. `Images.names` is a live list shared with the Image source's
    enum param, so new images show up in its dropdown immediately.
]]

local Images = {
    names = {},
    images = {},
    listeners = {},
}

local EXT = { png = true, jpg = true, jpeg = true, bmp = true, tga = true }

local function add(name, image)
    image:setFilter("linear", "linear")
    image:setWrap("mirroredrepeat", "mirroredrepeat")
    table.insert(Images.names, name)
    table.insert(Images.images, image)
    return #Images.names
end

function Images.init()
    local dir = "assets/images"
    if love.filesystem.getInfo(dir, "directory") then
        local files = love.filesystem.getDirectoryItems(dir)
        table.sort(files)
        for _, f in ipairs(files) do
            local ext = f:match("%.(%w+)$")
            if ext and EXT[ext:lower()] then
                local ok, img = pcall(love.graphics.newImage, dir .. "/" .. f)
                if ok then
                    -- "01_kennedy_sunrise.jpg" -> "Kennedy Sunrise"
                    local name = f:gsub("%.%w+$", ""):gsub("^%d+[_%-]", ""):gsub("[_%-]", " ")
                    name = name:gsub("(%a)(%w*)", function(a, b) return a:upper() .. b end)
                    add(name, img)
                end
            end
        end
    end
    -- Legacy: a demo.png next to main.lua
    if love.filesystem.getInfo("demo.png") then
        local ok, img = pcall(love.graphics.newImage, "demo.png")
        if ok then add("demo", img) end
    end
end

function Images.isImageFile(filename)
    local ext = filename:match("%.(%w+)$")
    return ext and EXT[ext:lower()] or false
end

-- Add an image from a dropped love File. Returns its index (0-based for enums) or nil, err.
function Images.addDropped(file)
    local name = file:getFilename():match("([^/\\]+)$") or "dropped"
    local ok, err = file:open("r")
    if not ok then return nil, err end
    local data = file:read("data")
    file:close()
    local ok2, imgData = pcall(love.image.newImageData, data)
    if not ok2 then return nil, imgData end
    local img = love.graphics.newImage(imgData)
    local index = add((name:gsub("%.%w+$", "")), img)
    for _, fn in ipairs(Images.listeners) do fn(index) end
    return index - 1
end

function Images.get(index0)
    return Images.images[(index0 or 0) + 1]
end

function Images.count()
    return #Images.images
end

return Images
