local suit = require 'lib.suit'
local strings = require 'lib.strings'

local panel = {
  x = 0,
  y = -winHeight,
  status = 'inactive',
  innerContent = 'builds',
  builds = {},
  buildName = love.graphics.newText(headerFont, ''),
  className = love.graphics.newText(font, ''),
  mouseDown = nil
}

local divider  = love.graphics.newImage('assets/LineConnectorNormal.png')
local leftIcon = love.graphics.newImage('assets/left.png')
local charStatLabels = love.graphics.newText(headerFont, 'Str:\nInt:\nDex:')
local charStatText = love.graphics.newText(headerFont, '0\n0\n0')
local generalStatLabels = love.graphics.newText(font, '')
local generalStatText = love.graphics.newText(font, '')
local keystoneLabels = {}
local keystoneDescriptions = {}

local buttonText = love.graphics.newText(headerFont, '')

local plusbutton = love.graphics.newImage('assets/cross100x100.png')

function panel:init(builds)
  self.statText = {
    maxY = love.window.toPixels(125),
    minY = love.window.toPixels(125),
    y    = love.window.toPixels(125),
    yadj = function(self, dy)
      self.y = lume.clamp(self.y+dy, self.minY, self.maxY)
    end
  }

  self.buildPanel = {
    y = love.window.toPixels(125),
    maxY = love.window.toPixels(125),
    minY = love.window.toPixels(125),
    lastCheck = nil, -- last # of builds for which the height was checked
    yadj = function(self, dy)
      self.y = lume.clamp(self.y+dy, self.minY, self.maxY)
    end
  }

  self:resize()
  self.editing = nil
  self.builds = builds
  self:initIcons()
end

function panel:resize()
  local w, h = love.graphics.getDimensions()
  local minWidth, maxWidth = love.window.toPixels(300), love.window.toPixels(400)

  if h > w then
    self.width = math.min(math.max(w, minWidth), maxWidth)
  else
    self.width = math.min(math.max(w/3, love.window.toPixels(300)), maxWidth)
  end

  self.buttonWidth = self.width / 3
  self.buttonHeight = love.window.toPixels(50)
end

function panel:toggle()
  if self.status == 'inactive' then
    self:show()
  elseif self.status == 'active' then
    self:hide()
  end
end

function panel:show()
  self.status = 'opening'
  local duration = 0.5
  Timer.tween(duration, self, {y = 0}, 'out-back')
  Timer.after(duration, function() panel.status = 'active' end)
end

function panel:hide()
  self.status = 'closing'
  local duration = 0.5
  Timer.tween(duration, self, {y = -winHeight}, 'in-back')
  Timer.after(duration, function()
    panel.status = 'inactive'
  end)
end

function panel:isTransitioning()
  return self.status == 'closing' or self.status == 'opening'
end

function panel:isActive()
  return self.status ~= 'inactive'
end

function panel:isExclusive()
  return false
end

function panel:draw(character)
  local five = love.window.toPixels(5)

  love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
  love.graphics.rectangle('fill', self.x, self.y, self.width, winHeight)

  -- Stat panel outline
  clearColor()
  love.graphics.rectangle('line', self.x, self.y, self.width, winHeight)

  -- Character stats
  love.graphics.draw(charStatLabels, self.x+love.window.toPixels(155), self.y+love.window.toPixels(18))
  love.graphics.draw(charStatText, self.x+love.window.toPixels(155)+charStatLabels:getWidth()*2, self.y+love.window.toPixels(18))

  -- Draw divider
  local w, h = divider:getDimensions()
  local sx = (self.width - five*2)/w
  love.graphics.draw(divider, self.x+five, self.y+love.window.toPixels(115), 0, sx, 1.0)

  -- Set stat panel scissor
  local min_y = self.y + love.window.toPixels(125)
  local max_y = winHeight - love.window.toPixels(leftIcon:getWidth() + 20)
  if DEBUG then
    love.graphics.setColor(1, 0, 0, 0.4)
    love.graphics.rectangle('fill', self.x+five, min_y, love.window.toPixels(self.width)-2*five, max_y-min_y)
    clearColor()
  end
  love.graphics.setScissor(self.x+five, min_y, love.window.toPixels(self.width)-2*five, max_y-min_y)

  if self.innerContent == 'stats' then
    -- Draw keystone node text
    local y = self.statText.y
    for i=1,character.keystoneCount do
      love.graphics.draw(keystoneLabels[i], self.x+five, self.y+y)
      y = y + keystoneLabels[i]:getHeight()
      love.graphics.draw(keystoneDescriptions[i], self.x+five, self.y+y)
      y = y + keystoneDescriptions[i]:getHeight()
    end

    if character.keystoneCount > 0 then
      y = y + headerFont:getHeight()
    end

    -- Draw general stats
    love.graphics.draw(generalStatLabels, self.x+five, self.y+y)
    love.graphics.draw(generalStatText, self.x+five+generalStatLabels:getWidth()*1.5, self.y+y)
  elseif self.innerContent == 'builds' then
    -- Show builds listing
    local y = self.buildPanel.y + five
    love.graphics.setFont(font)
    clearColor()
    for i, build in ipairs(self.builds) do
      -- gotta check this manually, cause the scissor doesn't work with suit
      if y >= min_y and y <= max_y then
        -- Build title and class strings
        local c, a = Graph.getClassData(build.nodes)
        self.buildName:set(build.name)
        self.className:set(strings.capitalize(Node.Classes[c].ascendancies[a]))

        -- Draw build title
        if self.editing ~= nil and self.editing.index == i then
          local input = suit.Input(self.editing, {id = 'edit-build-name', font=headerFont}, five, self.y+y)
        else
          if suit.Label(build.name, {font=headerFont}, five, self.y+y).hit then
            changeActiveBuild(i)
          end
        end

        -- Draw edit icon
        self.icons.edit.options.id = 'edit-button-'..tostring(i)
        if suit.ImageButton(self.icons.edit.default, self.icons.edit.options, self.width - love.window.toPixels(75), self.y+y).hit then
          if self.editing == nil then
            if DEBUG then
              print("enable editing for "..i)
            end
            self.editing = {
              index = i,
              text = build.name
            }
          else
            self.builds[i].name = self.editing.text
            self.editing = nil
            -- can we do this from here? probably need to rethink this whole graph.export function
            -- i think we need a whole savedata class that keeps track of all this bullshit
            saveData = Graph.export(saveData, currentBuild, activeClass, ascendancyClass, nodes)
          end
        end

        -- Draw delete icon
        if #self.builds > 1 then
          self.icons.delete.options.id = 'delete-button-'..tostring(i)
          if suit.ImageButton(self.icons.delete.default, self.icons.delete.options, self.width - love.window.toPixels(37), self.y+y).hit then
            modal:setTitle('Delete Build '..build.name..'?')
            modal:setActive(function()
              deleteBuild(i)
            end)
          end
        end
      end

      -- Draw class name
      y = y + self.buildName:getHeight()
      love.graphics.draw(self.className, five, self.y+y)
      y = y + self.className:getHeight()
    end

    -- Update height of build panel if necessary
    if self.buildPanel.lastCheck == nil or self.buildPanel.lastCheck ~= #self.builds then
      self.buildPanel.lastCheck = #self.builds
      local diff = (winHeight - love.window.toPixels(125)) - y
      if diff < 0 then
        self.buildPanel.minY = diff
      end
    end

    -- Show new build button
    local scale = 0.5*love.window.getDPIScale()
    if suit.ImageButton(plusbutton, {}, five, self.y+y, 0, scale, scale).hit then
      startNewBuild()
      self:hide()
    end
  end

  -- Reset scissor
  love.graphics.setScissor()

  -- Draw left icon (click to close stats drawer)
  local w, h = leftIcon:getDimensions()
  local sw, sh = love.window.toPixels(w, h)

  -- Draw toggle icon
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(leftIcon,
                     self.x+self.width/2,
                     self.y+winHeight-sw/2-love.window.toPixels(10),
                     math.pi/2,
                     love.window.getDPIScale(),
                     love.window.getDPIScale(),
                     w/2,
                     h/2)


  -- Draw stat button
  local padding = love.window.toPixels(5)
  local y = self.y + winHeight - padding - self.buttonHeight
  love.graphics.rectangle('line', padding, y, self.buttonWidth, self.buttonHeight)
  if self.statsButtonIsHovered then
    love.graphics.setColor(1, 0, 0, 0.4)
    love.graphics.rectangle('fill', padding, y, self.buttonWidth, self.buttonHeight)
    clearColor()
  end

  -- Draw builds button
  love.graphics.rectangle('line', self.width - padding - self.buttonWidth, y, self.buttonWidth, self.buttonHeight)
  if self.buildsButtonIsHovered then
    love.graphics.setColor(1, 0, 0, 0.4)
    love.graphics.rectangle('fill', self.width - padding - self.buttonWidth, y, self.buttonWidth, self.buttonHeight)
    clearColor()
  end

  -- Stats button text
  buttonText:set('Stats')
  local textWidth, textHeight = buttonText:getWidth(), buttonText:getHeight()
  local y = y + (self.buttonHeight - textHeight)/2
  love.graphics.draw(buttonText, padding + (self.buttonWidth - textWidth)/2, y)

  -- Builds button text
  buttonText:set('Builds')
  textWidth, textHeight = buttonText:getWidth(), buttonText:getHeight()
  love.graphics.draw(buttonText, self.width - padding - (self.buttonWidth + textWidth)/2, y)

end

function panel:updateStatText(character)
  -- Update base stats
  charStatText:set(string.format('%i\n%i\n%i', character.str, character.int, character.dex))

  -- Update general stats
  local _labels = {}
  local _stats = {}
  local text
  for desc, n in pairs(character.stats) do
    if n > 0 then
      local width, wrapped = font:getWrap(desc, love.window.toPixels(270))
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
  local height = generalStatText:getHeight()

  -- Update Keystone Text
  local i = 1
  for nid, descriptions in pairs(character.keystones) do
    -- Recycle labels if possible
    local label = keystoneLabels[i] or love.graphics.newText(headerFont, '')
    local desc = keystoneDescriptions[i] or love.graphics.newText(font, '')

    local _desc = {}
    for _, line in ipairs(descriptions) do
      local width, wrapped = font:getWrap(line, love.window.toPixels(270))
      for _, wrappedLine in ipairs(wrapped) do
        _desc[#_desc+1] = wrappedLine
      end
    end

    label:set(nodes[nid].name)
    desc:set(table.concat(_desc, '\n'))
    keystoneLabels[i] = label
    keystoneDescriptions[i] = desc
    height = height + label:getHeight() + desc:getHeight()
    i = i + 1
  end

  character.keystoneCount = i-1
  if i ~= 0 then
    height = height + headerFont:getHeight()
  end

  local diff = (winHeight - love.window.toPixels(125)) - height
  if diff < 0 then
    self.statText.minY = diff
  end
end

function panel:mousepressed(x, y)
  self.mouseOnToggle = false
  self.mouseDown = nil
  self.scrolling = false

  if self:isMouseOverToggleButton(x, y) then
    self.mouseOnToggle = true
    return true
  elseif self:isMouseOverStatButton(x, y) then
    self.mouseDown = 'button.stats'
    return true
  elseif self:isMouseOverBuildsButton(x, y) then
    self.mouseDown = 'button.builds'
    return true
  else
    if self:isMouseInStatSection(x, y) then
      self.scrolling = true
      return true
    end
  end

  return false
end

function panel:mousemoved(x, y, dx, dy)
  if not self:isActive() then
    return false
  end

  if love.mouse.isDown(1) and self.scrolling then
    self:scrollContent(dy)
    return true
  end

  -- Check if mouse is over either stats or builds button
  if self:isMouseOverBuildsButton(x, y) or self:isMouseOverStatButton(x, y) then return true end

  -- Otherwise disable related flags
  -- print('disabling stat and build button hover flags')
  self.statsButtonIsHovered = false
  self.buildsButtonIsHovered = false

  if self.mouseOnToggle then
    return true
  end

  return false
end

function panel:containsMouse(x, y)
  if x == nil or y == nil then
    x, y = love.mouse.getPosition()
  end
  return self:isActive() and x < self.width
end

function panel:isMouseInStatSection(x, y)
  if x == nil or y == nil then
    x, y = love.mouse.getPosition()
  end
  return x < self.width and y > love.window.toPixels(125)
end

function panel:isMouseOverToggleButton(x, y)
  love.graphics.draw(leftIcon, self.x+love.window.toPixels(295)-love.window.toPixels(w), (winHeight-love.window.toPixels(h))/2, 0, love.window.getDPIScale(), love.window.getDPIScale())
  local w, h = leftIcon:getDimensions()
  w, h = love.window.toPixels(w), love.window.toPixels(h)

  local x1 = (self.width-h)/2

  local x1 = (self.width-h)/2
  local x2 = (self.width+h)/2
  local y2 = self.y+winHeight-love.window.toPixels(10)
  local y1 = y2-w

  return x > x1 and x < x2 and y > y1 and y < y2
end

function panel:isMouseOverStatButton(x, y)
  local padding = love.window.toPixels(5)
  local bx = padding
  local by = self.y + winHeight - padding - self.buttonHeight

  if x > bx and x < bx + self.buttonWidth and y > by and y < by + self.buttonHeight then
    self.statsButtonIsHovered = true
    return true
  end

  return false
end

function panel:isMouseOverBuildsButton(x, y)
  local padding = love.window.toPixels(5)
  local bx = self.width - padding - self.buttonWidth
  local by = self.y + winHeight - padding - self.buttonHeight

  if x > bx and x < bx + self.buttonWidth and y > by and y < by + self.buttonHeight then
    self.buildsButtonIsHovered = true
    return true
  end

  return false
end

function panel:scrollContent(dy)
  if self.innerContent == 'stats' then
    self.statText:yadj(dy)
  else
    self.buildPanel:yadj(dy)
  end
end

function panel:click(x, y)
  -- Stop scrolling
  self.scrolling = false

  -- Check if menu close button was pushed
  if self.mouseOnToggle and self:isMouseOverToggleButton(x, y) then
    self:toggle()
    return true
  end

  -- Check if mouse is over either stats or builds button
  if self.mouseDown == 'button.stats' and self:isMouseOverStatButton(x, y) then
    self.innerContent = 'stats'
    return true
  end
  if self.mouseDown == 'button.builds' and self:isMouseOverBuildsButton(x, y) then
    self.innerContent = 'builds'
    return true
  end

  -- Need to return t/f for constintency with other GUI elements
  -- Lets the GUI layer processor know whether or not to continue checking elements
  self.mouseAttached = false
  return self:containsMouse(x, y)
end

function panel:setBuilds(builds)
  self.builds = builds
end

function panel:initIcons()
  self.icons = {}
  self.icons.edit = {
    default = love.graphics.newImage('icons/edit_default.png'),
    options = {
      id = 'edit-button',
      hovered = love.graphics.newImage('icons/edit_hovered.png'),
      active = love.graphics.newImage('icons/edit_active.png'),
    }
  }
  self.icons.delete = {
    default = love.graphics.newImage('icons/delete_default.png'),
    options = {
      id = 'delete-button',
      hovered = love.graphics.newImage('icons/delete_hovered.png'),
      active = love.graphics.newImage('icons/delete_active.png'),
    }
  }
end

return panel
