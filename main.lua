local scaleFix = 2.5

local OS = love.system.getOS()
local json   = require 'vendor.dkjson'
local Layout = require 'vendor.luigi.luigi.layout'
local dark   = require 'vendor.luigi.luigi.theme.dark'
local Timer  = require 'vendor.hump.timer'
local lume   = require 'vendor.lume.lume'

local imgui = require 'imgui'

require 'downloader'
require 'node'
require 'group'
require 'colors'
require 'graph'

DEBUG = false
pinches = {nil, nil}

camera = {
  x         = 0,
  y         = 0,
  scale     = 0.5,
  maxScale  = 1.0,
  minScale  = 0.1,
  scaleStep = 0.05,
  zoomIn = (function()
      camera.scale = camera.scale + camera.scaleStep
      camera.scale = lume.clamp(camera.scale, camera.minScale, camera.maxScale)
      scaledHeight = winHeight/camera.scale
      scaledWidth = winWidth/camera.scale
      refillBatches()
  end),
  zoomOut = (function()
      camera.scale = camera.scale - camera.scaleStep
      camera.scale = lume.clamp(camera.scale, camera.minScale, camera.maxScale)
      scaledHeight = winHeight/camera.scale
      scaledWidth = winWidth/camera.scale
      refillBatches()
  end)
}

-- Use these for culling later
winWidth, winHeight = love.graphics.getDimensions()
scaledWidth, scaledHeight = winWidth/camera.scale, winHeight/camera.scale

maxActive = 123
activeClass = 1
ascendancyClass = 1
clickCoords = {x = 0, y = 0}
visibleNodes = {}
visibleGroups = {}
startNodes = {}
activeNodes = {}
addTrail = {}
removeTrail = {}
orig_r, orig_g, orig_b, orig_a = love.graphics.getColor()

-- Store saveDir
local saveDir = love.filesystem.getSaveDirectory()

-- Load GUI layout(s)
local guiButtons = {}

-- Keep track of character stats
local character = {
  str       = 0,
  int       = 0,
  dex       = 0,
  stats     = {},
  keystones = {},
}
local characterURL = ''


-- le Font
local headerFont = love.graphics.newFont('fonts/fontin-bold-webfont.ttf', 20)
local font       = love.graphics.newFont('fonts/fontin-bold-webfont.ttf', 14)

-- Stat window images
local statsShowing = false
local statsTransitioning = false
local charStatLabels = love.graphics.newText(headerFont, 'Str:\nInt:\nDex:')
local charStatText = love.graphics.newText(headerFont, '0\n0\n0')
local generalStatLabels = love.graphics.newText(font, '')
local generalStatText = love.graphics.newText(font, '')
local portrait = love.graphics.newImage('assets/'..Node.classes[activeClass]..'-portrait.png')
local divider  = love.graphics.newImage('assets/LineConnectorNormal.png')
local leftIcon = love.graphics.newImage('assets/left.png')

-- Dialog Window stuff
local dialogWindowVisible = false
local dialogHeaderText    = love.graphics.newText(headerFont, '')
local dialogContentText   = love.graphics.newText(font, '')
local dialogPosition      = {x = 0, y = 0, w = 300, h = 150}
local statPanelLocation = {x = -300, y = 0}

-- Class picker window stuff
local portraits = {}
local classPickerShowing = false
for _, class in ipairs(Node.classes) do
  portraits[#portraits+1] = love.graphics.newImage('assets/'..class..'-portrait.png')
end

-- Use to determine whether to plan route/refund or activate nodes
local lastClicked = nil

-- Graph Search thread
local graphSearchThread = nil
local graphSearchChannel = love.thread.getChannel('routeChannel')

function love.load()

  -- Get tree data. Will download new version if necessary
  -- Tree = Downloader.getLuaTree()
  -- local data = Downloader.processNodes(Tree)
  Tree = require 'passive-skill-tree'

  -- Read save file
  local savedNodes = {}
  if love.filesystem.exists('builds.lua') then
    local saveDataFunc = love.filesystem.load('builds.lua')
    local saveData = saveDataFunc()
    activeClass, ascendancyClass, savedNodes = Graph.import(saveData.nodes)
    portrait = love.graphics.newImage('assets/'..Node.classes[activeClass]..'-portrait.png')
  end

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

      local fileData = love.filesystem.newFileData('assets/'..fileName)
      local imageData = love.image.newImageData(fileData)
      local image = love.graphics.newImage(imageData)
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
  for _, n in ipairs(Tree.nodes) do
    local node = Node.create(n, groups[n.g])
    if groups[n.g].type == nil then
      groups[n.g].type = node.orbit
    end
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

  -- Activate nodes saved in user data
  for _, nid in ipairs(savedNodes) do
    activateNode(nid)
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
  startnid = startNodes[activeClass]
  startNode = nodes[startnid]
  camera.x = startNode.position.x
  camera.y = startNode.position.y

  -- Create SpriteBatch for background image
  tiledBackground()

  -- Fill up sprite batches
  refillBatches()

  -- Show GUI
  guiButtons.menuToggle = {
    x     = 10,
    y     = 10,
    sx    = 0.1,
    sy    = 0.1,
    image = love.graphics.newImage('assets/menu.png'),
    trigger = (function()
        -- Slide in stats board
        statsShowing = true
        Timer.tween(0.5, statPanelLocation, {x = 0}, 'in-out-quad')
    end)
  }

end

function love.update(dt)
  -- lurker.update(dt)
  Timer.update(dt)
  local message = graphSearchChannel:peek()
  if type(message) == 'table' then
    message = graphSearchChannel:pop()
    print('path:', table.concat(message, ', '))
  end
  if graphSearchThread ~= nil and graphSearchThread:getError() then
    print(graphSearchThread:getError())
  end
end

function love.resize(w, h)
  winWidth, winHeight = w, h
  scaledWidth, scaledHeight = winWidth/camera.scale, winHeight/camera.scale

  -- Regenerate tiled background
  tiledBackground()

  -- Regenerate sprite batches
  refillBatches()
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

  if DEBUG then
    -- print FPS counter in top-left
    local fps, timePerFrame = love.timer.getFPS(), 1000 * love.timer.getAverageDelta()
    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.print(string.format("Current FPS: %.2f | Average frame time: %.3f ms", fps, timePerFrame), winWidth - 400, 10)

    -- Print character URL below
    love.graphics.print(characterURL, winWidth-400, 30)
    clearColor()
  end

  -- Draw UI
  if statsShowing then
    drawStatsPanel()
  end

  if dialogWindowVisible then
    drawDialogWindow()
  end

  if classPickerShowing then
    drawClassPickerWindow()
  end
end

if OS == 'iOS' then

  function love.touchpressed(id, x, y, dx, dy, pressure)
    dialogWindowVisible = false
  end

  function love.touchreleased(id, x, y, dx, dy, pressure)
    checkIfNodeClicked(x, y, id, true)
  end

  function love.touchmoved(id, x, y, dx, dy, pressure)
    dialogWindowVisible = false
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
    dialogWindowVisible = false
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

  function love.wheelmoved(x, y)
    if y > 0 then
      camera.zoomIn()
    elseif y < 0 then
      camera.zoomOut()
    end
  end

  function love.keypressed(key, scancode, isRepeat)
    if key == 'up' then
      camera.zoomIn()
    elseif key == 'down' then
      camera.zoomOut()
    elseif key == 'p' then
      print(lastClicked)
      if lastClicked then
        graphSearchThread = Graph.planShortestRoute(lastClicked)
      end
    elseif key == 'f1' then
      DEBUG = not DEBUG
    elseif scancode == '[' then
      if statsShowing then
        closeStatPanel()
      else
        guiButtons.menuToggle.trigger()
      end
    elseif key == 'escape' then
      love.event.quit()
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

    -- Check close button clicked
    local w, h = leftIcon:getDimensions()
    local x1, y1 = 300-w, (winHeight-h)/2
    local x2, y2 = x1+w, y1+h
    if mx >= x1 and mx <= x2 and my >= y1 and my <= y2 then
      closeStatPanel()
      return true
    end

    -- Check class portrait clicked
    if not statsTransitioning then
      local w, h = portrait:getDimensions()
      local x1, y1 = 5, 5
      local x2, y2 = x1+w, y1+h
      if mx >= x1 and mx <= x2 and my >= y1 and my <= y2 then
        classPickerShowing = not classPickerShowing
        return true
      end
    end
  end

  -- Check if any of the other class icons are clicked
  if classPickerShowing then
    local w, h = 110, 105
    local x1, y1 = statPanelLocation.x+w+5, 5
    local x2, y2 = x1+w, y1+h
    for i, class in ipairs(Node.classes) do
      if i ~= activeClass then
        if mx >= x1 and mx <= x2 and my >= y1 and my <= y2 then
          local buttons = {"Cancel", "OK", escapebutton=1, enterbutton=2}
          local decision = love.window.showMessageBox('Change Class?', 'Are you sure you want to change class and reset the skill tree?', buttons, 'info', true)
          print(decision)
          if decision == 2 then
            changeActiveClass(i)
            return true
          end
        end
        x1, x2 = x2, x2 + w
      end
    end
  end

  return false
end

function checkIfNodeHovered(x, y)
  local hovered = nil
  for nid, node in pairs(visibleNodes) do
    if not node:isMastery() and not node:isStart() then
    -- end
    -- if node.type ~= Node.NT_MASTERY and node.type ~= Node.NT_START then
      local wx, wy = cameraCoords(node.position.x, node.position.y)
      local dx, dy = wx - x, wy - y
      local r = Node.Radii[node.type] * camera.scale
      if dx * dx + dy * dy <= r * r then
        hovered = nid
        showNodeDialog(nid)
      end
    end
  end

  -- Do route planning on hover, since desktop OS
  -- doesn't use the two-click method of activating nodes
  if hovered == nil then
    lastClicked = nil
    addTrail = {}
    removeTrail = {}
    dialogWindowVisible = false
  elseif hovered ~= lastClicked then
    if DEBUG then
      print(hovered..' hovered')
    end
    lastClicked = hovered
    addTrail = {}
    removeTrail = {}
    if nodes[hovered].active then
      removeTrail = Graph.planRefund(hovered) or {}
    else
      addTrail = Graph.planShortestRoute(hovered) or {}
    end
  end
end

function checkIfNodeClicked(x, y, button, isTouch)
  for nid, node in pairs(visibleNodes) do
    local wx, wy = cameraCoords(node.position.x, node.position.y)
    local dx, dy = wx - x, wy - y
    local r = Node.Radii[node.type] * camera.scale
    if dx * dx + dy * dy <= r * r then
      -- Debug
      if DEBUG then
        print('clicked: '..node.id)
        -- local neighbors = ''
        -- for _, nnid in ipairs(node.neighbors) do
        --   neighbors = neighbors..' '..nnid
        -- end
        -- print('Neighbors:', neighbors)
      end


      -- For mobile, use two-tap node selection system
      if OS == 'iOS' then
        if node.id == lastClicked then
          -- On second click, toggle all nodes in highlighted trail
          for id,_ in pairs(addTrail) do
            if not nodes[id].active then
              activateNode(id)
            end
          end
          addTrail = {}
          -- Remove all nodes in removeTrail
          for id,_ in pairs(removeTrail) do
            deactivateNode(id)
          end
          removeTrail = {}
          refillBatches()
          lastClicked = nil
        else

          -- On first click, we should give some preview information:
          --  Dialog box diplaying information about the clicked node
          --  Preview a route from closest active node
          if node.active then
            addTrail = {}
            removeTrail = Graph.planRefund(nid)
          else
            removeTrail = {}
            addTrail = Graph.planShortestRoute(nid)
          end
          showNodeDialog(nid)
          lastClicked = nid
        end

      -- For desktop OS, we don't need the double-click behavior
      else
        -- Gather nodes for addition or removal
        if node.active then
          addTrail = {}
          removeTrail = Graph.planRefund(nid)
        else
          removeTrail = {}
          addTrail = Graph.planShortestRoute(nid)
        end

        for id,_ in pairs(addTrail) do
          if not nodes[id].active then
            activateNode(id)
          end
        end
        addTrail = {}
        -- Remove all nodes in removeTrail
        for id,_ in pairs(removeTrail) do
          deactivateNode(id)
        end
        removeTrail = {}
        refillBatches()
        lastClicked = nil
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

function tiledBackground()
  if background then
    background:clear()
  end
  local bgImage = love.graphics.newImage('assets/Background1.png')
  local w, h = bgImage:getDimensions()
  local tilesX, tilesY = math.ceil(winWidth/w), math.ceil(winHeight/h)
  background = love.graphics.newSpriteBatch(bgImage, (tilesX+1)*(tilesY+1), "static")
  for tx = 0, tilesX do
    for ty=0, tilesY do
      background:add(w*tx, h*ty)
    end
  end
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
  local contentText = ''
  dialogHeaderText:set(node.name)

  -- Add all description texts to dialog
  for _, desc in ipairs(node.descriptions) do
    contentText = contentText .. '\n' .. desc
  end
  dialogContentText:set(contentText)

  -- Update dialog window dimensions based on new text
  local w1, h1 = dialogHeaderText:getDimensions()
  local w2, h2 = dialogContentText:getDimensions()
  if w1 > w2 then
    dialogPosition.w = w1
  else
    dialogPosition.w = w2
  end
  dialogPosition.w = dialogPosition.w + 10
  dialogPosition.h = 5*3 + h1 + h2

  -- Get position of node in camera coords, and adjust it so that
  -- the whole window will always fit on the screen
  local x, y = cameraCoords(node.position.x, node.position.y)
  x, y = adjustDialogPosition(x, y, dialogPosition.w, dialogPosition.h, 20)
  dialogPosition.x, dialogPosition.y = x, y

  -- Set window to visible
  dialogWindowVisible = true
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
  local dx, dy = x, y
  local hx, hy = winWidth/2, winHeight/2

  if x < hx and y < hy then         -- Upper-left quadrant
    dx, dy = x + offset, y + offset
  elseif x > hx and y < hy then     -- Upper-right quadrant
    dx, dy = x - w - offset, y + offset
  elseif x < hx and y > hy then     -- Lower-left quadrant
    dx, dy = x + offset, y - h - offset
  else                              -- Lower-right quadrant
    dx, dy = x - w - offset, y - h - offset
  end

  -- Some of the dialog boxes are super-wide
  if dx + w > winWidth then
    dx = winWidth - w - offset
  elseif dx - w < 0 then
    dx = offset
  end

  return dx, dy
end

function dist(v1, v2)
  return math.sqrt((v2.x - v1.x)*(v2.x - v1.x) + (v2.y - v1.y)*(v2.y - v1.y))
end

function drawStatsPanel()
  love.graphics.setColor(1, 1, 1, 240)
  love.graphics.rectangle('fill', statPanelLocation.x, 0, 300, winHeight)

  -- Stat panel outline
  clearColor()
  love.graphics.rectangle('line', statPanelLocation.x, 0, 300, winHeight)

  -- Draw portrait
  love.graphics.draw(portrait, statPanelLocation.x+5, 5)

  -- Character stats
  love.graphics.draw(charStatLabels, statPanelLocation.x+155, 18)
  love.graphics.draw(charStatText, statPanelLocation.x+155+charStatLabels:getWidth()*2, 18)

  -- Draw divider
  love.graphics.draw(divider, statPanelLocation.x+5, 115, 0, 0.394, 1.0)

  -- Draw general stats
  love.graphics.draw(generalStatLabels, statPanelLocation.x+5, 125)
  love.graphics.draw(generalStatText, statPanelLocation.x+5+generalStatLabels:getWidth()*1.5, 125)

  -- Draw keystone node text

  -- Draw left icon (click to close stats drawer)
  local w, h = leftIcon:getDimensions()
  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.draw(leftIcon, statPanelLocation.x+295-w, (winHeight-h)/2, 0)
end

function drawDialogWindow()
  -- Inner and outer rectangles
  love.graphics.setColor(1, 1, 1, 240)
  love.graphics.rectangle('fill', dialogPosition.x, dialogPosition.y, dialogPosition.w, dialogPosition.h)
  clearColor()
  love.graphics.rectangle('line', dialogPosition.x, dialogPosition.y, dialogPosition.w, dialogPosition.h)

  -- Draw text
  love.graphics.draw(dialogHeaderText, dialogPosition.x + 5, dialogPosition.y + 5)
  love.graphics.draw(dialogContentText, dialogPosition.x + 5, dialogPosition.y + 20)
end

function drawClassPickerWindow()
  local w, h = 110, 105
  local x, y = statPanelLocation.x+w+5, 5
  for i, img in ipairs(portraits) do
    if i ~= activeClass then
      love.graphics.draw(img, x, y)
      x = x + w
    end
  end
end

function activateNode(nid)
  nodes[nid].active = true

  -- Add node stats to character stats
  local node = nodes[nid]
  parseDescriptions(node, add)
  updateStatText()

  -- @TODO: Send to threads that node became active

  characterURL = Graph.export(activeClass, ascendancyClass, nodes)
end

function deactivateNode(nid)
  nodes[nid].active = false

  -- Remove node stats from character stats
  local node = nodes[nid]
  parseDescriptions(node, subtract)
  updateStatText()

  -- @TODO: Send to threads that node became inactive

  characterURL = Graph.export(activeClass, ascendancyClass, nodes)
end

function parseDescriptions(node, op)
  local found = {}
  if node.type == Node.NT_KEYSTONE then
    character.keystones[node.id] = node.descriptions
  else
    for _, desc in ipairs(node.descriptions) do
      for n,s in desc:gmatch("(%d+) (%a[%s%a]*)") do
        found[#found+1] = s
        if DEBUG then
          print('s: '..s, 'n: '..n)
        end
        n = tonumber(n)
        if s == 'to Strength' then
          character.str = op(character.str, n)
        elseif s == 'to Intelligence' then
          character.int = op(character.int, n)
        elseif s == 'to Dexterity' then
          character.dex = op(character.dex, n)
        elseif s == 'to Dexterity and Intelligence' or s == 'to Intelligence and Dexterity' then
          character.dex = op(character.dex, n)
          character.int = op(character.int, n)
        elseif s == 'to Strength and Intelligence' or s == 'to Intelligence and Strength' then
          character.str = op(character.str, n)
          character.int = op(character.int, n)
        elseif s == 'to Strength and Dexterity' or s == 'to Dexterity and Strength' then
          character.str = op(character.str, n)
          character.dex = op(character.dex, n)
        else
          local v = character.stats[s] or 0
          v = op(v, n)
          if v == 0 then
            v = nil
          end
          character.stats[s] = v
        end
      end

      if #found == 0 then
        for n,s in desc:gmatch("(%d+)(%%? %a[%s%a]*)") do
          found[#found+1] = s
          local v = character.stats[s] or 0
          v = op(v, n)
          if v == 0 then
            v = nil
          end
          character.stats[s] = v
        end
      end

      if #found == 0 then
        print('Still not found :(')
        print(desc)
      end

    end
  end
end

-- Helper functions so that I can use + or - as arguments
-- to other functions
function add(n1, n2)
  if DEBUG then
    print('Adding '..n1..' to '..n2)
  end
  return n1+n2
end

function subtract(n1, n2)
  return n1-n2
end

function updateStatText()
  -- Update base stats
  charStatText:set(string.format('%i\n%i\n%i', character.str, character.int, character.dex))

  -- Update general stats
  local _labels = {}
  local _stats = {}
  local text
  for desc, n in pairs(character.stats) do
    if n > 0 then
      width, wrapped = font:getWrap(desc, 250)
      for i, text in ipairs(wrapped) do
        if i == 1 then
          _labels[#_labels+1] = n
        else
          _labels[#_labels+1] = ' '
        end
        _stats[#_stats+1] = text
      end
    end
  end
  generalStatLabels:set(table.concat(_labels, '\n'))
  generalStatText:set(table.concat(_stats, '\n'))
end

function closeStatPanel()
  classPickerShowing = false
  statsTransitioning = true
  Timer.tween(0.5, statPanelLocation, {x = -300}, 'in-out-quad')
  Timer.after(0.5, function()
                statsTransitioning = false
                statsShowing = false
  end)
end

function changeActiveClass(sel)
  closeStatPanel()
  activeClass = sel
  addTrail    = {}
  removeTrail = {}
  startnid = startNodes[activeClass]
  startNode = nodes[startnid]
  portrait = love.graphics.newImage('assets/'..Node.classes[activeClass]..'-portrait.png')
  for nid, node in pairs(nodes) do
    if node.active then
      deactivateNode(nid)
    end
  end
  nodes[startnid].active = true
  camera.x, camera.y = startNode.position.x, startNode.position.y
  refillBatches()
end
