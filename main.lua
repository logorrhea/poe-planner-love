scaleFix = 2.5

local OS = love.system.getOS()
local json   = require 'vendor.dkjson'
local Layout = require 'vendor.luigi.luigi.layout'
local dark   = require 'vendor.luigi.luigi.theme.dark'
local Timer  = require 'vendor.hump.timer'
local lume   = require 'vendor.lume.lume'

local lurker = require 'vendor.lurker.lurker'
lurker.protected = false

require 'node'
require 'group'
require 'colors'
require 'graph'

pinches = {nil, nil}

camera = {
  x         = 0,
  y         = 0,
  scale     = 0.5,
  maxScale  = 1.0,
  minScale  = 0.1,
  scaleStep = 0.05
}

-- Use these for culling later
winWidth, winHeight = love.graphics.getDimensions()
scaledWidth, scaledHeight = winWidth/camera.scale, winHeight/camera.scale

maxActive = 123
activeClass = 2
clickCoords = {x = 0, y = 0}
visibleNodes = {}
visibleGroups = {}
startNodes = {}
addTrail = {}
removeTrail = {}
orig_r, orig_g, orig_b, orig_a = love.graphics.getColor()

-- Load GUI layout(s)
local elements = require('ui.layout')
local layout = Layout(elements)
local guiButtons = {}

-- @TODO: Move dialog window away from UI library
local dialog = Layout {
  type       = 'panel',
  text       = '',
  width      = 300,
  height     = 150,
  wrap       = true,
  background = {1, 1, 1, 240},
  outline    = {255, 255, 255, 255},
  font       = 'fonts/fontin-bold-webfont.ttf',
  size       = 20,
}
dialog:onPress(function(e)
    dialog:hide()
    checkIfNodeClicked(e.x, e.y, e.button, e.hit)
end)

-- @TODO: Move class picker away from UI library
local classPickerShowing = false
local classPickerOpts = require 'ui.classPicker'
local classPicker = Layout(classPickerOpts)

-- Stat window images
local portrait = love.graphics.newImage('assets/'..Node.portraits[activeClass]..'-portrait.png')
local divider  = love.graphics.newImage('assets/LineConnectorNormal.png')
local leftIcon = love.graphics.newImage('assets/left.png')


-- Adjust UI theme
layout:setTheme(dark)
dialog:setTheme(dark)

-- Adjust style
local style = {
  font = 'fonts/fontin-bold-webfont.ttf',
}
layout:setStyle(style)
dialog:setStyle(style)

local lastClicked = nil

function love.load()

  -- Read data file
  -- file, err = love.filesystem.newFile('data/json/skillTree.json')
  file, err = love.filesystem.newFile('dat.json')
  file:open('r')
  dataString = file:read()
  file:close()

  -- Parse json data into table
  Tree, err = json.decode(dataString)

  -- Cache node count
  local nodeCount = #Tree.nodes
  local groupCount = 0
  for gid, group in pairs(Tree.groups) do
    groupCount = groupCount + 1
  end

  -- Generate images
  images = {}
  batches = {}

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

      local image = love.graphics.newImage('assets/'..fileName)
      if tableContainsValue(Node.InactiveSkillFrames, name) then
        batches[name] = love.graphics.newSpriteBatch(image, nodeCount)
      elseif tableContainsValue(Node.ActiveSkillFrames, name) then
        batches[name] = love.graphics.newSpriteBatch(image, maxActive)
      elseif name == 'PSGroupBackground1' then
        batches[name] = love.graphics.newSpriteBatch(image, groupCount)
      elseif name == 'PSGroupBackground2' then
        batches[name] = love.graphics.newSpriteBatch(image, groupCount)
      elseif name == 'PSGroupBackground3' then
        batches[name] = love.graphics.newSpriteBatch(image, (#Node.classframes + groupCount)*2)
      elseif name == 'PSStartNodeBackgroundInactive' then
        batches[name] = love.graphics.newSpriteBatch(image, #Node.classframes)
      else
        batches[name] = love.graphics.newSpriteBatch(image, 10)
      end
    end

  end

  -- Get connection images
  images.straight_connector = {
    active       = love.graphics.newImage('assets/LineConnectorActive.png'),
    intermediate = love.graphics.newImage('assets/LineConnectorIntermediate.png'),
    inactive     = love.graphics.newImage('assets/LineConnectorNormal.png')
  }

  spriteQuads = {}
  for name, sizes in pairs(Tree.skillSprites) do
    local spriteInfo = sizes[#sizes]
    local image = love.graphics.newImage('assets/'..spriteInfo.filename)
    local slots = string.match(name, 'Active') ~= nil and maxActive or nodeCount
    batches[name] = love.graphics.newSpriteBatch(image, slots)
    spriteQuads[name] = {}
    for title, coords in pairs(spriteInfo.coords) do
      spriteQuads[name][title] = love.graphics.newQuad(coords.x, coords.y, coords.w, coords.h, image:getDimensions())
    end
  end

  -- Create groups
  groups = {}
  for gid, group in pairs(Tree.groups) do
    local id = tonumber(gid)
    local group = Group.create(id, group)
    groups[id] = group
  end

  -- Create nodes
  nodes = {}
  for _, n in pairs(Tree.nodes) do
    local node = Node.create(n, groups[n.g])
    if groups[n.g].orbit == nil and node.orbit ~= nil then
      groups[n.g].orbit = node.orbit
    end

    -- Determine sprite sheet to use
    local activeName = Node.ActiveSkillsheets[node.type]
    local inactiveName = Node.InactiveSkillsheets[node.type]
    node.activeSheet = activeName
    node.inactiveSheet = inactiveName
    node:setQuad(spriteQuads[activeName][node.icon])

    -- Add to startNode table if it is one
    if node.type == Node.NT_START then
      local spc = node:startPositionClass()
      startNodes[spc] = node.id
    end

    nodes[node.id] = node
  end

  -- Run through nodes a second time, so we can make links
  -- go both directions
  for nid, node in pairs(nodes) do
    for _, lnid in ipairs(node.out) do
      if lnid ~= nid and nodes[lnid].neighbors[nid] == nil then
        table.insert(nodes[lnid].neighbors, nid)
      end
    end
  end

  -- Set better starting position
  local startnid = startNodes[activeClass]
  local startNode = nodes[startnid]
  camera.x = startNode.position.x
  camera.y = startNode.position.y

  -- Create SpriteBatch for background image
  local bgImage = love.graphics.newImage('assets/Background1.png')
  local w, h = bgImage:getDimensions()
  local tilesX, tilesY = math.ceil(winWidth/w), math.ceil(winHeight/h)
  background = love.graphics.newSpriteBatch(bgImage, (tilesX+1)*(tilesY+1), "static")
  for tx = 0, tilesX do
    for ty=0, tilesY do
      background:add(w*tx, h*ty)
    end
  end

  -- Fill up sprite batches
  refillBatches()

  -- Show GUI
  -- layout:show()
  dialog:hide()
  -- stats:hide()
  guiButtons.menuToggle = {
    x     = 10,
    y     = 10,
    sx    = 0.1,
    sy    = 0.1,
    image = love.graphics.newImage('assets/menu.png'),
    trigger = (function()
        -- Show stats board
        -- stats:show()

        -- Slide in stats board
        statsShowing = true
        -- Timer.tween(1, stats.root, {left = 0}, 'in-out-quad')
    end)
  }

end

function love.update(dt)
  lurker.update(dt)
  Timer.update(dt)
  -- if statsShowing then
  --   stats:show()
  -- end
end

function love.draw()
  love.graphics.clear(255, 255, 255, 255)
  love.graphics.setColor(255, 255, 255, 230)

  -- Draw background image separate from transformations
  love.graphics.draw(background)
  clearColor()

  -- Store the translation info, for profit
  local cx, cy = winWidth/(2*camera.scale), winHeight/(2*camera.scale)
  love.graphics.push()
  love.graphics.scale(camera.scale)
  love.graphics.translate(cx, cy)
  love.graphics.translate(-camera.x, -camera.y)

  -- Draw group backgrounds
  love.graphics.draw(batches['PSGroupBackground1'])
  love.graphics.draw(batches['PSGroupBackground2'])
  love.graphics.draw(batches['PSGroupBackground3'])

  -- Draw connections
  love.graphics.setColor(inactiveConnector)
  love.graphics.setLineWidth(2/camera.scale)
  for nid, node in pairs(visibleNodes) do
    node:drawConnections()
  end
  love.graphics.setLineWidth(1)
  clearColor()

  -- Draw the start node decorations first, they should be in the very back
  love.graphics.draw(batches['PSStartNodeBackgroundInactive'])

  -- Draw skill icons next
  for _, name in pairs(Node.ActiveSkillsheets) do
    love.graphics.draw(batches[name])
  end
  for _, name in pairs(Node.InactiveSkillsheets) do
    love.graphics.draw(batches[name])
  end

  -- Draw frames
  for _, name in pairs(Node.ActiveSkillFrames) do
    love.graphics.draw(batches[name])
  end
  for _, name in pairs(Node.InactiveSkillFrames) do
    love.graphics.draw(batches[name])
  end

  -- Draw active class frames
  for _, name in pairs(Node.classframes) do
    love.graphics.draw(batches[name])
  end

  love.graphics.pop()

  -- Draw menuToggle button in top-left
  for _, item in pairs(guiButtons) do
    love.graphics.draw(item.image, item.x, item.y, 0, item.sx, item.sy)
  end

  -- print FPS counter in top-left
  -- local fps, timePerFrame = love.timer.getFPS(), 1000 * love.timer.getAverageDelta()
  -- love.graphics.setColor(255, 255, 255, 255)
  -- love.graphics.print(string.format("Current FPS: %.2f | Average frame time: %.3f ms", fps, timePerFrame), 10, 10)
  clearColor()

  -- Draw UI
  if statsShowing then
    drawStatsPanel()
  end
end

if OS == 'iOS' then

  function love.touchpressed(id, x, y, dx, dy, pressure)
    dialog:hide()
  end

  function love.touchreleased(id, x, y, dx, dy, pressure)
    checkIfNodeClicked(x, y, id, true)
  end

  function love.touchmoved(id, x, y, dx, dy, pressure)
    dialog:hide()
    local touches = love.touch.getTouches()
    if #touches == 1 then
      camera.x = camera.x - (dx/camera.scale)
      camera.y = camera.y - (dy/camera.scale)
      refillBatches()
    elseif #touches == 2 then
      -- @TODO: handle zooming in and out with multitouch
      local ox, oy = nil, nil
      for tid, touch in pairs(touches) do
        if tid ~= id then
          ox, oy = love.touch.getPosition(touch)
        end
      end
      local d1 = dist({x=ox, y=oy}, {x=x, y=y})
      local d2 = dist({x=ox, y=oy}, {x=x+dx, y=y+dy})

      camera.scale = camera.scale + (d2-d1)/100 -- should handle both zoom in and out
      camera.scale = lume.clamp(camera.scale, camera.minScale, camera.maxScale)
    elseif #touches == 5 then
      love.event.quit()
    end
  end

else

  function love.mousepressed(x, y, button, isTouch)
    dialog:hide()
    clickCoords.x, clickCoords.y = x, y
  end

  function love.mousereleased(x, y, button, isTouch)
    if not isTouch then
      local dx = x - clickCoords.x
      local dy = y - clickCoords.y

      if math.abs(dx) <= 3 and math.abs(dy) <= 3 then
        local guiItemClicked = checkIfGUIItemClicked(x, y, button, isTouch)
        if not guiItemClicked then
          checkIfNodeClicked(x, y, button, isTouch)
        end
      end
    end
  end

  function love.mousemoved(x, y, dx, dy)
    if love.mouse.isDown(1) then
      camera.x = camera.x - (dx/camera.scale)
      camera.y = camera.y - (dy/camera.scale)
      refillBatches()
    else
      checkIfNodeHovered(x, y)
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
      refillBatches()
    elseif key == 'down' then
      camera.scale = camera.scale - camera.scaleStep
      if camera.scale < camera.minScale then
        camera.scale = camera.minScale
      end
      scaledHeight = winHeight/camera.scale
      scaledWidth = winWidth/camera.scale
      refillBatches()
    elseif key == 'a' then
      if classPickerShowing then
        classPicker:hide();
        classPickerShowing = false
      else
        classPicker:show();
        classPickerShowing = true
      end
    end
  end

end

function checkIfGUIItemClicked(mx, my, button, isTouch)
  for name, item in pairs(guiButtons) do
    local w, h = item.image:getDimensions()
    w, h = w*item.sx, h*item.sy
    local x1, y1 = item.x, item.y
    local x2, y2 = item.x + w, item.y + h

    if mx >= x1 and mx <= x2 and my >= y1 and my <= y2 then
      item.trigger()
      return true
    end
  end

  if statsShowing then
    local w, h = leftIcon:getDimensions()
    local x1, y1 = 300-w, (winHeight-h)/2
    local x2, y2 = x1+w, y1+h
    if mx >= x1 and mx <= x2 and my >= y1 and my <= y2 then
      statsShowing = false
      return true
    end
  end
  return false
end

function checkIfNodeHovered(x, y)
  local hovered = false
  for nid, node in pairs(visibleNodes) do
    local wx, wy = cameraCoords(node.position.x, node.position.y)
    local dx, dy = wx - x, wy - y
    local r = Node.Radii[node.type] * camera.scale
    if dx * dx + dy * dy <= r * r then
      hovered = true
      showNodeDialog(nid)
    end
  end

  if not hovered then
    dialog:hide()
  end
end

function checkIfNodeClicked(x, y, button, isTouch)
  for nid, node in pairs(visibleNodes) do
    local wx, wy = cameraCoords(node.position.x, node.position.y)
    local dx, dy = wx - x, wy - y
    local r = Node.Radii[node.type] * camera.scale
    if dx * dx + dy * dy <= r * r then
      -- Debug
      print('clicked: '..node.id)
      -- local neighbors = ''
      -- for _, nnid in ipairs(node.neighbors) do
      --   neighbors = neighbors..' '..nnid
      -- end
      -- print('Neighbors:', neighbors)

      if node.id == lastClicked then
        -- On second click, toggle all nodes in highlighted trail
        for id,_ in pairs(addTrail) do
          nodes[id].active = true
        end
        addTrail = {}
        -- Remove all nodes in removeTrail
        for id,_ in pairs(removeTrail) do
          nodes[id].active = false
        end
        removeTrail = {}
        refillBatches()
        lastClicked = nil
      else
        -- On first click, we should give some preview information:
        --  Dialog box diplaying information about the clicked node
        --  Preview a route from closest active node
        if node.active then
          print('refund node')
          addTrail = {}
          removeTrail = Graph.planRefund(nid)
        else
          removeTrail = {}
          addTrail = Graph.planRoute(nid)
        end
        showNodeDialog(nid)
        lastClicked = nid
      end
      return true
    end
  end
  -- Not sure which behavior is better?
  -- Clear trail on empty click, or are they just trying to hide
  -- the dialog window? Maybe make it an option at some point?
  -- OR  - maybe the dialog window should have an obvious close button?
  -- addTrail = {}
  return false
end

function clearColor()
  love.graphics.setColor(orig_r, orig_g, orig_b, orig_a)
end

function refillBatches()

  -- Clear out batches
  for name, _ in pairs(batches) do
    batches[name]:clear()
  end

  -- Re-calculate visible nodes
  local tx, ty = winWidth/(2*camera.scale)-camera.x, winHeight/(2*camera.scale)-camera.y
  visibleNodes = {}
  visibleGroups = {}
  for nid, node in pairs(nodes) do
    if node:isVisible(tx, ty) then
      visibleNodes[node.id] = node
      if visibleGroups[node.gid] == nil then
        visibleGroups[node.gid] = groups[node.gid]
      end
    end
  end

  -- Re-fill them batches
  for nid, node in pairs(visibleNodes) do
    node:draw()
  end

  for gid, group in pairs(visibleGroups) do
    group:draw()
  end
end

function tableContainsValue(t, v)
  for _, n in pairs(t) do
    if n == v then
      return true
    end
  end
  return false
end

function showNodeDialog(nid)
  local node = nodes[nid]

  -- Update text and calculate dialog box position
  local newText = node.name
  for _, desc in ipairs(node.descriptions) do
    newText = newText .. '\n\t' .. desc
  end
  dialog.root.text = newText
  local x, y = cameraCoords(node.position.x, node.position.y)
  x, y = adjustDialogPosition(x, y, dialog.root.width, dialog.root.height, 20)

  -- Position has to be updated after displaying it
  dialog:show()
  dialog.root.position = {x = x, y = y}
end

function screenToWorldCoords(x, y)
  x, y = (x - winWidth/2) / camera.scale, (y - winHeight/2) / camera.scale
  return x + camera.x, y + camera.y
end

function cameraCoords(x, y)
  x, y = x - camera.x, y - camera.y
  return x * camera.scale + winWidth/2, y * camera.scale + winHeight/2
end

function adjustDialogPosition(x, y, w, h, offset)
  if x >= winWidth - w then
    x = x - w - offset
  else
    x = x + offset
  end
  if y >= winHeight - h then
    y = y - h - offset
  else
    y = y + offset
  end
  return x, y
end

function dist(v1, v2)
  return math.sqrt((v2.x - v1.x)*(v2.x - v1.x) + (v2.y - v1.y)*(v2.y - v1.y))
end

-- @TODO: Adjust size of stats panel based on device?
function drawStatsPanel()
  -- love.graphics.setBackgroundColor(1, 1, 1, 240)
  love.graphics.setColor(1, 1, 1, 240)
  love.graphics.rectangle('fill', 0, 0, 300, winHeight)


  -- Stat panel outline
  clearColor()
  love.graphics.rectangle('line', 0, 0, 300, winHeight)

  -- Draw portrait
  love.graphics.draw(portrait, 5, 5)

  -- Draw divider
  love.graphics.draw(divider, 5, 115, 0, 0.394, 1.0)

  -- Draw left icon (click to close stats drawer)
  local w, h = leftIcon:getDimensions()
  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.draw(leftIcon, 300-w, (winHeight-h)/2, 0)
end
