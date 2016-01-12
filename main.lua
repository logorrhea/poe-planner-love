------------------------------
-- Move to a new file later --
local SkillsPerOrbit = {1, 6, 12, 12, 12}
local OrbitRadii = {0, 82, 162, 335, 493}
local NodeRadii = {
    standard = 51,
    keystone = 109,
    notable = 70,
    mastery = 107,
    classStart = 200
}

function arc(node)
    return 2 * math.pi * node.orbitIndex / SkillsPerOrbit[node.orbit]
end

function nodePosition(node)
  local x = 0
  local y = 0

  if node.group ~= nil then
    local r = OrbitRadii[node.orbit]
    local a = arc(node)

    x = node.group.position.x - r * math.sin(-a)
    y = node.group.position.y - r * math.cos(-a)
  end

  return {x = x, y = y}
end
------------------------------

function love.load()
  json = require('vendor/dkjson')

  -- Read data file
  file, err = love.filesystem.newFile('data/json/skillTree.json')
  file:open('r')
  dataString = file:read()
  file:close()

  -- Parse json data into table
  Tree, err = json.decode(dataString)

  -- for k,v in pairs(data) do
  --   print(k)
  --   if k == "nodes" then
  --     for k2,v2 in pairs(v) do
  --       print("\t"..k2)
  --     end
  --   end
  -- end

end

function love.update(dt)
end

function love.draw()
  love.graphics.setColor(255, 255, 255)
  for nid, node in pairs(Tree.nodes) do
    local pos = nodePosition(node)
    love.graphics.circle('fill', pos.x, pos.y, 10, 10)
  end

   love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)
end
