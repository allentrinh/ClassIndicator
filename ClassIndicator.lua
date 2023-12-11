-- Import AceConfig-3.0
local AceAddon = LibStub("AceAddon-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")

-- Constants
local ADDON_PATH = "Interface\\AddOns\\ClassIndicator\\"
local CLASS_ICONS_PATH = ADDON_PATH .. "Assets\\ClassIcons\\"
local ANCHOR_POSITION = {
    ["TOP"] = "TOP",
    ["BOTTOM"] = "BOTTOM",
    ["RIGHT"] = "RIGHT",
    ["LEFT"] = "LEFT",
    ["CENTER"] = "CENTER",
}
local FRAME_STRATA = "HIGH"
local FRAME_LEVEL = 5

-- Default configuration values
local defaults = {
    global = {
        enabled = true,
        arenaOnly = false,
        size = 48,
        position = {
            horizontal = 0,
            vertical = 8,
            anchor = "TOP"
        }
    },
}

-- Create your addon as an AceAddon
local ClassIndicator = AceAddon:NewAddon("ClassIndicator", "AceConsole-3.0", "AceEvent-3.0")

-- Init a look up table
ClassIndicator.iconTextures = {}

---
-- Function to initialize the addon
-- @return (void)
function ClassIndicator:OnInitialize()
    -- Access the saved variables and initialize the database
    self.db = AceDB:New("ClassIndicatorDB", defaults, true)

    -- Register a slash command to open the options panel
    self:RegisterChatCommand("ci", "ToggleOptionsPanel")

    -- Register the options menu
    self:RegisterMenu()
end

---
-- Registers the menu
-- @return (void)
function ClassIndicator:RegisterMenu()
    -- Register the options table
    self.options = {
        name = "Class Indicator",
        type = "group",
        args = {
            enabled = {
                type = "toggle",
                name = "Enable",
                desc = "Toggle the display of class icons on unit frames",
                get = function() return self.db.global.enabled end,
                set = function(_, value)
                    self.db.global.enabled = value
                    self:ToggleAllTextures()
                end,
                order = 1,
                width = "full",
            },
            arenaOnly = {
                type = "toggle",
                name = "Arena only",
                desc = "Restrict the class icons to only show in arena",
                get = function() return self.db.global.arenaOnly end,
                set = function(_, value)
                    self.db.global.arenaOnly = value
                    self:ToggleAllTextures()
                end,
                order = 2,
                width = "full",
            },
            size = {
                type = "range",
                name = "Icon Size",
                desc = "The size of the class icons",
                min = 8,
                max = 144,
                step = 8,
                get = function() return self.db.global.size; end,
                set = function(_, value)
                    self.db.global.size = value
                    self:RefreshTextures()
                end,
                order = 3,
                width = "full",
            },
            position = {
                type = "group",
                name = "Position",
                desc = "Position of the icon",
                inline = true,
                order = 4,
                args = {
                    horizontal = {
                        type = "range",
                        name = "Horizontal",
                        desc = "Horizontal position",
                        min = -100,
                        max = 100,
                        step = 1,
                        get = function() return self.db.global.position.horizontal; end,
                        set = function(_, value)
                            self.db.global.position.horizontal = value
                            self:RefreshTextures()
                        end,
                        width = "full",
                    },
                    vertical = {
                        type = "range",
                        name = "Vertical",
                        desc = "Vertical position",
                        min = -100,
                        max = 100,
                        step = 1,
                        get = function() return self.db.global.position.vertical; end,
                        set = function(_, value)
                            self.db.global.position.vertical = value
                            self:RefreshTextures()
                        end,
                        width = "full",
                    },
                    anchor = {
                        type = "select",
                        name = "Anchor",
                        desc = "Anchor position on unit nameplates",
                        get = function() return self.db.global.position.anchor; end,
                        set = function(_, value)
                            self.db.global.position.anchor = value
                            self:RefreshTextures()
                        end,
                        values = ANCHOR_POSITION,
                    },
                },
            },
        },
    }

    -- Register the options table with AceConfig
    AceConfig:RegisterOptionsTable("ClassIndicator", self.options)

    -- Create a basic options panel
    self.optionsPanel = AceConfigDialog:AddToBlizOptions("ClassIndicator", "Class Indicator")
end

---
-- Handle the "OnEnable" event
-- @return (void)
function ClassIndicator:OnEnable()
    -- Create a frame
    self.frame = CreateFrame("Frame")
    self.frame:SetFrameStrata(FRAME_STRATA)
    self.frame:SetFrameLevel(FRAME_LEVEL)
    self.frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self.frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

    -- Add a frame event listener
    self.frame:SetScript("OnEvent", function(_, event, unitId)
        if event == "NAME_PLATE_UNIT_ADDED" then
            self:AddTextureToNameplateByUnitId(unitId)
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            self:RemoveTextureFromNameplateByUnitId(unitId)
        end
    end)
end

---
-- Adds a texture to a nameplate by unit id
-- @param unitId (string) the unit id
-- @return (void)
function ClassIndicator:AddTextureToNameplateByUnitId(unitId)
    if not unitId then
        return
    end

    local unitGUID = UnitGUID(unitId)
    local isFriend = UnitIsFriend("player", unitId)

    if not isFriend then
        return
    end

    local nameplate = C_NamePlate.GetNamePlateForUnit(unitId, false)
    local localizedClass, englishClass, localizedRace, englishRace, sex, name, realm = GetPlayerInfoByGUID(unitGUID)
    if englishClass then
        local iconTexturePath = CLASS_ICONS_PATH .. englishClass .. ".tga"
        self:AddTextureToNameplate(unitId, nameplate, iconTexturePath)
    end
end

---
-- Removes a texture from a nameplate by unit id
-- @param unitId (string) the unit id
-- @return (void)
function ClassIndicator:RemoveTextureFromNameplateByUnitId(unitId)
    if not unitId then
        return
    end

    -- We don't recognize this unit for some reason, exit early
    if self.iconTextures[unitId] == nil then
        return
    end

    -- Player still exists, leave the texture
    local unitGUID = UnitGUID(unitId)
    if UnitExists(unitGUID) then
        return
    end

    -- Player no longer exists, remove texture
    self.iconTextures[unitId]:Hide()
    self.iconTextures[unitId] = nil
end

---
-- Adds texture to a nameplate
-- @param unitId (string) the unit id
-- @param nameplate (string) the nameplate id
-- @param iconTexturePath (string) the icon texture path
-- @return (void)
function ClassIndicator:AddTextureToNameplate(unitId, nameplate, iconTexturePath)
    local iconTexture = nameplate:CreateTexture(nil, "OVERLAY")
    local iconSize = self.db.global.size
    local anchor = self.db.global.position.anchor
    local horizontal = self.db.global.position.horizontal
    local vertical = self.db.global.position.vertical
    local isShown = self:GetIsTextureShown()

    iconTexture:SetTexture(iconTexturePath)
    iconTexture:SetSize(iconSize, iconSize)
    iconTexture:SetPoint("CENTER", nameplate, anchor, horizontal, vertical)
    iconTexture:SetShown(isShown)

    self.iconTextures[unitId] = iconTexture
end

---
-- Toggles all textures
-- @return (void)
function ClassIndicator:ToggleAllTextures()
    local isShown = self:GetIsTextureShown()

    for _, iconTexture in pairs(self.iconTextures) do
        iconTexture:SetShown(isShown)
    end
end

---
-- Destroys all textures
-- @return (void)
function ClassIndicator:DestroyAllTextures()
    self:HideAllTextures()
    table.wipe(self.iconTextures)
end

-- Destroys the frame
-- @return (void)
function ClassIndicator:DestroyFrame()
    if self.frame == nil then
        return
    end

    self.frame:Hide()
    self.frame = nil
end

---
-- Refreshes textures when an option is changed
-- @return (void)
function ClassIndicator:RefreshTextures()
    for unitId, iconTexture in pairs(self.iconTextures) do
        local nameplate = C_NamePlate.GetNamePlateForUnit(unitId, false)
        local iconSize = self.db.global.size
        local anchor = self.db.global.position.anchor
        local horizontal = self.db.global.position.horizontal
        local vertical = self.db.global.position.vertical

        iconTexture:SetSize(iconSize, iconSize)
        iconTexture:SetPoint("CENTER", nameplate, anchor, horizontal, vertical)
    end
end

---
-- Handle the "OnDisable" event
-- @return (void)
function ClassIndicator:OnDisable()
    self:UnregisterAllEvents()
    self:DestroyAllTextures()
    self:DestroyFrame()
end

---
-- Toggle the options panel
-- @return (void)
function ClassIndicator:ToggleOptionsPanel()
    InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
    InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
end

---
-- Checks if textures should be shown based on enabled and arenaOnly values
-- @return (boolean)
function ClassIndicator:GetIsTextureShown()
    local isEnabled = self.db.global.enabled
    local isArenaOnly = self.db.global.arenaOnly
    local zoneType = GetZonePVPInfo()

    if not isEnabled then
        return false
    end

    if isArenaOnly and zoneType ~= "arena" then
        return false
    end

    return true
end
