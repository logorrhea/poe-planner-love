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

return Group
