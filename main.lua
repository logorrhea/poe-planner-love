-- Reddit thread relevant to fall of oriath updates: https://www.reddit.com/r/pathofexile/comments/6fwqu3/300_skill_tree_changes_compared_to_260/

VERSION = '0.1.1'

local scaleFix = 2.5

-- Local includes
local OS = love.system.getOS()
local json   = require 'lib.dkjson'
local Camera = require 'lib.camera'


-- Global includes
Timer = require 'lib.timer'
lume  = require 'lib.lume'
vec   = require 'lib.vector'
suit  = require 'lib.suit'



require 'downloader'
require 'node'
require 'group'
require 'colors'
require 'graph'

local unusedImages = {
  'Fade_Corner',
  'Fade_Side',

  'groups-3',

  'JewelFrameCanAllocate',
  'KeystoneFrameCanAllocate',

  'Line_Deco_Highlighted',
  'Line_Deco',

  'LineConnectorActive',
  'LineConnectorIntermediate',
  'LineConnectorNormal',

  'NotableFrameCanAllocate',

  'PSOrbit1Normal',
  'Orbit1Active',
  'Orbit1Intermediate',
  'Orbit2Normal',
  'Orbit2Active',
  'Orbit2Intermediate',
  'Orbit3Normal',
  'Orbit3Active',
  'Orbit3Intermediate',
  'Orbit4Normal',
  'Orbit4Active',
  'Orbit4Intermediate',

  'PassiveSkillScreenAscendancyFrameLargeCanAllocate',
  'PassiveSkillScreenAscendancyFrameSmallCanAllocate',

  'Skill_Frame_CanAllocate',
}

DEBUG = false
pinches = {nil, nil}

-- oldcamera = require 'camera'
camera = Camera(0, 0, 0.5)

-- Store window width and height
winWidth, winHeight = love.graphics.getDimensions()
scaledWidth, scaledHeight = winWidth/camera.scale, winHeight/camera.scale

maxActive = 123
maxAscendancy = 8
activeNodes = 0
activeAscendancy = 0
activeClass = 1
ascendancyClass = 1
clickCoords = {x = 0, y = 0}
visibleNodes = {}
visibleGroups = {}
startNodes = {}
addTrail = {}
removeTrail = {}
ascendancyNodes = {}
orig_r, orig_g, orig_b, orig_a = love.graphics.getColor()

ascendancyTreeOrigins = {}

-- track touch data
local touchIds = {}
local touches = {}

-- Keep track of character stats
local character = {
  str       = 0,
  int       = 0,
  dex       = 0,
  stats     = {},
  keystones = {},
  keystoneCount = 0,
}
characterURL = ''


-- le Fonts
headerFont = love.graphics.newFont('fonts/fontin-bold-webfont.ttf', 20*love.window.getPixelScale())
headerFont:setFilter('nearest', 'nearest')
font = love.graphics.newFont('fonts/fontin-bold-webfont.ttf', 14*love.window.getPixelScale())
font:setFilter('nearest', 'nearest')
reminderFont = love.graphics.newFont('fonts/fontin-italic-webfont.ttf', 14*love.window.getPixelScale())
reminderFont:setFilter('nearest', 'nearest')

-- Change default font
love.graphics.setFont(font)

-- Stat window images
local statsShowing = false
local statsTransitioning = false
local portrait

-- Dialog Window stuff
local statPanelLocation = {x = -love.window.toPixels(300), y = 0}
local statTextLocation  = {
  maxY = love.window.toPixels(125),
  minY = love.window.toPixels(125),
  y    = love.window.toPixels(125),
  yadj = function(self, dy)
    self.y = lume.clamp(self.y+dy, self.minY, self.maxY)
  end
}

-- Use to determine whether to plan route/refund or activate nodes
local lastClicked = nil

-- Layers for click handling (lower = higher priority)
local layers = {}

saveData = {}
currentBuild = nil
startingNewBuild = false
changingBuild = false

times = {}
function love.load()
  times.start = love.timer.getTime()

  -- Get tree data. Will download new version if necessary
  -- Tree = Downloader.getLuaTree()
  Tree = require 'passive-skill-tree'
  times.tree = love.timer.getTime()

  -- Read save file
  local savedNodes = {}
  saveData = {}
  if love.filesystem.exists('builds.lua') then
    local saveDataFunc = love.filesystem.load('builds.lua')
    saveData = saveDataFunc()
    currentBuild = saveData.lastOpened

    -- I dunno :(
    if currentBuild == nil then
      activeClass = 1
      ascendancyClass = 1
      currentBuild = 1
      saveData.builds = {[1] = {name='ascendant', nodes=''}}
      saveData = Graph.export(saveData, currentBuild, activeClass, ascendancyClass, {})
    else
      -- Correct lastOpened if in old format
      if type(currentBuild) ~= 'number' then
        currentBuild = Graph.getBuild(currentBuild, saveData)
        saveData.lastOpened = currentBuild
      end

      activeClass, ascendancyClass, savedNodes = Graph.import(saveData)
      if ascendancyClass == 0 then
        ascendancyClass = 1
      end
    end

  else

    -- No save file detected, create fresh one
    activeClass = 1
    ascendancyClass = 1
    currentBuild = 1
    saveData.builds = {[1] = {name='ascendant', nodes=''}}
    saveData.version = VERSION
    saveData = Graph.export(saveData, currentBuild, activeClass, ascendancyClass, {})
  end
  times.save = love.timer.getTime()

  -- Cache node count
  local nodeCount = #Tree.nodes
  local groupCount = 0
  for gid, group in pairs(Tree.groups) do
    groupCount = groupCount + 1
  end
  times.nodeCount = love.timer.getTime()

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
      if not table.icontains(unusedImages, name) then

        local fileName = nil
        for match in filePath:gmatch("[^/%.]+%.[^/%.]+") do
          fileName = match
        end
        fileName = fileName:gsub(".gif", ".png") -- this needs a better solution, probably

        local fileData = love.filesystem.newFileData('assets/'..fileName)
        local imageData = love.image.newImageData(fileData)
        local image = love.graphics.newImage(imageData)

        if name == 'PSSkillFrame' then
          batches[name] = love.graphics.newSpriteBatch(image, nodeCount)
        elseif name == 'PSSkillFrameActive' then
          batches[name] = love.graphics.newSpriteBatch(image, maxActive)
        elseif name == 'PSGroupBackground1' then
          batches[name] = love.graphics.newSpriteBatch(image, groupCount)
        elseif name == 'PSGroupBackground2' then
          batches[name] = love.graphics.newSpriteBatch(image, groupCount)
        elseif name == 'PSGroupBackground3' then
          batches[name] = love.graphics.newSpriteBatch(image, (#Node.Classes + groupCount)*2)
        elseif name == 'PSStartNodeBackgroundInactive' then
          batches[name] = love.graphics.newSpriteBatch(image, #Node.Classes)
        elseif name == 'NotableFrameAllocated' or name == 'NotableFrameUnallocated' then
          batches[name] = love.graphics.newSpriteBatch(image, 395)
        elseif name == 'KeystoneFrameUnallocated' or name == 'KeystoneFrameAllocated' then
          batches[name] = love.graphics.newSpriteBatch(image, 23)
        elseif name == 'JewelFrameUnallocated' or name == 'JewelFrameAllocated' then
          batches[name] = love.graphics.newSpriteBatch(image, 21)
        else
          batches[name] = love.graphics.newSpriteBatch(image, 10)
        end

      end -- end table.icontains
    end -- end if filepath

  end
  times.batches = love.timer.getTime()


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
  times.quads = love.timer.getTime()

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
    if activeName and inactiveName then
      node.activeSheet = activeName
      node.inactiveSheet = inactiveName
      node:setQuad(spriteQuads[activeName][node.icon])
    end

    -- Add to startNode table if it is one
    if node.type == Node.NT_START then
      local spc = node:startPositionClass()
      startNodes[spc] = node.id
    end

    nodes[node.id] = node
  end
  times.nodes = love.timer.getTime()

  -- Straight line connector spritebatches
  local connectorSpriteInactive = love.graphics.newImage('assets/straight-connector-inactive.png')
  local connectorSpriteActive = love.graphics.newImage('assets/straight-connector-active.png')
  local connectorSpriteAdd = love.graphics.newImage('assets/straight-connector-add.png')
  local connectorSpriteRemove = love.graphics.newImage('assets/straight-connector-remove.png')
  connectorSpriteInactive:setFilter('nearest', 'nearest')
  connectorSpriteActive:setFilter('nearest', 'nearest')
  connectorSpriteAdd:setFilter('nearest', 'nearest')
  connectorSpriteRemove:setFilter('nearest', 'nearest')

  local x, y = connectorSpriteInactive:getDimensions()
  batches['connector-inactive'] = love.graphics.newSpriteBatch(connectorSpriteInactive, 15000)
  batches['connector-active'] = love.graphics.newSpriteBatch(connectorSpriteActive, 15000)
  batches['connector-add'] = love.graphics.newSpriteBatch(connectorSpriteAdd, 5000)
  batches['connector-remove'] = love.graphics.newSpriteBatch(connectorSpriteRemove, 5000)
  spriteQuads['connectors'] = {
    love.graphics.newQuad(0, 0, 1, 1, x, y),
    love.graphics.newQuad(0, 1, 1, 1, x, y),
    love.graphics.newQuad(0, 2, 1, 1, x, y),
    love.graphics.newQuad(0, 3, 1, 1, x, y),
  }

  -- Set better starting position
  startnid = startNodes[activeClass]
  startNode = nodes[startnid]
  camera:lookAt(startNode.position.x, startNode.position.y)

  -- Fancy class background batches
  setFancyBackground()

  -- Create ascendancy button and panel
  ascendancyButton = require 'ui.ascendancybutton'
  ascendancyButton:init(Tree, startnid)
  ascendancyPanel = require 'ui.ascendancypanel'
  ascendancyPanel:init(ascendancyButton, batches)

  -- Ascendancy class picker
  ascendancyClassPicker = require 'ui.ascendancyclasspicker'
  ascendancyClassPicker:init()
  times.gui = love.timer.getTime()

  -- Create class picker
  classPicker = require 'ui.classpicker'
  classPicker:init(ascendancyClassPicker)

  -- Create stats panel
  menu = require 'ui.statpanel'
  menu:init(saveData.builds)

  -- Create portrait
  portrait = require 'ui.portrait'
  portrait:init(classPicker:getPortrait(activeClass), menu, classPicker)

  -- Create menu toggle
  menuToggle = require 'ui.menutoggle'
  menuToggle:init(menu)

  -- Search box
  searchBox = require 'ui.searchbox'
  searchBox:init()

  -- Keyboard shortcut legend
  legend = require 'ui.legend'
  legend:init()

  -- Node details dialog
  dialog = require 'ui.dialog'
  dialog:init()

  -- Message box modal
  modal = require 'ui.modal'
  modal:init()

  -- Set up click/touch handler layers
  layers[1] = ascendancyClassPicker
  layers[2] = classPicker
  layers[3] = portrait
  layers[4] = menu
  layers[5] = menuToggle
  layers[6] = searchBox
  layers[7] = modal

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
  times.links = love.timer.getTime()

  -- Create SpriteBatch for background image
  tiledBackground()
  times.background = love.timer.getTime()

  -- Fill up sprite batches
  refillBatches()
  times.refill = love.timer.getTime()

  -- Dimming shader
  dimmer = love.graphics.newShader('shaders/dimmer.hlsl')

  if OS ~= 'iOS' and OS ~= 'Android' then
    -- Mouse cursor
    cursorImage = love.graphics.newImage('assets/pointer2.png')
    cursor = love.mouse.newCursor(cursorImage:getData(), 0, 0)
    love.mouse.setCursor(cursor)
  end
end

function love.update(dt)
  if not love.window.hasFocus() then
    love.timer.sleep(1/30)
  end

  searchBox:update(dt)
  Timer.update(dt)
  -- require('lib.lovebird').update()
end

function love.resize(w, h)
  winWidth, winHeight = w, h
  scaledWidth, scaledHeight = winWidth/camera.scale, winHeight/camera.scale

  -- Regenerate tiled background
  tiledBackground()

  -- Regenerate sprite batches
  refillBatches()

  -- Reset centers on class picker
  ascendancyClassPicker:setCenters()
  classPicker:setCenters()

  menu:resize()
  searchBox:resize()
end

function love.draw()

  love.graphics.clear(255, 255, 255, 255)

  -- Set grayscale shader if classpickers are active
  if classPicker:isActive() or ascendancyClassPicker:isActive() then
    love.graphics.setShader(dimmer)
  end

  -- Draw background image separate from transformations
  clearColor()
  love.graphics.draw(background)

  camera:attach()

  -- Store the translation info, for profit
  local cx, cy = winWidth/(2*camera.scale), winHeight/(2*camera.scale)

  -- Draw fancy class background if applicable
  -- if fancyBackground ~= nil then
  if Node.Classes[activeClass].bg ~= 'none' then
    -- print(activeClass)
    love.graphics.draw(fancyBackground, startNode.position.x, startNode.position.y, 0, 1, 1, Node.Classes[activeClass].bg_pos.x, Node.Classes[activeClass].bg_pos.y)
  end

  -- Draw group backgrounds
  love.graphics.draw(batches['PSGroupBackground1'])
  love.graphics.draw(batches['PSGroupBackground2'])
  love.graphics.draw(batches['PSGroupBackground3'])

  -- Draw line sprite batch
  -- Now includes straight and curved lines for non-ascendancy nodes
  love.graphics.draw(batches['connector-inactive'])
  love.graphics.draw(batches['connector-active'])
  love.graphics.draw(batches['connector-add'])
  love.graphics.draw(batches['connector-remove'])

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
  for _, class in pairs(Node.Classes) do
    love.graphics.draw(batches[class.frame])
  end

  love.graphics.setColor(255, 255, 0, 150)
  for _, nid in ipairs(searchBox:getMatches('regular')) do
    love.graphics.circle('fill', nodes[nid].position.x, nodes[nid].position.y, nodes[nid].radius)
  end
  clearColor()

  -- Ascendancy graph
  if ascendancyButton:isActive() then
    ascendancyPanel:draw()
  end

  -- Ascendancy bubble toggler
  ascendancyButton:draw()

  love.graphics.push()
  local center = {x=0,y=0}
  center.x, center.y = ascendancyPanel:getCenter()
  local ascendancyTreeStart = ascendancyTreeOrigins[Node.getAscendancyClassName()]
  if ascendancyTreeStart then
    love.graphics.translate(center.x-ascendancyTreeStart.position.x, center.y-ascendancyTreeStart.position.y)

    -- Draw ascendancy node connections
    love.graphics.setColor(inactiveConnector)
    love.graphics.setLineWidth(3/camera.scale)
    if ascendancyButton:isActive() then
      for nid, node in pairs(ascendancyNodes) do
        node:drawConnections()
      end
    end
    love.graphics.setLineWidth(1)
    clearColor()

    -- Draw ascendancy nodes
    if ascendancyButton:isActive() then
      for nid,node in pairs(ascendancyNodes) do
        node:immediateDraw()
      end
    end
  end
  love.graphics.pop()

  -- Pop graphics state to draw UI
  love.graphics.setShader()
  camera:detach()

  -- Draw menuToggle.image button in top-left
  if menuToggle:isActive() then
    menuToggle:draw()
  end

  if DEBUG then
    -- print FPS counter in top-left
    local fps, timePerFrame = love.timer.getFPS(), 1000 * love.timer.getAverageDelta()
    local stats = love.graphics.getStats()

    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.print(string.format("Current FPS: %.2f | Average frame time: %.3f ms", fps, timePerFrame), winWidth - love.window.toPixels(400), love.window.toPixels(10))

    love.graphics.print(string.format("Draw calls: %d", stats.drawcalls), winWidth - love.window.toPixels(400), love.window.toPixels(30))

    -- Print character URL below
    love.graphics.print(characterURL, winWidth-love.window.toPixels(400), love.window.toPixels(30))
    clearColor()
  end

  -- Draw UI
  if menu:isActive() then
    menu:draw(character)
    portrait:draw()
  end

  if dialog:isActive() then
    dialog:draw()
  end

  if classPicker:isActive() then
    classPicker:draw()
  end

  if ascendancyClassPicker:isActive() then
    ascendancyClassPicker:draw()
  end

  -- Draw # active nodes
  love.graphics.print(string.format("%i/%i", activeNodes, maxActive), winWidth - love.window.toPixels(100), love.window.toPixels(10))
  love.graphics.print(string.format("%i/%i", activeAscendancy, maxAscendancy), winWidth - love.window.toPixels(100), love.window.toPixels(30))

  if not menu:isActive() then
    searchBox:draw()
  end

  if modal:isActive() then
    modal:draw()
  end

  suit.draw()

  if love.keyboard.isScancodeDown('/') and (love.keyboard.isScancodeDown('rshift') or love.keyboard.isScancodeDown('lshift')) then
    legend:draw()
  end
end

function love.touchmoved(id, x, y, dx, dy, pressure)
  local touches = love.touch.getTouches()
  if #touches == 1 then
    -- potentially trigger hover states on modal buttons
    if modal:isActive() then
      modal:mousemoved(x, y, dx, dy)
    elseif not classPicker:isActive() and not ascendancyClassPicker:isActive() then
      -- scroll text
      if not menu:mousemoved(x, y, dx, dy) then
        -- camera pan
        camera:move(-dx/camera.scale, -dy/camera.scale)
        refillBatches()
      end
    end
  elseif #touches == 2 then
    -- camera zoom
    local t = nil
    for _, tid in ipairs(touches) do
      if tid ~= id then
        t = tid
      end
    end

    local ox, oy = love.touch.getPosition(t)
    local d1 = lume.distance(ox, oy, x, y)
    local d2 = lume.distance(ox, oy, x+dx, y+dy)

    if d1 ~= d2 then
      if d2-d1 > 0 then
        camera:zoomIn()
        refillBatches()
      else
        camera:zoomOut()
        refillBatches()
      end
    end
  elseif #touches == 5 then
    saveData = Graph.export(saveData, currentBuild, activeClass, ascendancyClass, nodes)
    love.event.quit()
  end
end

function love.mousepressed(x, y, button, isTouch)
  dialog:hide()
  clickCoords.x, clickCoords.y = x, y
  menu:mousepressed(x, y)
end

function love.mousereleased(x, y, button, isTouch)
  local clickResult = false
  local i = 1
  local layer
  while clickResult == false and i <= #layers do
    layer = layers[i]
    if layer:isActive() then
      clickResult = layer:click(x, y)
      if clickResult or layer:isExclusive() then return end
    end
    i = i + 1
  end

  -- Try ascendancy tree toggle button
  if ascendancyButton:click(x, y) then return end

  -- Try ascendancy nodes
  if not clickResult and ascendancyButton:isActive() then
    for nid, node in pairs(ascendancyNodes) do
      if node:click(x, y) then
        toggleNodes(nid, isTouch)
        return
      end
    end
  end

  -- Try regular nodes
  if not clickResult and (not ascendancyButton:isActive() or not ascendancyPanel:containsMouse(x, y)) then
    for nid, node in pairs(visibleNodes) do
      if node:click(x, y) then
        toggleNodes(nid, isTouch)
        return
      end
    end
  end

  addTrail = {}
  removeTrail = {}
  lastClicked = nil
end

function love.mousemoved(x, y, dx, dy, isTouch)
  if isTouch then return end

  -- Bail if modal is active
  if modal:isActive() then
    return modal:mousemoved(x, y, dx, dy)
  end

  -- Bail if either classpicker is active
  if classPicker:isActive() or ascendancyClassPicker:isActive() then return end

  if love.mouse.isDown(1) then
    -- Check if we are scrolling stat text
    if not menu:mousemoved(x, y, dx, dy) then
      -- Otherwise pan camera
      camera:move(-dx/camera.scale, -dy/camera.scale)
      refillBatches()
    end
    return
  end

  if not isTouch then
    -- If mouse not down, see if we are hovering over a node
    local mouseInAscendancyPanel = ascendancyButton:isActive() and ascendancyPanel:containsMouse(x, y)
    local mouseInMenu = menu:isActive() and menu:containsMouse(x, y)
    if not mouseInMenu then
      local hovered = nil
      if ascendancyButton:isActive() then
        if ascendancyButton:isActive() then
          hovered = checkIfAscendancyNodeHovered(x, y)
        end
      end
      if hovered == nil and not mouseInAscendancyPanel and not isTouch then
        hovered = checkIfNodeHovered(x, y)
      end
      if hovered == nil then
        lastClicked = nil
        addTrail = {}
        removeTrail = {}
        dialog:hide()
      end
    end
  end
end

function love.wheelmoved(x, y)
  if menu:isActive() and menu:isMouseInStatSection() then
    menu:scrollContent(y*love.window.toPixels(5))
  else
    if y > 0 then
      camera:zoomIn()
      refillBatches()
    elseif y < 0 then
      camera:zoomOut()
      refillBatches()
    end
  end
end

function love.keypressed(key, scancode, isRepeat)
  suit.keypressed(key)
  if key == 'up' then
    camera:zoomIn()
    refillBatches()
  elseif key == 'down' then
    camera:zoomOut()
    refillBatches()
  elseif key == 'f1' then
    DEBUG = not DEBUG
  elseif scancode == '[' then
    if menu:isActive() then
      menu.innerContent = 'stats'
    end
  elseif scancode == ']' then
    if menu:isActive() then
      menu.innerContent = 'builds'
    end
  elseif scancode == '`' then
    if not ascendancyClassPicker:isActive() and not classPicker:isActive() and not menu:isTransitioning() then
      menu:toggle()
    end
  elseif key == 'escape' then
    if modal:isActive() then
      modal:setInactive()
    elseif menu:isActive() then
      menu:toggle()
    elseif searchBox:isActive() then
      searchBox:hide()
    else
      modal:setTitle('Close PoE Planner?')
      modal:setActive(function()
        saveData = Graph.export(saveData, currentBuild, activeClass, ascendancyClass, nodes)
        love.event.quit()
      end)
    end
  elseif scancode == 'pagedown' then
    if menu:isActive() then
      menu:scrollContent(-love.window.toPixels(125))
    end
  elseif scancode == 'pageup' then
    if menu:isActive() then
      menu:scrollContent(love.window.toPixels(125))
    end
  elseif scancode == 'backspace' and searchBox:isFocused() then
    searchBox:backspace()
  elseif scancode == 'return' then
    if modal:isActive() then
      modal:confirm()
    end
  elseif scancode == 'f' then
    if love.keyboard.isScancodeDown('lctrl') or love.keyboard.isScancodeDown('rctrl') then
      if searchBox:isActive() then
        searchBox:hide()
      else
        searchBox:show()
      end
    end
  elseif scancode == '/' then
    if not love.keyboard.isScancodeDown('lshift') and not love.keyboard.isScancodeDown('rshift') then
      searchBox:show()
    end
  else
    if DEBUG then
      print('scancode: '..scancode)
    end
  end
end

function love.textinput(t)
  if searchBox:isFocused() then
    searchBox:textinput(t)
  end
  suit.textinput(t)
end

function checkIfNodeHovered(x, y)
  local hovered = nil
  for nid, node in pairs(visibleNodes) do
    if not node:isMastery() and not node:isStart() then
      local wx, wy = camera:cameraCoords(node.position.x, node.position.y)
      local dx, dy = wx - x, wy - y
      local r = Node.Radii[node.type] * camera.scale
      if dx * dx + dy * dy <= r * r then
        hovered = nid
        dialog:show(nodes[nid])
      end
    end
  end

  -- Do route planning on hover, since desktop OS
  -- doesn't use the two-click method of activating nodes
  if hovered == nil then
    addTrail = {}
    removeTrail = {}
    dialog:hide()
    refillLineBatch()
    lastClicked = nil
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
    refillLineBatch()
  end

  return hovered
end

function checkIfAscendancyNodeHovered(x, y, button, isTouch)
  local hovered = nil

  local ascendancyTreeStart = ascendancyTreeOrigins[Node.getAscendancyClassName()]
  if ascendancyTreeStart == nil then return nil end
  local center = {}
  center.x, center.y = ascendancyPanel:getCenter()

  local offset = {}
  offset.x, offset.y = center.x-ascendancyTreeStart.position.x, center.y-ascendancyTreeStart.position.y

  for nid, node in pairs(ascendancyNodes) do
    if not node.isAscendancyStart then
      local pos = {
        x = node.position.x + offset.x,
        y = node.position.y + offset.y,
      }
      local wx, wy = camera:cameraCoords(pos.x, pos.y)
      local dx, dy = wx - x, wy - y
      local r = Node.Radii[node.type] * camera.scale
      if dx * dx + dy * dy <= r * r then
        if not node.isAscendancyStart then
          hovered = nid
          dialog:show(nodes[nid], wx, wy)
        end
      end
    end
  end

  if hovered == nil then
    lastClicked = nil
    addTrail = {}
    removeTrail = {}
    dialog:hide()
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

  return hovered
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
  local w, h = love.graphics.getDimensions()
  w, h = w/camera.scale, h/camera.scale

  local tx, ty = winWidth/(2*camera.scale)-camera.x, winHeight/(2*camera.scale)-camera.y
  -- local tx, ty = camera:cameraCoords(winWidth/2, winHeight/2)
  visibleNodes = {}
  visibleGroups = {}
  ascendancyNodes = {}
  for nid, node in pairs(nodes) do
    if node:isVisible(tx, ty, w, h) then
      visibleNodes[node.id] = node
      if visibleGroups[node.gid] == nil then
        visibleGroups[node.gid] = groups[node.gid]
      end
    end

    -- Fill ascendancy node table
    if node.type > 6 and node.ascendancyName == Node.getAscendancyClassName() then
      -- ascendancyNodes[#ascendancyNodes] = node
      ascendancyNodes[nid] = node
      if node.isAscendancyStart then
        ascendancyTreeOrigins[node.ascendancyName] = node
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

-- Only refill the straight line connector spritebatch
-- (for when we hover a node and need to highlight certain connections)
function refillLineBatch()
  batches['connector-inactive']:clear()
  batches['connector-active']:clear()
  batches['connector-add']:clear()
  batches['connector-remove']:clear()
  for nid, node in pairs(visibleNodes) do
    node:drawBatchConnections()
  end
end

function dist(v1, v2)
  return math.sqrt((v2.x - v1.x)*(v2.x - v1.x) + (v2.y - v1.y)*(v2.y - v1.y))
end

function activateNode(nid)
  nodes[nid].active = true

  -- Add node stats to character stats
  local node = nodes[nid]
  parseDescriptions(node, add)
  menu:updateStatText(character)
  if not node.isAscendancyStart then
    if node:isAscendancy() then
      if not node.isMultipleChoice then
        activeAscendancy = activeAscendancy + 1
      end
    else
      activeNodes = activeNodes + 1
    end
  end

  -- Some nodes grant passive skill points
  maxActive = maxActive + node.passivePointsGranted
end

function deactivateNode(nid)
  nodes[nid].active = false

  -- Remove node stats from character stats
  local node = nodes[nid]
  parseDescriptions(node, subtract)
  menu:updateStatText(character)
  if not node.isAscendancyStart then
    if node:isAscendancy() then
      if not node.isMultipleChoice then
        activeAscendancy = activeAscendancy - 1
      end
    else
      activeNodes = activeNodes - 1
    end
  end

  -- Some nodes grant passive skill points
  maxActive = maxActive - node.passivePointsGranted
end

function parseDescriptions(node, op)
  local found = {}
  if node.type == Node.NT_KEYSTONE then
    if op == subtract then
      character.keystones[node.id] = nil
    else
      character.keystones[node.id] = node.descriptions
    end
  else
    for i, desc in ipairs(node.descriptions) do
      for n,s in desc:gmatch("+?(%d+) (%a[%s%a]*)") do
        found[#found+1] = s
        if DEBUG then
          print('here')
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

      if #found ~= i then
        for p,n,s in desc:gmatch("([%a%s,]*)(%d+%.?%d*)(%%? %a[%s%a]*)") do
          if DEBUG then
            print('p: '..p, 's: '..s, 'n: '..n)
            print(desc)
          end

          local label = p..s

          found[#found+1] = label
          local v = character.stats[label] or 0

          v = op(v, n)
          if v == 0 then
            v = nil
          end

          character.stats[label] = v
        end
      end

      if #found ~= i then
        if DEBUG then
          print('Still not found :(')
          print(desc)
        end
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
  if DEBUG then
    print('Subtracting '..n1..' from '..n2)
  end
  return n1-n2
end

function changeActiveClass(class, aclass)
  -- Don't do anything if not new class
  local isClassChange = not startingNewBuild and not changingBuild
  if isClassChange and class == activeClass and aclass == ascendancyClass then return false end

  -- Provide confirmation dialog; no need to confirm when starting a new build
  if isClassChange then
    modal:setTitle('Change class and reset the skill tree?')
    modal:setActive(function()
      doChangeActiveClass(class, aclass)
    end)
  else
    doChangeActiveClass(class, aclass)
  end
end

function doChangeActiveClass(class, aclass)
  -- -- Don't do anything if not new class
  local isClassChange = not startingNewBuild and not changingBuild
  if isClassChange and class == activeClass and aclass == ascendancyClass then return false end

  addTrail    = {}
  removeTrail = {}

  -- Only reset tree if main class changed
  if activeClass ~= class or startingNewBuild or changingBuild then
    activeClass = class
    startnid = startNodes[activeClass]
    startNode = nodes[startnid]
    portrait:updatePortrait(classPicker:getPortrait(activeClass))
    setFancyBackground()

    for nid, node in pairs(nodes) do
      if node.active then
        deactivateNode(nid)
      end
    end

    nodes[startnid].active = true
    camera:lookAt(startNode.position.x, startNode.position.y)
    ascendancyButton:changeStart(startnid)

    activeNodes = 0

    character = {
      str       = 0,
      int       = 0,
      dex       = 0,
      stats     = {},
      keystones = {},
      keystoneCount = 0,
    }
  end

  -- Probably don't need this check, but whatever
  if ascendancyClass ~= aclass or startingNewBuild or changingBuild then
    ascendancyClass = aclass
    for nid, node in pairs(ascendancyNodes) do
      if node.active then
        deactivateNode(nid)
      end
    end
    activeAscendancy = 0
  end

  -- If we were starting a new build, give it a name and do an export
  if startingNewBuild then
    currentBuild = #saveData.builds+1
    saveData.builds[currentBuild] = {name = getUniqueBuildName(class, aclass)}
    saveData = Graph.export(saveData, currentBuild, class, aclass, nodes)
    startingNewBuild = false
  end

  -- Save changes if performing a regular class change
  if isClassChange then
    saveData = Graph.export(saveData, currentBuild, activeClass, ascendancyClass, nodes)
  end

  -- Always refill the batches
  refillBatches()
end

function changeActiveBuild(buildId)
  currentBuild = buildId
  activeClass, ascendancyClass, savedNodes = Graph.parse(saveData.builds[buildId].nodes)
  changingBuild = true
  doChangeActiveClass(activeClass, ascendancyClass)
  for _, nid in ipairs(savedNodes) do
    activateNode(nid)
  end
  changingBuild = false
  refillBatches()
end

function deleteBuild(buildId)
  if #saveData.builds == 1 then return end
  table.remove(saveData.builds, buildId)
  changeActiveBuild(1)
end

function startNewBuild()
  -- Save current build
  saveData = Graph.export(saveData, currentBuild, activeClass, ascendancyClass, nodes)
  startingNewBuild = true
  classPicker:activate()
end

function toggleNodes(nid, isTouch)
  local clicked = nodes[nid]
  if clicked.active then
    addTrail = {}
    removeTrail = Graph.planRefund(clicked.id)
    refillLineBatch()
  else
    removeTrail = {}
    addTrail = Graph.planShortestRoute(clicked.id)
    refillLineBatch()
  end

  if not isTouch or lastClicked == nid then
    -- Add nodes in addTrail
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
    saveData = Graph.export(saveData, currentBuild, activeClass, ascendancyClass, nodes)
    refillBatches()
    lastClicked = nil
  else
    lastClicked = nid
    dialog:show(nodes[nid])
  end
end

function getUniqueBuildName(class, aclass)
  local ogname = Node.Classes[class].ascendancies[aclass]
  local name = ogname
  local index = 2

  while saveData.builds[name] ~= nil do
    name = ogname..tostring(index)
    index = index+1
  end

  return name
end

function setFancyBackground()
  if Node.Classes[activeClass].bg ~= 'none' then
    local name = Node.Classes[activeClass].bg
    fancyBackground = love.graphics.newImage('assets/'..name..'.png')
  else
    fancyBackground = nil
  end
end
