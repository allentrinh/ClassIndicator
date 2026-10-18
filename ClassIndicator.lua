local AceAddon = LibStub("AceAddon-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")

local ADDON_PATH = "Interface\\AddOns\\ClassIndicator\\"
local CLASS_ICONS_PATH = ADDON_PATH .. "Assets\\ClassIcons\\"
local ANCHOR_POSITION = {
    ["TOP"] = "TOP",
    ["BOTTOM"] = "BOTTOM",
    ["RIGHT"] = "RIGHT",
    ["LEFT"] = "LEFT",
    ["CENTER"] = "CENTER",
}

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

local ClassIndicator = AceAddon:NewAddon("ClassIndicator", "AceConsole-3.0", "AceEvent-3.0")

ClassIndicator.iconTextures = {}
ClassIndicator.activePlates = {}

function ClassIndicator:OnInitialize()
    self.db = AceDB:New("ClassIndicatorDB", defaults, true)
    self:RegisterChatCommand("ci", "ToggleOptionsPanel")
    self:RegisterMenu()
end

function ClassIndicator:RegisterMenu()
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
                    self:RefreshTextures()
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
                    self:RefreshTextures()
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
                get = function() return self.db.global.size end,
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
                        get = function() return self.db.global.position.horizontal end,
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
                        get = function() return self.db.global.position.vertical end,
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
                        get = function() return self.db.global.position.anchor end,
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

    AceConfig:RegisterOptionsTable("ClassIndicator", self.options)
    self.optionsPanel = AceConfigDialog:AddToBlizOptions("ClassIndicator", "Class Indicator")
end

function ClassIndicator:OnEnable()
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "RefreshTextures")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "RefreshTextures")
end

function ClassIndicator:OnDisable()
    self:UnregisterAllEvents()
    for _, iconTexture in pairs(self.iconTextures) do
        iconTexture:Hide()
    end
end

function ClassIndicator:NAME_PLATE_UNIT_ADDED(event, unitId)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unitId, false)
    if not nameplate then return end

    if self.iconTextures[nameplate] then
        self.iconTextures[nameplate]:Hide()
    end

    if UnitIsUnit(unitId, "player") or not UnitIsFriend("player", unitId) or not UnitIsPlayer(unitId) then return end

    local unitGUID = UnitGUID(unitId)
    if not unitGUID then return end

    local _, englishClass = GetPlayerInfoByGUID(unitGUID)
    if not englishClass then return end

    if not self.iconTextures[nameplate] then
        self.iconTextures[nameplate] = nameplate:CreateTexture(nil, "OVERLAY")
    end

    self.activePlates[unitId] = nameplate

    local tex = self.iconTextures[nameplate]
    local db = self.db.global

    tex:SetTexture(CLASS_ICONS_PATH .. englishClass .. ".tga")
    tex:SetSize(db.size, db.size)
    tex:SetPoint("CENTER", nameplate, db.position.anchor, db.position.horizontal, db.position.vertical)
    tex:SetShown(self:GetIsTextureShown())
end

function ClassIndicator:NAME_PLATE_UNIT_REMOVED(event, unitId)
    local nameplate = self.activePlates[unitId]
    if nameplate and self.iconTextures[nameplate] then
        self.iconTextures[nameplate]:Hide()
    end
    self.activePlates[unitId] = nil
end

function ClassIndicator:RefreshTextures()
    local db = self.db.global
    local isShown = self:GetIsTextureShown()

    for nameplate, iconTexture in pairs(self.iconTextures) do
        iconTexture:Hide()
    end

    for unitId, nameplate in pairs(self.activePlates) do
        local iconTexture = self.iconTextures[nameplate]
        if iconTexture then
            iconTexture:SetSize(db.size, db.size)
            iconTexture:SetPoint("CENTER", nameplate, db.position.anchor, db.position.horizontal, db.position.vertical)
            iconTexture:SetShown(isShown)
        end
    end
end

function ClassIndicator:ToggleOptionsPanel()
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(self.optionsPanel.name)
    else
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
    end
end

function ClassIndicator:GetIsTextureShown()
    if not self.db.global.enabled then return false end
    if self.db.global.arenaOnly then
        local _, instanceType = IsInInstance()
        return instanceType == "arena"
    end
    return true
end
