--[[
    Screenshots and recordings.

    Screenshots copy the output canvas (rgba8, no UI) and encode on worker
    threads so the app never hitches. Recording switches the clock to a fixed
    step, writes a PNG sequence, then (if ffmpeg is on PATH) builds an MP4 and
    a palette-optimized GIF. Raw frames are never piped through io.popen:
    Windows text-mode pipes corrupt binary data.

    Files land in the save directory under captures/.
]]

local FS = require("src.util.fs")

local Capture = {}

local WORKERS = 4
local MAX_QUEUE = 6

local threads = {}
local jobs, results
local ffmpegAvailable = nil
local listeners = {}

Capture.recording = nil   -- { dir, frame, fps, started }
Capture.pending = 0

local function stamp()
    return os.date("%Y%m%d_%H%M%S")
end

local function emit(kind, msg, path)
    for _, fn in ipairs(listeners) do fn(kind, msg, path) end
end

function Capture.onEvent(fn)
    table.insert(listeners, fn)
end

function Capture.init()
    jobs = love.thread.getChannel("capture_jobs")
    results = love.thread.getChannel("capture_results")
    jobs:clear()
    results:clear()
    for i = 1, WORKERS do
        local t = love.thread.newThread("src/capture_worker.lua")
        t:start()
        threads[i] = t
    end
    love.filesystem.createDirectory("captures")
    jobs:push({ kind = "probe" })
end

function Capture.ffmpeg()
    return ffmpegAvailable
end

function Capture.screenshot(canvas, label)
    local data = canvas:newImageData()
    local path = "captures/" .. (label or "shot") .. "_" .. stamp() .. ".png"
    jobs:push({ kind = "png", data = data, path = path })
    Capture.pending = Capture.pending + 1
    return path
end

-- Screenshot of the whole window, UI included.
function Capture.screenshotWindow()
    love.graphics.captureScreenshot(function(data)
        local path = "captures/window_" .. stamp() .. ".png"
        jobs:push({ kind = "png", data = data, path = path })
        Capture.pending = Capture.pending + 1
    end)
end

function Capture.startRecording(fps)
    local dir = "captures/rec_" .. stamp()
    love.filesystem.createDirectory(dir)
    -- With ffmpeg we write uncompressed TGA (near-free to encode) and delete
    -- the frames after building the GIF/MP4; without it, keep PNGs.
    local ext = ffmpegAvailable and "tga" or "png"
    Capture.recording = { dir = dir, frame = 0, fps = fps or 30, started = love.timer.getTime(), ext = ext }
    return dir
end

-- Call once per rendered frame while recording.
function Capture.recordFrame(canvas)
    local rec = Capture.recording
    if not rec then return end
    -- Back-pressure: wait for encoders instead of queueing unbounded memory.
    while jobs:getCount() > MAX_QUEUE do
        Capture.update()
        love.timer.sleep(0.002)
    end
    rec.frame = rec.frame + 1
    local data = canvas:newImageData()
    jobs:push({ kind = "png", format = rec.ext, data = data,
        path = string.format("%s/frame_%05d.%s", rec.dir, rec.frame, rec.ext), frame = rec.frame })
    Capture.pending = Capture.pending + 1
end

function Capture.stopRecording()
    local rec = Capture.recording
    if not rec then return end
    Capture.recording = nil
    if rec.frame == 0 then return end
    rec.finishing = true
    Capture.finishing = rec
end

function Capture.update()
    if not results then return end
    while true do
        local r = results:pop()
        if not r then break end
        if r.kind == "png" then
            Capture.pending = Capture.pending - 1
            if not r.ok then
                emit("error", "Capture failed: " .. tostring(r.msg))
            elseif not r.frame then
                emit("screenshot", "Saved " .. r.path, FS.savePath(r.path))
            end
        elseif r.kind == "probe" then
            ffmpegAvailable = r.ok
        elseif r.kind == "ffmpeg" then
            if r.ok then
                emit("video", "Saved GIF + MP4", r.dir)
            else
                emit("error", "ffmpeg failed: " .. tostring(r.msg):sub(1, 200), r.dir)
            end
        end
    end
    -- When a finished recording's frames are all on disk, encode it.
    local fin = Capture.finishing
    if fin and Capture.pending <= 0 and jobs:getCount() == 0 then
        Capture.finishing = nil
        local absDir = FS.savePath(fin.dir)
        if ffmpegAvailable then
            jobs:push({
                kind = "ffmpeg", dir = absDir, relDir = fin.dir, ext = fin.ext, frames = fin.frame, fps = fin.fps,
                mp4 = absDir .. "/recording.mp4", gif = absDir .. "/recording.gif", gifWidth = 640,
                cleanup = fin.ext == "tga",
            })
            emit("info", string.format("Encoding %d frames with ffmpeg…", fin.frame), absDir)
        else
            emit("video", string.format("Saved %d PNG frames (ffmpeg not found)", fin.frame), absDir)
        end
    end
end

function Capture.quit()
    if not jobs then return end
    for _ = 1, #threads do jobs:push({ kind = "quit" }) end
end

return Capture
