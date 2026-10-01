--[[
    Capture worker thread.

    Jobs (tables pushed on the "capture_jobs" channel):
        { kind = "png", data = ImageData, path = "captures/x.png" }
        { kind = "ffmpeg", dir = "<abs dir>", fps = 30, gif = "<abs>", mp4 = "<abs>", gifWidth = 720 }
        { kind = "probe" }                      -- check whether ffmpeg exists
        { kind = "quit" }
    Results go to "capture_results": { kind, ok, path?, msg? }
]]

require("love.image")
require("love.filesystem")

local jobs = love.thread.getChannel("capture_jobs")
local results = love.thread.getChannel("capture_results")

local function run(cmd)
    local p = io.popen(cmd .. " 2>&1")
    if not p then return false, "could not start process" end
    local out = p:read("*a")
    local ok = p:close()
    return ok, out
end

while true do
    local job = jobs:demand()
    if job.kind == "quit" then
        break
    elseif job.kind == "png" then
        local ok, err = pcall(function()
            job.data:encode(job.format or "png", job.path)
        end)
        job.data:release()
        results:push({ kind = "png", ok = ok, path = job.path, msg = not ok and tostring(err) or nil, frame = job.frame })
    elseif job.kind == "probe" then
        local p = io.popen("ffmpeg -version 2>&1")
        local first = p and p:read("*l") or ""
        if p then p:close() end
        results:push({ kind = "probe", ok = first:find("ffmpeg version") ~= nil, msg = first })
    elseif job.kind == "ffmpeg" then
        local input = '"' .. job.dir .. '/frame_%05d.' .. (job.ext or "png") .. '"'
        local msgs = {}
        local okAll = true
        if job.mp4 then
            local ok, out = run(string.format(
                'ffmpeg -y -loglevel error -framerate %d -i %s -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -c:v libx264 -pix_fmt yuv420p -crf 17 -preset slow "%s"',
                job.fps, input, job.mp4))
            if not ok then okAll = false; table.insert(msgs, out) end
        end
        if job.gif then
            local ok, out = run(string.format(
                'ffmpeg -y -loglevel error -framerate %d -i %s -vf "fps=%d,scale=%d:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a" "%s"',
                job.fps, input, math.min(job.fps, 30), job.gifWidth or 720, job.gif))
            if not ok then okAll = false; table.insert(msgs, out) end
        end
        if okAll and job.cleanup then
            -- intermediate frames are big and uncompressed; keep only the videos
            for i = 1, job.frames do
                love.filesystem.remove(string.format("%s/frame_%05d.%s", job.relDir, i, job.ext))
            end
        end
        results:push({ kind = "ffmpeg", ok = okAll, path = job.gif or job.mp4, msg = table.concat(msgs, "\n"), dir = job.dir })
    end
end
