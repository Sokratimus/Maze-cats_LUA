-- draw.lua
local client = require("client")
local common = require("game_common")
local logger = require("logger")

local draw = {}

local cellSize = 32
local GRID_SIZE = 25
local selectedCard = { type = nil, rotation = 0 }
local selectedFromHand = nil
local movingPlayer = false
local images = {}
local font

function draw.load()
    font = love.graphics.newFont("assets/fonts/Roboto.ttf", 20)
    love.graphics.setFont(font)

    images = {
        cardBack = love.graphics.newImage("assets/ui/card_back.png"),
        endTurn = love.graphics.newImage("assets/ui/end_turn.jpg"),

        tiles = {
            straight = love.graphics.newImage("assets/tiles/Straight.jpg"),
            cross = love.graphics.newImage("assets/tiles/Cross.jpg"),
            t = love.graphics.newImage("assets/tiles/T.jpg"),
            corner = love.graphics.newImage("assets/tiles/Corner.jpg"),
            deadend = love.graphics.newImage("assets/tiles/DeadEnd.jpg"),
            empty = love.graphics.newImage("assets/tiles/Empty.jpg")
        }
    }
end

function draw.update(dt) 
    local mx, my = love.mouse.getPosition()
    local winW, winH = love.graphics.getDimensions()
    local cardW, cardH = 128, 192
    local hand = client.getPlayer() and client.getPlayer().hand or {}
    logger.log("draw.update — player.hand size: " .. tostring(#hand))

    for i, card in ipairs(hand) do
        local handX = winW - 300 + (i - 1) * 40
        local handY = winH - 140 + math.sin(i) * 5
        local angle = math.rad(-30 + i * 10)

        card.x = handX
        card.y = handY

        local tri = draw.getTriangleZonePoints(handX, handY, cardW, cardH, angle, 50, 40)
        card.hover = draw.pointInTriangle(mx, my, unpack(tri))
    end

    local drawnCard = client.getDrawnCard()
    if drawnCard then
        local handX = winW - 150
        local handY = 300

        local tri = draw.getTriangleZonePoints(handX, handY, cardW, cardH, 0, 50, 40)
        drawnCard.hover = draw.pointInTriangle(mx, my, unpack(tri))
    end
end

function draw.draw()

    for i, msg in ipairs(client.debugMessages) do
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(msg, 10, 10 + (i - 1) * 18)
    end

    local state = client.getState()
    if not state or not state.grid then return end

    local winW, winH = love.graphics.getDimensions()
    local offsetX = (winW - cellSize * GRID_SIZE) / 2
    local offsetY = (winH - cellSize * GRID_SIZE) / 2

    if not state.grid[1] then
        love.graphics.setColor(1, 0.5, 0)
        love.graphics.print("Сітка ще не ініціалізована", 10, 70)
        return
    end

    -- Поле
    for y = 1, GRID_SIZE do
        local row = state.grid[y]
        if row then
            for x = 1, GRID_SIZE do
                local cell = row[x]
                if cell then
                    local drawX = offsetX + (x - 1) * cellSize
                    local drawY = offsetY + (y - 1) * cellSize
                    local texture = images.tiles[cell.type]
                    local rotation = math.rad(cell.rotation or 0)

                    if texture then
                        love.graphics.setColor(1, 1, 1)
                        love.graphics.draw(texture, drawX + cellSize / 2, drawY + cellSize / 2, rotation,
                            cellSize / texture:getWidth(),
                            cellSize / texture:getHeight(),
                            texture:getWidth() / 2, texture:getHeight() / 2)
                    else
                        -- Рисуем серую сетку для пустых ячеек
                        love.graphics.setColor(0.2, 0.2, 0.2, 0.3)
                        love.graphics.rectangle("line", drawX, drawY, cellSize, cellSize)
                    end
                end
            end
        end
    end

    -- Гравці
    for i, p in ipairs(state.players or {}) do
        local px = offsetX + (p.x - 1) * cellSize + cellSize / 2
        local py = offsetY + (p.y - 1) * cellSize + cellSize / 2

        love.graphics.setColor(p.color)
        love.graphics.circle("fill", px, py, cellSize / 4)

        if i == state.currentPlayerIndex then
            if p.turnStage == "move" then
                -- 🔶 Оранжевое кольцо — режим перемещения
                love.graphics.setColor(1, 0.5, 0)
            else
                -- 🟡 Жёлтое кольцо — обычное выделение хода
                love.graphics.setColor(1, 1, 0)
            end
            love.graphics.setLineWidth(3)
            love.graphics.circle("line", px, py, cellSize / 4 + 2)
        end
    end

    -- Витягнута карта
    local drawnCard = client.getDrawnCard()
    if drawnCard then
        local winW, winH = love.graphics.getDimensions()
        local handX = winW - 150
        local handY = 300
        local scale = drawnCard.hover and 1.2 or 1

        draw.drawCard(
            handX,
            handY,
            128, 192,
            0,
            drawnCard.type,
            drawnCard.rotation,
            drawnCard.hover,
            scale
        )
    end

    if selectedCard.type then
        local mx, my = love.mouse.getPosition()
        local gx = math.floor((mx - offsetX) / cellSize) + 1
        local gy = math.floor((my - offsetY) / cellSize) + 1

        if gx >= 1 and gx <= GRID_SIZE and gy >= 1 and gy <= GRID_SIZE then
            local texture = images.tiles[selectedCard.type]
            if texture then
                local drawX = offsetX + (gx - 1) * cellSize + cellSize / 2
                local drawY = offsetY + (gy - 1) * cellSize + cellSize / 2
                local rotation = math.rad(selectedCard.rotation or 0)

                love.graphics.setColor(1, 1, 1, 0.5) -- напівпрозора картка
                love.graphics.draw(texture, drawX, drawY, rotation,
                    cellSize / texture:getWidth(),
                    cellSize / texture:getHeight(),
                    texture:getWidth() / 2, texture:getHeight() / 2)
            end
        end
    end

    -- Карти в руці
    local hand = client.getPlayer() and client.getPlayer().hand or {}
    love.graphics.print("🎴 Карт в руці: " .. tostring(#hand), 20, 50)
    local hoveredCard = nil

    for i, card in ipairs(hand) do
        local handX = winW - 300 + (i - 1) * 40
        local handY = winH - 140 + math.sin(i) * 5
        local angle = math.rad(-30 + i * 10)
        local scale = card.hover and 1.2 or 1

        if card.hover then
            hoveredCard = {
                x = handX,
                y = handY,
                type = card.type,
                rotation = card.rotation,
                angle = angle,
                scale = scale
            }
        else
            draw.drawCard(handX, handY, 128, 192, angle, card.type, card.rotation, false, scale)
        end
    end

    if hoveredCard then
        draw.drawCard(
            hoveredCard.x,
            hoveredCard.y,
            128, 192,
            hoveredCard.angle,
            hoveredCard.type,
            hoveredCard.rotation,
            true,
            hoveredCard.scale
        )
    end

    local dbgY = 600
    for i, msg in ipairs(client.debugMessages or {}) do
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(msg, 10, dbgY)
        dbgY = dbgY + 15
    end

    -- Кнопка "Кінець ходу"
    local endTurnSize = 100
    local endTurnX = 50
    local endTurnY = love.graphics.getHeight() - endTurnSize - 50

    love.graphics.setColor(1, 1, 1)
    if images.endTurn then
        love.graphics.draw(images.endTurn, endTurnX, endTurnY, 0,
            endTurnSize / images.endTurn:getWidth(),
            endTurnSize / images.endTurn:getHeight())
    else
        love.graphics.setColor(0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", endTurnX, endTurnY, endTurnSize, endTurnSize)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Кінець\nходу", endTurnX, endTurnY + 25, endTurnSize, "center")
    end

    -- 🏷️ Відображення метки поточного гравця (для цього клієнта)
    local myId = client.playerId
    if myId then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, 220, 40)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(font)
        love.graphics.print("🎮 Гравець " .. tostring(myId), 20, 10)
    end
end

function draw.drawCard(x, y, w, h, rotation, cardType, cardRotation, isHover, scale)
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(images.cardBack, x, y, rotation,
        (w / images.cardBack:getWidth()) * scale,
        (h / images.cardBack:getHeight()) * scale,
        images.cardBack:getWidth() / 2, images.cardBack:getHeight() / 2)

    if not cardType or not images.tiles[cardType] then return end

    local icon = images.tiles[cardType]
    local iconScaleX = (w * 0.45 * scale) / icon:getWidth()
    local iconScaleY = (h * 0.27 * scale) / icon:getHeight()
    local offsetX, offsetY = 0, -h * 0.04 * scale

    local cosR = math.cos(rotation)
    local sinR = math.sin(rotation)
    local rx = x + offsetX * cosR - offsetY * sinR
    local ry = y + offsetX * sinR + offsetY * cosR

    love.graphics.draw(icon, rx, ry, rotation, iconScaleX, iconScaleY, icon:getWidth() / 2, icon:getHeight() / 2)

    if isHover then
        local tri = draw.getTriangleZonePoints(x, y, w, h, rotation, 50, 40)
        love.graphics.setColor(1, 0, 0, 0.3)
        love.graphics.polygon("fill", tri)
    end
end

function draw.getTriangleZonePoints(x, y, w, h, rotation, offsetRight, offsetDown)
    local cx, cy = x, y
    local localX = -w / 2
    local localY = -h / 2
    local cosR = math.cos(rotation)
    local sinR = math.sin(rotation)
    local topLeftX = cx + localX * cosR - localY * sinR
    local topLeftY = cy + localX * sinR + localY * cosR
    local sideX = offsetRight * cosR
    local sideY = offsetRight * sinR
    local downX = offsetDown * -sinR
    local downY = offsetDown * cosR
    local p1x = topLeftX
    local p1y = topLeftY
    local p2x = topLeftX + sideX
    local p2y = topLeftY + sideY
    local p3x = topLeftX + downX
    local p3y = topLeftY + downY
    return { p1x, p1y, p2x, p2y, p3x, p3y }
end

function draw.pointInTriangle(px, py, ax, ay, bx, by, cx, cy)
    local v0x, v0y = cx - ax, cy - ay
    local v1x, v1y = bx - ax, by - ay
    local v2x, v2y = px - ax, py - ay

    local dot00 = v0x * v0x + v0y * v0y
    local dot01 = v0x * v1x + v0y * v1y
    local dot02 = v0x * v2x + v0y * v2y
    local dot11 = v1x * v1x + v1y * v1y
    local dot12 = v1x * v2x + v1y * v2y

    local invDenom = 1 / (dot00 * dot11 - dot01 * dot01)
    local u = (dot11 * dot02 - dot01 * dot12) * invDenom
    local v = (dot00 * dot12 - dot01 * dot02) * invDenom

    return (u >= 0) and (v >= 0) and (u + v < 1)
end

function draw.mousepressed(mx, my, button)
    local player = client.getPlayer()
    if not player then return end

    local winW, winH = love.graphics.getDimensions()
    local cardW, cardH = 128, 192

    -- Натискання на карту в руці
    for i, card in ipairs(player.hand) do
        if card.hover and button == 1 then
            selectedCard.type = card.type
            selectedCard.rotation = card.rotation
            selectedFromHand = i
            return
        end
    end

    -- Натискання на витягнуту карту
    local drawnCard = client.getDrawnCard()
    if drawnCard and drawnCard.hover and button == 1 then
        selectedCard.type = drawnCard.type
        selectedCard.rotation = drawnCard.rotation
        selectedFromHand = "drawn"
        logger.log("✅ Клік по drawnCard: " .. selectedCard.type)
        return
    end

    local handZoneX = winW - 320
    local handZoneY = winH - 170
    local handZoneW = 250
    local handZoneH = 200

    -- Заміна карти при повній руці
    if client.getDrawnCard() and button == 1 and player.turnStage == "place" then
        for i, card in ipairs(player.hand) do
            if card.hover then
                logger.log("♻️ Заміна карти у руці: слот " .. i)
                client.send("TAKECARD:" .. tostring(i))
                selectedCard.type = nil
                selectedFromHand = nil
                return
            end
        end
    end

    -- Поворот карти правою кнопкою
    if button == 2 and selectedCard.type then
        selectedCard.rotation = (selectedCard.rotation + 90) % 360
        return
    end

    -- Натискання на поле — спроба поставити карту
    
   local state = client.getState()
    if not state or not state.grid then return end

    local offsetX = (winW - cellSize * GRID_SIZE) / 2
    local offsetY = (winH - cellSize * GRID_SIZE) / 2
    local gx = math.floor((mx - offsetX) / cellSize) + 1
    local gy = math.floor((my - offsetY) / cellSize) + 1

    if gx >= 1 and gx <= GRID_SIZE and gy >= 1 and gy <= GRID_SIZE then
        if selectedCard.type and player.turnStage == "place" then
            local source = selectedFromHand == "drawn" and "D" or tostring(selectedFromHand or 0)
            local msg = string.format("PLACE:%d,%d,%s,%d,%s", gx, gy, selectedCard.type, selectedCard.rotation, source)
            client.send(msg)

            -- обнуляем выбранную карту
            selectedCard.type = nil
            selectedFromHand = nil
            return
        elseif player.turnStage == "move" then
            local msg = string.format("MOVE:%d,%d", gx, gy)
            client.send(msg)
            return
        end
    end

    -- Кнопка "Кінець ходу"
    local endTurnSize = 100
    local endTurnX = 50
    local endTurnY = winH - endTurnSize - 50
    local endTurnW = endTurnSize
    local endTurnH = endTurnSize

    if mx >= endTurnX and mx <= endTurnX + endTurnW and my >= endTurnY and my <= endTurnY + endTurnH then  
            client.send("ENDTURN:")
    end
end

return draw