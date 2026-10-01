--[[
    Capture test: screenshot, then a 2-second recording encoded by ffmpeg.

        lovec . --fresh --preset 05_deep_field --script tests/capture.lua
]]

local Capture = require("src.capture")

local function listCaptures()
    local out = {}
    for _, f in ipairs(love.filesystem.getDirectoryItems("captures")) do out[f] = true end
    return out
end

local before
local recDir
local t0, t1

return {
    { at = 0.5, check = function(App) before = listCaptures(); return true, "snapshot captures dir" end },
    { at = 0.6, key = "f12" },
    { at = 1.5, check = function(App)
        for f in pairs(listCaptures()) do
            if not before[f] and f:match("^shot_.*%.png$") then return true, "screenshot written: " .. f end
        end
        return false, "screenshot written"
    end },

    { at = 1.6, key = "f9" },
    { at = 1.7, check = function(App)
        recDir = Capture.recording and Capture.recording.dir
        t0 = Capture.recording and Capture.recording.started
        return recDir ~= nil and App.clock.fixedFps == 30, "recording started with a fixed 30 fps clock"
    end },
    { at = 3.69, check = function(App) t1 = love.timer.getTime(); return true, "mark stop time" end },
    { at = 3.7, key = "f9" },
    { at = 3.8, check = function(App)
        return Capture.recording == nil and App.clock.fixedFps == nil, "recording stopped, clock back to real time"
    end },
    { at = 4.5, check = function(App)
        local n = 0
        for _, f in ipairs(love.filesystem.getDirectoryItems(recDir)) do
            if f:match("^frame_%d+%.%a+$") then n = n + 1 end
        end
        -- Never faster than real time (the preview would run fast), never empty.
        -- Hitches can only lose time, since catch-up is capped at one frame.
        local realtime = (t1 - t0) * 30
        return n >= 30 and n <= realtime * 1.1 + 2,
            string.format("frames paced to real time (%d frames over %.2fs, max ~%d)", n, t1 - t0, realtime)
    end },
    { at = 12.0, check = function(App)
        if not Capture.ffmpeg() then return true, "ffmpeg not available: skipped GIF/MP4" end
        local gif = love.filesystem.getInfo(recDir .. "/recording.gif")
        local mp4 = love.filesystem.getInfo(recDir .. "/recording.mp4")
        local leftover = 0
        for _, f in ipairs(love.filesystem.getDirectoryItems(recDir)) do
            if f:match("%.tga$") then leftover = leftover + 1 end
        end
        return gif ~= nil and mp4 ~= nil and gif.size > 10000 and mp4.size > 10000 and leftover == 0,
            "ffmpeg produced GIF (" .. tostring(gif and gif.size) .. " B) and MP4 (" .. tostring(mp4 and mp4.size) .. " B)"
    end },
    { at = 12.2, quit = true },
}
