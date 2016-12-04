function love.conf(t)
  t.identity = 'poe-planner-love'
  t.version = '0.10.1'

  t.window.title = 'PoE Skill Tree Planner'
  t.window.icon = 'logo.png'
  t.window.width = 1024
  t.window.height = 768
  t.window.resizable = true
  t.window.highdpi = true
  t.window.msaa = 4
  t.gammacorrect = true

  -- Disable unused packages
  t.modules.joystick = false
  t.modules.physics = false
  t.modules.thread = false
  t.modules.video = false

end
