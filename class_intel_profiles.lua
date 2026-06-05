local RoleHelper = require("power_ranger_on/role_helper")

local ClassIntelProfiles = {}

ClassIntelProfiles.PROFILES = {
    { key = "general", label = "General" },
    { key = "melee", label = "Melee" },
    { key = "mage", label = "Mage" },
    { key = "archer", label = "Archer" },
    { key = "healer", label = "Healer" },
    { key = "tank", label = "Tank" }
}

ClassIntelProfiles.STATS = {
    { key = "pdef", setting = "showInfoPdef", label = "PDef" },
    { key = "mdef", setting = "showInfoMdef", label = "MDef" },
    { key = "block", setting = "showInfoBlock", label = "Block" },
    { key = "parry", setting = "showInfoParry", label = "Parry" },
    { key = "evasion", setting = "showInfoEvasion", label = "Evasion" },
    { key = "toughness", setting = "showInfoToughness", label = "Tough" },
    { key = "resilience", setting = "showInfoResilience", label = "Resil" },
    { key = "critRate", setting = "showInfoCritRate", label = "Crit" }
}

local DEFAULTS = {
    general = { pdef = true, mdef = true, block = true, parry = true, evasion = true, critRate = true },
    melee = { pdef = true, mdef = true, block = true, parry = true, evasion = true, critRate = true },
    mage = { pdef = true, mdef = true, evasion = true, critRate = true },
    archer = { pdef = true, mdef = true, evasion = true, critRate = true },
    healer = { pdef = true, mdef = true, critRate = true },
    tank = { pdef = true, mdef = true, block = true, parry = true, toughness = true, resilience = true }
}

local PROFILE_LABELS = {
    general = "General",
    melee = "Melee",
    mage = "Mage",
    archer = "Archer",
    healer = "Healer",
    tank = "Tank"
}

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function classIds(targetInfo)
    local class = targetInfo and targetInfo.class
    if type(class) ~= "table" then return nil end
    local first = tonumber(class["1"] or class[1])
    local second = tonumber(class["2"] or class[2])
    local third = tonumber(class["3"] or class[3])
    if not first or not second or not third then return nil end
    return first - 1, second - 1, third - 1
end

local function hasTree(targetInfo, tree)
    local a, b, c = classIds(targetInfo)
    return a == tree or b == tree or c == tree
end

local function keyHasTree(key, tree)
    key = tostring(key or "")
    tree = tostring(tree or "")
    return key:find(tree, 1, true) ~= nil
end

local function profileFromClassKey(key)
    if keyHasTree(key, 2) then return "tank" end
    if keyHasTree(key, 9) then return "healer" end
    if keyHasTree(key, 5) then return "archer" end
    if keyHasTree(key, 0) then return "melee" end
    if keyHasTree(key, 6) then return "mage" end
    return nil
end

function ClassIntelProfiles.DefaultProfiles()
    local copy = {}
    for key, values in pairs(DEFAULTS) do
        copy[key] = {}
        for stat, enabled in pairs(values) do copy[key][stat] = enabled end
    end
    return copy
end

function ClassIntelProfiles.Ensure(settings)
    if type(settings.classIntelProfiles) ~= "table" then settings.classIntelProfiles = ClassIntelProfiles.DefaultProfiles() end
    for key, values in pairs(DEFAULTS) do
        if type(settings.classIntelProfiles[key]) ~= "table" then settings.classIntelProfiles[key] = {} end
        for stat, enabled in pairs(values) do
            if settings.classIntelProfiles[key][stat] == nil then settings.classIntelProfiles[key][stat] = enabled end
        end
    end
    if not settings.classIntelEditProfile then settings.classIntelEditProfile = "general" end
end

function ClassIntelProfiles.Classify(targetInfo, className)
    if hasTree(targetInfo, 2) then return "tank" end
    if hasTree(targetInfo, 9) then return "healer" end
    if hasTree(targetInfo, 5) then return "archer" end
    if hasTree(targetInfo, 0) then return "melee" end
    if hasTree(targetInfo, 6) then return "mage" end
    local classKey = RoleHelper.getClassKey(className)
    local profile = profileFromClassKey(classKey)
    if profile then return profile end
    local role = RoleHelper.getRoleFromClass(className)
    if role == "tank" then return "tank" end
    if role == "healer" then return "healer" end
    local name = lower(className)
    if name:find("bow", 1, true) or name:find("ranger", 1, true) or name:find("arrow", 1, true) then return "archer" end
    if name:find("mage", 1, true) or name:find("sorcer", 1, true) or name:find("spells", 1, true)
        or name:find("arcan", 1, true) or name:find("demon", 1, true) then return "mage" end
    return "general"
end

function ClassIntelProfiles.Label(profileKey)
    return PROFILE_LABELS[profileKey] or "General"
end

function ClassIntelProfiles.ShouldShow(settings, targetInfo, className, statKey)
    ClassIntelProfiles.Ensure(settings)
    local profileKey = ClassIntelProfiles.Classify(targetInfo, className)
    local profile = settings.classIntelProfiles[profileKey]
    if type(profile) ~= "table" then profile = settings.classIntelProfiles.general end
    if type(profile) ~= "table" then return false end
    return profile[statKey] == true
end

function ClassIntelProfiles.NeedsExtraStats(settings)
    ClassIntelProfiles.Ensure(settings)
    for _, profile in pairs(settings.classIntelProfiles or {}) do
        if type(profile) == "table" then
            if profile.block or profile.parry or profile.evasion or profile.toughness or profile.resilience or profile.critRate then
                return true
            end
        end
    end
    return false
end

function ClassIntelProfiles.CycleEditProfile(settings, delta)
    ClassIntelProfiles.Ensure(settings)
    local current = settings.classIntelEditProfile or "general"
    local index = 1
    for i, entry in ipairs(ClassIntelProfiles.PROFILES) do
        if entry.key == current then index = i break end
    end
    index = index + (tonumber(delta) or 1)
    if index < 1 then index = #ClassIntelProfiles.PROFILES end
    if index > #ClassIntelProfiles.PROFILES then index = 1 end
    settings.classIntelEditProfile = ClassIntelProfiles.PROFILES[index].key
    return settings.classIntelEditProfile
end

function ClassIntelProfiles.ToggleStat(settings, statKey)
    ClassIntelProfiles.Ensure(settings)
    local profile = settings.classIntelProfiles[settings.classIntelEditProfile or "general"]
    profile[statKey] = not profile[statKey]
    return profile[statKey]
end

return ClassIntelProfiles
