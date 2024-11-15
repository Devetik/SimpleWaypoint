-- Déclare la table principale de l'addon
SimpleWaypoint = SimpleWaypoint or {}
local waypoints = SimpleWaypoint.waypoints or {}
SimpleWaypoint.waypoints = waypoints
local pins = {} -- Table pour stocker les pins

-- Chargement de la bibliothèque HereBeDragons
local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

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

    print(string.format("Waypoint ajouté : [%s] %.2f, %.2f", title, x * 100, y * 100))
end

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

-- Fonction pour rafraîchir les pins
function SimpleWaypoint:RefreshPins()
    for _, waypoint in ipairs(waypoints) do
        self:CreateMapPin(waypoint)
    end
    print("Pins rafraîchis.")
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

-- Fonction pour enregistrer la position actuelle
function SimpleWaypoint:AddCurrentPosition()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        print("Impossible de déterminer la position actuelle.")
        return
    end

    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if position then
        local x, y = position:GetXY()
        if x and y then
            self:AddWaypoint(mapID, x, y, "Position actuelle")
        else
            print("Impossible de déterminer les coordonnées.")
        end
    else
        print("Impossible de déterminer la position actuelle.")
    end
end

-- Ajout d'un rafraîchissement périodique
local refreshTimer = CreateFrame("Frame")
refreshTimer.elapsed = 0
refreshTimer:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= 10 then -- Rafraîchit toutes les 10 secondes
        SimpleWaypoint:RefreshPins()
        self.elapsed = 0
    end
end)

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
        SimpleWaypoint:AddCurrentPosition()
    else
        print("Commandes :")
        print("/swp add <mapID> <x> <y> - Ajoute un point")
        print("/swp clear - Supprime tous les points")
        print("/swp relo - Ajoute un point à votre position actuelle")
    end
end

print("SimpleWaypoint chargé. Utilisez /swp pour interagir.")
