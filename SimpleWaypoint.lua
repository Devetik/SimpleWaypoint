-- Déclare la table principale de l'addon
SimpleWaypoint = SimpleWaypoint or {}
local waypoints = SimpleWaypoint.waypoints or {}
SimpleWaypoint.waypoints = waypoints
local pins = {} -- Table pour stocker les pins
local guildMembers = {} -- Table pour stocker les informations des membres de la guilde

-- Chargement de la bibliothèque HereBeDragons
local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

-- Intervalle de mise à jour
local updateInterval = 2 -- En secondes
local movementThreshold = 0.005 -- 5% de la carte (environ 5 mètres)
local timeSinceLastUpdate = 0
local lastSentPosition = { x = nil, y = nil, mapID = nil } -- Dernière position envoyée

-- Fonction pour calculer la distance entre deux points
local function CalculateDistance(x1, y1, x2, y2)
    if not x1 or not y1 or not x2 or not y2 then return math.huge end
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

-- Préfixe unique pour l'addon
local ADDON_PREFIX = "SimpleWaypoint"

-- Inscription du préfixe pour la communication addon
C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)

-- Fonction pour envoyer la position via Addon Message
function SimpleWaypoint:SendGuildPosition()
    if IsInGuild() then
        local mapID = C_Map.GetBestMapForUnit("player")
        if not mapID then return end

        local position = C_Map.GetPlayerMapPosition(mapID, "player")
        if position then
            local x, y = position:GetXY()
            if x and y then
                -- Vérifie si la position a changé significativement
                if CalculateDistance(x, y, lastSentPosition.x, lastSentPosition.y) > movementThreshold then
                    local name = UnitName("player")
                    local level = UnitLevel("player")
                    local class = UnitClass("player")
                    local rank = "Membre"

                    -- Parcours des membres de la guilde pour trouver le rang
                    for i = 1, GetNumGuildMembers() do
                        local memberName, memberRank = GetGuildRosterInfo(i)
                        if memberName and memberName == name then
                            rank = memberRank
                            break
                        end
                    end

                    local icon = "Interface\\AddOns\\SimpleWaypoint\\Textures\\Pin"
                    local message = string.format("%s,%s,%d,%s,%.3f,%.3f,%d,%s", name, rank, level, class, x, y, mapID, icon)
                    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, message, "GUILD")
                    lastSentPosition = { x = x, y = y, mapID = mapID }
                end
            end
        end
    end
end

-- Fonction pour vérifier si le message provient du joueur lui-même
local function IsSelf(sender)
    local playerName = UnitName("player")
    local realmName = GetNormalizedRealmName()
    local fullPlayerName = playerName .. "-" .. realmName
    return sender == fullPlayerName
end

-- Fonction pour traiter les messages reçus via Addon Message
local function OnAddonMessage(prefix, text, channel, sender)
    if prefix == ADDON_PREFIX and not IsSelf(sender) then
        local name, rank, level, class, x, y, mapID, icon = strsplit(",", text)
        --print("Update ", name, " ", rank, " ", level, " ", class, " ", x, " ", y, " ", mapID, " ", icon)
        x, y, mapID, level = tonumber(x), tonumber(y), tonumber(mapID), tonumber(level)

        if x and y and mapID then
            guildMembers[name] = {
                rank = rank,
                level = level,
                class = class,
                x = x,
                y = y,
                mapID = mapID,
                icon = icon,
            }
            SimpleWaypoint:CreateGuildMemberPin(name)
        end
    end
end

-- Gestion des événements
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        OnAddonMessage(prefix, text, channel, sender)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        SimpleWaypoint:RefreshPins()
    end
end)

-- Mise à jour périodique pour envoyer la position
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    timeSinceLastUpdate = timeSinceLastUpdate + elapsed
    if timeSinceLastUpdate >= updateInterval then
        SimpleWaypoint:SendGuildPosition()
        timeSinceLastUpdate = 0
    end
end)

print("SimpleWaypoint chargé avec communication invisible via Addon Message.")


-- Fonction pour créer ou mettre à jour un pin pour un membre de la guilde
function SimpleWaypoint:CreateGuildMemberPin(memberName)
    local member = guildMembers[memberName]
    if not member then return end

    -- Supprime l'ancien pin si nécessaire
    if pins[memberName] then
        HBDPins:RemoveWorldMapIcon(memberName, pins[memberName])
        HBDPins:RemoveMinimapIcon(memberName, pins[memberName])
    end
    SimpleWaypoint:RemovePinsByTitle(memberName)
    -- Crée un nouveau pin
    local pin = CreateFrame("Frame", nil, UIParent)
    pin:SetSize(12, 12)
    local texture = pin:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    texture:SetTexture(member.icon or "Interface\\AddOns\\SimpleWaypoint\\Textures\\Pin")
    pin.texture = texture

    self:AddWaypoint(member.mapID, member.x, member.y, memberName)

    -- -- Ajoute un tooltip au pin
    -- pin:SetScript("OnEnter", function()
    --     GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    --     GameTooltip:SetText(string.format("%s (Niveau: %d, Classe: %s, Rang: %s)", memberName, member.level, member.class, member.rank))
    --     GameTooltip:Show()
    -- end)
    -- pin:SetScript("OnLeave", function()
    --     GameTooltip:Hide()
    -- end)

    -- Stocke le pin
    pins[memberName] = pin
end

-- Fonction pour rafraîchir les pins dynamiquement
function SimpleWaypoint:RefreshPins()
    for memberName, _ in pairs(guildMembers) do
        self:CreateGuildMemberPin(memberName)
    end
    print("Pins rafraîchis dynamiquement.")
end

-- Gestion des événements
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_GUILD")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_GUILD" then
        local text, sender = ...
        ProcessGuildMessage(text, sender)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        SimpleWaypoint:RefreshPins()
    end
end)

-- Mise à jour périodique pour envoyer la position
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    timeSinceLastUpdate = timeSinceLastUpdate + elapsed
    if timeSinceLastUpdate >= updateInterval then
        SimpleWaypoint:SendGuildPosition()
        timeSinceLastUpdate = 0
    end
end)

-----------------------------------------------------------
-----------------------------------------------------------
-----------------------------------------------------------

-- Fonction pour créer deux pins (carte et mini-carte)
function SimpleWaypoint:CreateMapPin(waypoint)
    -- Supprime les anciens pins s'ils existent
    if pins[waypoint] then
        if pins[waypoint].world then
            HBDPins:RemoveWorldMapIcon("SimpleWaypoint", pins[waypoint].world)
        end
        if pins[waypoint].minimap then
            HBDPins:RemoveMinimapIcon("SimpleWaypoint", pins[waypoint].minimap)
        end
        pins[waypoint] = nil
    end

    -- Crée un pin pour la carte mondiale
    local worldPin = CreateFrame("Frame", nil, UIParent)
    worldPin:SetSize(12, 12)

    local worldTexture = worldPin:CreateTexture(nil, "OVERLAY")
    worldTexture:SetAllPoints()
    worldTexture:SetTexture("Interface\\AddOns\\SimpleWaypoint\\Textures\\Pin") -- Chemin vers une icône personnalisée
    worldPin.texture = worldTexture

    local worldAdded = HBDPins:AddWorldMapIconMap("SimpleWaypoint", worldPin, waypoint.mapID, waypoint.x, waypoint.y, HBD_PINS_WORLDMAP_SHOW_WORLD) -- HBD_PINS_WORLDMAP_SHOW_PARENT si uniquement locale

    -- Crée un pin pour la mini-carte
    local minimapPin = CreateFrame("Frame", nil, UIParent)
    minimapPin:SetSize(12, 12)

    local minimapTexture = minimapPin:CreateTexture(nil, "OVERLAY")
    minimapTexture:SetAllPoints()
    minimapTexture:SetTexture("Interface\\AddOns\\SimpleWaypoint\\Textures\\Pin") -- Chemin vers une icône personnalisée
    minimapPin.texture = minimapTexture

    local minimapAdded = HBDPins:AddMinimapIconMap("SimpleWaypoint", minimapPin, waypoint.mapID, waypoint.x, waypoint.y, false)

    -- Stocke les deux pins
    pins[waypoint] = {
        world = worldPin,
        minimap = minimapPin,
        title = waypoint.title
    }

    -- Ajoute un tooltip au pin de la carte mondiale
    worldPin:SetScript("OnEnter", function()
        GameTooltip:SetOwner(worldPin, "ANCHOR_RIGHT")
        GameTooltip:SetText(waypoint.title)
        GameTooltip:Show()
    end)
    worldPin:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Ajoute un tooltip au pin de la mini-carte
    minimapPin:SetScript("OnEnter", function()
        GameTooltip:SetOwner(minimapPin, "ANCHOR_RIGHT")
        GameTooltip:SetText(waypoint.title)
        GameTooltip:Show()
    end)
    minimapPin:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end





-- Fonction pour ajouter un waypoint
function SimpleWaypoint:AddWaypoint(mapID, x, y, title)
    local waypoint = {
        mapID = mapID,
        x = x,
        y = y,
        title = title or "Waypoint",
    }
    table.insert(waypoints, waypoint)

    -- Ajout du pin via HereBeDragons
    self:CreateMapPin(waypoint)
end

-- Fonction pour supprimer tous les waypoints
function SimpleWaypoint:ClearAllWaypoints()
    for _, pinSet in pairs(pins) do
        if pinSet.world then
            HBDPins:RemoveWorldMapIcon("SimpleWaypoint", pinSet.world)
        end
        if pinSet.minimap then
            HBDPins:RemoveMinimapIcon("SimpleWaypoint", pinSet.minimap)
        end
    end
    waypoints = {}
    pins = {}
    print("Tous les waypoints ont été supprimés.")
end

function SimpleWaypoint:RemovePinsByTitle(title)
    -- Vérifie que le titre est valide
    if not title then
        print("Erreur : aucun titre fourni pour la suppression.")
        return
    end

    -- Parcourt la table `pins`
    for key, pinSet in pairs(pins) do
        if pinSet.title == title then
            -- Supprime les pins de la carte mondiale
            if pinSet.world then
                HBDPins:RemoveWorldMapIcon("SimpleWaypoint", pinSet.world)
            end

            -- Supprime les pins de la mini-carte
            if pinSet.minimap then
                HBDPins:RemoveMinimapIcon("SimpleWaypoint", pinSet.minimap)
            end

            -- Retire l'entrée de la table `pins`
            pins[key] = nil
        end
    end
end



-- Commandes slash
SLASH_SIMPLEWAYPOINT1 = "/swp"
SlashCmdList["SIMPLEWAYPOINT"] = function(msg)
    local cmd, arg1, arg2, arg3 = strsplit(" ", msg)
    if cmd == "add" and arg1 and arg2 and arg3 then
        local mapID = tonumber(arg1)
        local x = tonumber(arg2) / 100
        local y = tonumber(arg3) / 100
        if mapID and x and y then
            SimpleWaypoint:AddWaypoint(mapID, x, y, "Point Custom")
        else
            print("Utilisation : /swp add <mapID> <x> <y>")
        end
    elseif cmd == "clear" then
        SimpleWaypoint:ClearAllWaypoints()
    elseif cmd == "relo" then
        SimpleWaypoint:RemovePinsByTitle("Ævi")
    else
        print("Commandes :")
        print("/swp add <mapID> <x> <y> - Ajoute un point")
        print("/swp clear - Supprime tous les points")
        print("/swp relo - Ajoute un point à votre position actuelle")
    end
end

---------------------------------------------------------------------
---------------------------------------------------------------------
---------------------------------------------------------------------
---------------------------------------------------------------------
---
----- Fonction pour enregistrer la position actuelle

print("SimpleWaypoint fusionné avec Astralith_Map et chargé.")
