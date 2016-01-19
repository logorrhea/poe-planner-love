local json = require('vendor/dkjson')

require 'node'
require 'group'

camera = {
  x         = 0,
  y         = 0,
  scale     = 0.1,
  -- scale = 1.0,
  maxScale  = 0.6,
  minScale  = 0.1,
  scaleStep = 0.05
}

clickCoords = {x = 0, y = 0}

visibleNodes = {}

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
  -- @TODO: Store all this shit as SpriteBatches
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

  -- Get connection images
  images.straight_connector = {
    active = love.graphics.newImage('assets/LineConnectorActive.png'),
    intermediate = love.graphics.newImage('assets/LineConnectorIntermediate.png'),
    inactive = love.graphics.newImage('assets/LineConnectorNormal.png')
  }

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

    -- Determine sprite sheet to use

    if node.type == Node.NT_NOTABLE then
      node.activeSheet = images["notableActive"]
      node.inactiveSheet = images["notableInactive"]
    elseif node.type == Node.NT_KEYSTONE then
      node.activeSheet = images["keystoneActive"]
      node.inactiveSheet = images["keystoneInactive"]
    elseif node.type == Node.NT_MASTERY then
      node.activeSheet = images["mastery"]
      node.inactiveSheet = images["mastery"]
    else
      node.activeSheet = images["normalActive"]
      node.inactiveSheet = images["normalInactive"]
    end

    node.imageQuad = spriteQuads[node.icon]

    nodes[node.id] = node
  end

  -- Use these for culling later
  winWidth, winHeight = love.graphics.getDimensions()
  scaledWidth, scaledHeight = winWidth/camera.scale, winHeight/camera.scale
end

function love.update(dt)
end

function love.draw()
  love.graphics.clear(255, 255, 255, 255)
  love.graphics.push()
  love.graphics.scale(camera.scale, camera.scale)

  -- Store the translation info, for profit
  local tx, ty = -camera.x/camera.scale, -camera.y/camera.scale
  love.graphics.translate(tx, ty)

  for nid, node in pairs(nodes) do
    -- @TODO: Once we move everything over to SpriteBatches, we can probably
    -- do these comparisons at SpriteBatch-creation-time. Simply leave out all
    -- the ones that don't need to drawn
    node:draw(tx, ty)
  end
  love.graphics.pop()

  -- print FPS counter in top-left
  love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)
end

function love.mousepressed(x, y, button, isTouch)
  clickCoords.x, clickCoords.y = x, y
end

function love.mousereleased(x, y, button, isTouch)
  local dx = x - clickCoords.x
  local dy = y - clickCoords.y

  if math.abs(dx) <= 3 and math.abs(dy) <= 3 then
    checkIfNodeClicked(x, y, button, isTouch)
  else
    visibleNodes = {}
  end
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

function checkIfNodeClicked(x, y, button, isTouch)
  for nid, node in pairs(visibleNodes) do
    local dx = (node.position.x*camera.scale) - camera.x - x
    local dy = (node.position.y*camera.scale) - camera.y - y
    local r = Node.Radii[node.type] * camera.scale
    if dx * dx + dy * dy <= r * r then
      node.active = not node.active
      print(node.id .. ' was clicked')
      return
    end
  end
end
