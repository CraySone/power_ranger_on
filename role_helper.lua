local api = require("api")

--[[
==========================================================================
                           ROLE HELPER MODULE
==========================================================================
Provides role detection (Tank/Healer/DPS) based on class names
Adapted from role_identifier addon
==========================================================================
]]

local RoleHelper = {}

-- All known classes in ArcheAge Classic
local classes = {
    ['056'] = "Destroyer",
    ['023'] = "Abolisher",
    ['679'] = "Animist",
    ['135'] = "Arcane Hunter",
    ['136'] = "Arcanist",
    ['125'] = "Archon",
    ['039'] = "Argent",
    ['179'] = "Assassin",
    ['345'] = "Astral Ranger",
    ['189'] = "Athame",
    ['235'] = "Bastion",
    ['246'] = "Battlemage",
    ['049'] = "Blackguard",
    ['078'] = "Blade Dancer",
    ['027'] = "Blighter",
    ['459'] = "Blood Arrow",
    ['034'] = "Bloodreaver",
    ['058'] = "Bloodskald",
    ['089'] = "Bloodthrall",
    ['035'] = "Bonestalker",
    ['369'] = "Boneweaver",
    ['126'] = "Cabalist",
    ['289'] = "Caretaker",
    ['389'] = "Cleric",
    ['789'] = "Confessor",
    ['026'] = "Crusader",
    ['469'] = "Cultist",
    ['167'] = "Daggerspell",
    ['248'] = "Dark Aegis",
    ['037'] = "Darkrunner",
    ['028'] = "Dawncaller",
    ['279'] = "Death Warden",
    ['124'] = "Defiler",
    ['146'] = "Demonologist",
    ['019'] = "Dervish",
    ['018'] = "Dirgeweaver",
    ['479'] = "Doombringer",
    ['024'] = "Doomlord",
    ['045'] = "Dreadbow",
    ['015'] = "Dreadhunter",
    ['247'] = "Dreadnaught",
    ['245'] = "Dreadstone",
    ['123'] = "Dreambreaker",
    ['259'] = "Druid",
    ['268'] = "Earthsinger",
    ['578'] = "Ebonsong",
    ['349'] = "Edgewalker",
    ['137'] = "Eidolon",
    ['138'] = "Enchantrix",
    ['036'] = "Enforcer",
    ['367'] = "Enigmatist",
    ['568'] = "Evoker",
    ['047'] = "Executioner",
    ['378'] = "Exorcist",
    ['256'] = "Farslayer",
    ['069'] = "Fleshshaper",
    ['458'] = "Gravesinger",
    ['689'] = "Gypsy",
    ['016'] = "Harbinger",
    ['067'] = "Hellweaver",
    ['038'] = "Herald",
    ['158'] = "Hex Ranger",
    ['013'] = "Hex Warden",
    ['012'] = "Hexblade",
    ['139'] = "Hierophant",
    ['258'] = "Honorguard",
    ['014'] = "Hordebreaker",
    ['358'] = "Howler",
    ['567'] = "Infiltrator",
    ['079'] = "Inquisitor",
    ['249'] = "Justicar",
    ['168'] = "Lamentor",
    ['025'] = "Liberator",
    ['048'] = "Lorebreaker",
    ['569'] = "Naturalist",
    ['149'] = "Necromancer",
    ['278'] = "Nightbearer",
    ['237'] = "Nightblade",
    ['134'] = "Nightcloak",
    ['178'] = "Nightwitch",
    ['478'] = "Nocturne",
    ['359'] = "Oracle",
    ['057'] = "Outrider",
    ['029'] = "Paladin",
    ['348'] = "Phantasm",
    ['347'] = "Planeshifter",
    ['128'] = "Poxbane",
    ['357'] = "Primeval",
    ['579'] = "Ranger",
    ['046'] = "Ravager",
    ['467'] = "Reaper",
    ['468'] = "Requiem",
    ['346'] = "Revenant",
    ['269'] = "Scion",
    ['457'] = "Shadehunter",
    ['145'] = "Shadestriker",
    ['129'] = "Shadowbane",
    ['017'] = "Shadowblade",
    ['127'] = "Shadowknight",
    ['169'] = "Shaman",
    ['147'] = "Shroudmaster",
    ['234'] = "Skullknight",
    ['379'] = "Soothsayer",
    ['489'] = "Sorrowsong",
    ['159'] = "Soulbow",
    ['589'] = "Soulsong",
    ['456'] = "Spellbow",
    ['678'] = "Spellsinger",
    ['368'] = "Spellsong",
    ['068'] = "Spellsword",
    ['257'] = "Stone Arrow",
    ['156'] = "Stormcaster",
    ['356'] = "Stormchaser",
    ['267'] = "Swiftstone",
    ['239'] = "Templar",
    ['236'] = "Thaumaturge",
    ['238'] = "Tomb Warden",
    ['148'] = "Tombcaller",
    ['157'] = "Trickster",
    ['059'] = "Warpriest"
}

-- Default role classifications
local DEFAULT_TANKS = {"Abolisher", "Skullknight", "Templar", "Bastion", "Paladin", "Doomlord"}
local DEFAULT_HEALERS = {"Cleric", "Hierophant", "Soothsayer", "Caretaker", "Edgewalker", "Gypsy"}

-- Get class name from skillset table
function RoleHelper.getClassName(classTable)
    if not classTable then return nil end

    local first = tonumber(classTable['1'] or classTable[1])
    local second = tonumber(classTable['2'] or classTable[2])
    local third = tonumber(classTable['3'] or classTable[3])
    if not first or not second or not third then return nil end

    local tree1, tree2, tree3 = first - 1, second - 1, third - 1
    local key = tree1 .. tree2 .. tree3
    return classes[key]
end

function RoleHelper.getClassKey(className)
    if not className then return nil end
    local needle = string.lower(tostring(className or ""))
    if needle == "" then return nil end
    for key, name in pairs(classes) do
        if string.lower(tostring(name or "")) == needle then return key end
    end
    return nil
end

-- Check if a value exists in a table (case-insensitive)
local function hasValue(tab, val)
    if not tab or not val then return false end

    for _, value in ipairs(tab) do
        if string.lower(value) == string.lower(val) then
            return true
        end
    end
    return false
end

-- Determine role from class name
-- Returns: "tank", "healer", or "dps"
function RoleHelper.getRoleFromClass(className, customTanks, customHealers)
    if not className then return "dps" end

    local tanks = customTanks or DEFAULT_TANKS
    local healers = customHealers or DEFAULT_HEALERS

    if hasValue(tanks, className) then
        return "tank"
    elseif hasValue(healers, className) then
        return "healer"
    else
        return "dps"
    end
end

-- Get role icon path based on role type
function RoleHelper.getRoleIconPath(role)
    local iconPaths = {
        tank = "../Addon/power_ranger_on/icons/RoleTank.png",
        healer = "../Addon/power_ranger_on/icons/RoleHealer.png",
        dps = "../Addon/power_ranger_on/icons/RoleDPS.png"
    }
    return iconPaths[role] or iconPaths.dps
end

-- Calculate gearscore color (gradient from green to red)
-- 3000 = bright green (0, 1, 0)
-- 9000 = bright red (1, 0, 0)
function RoleHelper.getGearscoreColor(gearscore)
    if not gearscore or gearscore < 3000 then
        return {0, 1, 0, 1} -- Bright green for low/invalid scores
    elseif gearscore >= 9000 then
        return {1, 0, 0, 1} -- Bright red for max scores
    end

    -- Calculate interpolation factor (0 to 1)
    local range = 9000 - 3000
    local position = gearscore - 3000
    local factor = position / range

    -- Interpolate from green (0,1,0) to red (1,0,0)
    local red = factor
    local green = 1 - factor
    local blue = 0

    return {red, green, blue, 1}
end

return RoleHelper
