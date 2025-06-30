-- logger.lua
local logger = {}

local logFile

function logger.init(path)
    logFile = io.open(path or "log.txt", "w")
    if logFile then
        logger.initialized = true
        logger.log("🚀 Логгер запущено")
    end
end

function logger.log(message)
    local time = os.date("%H:%M:%S")
    local fullMessage = "[" .. time .. "] " .. tostring(message)
    print(fullMessage)  -- опціонально
    if logFile then
        logFile:write(fullMessage .. "\n")
        logFile:flush()
    end
end

return logger