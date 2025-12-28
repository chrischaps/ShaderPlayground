function love.conf(t)
    t.window.title = "Shader Playground"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.vsync = 1
    t.window.msaa = 0

    t.console = true  -- Enable console on Windows for debugging

    t.modules.audio = true
    t.modules.joystick = true
    t.modules.physics = false
end
