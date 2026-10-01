--[[
    Playback clock: time, pause, speed, single-step, and a fixed-step mode
    used while recording so frames are evenly spaced however slow the
    render is.
]]

local Clock = {}
Clock.__index = Clock

function Clock.new()
    return setmetatable({
        time = 0,
        dt = 0,
        frame = 0,
        paused = false,
        speed = 1,
        fixedFps = nil,
        stepFrames = 0,
    }, Clock)
end

function Clock:update(realDt)
    local dt
    if self.fixedFps then
        dt = 1 / self.fixedFps
    elseif self.paused then
        if self.stepFrames > 0 then
            self.stepFrames = self.stepFrames - 1
            dt = 1 / 60
        else
            dt = 0
        end
    else
        dt = math.min(realDt, 1 / 15) * self.speed
    end
    self.dt = dt
    self.time = self.time + dt
    if dt ~= 0 then
        self.frame = self.frame + 1
    end
end

function Clock:togglePause()
    self.paused = not self.paused
end

function Clock:step(n)
    self.paused = true
    self.stepFrames = self.stepFrames + (n or 1)
end

function Clock:setFixed(fps)
    self.fixedFps = fps
end

function Clock:reset()
    self.time = 0
    self.frame = 0
end

return Clock
