local json = require('vendor/dkjson')
require 'node'
require 'group'

local camera = {
  x         = 0,
  y         = 0,
  scale     = 0.1,
  maxScale  = 0.5,
  minScale  = 0.1,
  scaleStep = 0.05
}

function love.load()

  -- Read data file
  -- file, err = love.filesystem.newFile('data/json/skillTree.json')
  file, err = love.filesystem.newFile('dat.json')
  file:open('r')
  dataString = file:read()
  file:close()

  -- Parse json data into table
  Tree, err = json.decode(dataString)

  -- Generate images
  images = {}
  for name, sheet in pairs(Tree.spriteSheets) do
    print(sheet)
    -- images[name] = love.graphics.newImage(sheet)
  end

  -- Create grups
  groups = {}
  for gid, group in pairs(Tree.groups) do
    local id = tonumber(gid)
    groups[id] = Group.create(id, group)
  end

  -- Create nodes
  nodes = {}
  for _, node in pairs(Tree.nodes) do
    local node = Node.create(node, groups[node.g])
    nodes[node.id] = node
  end

end

function love.update(dt)
end

function love.draw()
  love.graphics.push()
  love.graphics.scale(camera.scale, camera.scale)
  love.graphics.translate(-camera.x/camera.scale, -camera.y/camera.scale)
  for nid, node in pairs(nodes) do
    node:draw()
  end
  love.graphics.pop()

  -- print FPS counter in top-left
  love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)
end

function love.mousepressed(x, y, button, isTouch)
end

function love.mousereleased(x, y, button, isTouch)
end

function love.mousemoved(x, y, dx, dy)
  if love.mouse.isDown(1) then
    camera.x = camera.x - dx
    camera.y = camera.y - dy
  end
end

function love.keypressed(key, scancode, isRepeat)
  if key == 'up' then
    camera.scale = camera.scale + camera.scaleStep
    if camera.scale > camera.maxScale then
      camera.scale = camera.maxScale
    end
  elseif key == 'down' then
    camera.scale = camera.scale - camera.scaleStep
    if camera.scale < camera.minScale then
      camera.scale = camera.minScale
    else
      print(camera.scale)
    end
  end
end
