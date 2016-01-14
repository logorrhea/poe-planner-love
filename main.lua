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
  for name, sizes in pairs(Tree.assets) do
    local filePath = nil
    local largest = 0
    for size, sizeFilePath in pairs(sizes) do
      if tonumber(size) > largest then
        largest = tonumber(size)
        filePath = sizeFilePath
      end
    end

    if filePath ~= nil then
      local fileName = nil
      for match in filePath:gmatch("[^/%.]+%.[^/%.]+") do
        fileName = match
      end
      fileName = fileName:gsub(".gif", ".png") -- this needs a better solution, probably
      images[name] = love.graphics.newImage('assets/'..fileName)
    end
  end

  spriteQuads = {}
  for name, sizes in pairs(Tree.skillSprites) do
    local spriteInfo = sizes[#sizes]
    local sheet = love.graphics.newImage('assets/'..spriteInfo.filename)
    images[name] = sheet
    for title, coords in pairs(spriteInfo.coords) do
      spriteQuads[title] = love.graphics.newQuad(coords.x, coords.y, coords.w, coords.h, sheet:getDimensions())
    end
  end

  -- Create groups
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

  -- Use these for culling later
  winWidth, winHeight = love.graphics.getDimensions()
  scaledWidth, scaledHeight = winWidth/camera.scale, winHeight/camera.scale
end

function love.update(dt)
end

function love.draw()
  love.graphics.push()
  love.graphics.scale(camera.scale, camera.scale)

  -- Store the translation info, for profit
  local tx, ty = -camera.x/camera.scale, -camera.y/camera.scale
  love.graphics.translate(tx, ty)

  for nid, node in pairs(nodes) do
    -- @TODO: Wrap all this into node:draw()
    if node.position.x + tx <= scaledWidth and
      node.position.x + tx >= 0 and
      node.position.y + ty >= 0 and
      node.position.y + ty <= scaledHeight then
      love.graphics.draw(images['normalActive'], spriteQuads[node.icon], node.position.x, node.position.y)
    end
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
    scaledHeight = winHeight/camera.scale
    scaledWidth = winWidth/camera.scale
  elseif key == 'down' then
    camera.scale = camera.scale - camera.scaleStep
    if camera.scale < camera.minScale then
      camera.scale = camera.minScale
    end
    scaledHeight = winHeight/camera.scale
    scaledWidth = winWidth/camera.scale
  end
end
