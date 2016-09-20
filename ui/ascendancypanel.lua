local lume = require 'vendor.lume.lume'
local panel = {}
local images = {}

-- local images = {
--   -- Scion
--   ascendant = 'ClassesAscendant',

--   -- Shadow
--   assassin = 'ClassesAssassin',
--   saboteur = 'ClassesSaboteur',
--   trickster = 'ClassesTrickster',

--   -- Marauder
--   berserker = 'ClassesBerserker',
--   juggernaut = 'ClassesJuggernaut',
--   chieftain = 'ClassesChieftain',

--   -- Ranger
--   deadeye = 'ClassesDeadeye',
--   pathfinder = 'ClassesPathfinder',
--   raider = 'ClassesRaider',

--   -- Witch
--   elementalist = 'ClassesElementalist',
--   necromancer = 'ClassesNecromancer',
--   occultist = 'ClassesOccultist',

--   -- Templar
--   guardian = 'ClassesGuardian',
--   hierophant = 'ClassesHierophant',
--   inquisitor = 'ClassesInquisitor',

--   -- Duelist
--   champion = 'ClassesChampion',
--   gladiator = 'ClassesGladiator',
--   slayer = 'ClassesSlayer',
-- }

function panel:init(batches)
  for _,class in ipairs(Node.AscendancyClasses) do
    local imageName = 'Classes'..string.upper(class:sub(1,1))..class:sub(2,-1)
    images[class] = batches[imageName]:getTexture()
    print(class, imageName, images[class]:getDimensions())
  end
end

-- Draw panel according to ascendancy button location
function panel:draw(button)
  local x, y = button:getPosition()
  love.graphics.draw(images['ascendant'], x, y)
end

return panel
