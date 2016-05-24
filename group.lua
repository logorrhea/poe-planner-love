local scaleFix = 2.5

Group = {}
Group .__index = Group

function Group.create(id, data)
  local group = {id = id}
  setmetatable(group, Group)

  group.nodes = data.n

  group.position = {
    x = data.x/scaleFix,
    y = data.y/scaleFix
  }

  group.ocpOrb = data.oo

  return group
end

function Group:draw()
  local spriteName = self:getSpriteName()
  if spriteName ~= nil then
    local sprite = batches[spriteName]:getTexture()
    local w, h = sprite:getDimensions()
    if self.type == 4 then
      batches['PSGroupBackground3']:add(self.position.x - w/2, self.position.y - h)
      batches['PSGroupBackground3']:add(self.position.x + w/2, self.position.y + h, math.pi)
    else
      batches[spriteName]:add(self.position.x - w/2, self.position.y - h/2)
    end
  end
end

function Group:getSpriteName()
  if self.type == 1 and #self.nodes > 1 then
    return 'PSGroupBackground2'
  elseif self.type == 2 then
    return 'PSGroupBackground1'
  elseif self.type == 3 then
    return 'PSGroupBackground2'
  elseif self.type == 4 then
    return 'PSGroupBackground3'
  else
    return nil
  end
end

return Group
