local GRID_SIZE = 25
local cellSize = 32
local tunnelIdCounter = 1
local tunnelStats = {}


local selectedCard = {
    type = nil,
    rotation = 0
}

local cardList = { "straight", "cross", "t", "corner", "deadend", "empty" }

function love.load()
    love.graphics.setBackgroundColor(0.7, 0.7, 0.7)
    love.window.setMode(1080, 720, {resizable = true, minwidth = 300, minheight = 300})

    tiles = {
        straight = love.graphics.newImage("assets/tiles/Straight.jpg"),
        cross = love.graphics.newImage("assets/tiles/Cross.jpg"),
        t = love.graphics.newImage("assets/tiles/T.jpg"),
        corner = love.graphics.newImage("assets/tiles/Corner.jpg"),
        deadend = love.graphics.newImage("assets/tiles/DeadEnd.jpg"),
        empty = love.graphics.newImage("assets/tiles/Empty.jpg"),
        void = nil
    }

    grid = {}
    for y = 1, GRID_SIZE do
        grid[y] = {}
        for x = 1, GRID_SIZE do
            grid[y][x] = {
                type = "void",
                rotation = 0,
                occupied = false
            }
        end
    end

    player = nil
    playerTurnActive = false
    
    images = {
    cardBack = love.graphics.newImage("assets/ui/card_back.png") -- та что ты вырезал
    }

    playerHand = {}

    for i = 1, 6 do
        table.insert(playerHand, {
            type = cardList[math.random(#cardList)],
            x = 0, y = 0,
            hover = false
        })
    end

    selectedFromHand = nil
    drawnCard = nil
end


function love.update(dt)
    local mx, my = love.mouse.getPosition()
    local winW, winH = love.graphics.getDimensions()
    local cardW, cardH = 128, 192

    -- Обновляем положение карт в руке
    for i, card in ipairs(playerHand) do
        local handX = winW - 300 + (i - 1) * 40
        local handY = winH - 140 + math.sin(i) * 5
        local angle = math.rad(-30 + i * 10)

        card.x = handX
        card.y = handY

        local tri = getTriangleZonePoints(handX, handY, cardW, cardH, angle, 50, 40)
        card.hover = pointInTriangle(mx, my, unpack(tri))
    end

    -- Обновляем положение вытянутой карты
    if drawnCard then
        local deckW, deckH = 128, 192
        local handX = winW - 150
        local handY = 300
        local angle = 0

        drawnCard.x = handX
        drawnCard.y = handY

        local tri = getTriangleZonePoints(handX, handY, deckW, deckH, angle, 50, 40)
        drawnCard.hover = pointInTriangle(mx, my, unpack(tri))
    end
end

function drawNewCard()
    if not drawnCard then
        drawnCard = drawRandomCard()
    end
end

function pointInTriangle(px, py, ax, ay, bx, by, cx, cy)
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

function drawRandomCard()
    return {
        type = cardList[math.random(#cardList)],
        x = 0,
        y = 0,
        hover = false,
        rotation = 0
    }
end

function getTriangleZonePoints(x, y, w, h, rotation, offsetRight, offsetDown)
    -- Центр карти
    local cx, cy = x, y

    -- Вектор від центру до верхнього лівого кута
    local localX = -w / 2
    local localY = -h / 2

    -- Обертаємо вектор на заданий кут
    local cosR = math.cos(rotation)
    local sinR = math.sin(rotation)

    -- Отримуємо позицію верхнього лівого кута з урахуванням повороту
    local topLeftX = cx + localX * cosR - localY * sinR
    local topLeftY = cy + localX * sinR + localY * cosR

    -- Вектори по сторонам карти
    local sideX = offsetRight * cosR
    local sideY = offsetRight * sinR
    local downX = offsetDown * -sinR
    local downY = offsetDown * cosR

    -- Три точки трикутника від верхнього лівого кута
    local p1x = topLeftX
    local p1y = topLeftY
    local p2x = topLeftX + sideX
    local p2y = topLeftY + sideY
    local p3x = topLeftX + downX
    local p3y = topLeftY + downY

    return {
        p1x, p1y,
        p2x, p2y,
        p3x, p3y
    }
end

function drawCardWithIcon(x, y, w, h, rotation, cardBackImage, cardType, cardRotation, tilesTable, showIcon, scale)
    scale = scale or 1

    -- Рисуем рубашку карты
    local backW, backH = cardBackImage:getWidth(), cardBackImage:getHeight()
    local scaleX = (w / backW) * scale
    local scaleY = (h / backH) * scale

    rotation = rotation or 0

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(cardBackImage, x, y, rotation,
        scaleX, scaleY,
        backW / 2, backH / 2
    )

    -- Не рисуем иконку, если флаг неактивен или тип не указан
    if not showIcon or not cardType or not tilesTable[cardType] then return end

    -- Подготовка иконки туннеля
    local icon = tilesTable[cardType]
    local iconW, iconH = icon:getWidth(), icon:getHeight()

    -- Настройка масштаба и положения иконки внутри карты
    local iconScaleW = 0.45
    local iconScaleH = 0.27
    local offsetX = 0
    local offsetY = -h * 0.04 * scale  -- масштабируем тоже

    local iconScaleX = (w * iconScaleW * scale) / iconW
    local iconScaleY = (h * iconScaleH * scale) / iconH

    -- Поворот смещения, чтобы иконка учитывала угол карты
    local cosR = math.cos(rotation)
    local sinR = math.sin(rotation)
    local rotatedOffsetX = offsetX * cosR - offsetY * sinR
    local rotatedOffsetY = offsetX * sinR + offsetY * cosR

    -- Рисуем иконку
    love.graphics.draw(icon,
        x + rotatedOffsetX,
        y + rotatedOffsetY,
        rotation,
        iconScaleX, iconScaleY,
        iconW / 2, iconH / 2
    )
end

function getOpenSides(cell)
    local open = {
        straight = {
            [0] = {left=true, right=true},
            [90] = {up=true, down=true},
            [180] = {left=true, right=true},
            [270] = {up=true, down=true}
        },
        cross = {
            [0] = {up=true, down=true, left=true, right=true},
            [90] = {up=true, down=true, left=true, right=true},
            [180] = {up=true, down=true, left=true, right=true},
            [270] = {up=true, down=true, left=true, right=true}
        },
        t = {
            [0] = {left=true, right=true, down=true},
            [90] = {up=true, down=true, right=true},
            [180] = {left=true, right=true, up=true},
            [270] = {up=true, down=true, left=true}
        },
        corner = {
            [0] = {down=true, right=true},
            [90] = {down=true, left=true},
            [180] = {up=true, left=true},
            [270] = {up=true, right=true}
        },
        deadend = {
            [0] = {right=true},
            [90] = {down=true},
            [180] = {left=true},
            [270] = {up=true}
        },
        empty = {
            [0] = {}
        }
    }
    return open[cell.type] and open[cell.type][cell.rotation or 0] or {}
end

function getExitDelta(tileType)
    if tileType == "deadend" then return -1 end
    if tileType == "t" then return 1 end
    if tileType == "cross" then return 2 end
    return 0
end

function mergeTunnels(targetId, otherId)
    for y = 1, GRID_SIZE do
        for x = 1, GRID_SIZE do
            local cell = grid[y][x]
            if cell.tunnelId == otherId then
                cell.tunnelId = targetId
            end
        end
    end
    if tunnelStats[otherId] then
        tunnelStats[targetId].tileCount = tunnelStats[targetId].tileCount + tunnelStats[otherId].tileCount
        tunnelStats[targetId].exitScore = tunnelStats[targetId].exitScore + tunnelStats[otherId].exitScore
        tunnelStats[otherId] = nil
    end
end

function canMove(fromX, fromY, toX, toY)
    local dx, dy = toX - fromX, toY - fromY
    if math.abs(dx) + math.abs(dy) ~= 1 then return false end

    local from = grid[fromY] and grid[fromY][fromX]
    local to = grid[toY] and grid[toY][toX]
    if not from or not to then return false end
    if from.type == "void" or to.type == "void" then return false end

    local fromSides = getOpenSides(from)
    local toSides = getOpenSides(to)

    if dx == 1 then return fromSides.right and toSides.left end
    if dx == -1 then return fromSides.left and toSides.right end
    if dy == 1 then return fromSides.down and toSides.up end
    if dy == -1 then return fromSides.up and toSides.down end

    return false
end

function getConnectedNeighbors(x, y, cardType, rotation)
    local directions = {
        {dx=0, dy=-1, from="up", to="down"},
        {dx=0, dy=1,  from="down", to="up"},
        {dx=-1, dy=0, from="left", to="right"},
        {dx=1, dy=0,  from="right", to="left"}
    }

    local openSides = getOpenSides({type = cardType, rotation = rotation})
    local hasConnection = false

    for _, dir in ipairs(directions) do
        local nx, ny = x + dir.dx, y + dir.dy
        if nx >= 1 and nx <= GRID_SIZE and ny >= 1 and ny <= GRID_SIZE then
            local neighbor = grid[ny][nx]
            if neighbor and neighbor.type ~= "void" then
                local neighborSides = getOpenSides(neighbor)

                local thisSide = openSides[dir.from]
                local neighborSide = neighborSides[dir.to]

                if (thisSide and not neighborSide) or (not thisSide and neighborSide) then
                    return false
                end

                if thisSide and neighborSide then
                    hasConnection = true
                end
            end
        end
    end

    return hasConnection
end

function isPlacementValid(x, y, cardType, rotation)
    if cardType == "empty" then
        local directions = {
            {dx=0, dy=-1, side="down"},
            {dx=0, dy=1,  side="up"},
            {dx=-1, dy=0, side="right"},
            {dx=1, dy=0,  side="left"}
        }
        for _, dir in ipairs(directions) do
            local nx, ny = x + dir.dx, y + dir.dy
            if nx >= 1 and nx <= GRID_SIZE and ny >= 1 and ny <= GRID_SIZE then
                local neighbor = grid[ny][nx]
                if neighbor and neighbor.type ~= "void" then
                    local neighborSides = getOpenSides(neighbor)
                    if neighborSides[dir.side] then
                        return false
                    end
                end
            end
        end
        return true
    end

    local openSides = getOpenSides({type = cardType, rotation = rotation})
    local directions = {
        {dx=0, dy=-1, side="up", opp="down"},
        {dx=0, dy=1,  side="down", opp="up"},
        {dx=-1, dy=0, side="left", opp="right"},
        {dx=1, dy=0,  side="right", opp="left"}
    }

    local totalExitScore = 0
    local overlapCount = 0
    local seenTunnels = {}
    local connected = false

    -- Додаємо нові виходи
    local newExits = 0
    for side, open in pairs(openSides) do
        if open then newExits = newExits + 1 end
    end
    totalExitScore = totalExitScore + newExits

    -- Додаємо існуючі виходи + враховуємо перекриття
    for _, dir in ipairs(directions) do
        local nx, ny = x + dir.dx, y + dir.dy
        if nx >= 1 and nx <= GRID_SIZE and ny >= 1 and ny <= GRID_SIZE then
            local neighbor = grid[ny][nx]
            if neighbor and neighbor.type ~= "void" and neighbor.tunnelId then
                local neighborSides = getOpenSides(neighbor)
                if openSides[dir.side] and neighborSides[dir.opp] then
                    overlapCount = overlapCount + 2  -- 1 новий + 1 сусідній
                    connected = true
                end
                if not seenTunnels[neighbor.tunnelId] then
                    seenTunnels[neighbor.tunnelId] = true
                    totalExitScore = totalExitScore + (tunnelStats[neighbor.tunnelId] and tunnelStats[neighbor.tunnelId].exitScore or 0)
                end
            end
        end
    end

    local netScore = totalExitScore - overlapCount

    if netScore <= 0 then return false end
    return connected
end

function love.mousepressed(mx, my, button)
    local winW, winH = love.graphics.getDimensions()
    local cardSize = 64
    local cardX = winW - cardSize - 20

    -- Выбор карты
    for i, card in ipairs(cardList) do
        local cardY = 20 + (i - 1) * (cardSize + 10)
        if mx >= cardX and mx <= cardX + cardSize and my >= cardY and my <= cardY + cardSize then
            if button == 1 then
                selectedCard.type = card
                selectedCard.rotation = 0
                return
            end
        end
    end

    -- Поворот карты
    if button == 2 and selectedCard.type then
        selectedCard.rotation = (selectedCard.rotation + 90) % 360
        return
    end

    -- Выбор карты из колоды (drawnCard)
    if drawnCard and drawnCard.type and drawnCard.hover and button == 1 then
        selectedCard.type = drawnCard.type
        selectedCard.rotation = drawnCard.rotation or 0
        selectedFromHand = "drawn"
        return
    end

-- Размещение карты
    for i, card in ipairs(playerHand) do
    if card.hover and button == 1 then
        if drawnCard then
            if #playerHand < 6 then
                -- Добавляем в руку, если есть место
                table.insert(playerHand, {
                    type = drawnCard.type,
                    rotation = drawnCard.rotation or 0,
                    x = 0, y = 0,
                    hover = false
                })
            else
                -- Если рука полная — заменяем сразу
                playerHand[i] = {
                    type = drawnCard.type,
                    rotation = drawnCard.rotation or 0,
                    x = 0, y = 0,
                    hover = false
                }
            end

            -- Очищаем состояние
            drawnCard = nil
            selectedCard.type = nil
            selectedCard.rotation = 0
            selectedFromHand = nil
            replacementIndex = nil
            return
        end

        -- Обычный выбор карты из руки
        selectedCard.type = card.type
        selectedCard.rotation = card.rotation or 0
        selectedFromHand = i
        return
    end
end
    if drawnCard and drawnCard.type and #playerHand < 6 and button == 1 then
        local winW, winH = love.graphics.getDimensions()
        local cardW, cardH = 128, 192
        local handY = winH - 140

        -- правая граница — немного правее последней карты
        local startX = winW - 300
        local endX = startX + (#playerHand) * 40 + cardW / 2
        local mx, my = love.mouse.getPosition()

        if mx >= startX and mx <= endX and my >= handY - cardH/2 and my <= handY + cardH/2 then
            table.insert(playerHand, {
                type = drawnCard.type,
                rotation = drawnCard.rotation or 0,
                x = 0, y = 0,
                hover = false
            })
            drawnCard = nil
            selectedCard.type = nil
            selectedCard.rotation = 0
            selectedFromHand = nil
            return
        end
    end

    if selectedCard.type and selectedFromHand then
        local offsetX = (winW - cellSize * GRID_SIZE) / 2
        local offsetY = (winH - cellSize * GRID_SIZE) / 2
        local gridX = math.floor((mx - offsetX) / cellSize) + 1
        local gridY = math.floor((my - offsetY) / cellSize) + 1

        if gridX >= 1 and gridX <= GRID_SIZE and gridY >= 1 and gridY <= GRID_SIZE then
            local newType = selectedCard.type
            local newRot = selectedCard.rotation

            if isPlacementValid(gridX, gridY, newType, newRot) then
                grid[gridY][gridX].type = newType
                grid[gridY][gridX].rotation = newRot
                local neighbors = {}
                for _, dir in ipairs({{0,-1}, {0,1}, {-1,0}, {1,0}}) do
                    local nx, ny = gridX + dir[1], gridY + dir[2]
                    if nx >= 1 and nx <= GRID_SIZE and ny >= 1 and ny <= GRID_SIZE then
                        local neighbor = grid[ny][nx]
                        if neighbor.tunnelId then
                            table.insert(neighbors, neighbor.tunnelId)
                        end
                    end
                end

                local idToUse
                if #neighbors == 0 then
                    idToUse = tunnelIdCounter
                    tunnelIdCounter = tunnelIdCounter + 1
                    tunnelStats[idToUse] = {tileCount = 0, exitScore = 0}
                else
                    idToUse = neighbors[1]
                    for i = 2, #neighbors do
                        if neighbors[i] ~= idToUse then
                            mergeTunnels(idToUse, neighbors[i])
                        end
                    end
                end

                grid[gridY][gridX].tunnelId = idToUse
                tunnelStats[idToUse].tileCount = tunnelStats[idToUse].tileCount + 1
                tunnelStats[idToUse].exitScore = tunnelStats[idToUse].exitScore + getExitDelta(newType)

                -- Удалить карту из руки
                if selectedFromHand == "drawn" then
                    drawnCard = nil
                    selectedFromHand = nil
                else
                    table.remove(playerHand, selectedFromHand)
                    selectedFromHand = nil
                end

                -- Очистить выбор
                selectedCard.type = nil
                selectedCard.rotation = 0
                selectedFromHand = nil
            end
        end
    end

    -- Создание игрока
    local buttonW, buttonH = 160, 40
    local buttonX = 20
    local buttonY = love.graphics.getHeight() - buttonH - 20
    if mx >= buttonX and mx <= buttonX + buttonW and my >= buttonY and my <= buttonY + buttonH then
        if not player then
            local spawnX = math.ceil(GRID_SIZE / 2)
            local spawnY = GRID_SIZE

            local newId = tunnelIdCounter
            tunnelIdCounter = tunnelIdCounter + 1

            grid[spawnY][spawnX] = {
                type = "deadend",
                rotation = 270,
                tunnelId = newId,
                occupied = false
            }

            local openSides = getOpenSides(grid[spawnY][spawnX])
            local exitScore = 0
            for _ in pairs(openSides) do
                exitScore = exitScore + 1
            end

            tunnelStats[newId] = {
                tileCount = 1,
                exitScore = exitScore
            }

            -- ось це треба додати назад
            player = { x = spawnX, y = spawnY }
        end
    return
end

    -- Активация хода игрока
    local turnBtnW, turnBtnH = 160, 40
    local turnBtnX = 200
    local turnBtnY = love.graphics.getHeight() - turnBtnH - 20
    if mx >= turnBtnX and mx <= turnBtnX + turnBtnW and my >= turnBtnY and my <= turnBtnY + turnBtnH then
        if player then
            playerTurnActive = not playerTurnActive
        end
        return
    end

    -- Перемещение игрока
    if playerTurnActive and player and button == 1 then
        local offsetX = (winW - cellSize * GRID_SIZE) / 2
        local offsetY = (winH - cellSize * GRID_SIZE) / 2
        local gridX = math.floor((mx - offsetX) / cellSize) + 1
        local gridY = math.floor((my - offsetY) / cellSize) + 1

        if gridX >= 1 and gridX <= GRID_SIZE and gridY >= 1 and gridY <= GRID_SIZE then
            if canMove(player.x, player.y, gridX, gridY) then
                player.x = gridX
                player.y = gridY
                playerTurnActive = false
            end
        end
    end

    -- Кнопка: Вытянуть карту
    local drawBtnW, drawBtnH = 160, 40
    local drawBtnX = 380
    local drawBtnY = love.graphics.getHeight() - drawBtnH - 20

    if mx >= drawBtnX and mx <= drawBtnX + drawBtnW and my >= drawBtnY and my <= drawBtnY + drawBtnH then
        if not drawnCard then
            drawNewCard()
        end
        return
    end

    local winW, winH = love.graphics.getDimensions()
    local offsetXGrid = (winW - cellSize * GRID_SIZE) / 2
    local offsetYGrid = (winH - cellSize * GRID_SIZE) / 2

-- Сброс карты, если нажали вне поля и карта выбрана
if selectedFromHand and not (
    mx >= offsetXGrid and mx <= offsetXGrid + GRID_SIZE * cellSize and
    my >= offsetYGrid and my <= offsetYGrid + GRID_SIZE * cellSize
) then
    selectedCard.type = nil
    selectedCard.rotation = 0
    selectedFromHand = nil
end

    -- Сброс вытянутой карты
    local deckW, deckH = 128, 192
    local deckX = love.graphics.getWidth() - 150
    local deckY = 300

    local winW, winH = love.graphics.getDimensions()
    local offsetXGrid = (winW - cellSize * GRID_SIZE) / 2
    local offsetYGrid = (winH - cellSize * GRID_SIZE) / 2

    local inGrid = (
        mx >= offsetXGrid and mx <= offsetXGrid + GRID_SIZE * cellSize and
        my >= offsetYGrid and my <= offsetYGrid + GRID_SIZE * cellSize
    )

    if drawnCard and not inGrid and not (
        mx >= deckX - deckW/2 and mx <= deckX + deckW/2 and
        my >= deckY - deckH/2 and my <= deckY + deckH/2
    ) and not selectedFromHand then
        drawnCard = nil
    end
end

function drawCardPreview(cardType, x, y, size, rotation)
    local texture = tiles[cardType] or tiles.empty
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(texture, x + size / 2, y + size / 2, math.rad(rotation),
        size / texture:getWidth(),
        size / texture:getHeight(),
        texture:getWidth() / 2,
        texture:getHeight() / 2)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("line", x, y, size, size)
end

function love.draw()
    local cardSize = 32
    local winW, winH = love.graphics.getDimensions()
    local offsetX = (winW - cellSize * GRID_SIZE) / 2
    local offsetY = (winH - cellSize * GRID_SIZE) / 2

    for y = 1, GRID_SIZE do
        for x = 1, GRID_SIZE do
            local cell = grid[y][x]
            local drawX = offsetX + (x - 1) * cellSize
            local drawY = offsetY + (y - 1) * cellSize
            local texture = tiles[cell.type]
            local rotation = math.rad(cell.rotation or 0)

            if texture then
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(texture, drawX + cellSize / 2, drawY + cellSize / 2,
                    rotation,
                    cellSize / texture:getWidth(),
                    cellSize / texture:getHeight(),
                    texture:getWidth() / 2,
                    texture:getHeight() / 2)
            end

            -- Рамки
            local neighbors = {
                up = (y > 1) and grid[y - 1][x] or nil,
                down = (y < GRID_SIZE) and grid[y + 1][x] or nil,
                left = (x > 1) and grid[y][x - 1] or nil,
                right = (x < GRID_SIZE) and grid[y][x + 1] or nil
            }

            love.graphics.setColor(0, 0, 0)
            if not neighbors.up or neighbors.up.type == "void" then
                love.graphics.line(drawX, drawY, drawX + cellSize, drawY)
            end
            if not neighbors.down or neighbors.down.type == "void" then
                love.graphics.line(drawX, drawY + cellSize, drawX + cellSize, drawY + cellSize)
            end
            if not neighbors.left or neighbors.left.type == "void" then
                love.graphics.line(drawX, drawY, drawX, drawY + cellSize)
            end
            if not neighbors.right or neighbors.right.type == "void" then
                love.graphics.line(drawX + cellSize, drawY, drawX + cellSize, drawY + cellSize)
            end
        end
    end

    -- Панель карт
    -- local cardSize = 64
    -- local cardX = winW - cardSize - 20
    -- for i, card in ipairs(cardList) do
    --    local cardY = 20 + (i - 1) * (cardSize + 10)
    --    drawCardPreview(card, cardX, cardY, cardSize, 0)
    --end

    -- Превью выбранной карты
    if selectedCard.type then
        local mx, my = love.mouse.getPosition()
        drawCardPreview(selectedCard.type, mx - cardSize / 2, my - cardSize / 2, cardSize, selectedCard.rotation)
    end

    -- Игрок
    if player then
        local px = offsetX + (player.x - 1) * cellSize + cellSize / 2
        local py = offsetY + (player.y - 1) * cellSize + cellSize / 2
        if playerTurnActive then
            love.graphics.setColor(1, 1, 0)
        else
            love.graphics.setColor(1, 0, 0)
        end
        love.graphics.circle("fill", px, py, cellSize / 4)
    end

    -- Кнопки
    love.graphics.setFont(love.graphics.newFont(16))

    love.graphics.setColor(0.2, 0.6, 0.2)
    love.graphics.rectangle("fill", 20, winH - 60, 160, 40, 10, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Создать игрока", 20, winH - 50, 160, "center")

    love.graphics.setColor(0.2, 0.4, 0.8)
    love.graphics.rectangle("fill", 200, winH - 60, 160, 40, 10, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Ход игрока", 200, winH - 50, 160, "center")

    -- Вытянутая карта (drawnCard)
    if drawnCard then
        local angle = 0
        if not drawnCard.hover then
            drawCardWithIcon(drawnCard.x, drawnCard.y, 128, 192, angle, images.cardBack, drawnCard.type, drawnCard.rotation, tiles, true, 1)
        else
            drawCardWithIcon(drawnCard.x, drawnCard.y, 128, 192, angle, images.cardBack, drawnCard.type, drawnCard.rotation, tiles, true, 1.2)
            local tri = getTriangleZonePoints(drawnCard.x, drawnCard.y, 128, 192, angle, 50, 40)
            love.graphics.setColor(1, 0, 0, 0.3)
            love.graphics.polygon("fill", tri)
        end
    end
    -- Рисуем руку игрока
    local cardW, cardH = 128, 192

    -- Сначала рисуем все НЕ наведённые карты
    for i, card in ipairs(playerHand) do
        local angle = math.rad(-30 + i * 10)
        if not card.hover then
            drawCardWithIcon(card.x, card.y, cardW, cardH, angle,
                images.cardBack, card.type, card.rotation, tiles, true, 1)
        end
    end

    -- Потом наведённые — они сверху и масштабируются
    for i, card in ipairs(playerHand) do
        local angle = math.rad(-30 + i * 10)
        if card.hover then
            drawCardWithIcon(card.x, card.y, cardW, cardH, angle,
                images.cardBack, card.type, card.rotation, tiles, true, 1.2)

                    local tri = getTriangleZonePoints(card.x, card.y, cardW, cardH, angle, 50, 40)
                    love.graphics.setColor(1, 0, 0, 0.3)
                    love.graphics.polygon("fill", tri)
        end
    end

        -- Кнопка: Вытянуть карту
    love.graphics.setColor(0.8, 0.5, 0.1)
    love.graphics.rectangle("fill", 380, winH - 60, 160, 40, 10, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Вытянуть карту", 380, winH - 50, 160, "center")

    if player then
        local tile = grid[player.y][player.x]
        love.graphics.setColor(0, 0, 0)
        love.graphics.print("Tile ID: " .. (tile.tunnelId or "nil") .. 
        ", ExitScore: " .. (tunnelStats[tile.tunnelId] and tunnelStats[tile.tunnelId].exitScore or "nil"), 20, 20)
    end
end