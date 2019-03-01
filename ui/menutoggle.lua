local toggle = {
  x = 10,
  y = 20,
  name = 'Menu Toggle',
  status = 'active',
}

function toggle:init(target)
  self.target = target
  self.icon = {
    id = 'search-menu',
    default = love.graphics.newImage('icons/menu_default.png'),
    hovered = love.graphics.newImage('icons/menu_hovered.png'),
    active = love.graphics.newImage('icons/menu_active.png'),
  }
end

function toggle:click(mx, my)
  return false
  -- stub
end

function toggle:draw()
  if not self.target:isActive() then
    local x, y = love.window.toPixels(self.x, self.y)
    local w, h = self.icon.default:getDimensions()
    if suit.ImageButton(self.icon.default, {hovered = self.icon.hovered, active = self.icon.active}, x, y).hit then
      self.target:toggle()
    end
  end
end

function toggle:isActive()
  return self.status == 'active'
end

function toggle:isExclusive()
  return false
end

function toggle:toggle()
  if self.state == 'active' then
    self.state = 'inactive'
  else
    self.state = 'active'
  end
end

function toggle:activate()
  self.state = 'active'
end

function toggle:deactivate()
  self.state = 'inactive'
end


return toggle
