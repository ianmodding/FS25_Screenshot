ScreenshotColorAdjustment = {
    applyDelayMs = 120,
    rescanIntervalMs = 1000,
    values = {},
    adjustmentKeys = {
        "contrastDelta",
        "brightnessDayDelta",
        "brightnessNightDelta",
        "saturationDayDelta",
        "saturationNightDelta",
        "temperatureDayDelta",
        "temperatureNightDelta",
        "gammaDayDelta",
        "gammaNightDelta",
        "shadowBrightnessDayDelta"
    },
    internalRanges = {
        contrastDelta = {-50, 65},
        brightnessDayDelta = {-60, 100},
        brightnessNightDelta = {-60, 100},
        saturationDayDelta = {-100, 100},
        saturationNightDelta = {-100, 100},
        temperatureDayDelta = {-60, 120},
        temperatureNightDelta = {-60, 120},
        gammaDayDelta = {-30, 50},
        gammaNightDelta = {-30, 50},
        shadowBrightnessDayDelta = {-100, 50}
    },
    colorGroups = {"global", "shadows", "midtones", "highlights"},
    colorOperations = {"saturation", "contrast", "gamma", "gain"}
}

function ScreenshotColorAdjustment:getValue(key)
    return self.values[key] or 0
end

function ScreenshotColorAdjustment:setValue(key, value)
    if self.values[key] == nil then
        return false
    end

    value = math.floor(math.max(-100, math.min(100, value)) + 0.5)
    if self.values[key] == value then
        return false
    end

    self.values[key] = value
    if not self.applyPending then
        self.applyDelay = self.applyDelayMs
    end
    self.applyPending = true
    return true
end

function ScreenshotColorAdjustment:reset()
    for _, key in ipairs(self.adjustmentKeys) do
        self.values[key] = 0
    end

    self.applyPending = false
    self.applyDelay = 0
    self:applyProfiles()
end

function ScreenshotColorAdjustment:update(dt)
    if not self.active then
        return
    end

    if self.applyPending then
        self.applyDelay = math.max(self.applyDelay - dt, 0)
        if self.applyDelay == 0 then
            self:flushPending()
        end
    end

    if self.rescanOnUpdate then
        self.rescanDelay = math.max(self.rescanDelay - dt, 0)
        if self.rescanDelay == 0 then
            self.rescanDelay = self.rescanIntervalMs
            self:refreshProfiles()
        end
    end
end

function ScreenshotColorAdjustment:flushPending()
    if not self.active or not self.applyPending then
        return
    end

    self.applyPending = false
    self.applyDelay = 0
    self:applyProfiles()
end

function ScreenshotColorAdjustment:getInternalValue(key)
    local value = self:getValue(key)
    local range = self.internalRanges[key]
    if range == nil then
        return value
    end

    if value < 0 then
        return value * -range[1] / 100
    end

    return value * range[2] / 100
end

function ScreenshotColorAdjustment:beginSession(environment, rescanOnUpdate)
    if environment == nil or XMLFile == nil then
        print("[FS25 Screenshot] Color adjustments are unavailable in this mission.")
        return false
    end

    self.environment = environment
    self.activeProfiles = {}
    self.allProfiles = {}
    self.profileLookup = {}
    self.generatedSources = {}
    self.generatedFiles = {}
    self.generatedFileLookup = {}
    self.nextFileId = 0
    self.applyPending = false
    self.applyDelay = 0
    self.rescanOnUpdate = rescanOnUpdate == true
    self.rescanDelay = self.rescanIntervalMs
    self.active = true
    self.outputDirectory = getUserProfileAppPath() .. "modSettings/FS25_Screenshot/colorGrading/"

    for _, key in ipairs(self.adjustmentKeys) do
        self.values[key] = 0
    end

    createFolder(self.outputDirectory)
    self:refreshProfiles()

    if #self.activeProfiles == 0 then
        print("[FS25 Screenshot] No color-grading profiles were found for this map.")
        self.active = false
        self.rescanOnUpdate = false
        return false
    end

    return true
end

function ScreenshotColorAdjustment:refreshProfiles()
    if not self.active or self.environment == nil then
        return
    end

    self.applyPending = false
    self.applyDelay = 0
    self.activeProfiles = {}
    local visited = {}
    self:scanTable(self.environment.lighting, "environment.lighting", 0, visited)
    self:scanTable(self.environment.baseLighting, "environment.baseLighting", 0, visited)
    if #self.activeProfiles > 0 then
        self:classifyProfiles()
        self:applyProfiles()
    end
end

function ScreenshotColorAdjustment:scanTable(value, path, depth, visited)
    if type(value) ~= "table" or depth > 7 or visited[value] then
        return
    end

    visited[value] = true
    for key, child in pairs(value) do
        local childPath = path .. "." .. tostring(key)
        if type(child) == "table" then
            self:scanTable(child, childPath, depth + 1, visited)
        elseif type(child) == "string" then
            local normalizedPath = childPath:lower()
            local normalizedFilename = child:lower():gsub("\\", "/")
            local isColorGrading = normalizedPath:find("colorgrading", 1, true) ~= nil
                or normalizedPath:find("color_grading", 1, true) ~= nil
                or normalizedFilename:find("colorgrading", 1, true) ~= nil
                or normalizedFilename:find("color_grading", 1, true) ~= nil

            if isColorGrading and normalizedFilename:sub(-4) == ".xml" then
                self:registerProfile(value, key, child, childPath)
            end
        end
    end
end

function ScreenshotColorAdjustment:registerProfile(container, key, filename, path)
    local containerLookup = self.profileLookup[container]
    if containerLookup == nil then
        containerLookup = {}
        self.profileLookup[container] = containerLookup
    end

    local profile = containerLookup[key]
    if profile == nil then
        local generatedSource = self.generatedSources[filename]
        profile = {
            container = container,
            key = key,
            originalFilename = generatedSource ~= nil and generatedSource.filename or filename,
            path = path
        }
        containerLookup[key] = profile
        table.insert(self.allProfiles, profile)
    end

    profile.timeValue = self:getSlotTime(container)
    table.insert(self.activeProfiles, profile)
end

function ScreenshotColorAdjustment:getSlotTime(container)
    local timeKeys = {"timeHours", "time", "dayTime", 1}
    for _, key in ipairs(timeKeys) do
        if type(container[key]) == "number" then
            return container[key]
        end
    end

    return nil
end

function ScreenshotColorAdjustment:normalizeTime(value, maximum)
    if maximum > 90000 then
        return (value / (60 * 60 * 1000)) % 24
    elseif maximum > 1500 then
        return (value / (60 * 60)) % 24
    elseif maximum > 25 then
        return (value / 60) % 24
    elseif maximum <= 1 then
        return value * 24
    end

    return value % 24
end

function ScreenshotColorAdjustment:classifyProfiles()
    local maximumTime = 0
    for _, profile in ipairs(self.activeProfiles) do
        if profile.timeValue ~= nil then
            maximumTime = math.max(maximumTime, profile.timeValue)
        end
    end

    for _, profile in ipairs(self.activeProfiles) do
        local normalizedFilename = profile.originalFilename:lower():gsub("\\", "/")
        if normalizedFilename:find("night", 1, true) ~= nil or normalizedFilename:find("nacht", 1, true) ~= nil then
            profile.period = "night"
        elseif normalizedFilename:find("day", 1, true) ~= nil or normalizedFilename:find("tag", 1, true) ~= nil then
            profile.period = "day"
        elseif profile.timeValue ~= nil and maximumTime > 0 then
            local hour = self:normalizeTime(profile.timeValue, maximumTime)
            profile.period = hour >= 6 and hour < 21 and "day" or "night"
        else
            local hour = self.environment.currentHour or 12
            profile.period = hour >= 6 and hour < 21 and "day" or "night"
        end
    end
end

function ScreenshotColorAdjustment:hasAdjustments(period)
    if self:getValue("contrastDelta") ~= 0 then
        return true
    end

    if period == "night" then
        return self:getValue("brightnessNightDelta") ~= 0
            or self:getValue("saturationNightDelta") ~= 0
            or self:getValue("temperatureNightDelta") ~= 0
            or self:getValue("gammaNightDelta") ~= 0
    end

    return self:getValue("brightnessDayDelta") ~= 0
        or self:getValue("saturationDayDelta") ~= 0
        or self:getValue("temperatureDayDelta") ~= 0
        or self:getValue("gammaDayDelta") ~= 0
        or self:getValue("shadowBrightnessDayDelta") ~= 0
end

function ScreenshotColorAdjustment:getProfileFilename(filename, period)
    local keyParts = {filename, period}
    for _, adjustmentKey in ipairs(self.adjustmentKeys) do
        table.insert(keyParts, tostring(self:getValue(adjustmentKey)))
    end
    local cacheKey = table.concat(keyParts, "|")
    local cachedFilename = self.generatedFileLookup[cacheKey]
    if cachedFilename ~= nil then
        return cachedFilename
    end

    local sourceFilename = filename
    if not fileExists(sourceFilename) then
        local resolvedFilename = Utils.getFilename(sourceFilename, "")
        if resolvedFilename == nil or not fileExists(resolvedFilename) then
            Logging.warning("[FS25 Screenshot] Cannot find color-grading profile '%s'.", tostring(filename))
            return nil
        end
        sourceFilename = resolvedFilename
    end

    self.nextFileId = self.nextFileId + 1
    local outputFilename = self.outputDirectory .. string.format("profile_%05d.xml", self.nextFileId)
    if not self:createModifiedProfile(sourceFilename, outputFilename, period) then
        return nil
    end

    self.generatedFileLookup[cacheKey] = outputFilename
    self.generatedSources[outputFilename] = {filename = filename, period = period}
    table.insert(self.generatedFiles, outputFilename)
    return outputFilename
end

function ScreenshotColorAdjustment:getOperationFactor(key)
    return 1 + self:getInternalValue(key) / 100
end

function ScreenshotColorAdjustment:applyTemperature(rgb, key)
    local components = {}
    for component in string.gmatch(rgb or "", "%S+") do
        local number = tonumber(component)
        if number ~= nil then
            table.insert(components, number)
        end
    end
    if #components < 3 then
        components = {1, 1, 1}
    end

    local temperature = self:getInternalValue(key) / 120
    local red = math.max(0.01, 1 - temperature * 0.15)
    local green = math.max(0.01, 1 - temperature * 0.02)
    local blue = math.max(0.01, 1 + temperature * 0.15)
    return string.format("%.9g %.9g %.9g", components[1] * red, components[2] * green, components[3] * blue)
end

function ScreenshotColorAdjustment:createModifiedProfile(sourceFilename, outputFilename, period)
    local sourceXML = XMLFile.loadIfExists("screenshotColorSource", sourceFilename)
    if sourceXML == nil then
        Logging.warning("[FS25 Screenshot] Could not load color-grading profile '%s'.", tostring(sourceFilename))
        return false
    end

    local outputXML = XMLFile.create("screenshotColorOutput", outputFilename, "colorGrading")
    if outputXML == nil then
        sourceXML:delete()
        Logging.warning("[FS25 Screenshot] Could not create adjusted color-grading profile '%s'.", outputFilename)
        return false
    end

    outputXML:setFloat("colorGrading#shadowsMaxLuminance", sourceXML:getFloat("colorGrading#shadowsMaxLuminance", 0.25))
    outputXML:setFloat("colorGrading#highlightsMinLuminance", sourceXML:getFloat("colorGrading#highlightsMinLuminance", 0.85))

    local isNight = period == "night"
    local saturationKey = isNight and "saturationNightDelta" or "saturationDayDelta"
    local brightnessKey = isNight and "brightnessNightDelta" or "brightnessDayDelta"
    local temperatureKey = isNight and "temperatureNightDelta" or "temperatureDayDelta"
    local gammaKey = isNight and "gammaNightDelta" or "gammaDayDelta"
    local operationFactors = {
        saturation = self:getOperationFactor(saturationKey),
        contrast = self:getOperationFactor("contrastDelta"),
        gamma = self:getOperationFactor(gammaKey),
        gain = self:getOperationFactor(brightnessKey)
    }

    for _, groupName in ipairs(self.colorGroups) do
        for _, operationName in ipairs(self.colorOperations) do
            local key = string.format("colorGrading.%s.%s", groupName, operationName)
            local rgb = sourceXML:getString(key .. "#rgb", "1 1 1")
            local scale = sourceXML:getFloat(key .. "#scale", 1)

            if groupName == "global" then
                local factor = operationFactors[operationName]
                if factor ~= nil then
                    scale = scale * factor
                    scale = operationName == "gamma" and math.max(0.01, scale) or math.max(0, scale)
                end

                if operationName == "gain" then
                    rgb = self:applyTemperature(rgb, temperatureKey)
                end
            end

            if period == "day" and groupName == "shadows" and operationName == "gain" then
                scale = math.max(0, scale * self:getOperationFactor("shadowBrightnessDayDelta"))
            end

            outputXML:setString(key .. "#rgb", rgb)
            outputXML:setFloat(key .. "#scale", scale)
        end
    end

    outputXML:save()
    outputXML:delete()
    sourceXML:delete()
    return true
end

function ScreenshotColorAdjustment:applyProfiles()
    if not self.active then
        return
    end

    for _, profile in ipairs(self.activeProfiles) do
        local filename = profile.originalFilename
        if self:hasAdjustments(profile.period) then
            filename = self:getProfileFilename(profile.originalFilename, profile.period) or profile.originalFilename
        end
        profile.container[profile.key] = filename
    end

    self:refreshEnvironment()
end

function ScreenshotColorAdjustment:refreshEnvironment()
    if self.environment ~= nil then
        self.environment:update(1, true)
        if self.environment.lighting ~= nil then
            self.environment.lighting:update(1, true)
        end
        self:refreshCurrentColorGrading()
    end
end

function ScreenshotColorAdjustment:refreshCurrentColorGrading()
    if type(setColorGradingSettings) ~= "function" then
        if not self.nativeRefreshWarningLogged then
            Logging.warning("[FS25 Screenshot] Native color-grading refresh is unavailable.")
            self.nativeRefreshWarningLogged = true
        end
        return false
    end

    local entries = {}
    local maximumTime = 0
    for _, profile in ipairs(self.activeProfiles) do
        if profile.timeValue ~= nil then
            local path = profile.path:lower()
            local filename = profile.container[profile.key]
            if type(filename) == "string" then
                table.insert(entries, {
                    time = profile.timeValue,
                    filename = filename,
                    isColorGradingData = path:find("colorgradingdata", 1, true) ~= nil
                })
            end
        end
    end

    local hasColorGradingData = false
    for _, entry in ipairs(entries) do
        if entry.isColorGradingData then
            hasColorGradingData = true
            break
        end
    end

    if hasColorGradingData then
        local filteredEntries = {}
        for _, entry in ipairs(entries) do
            if entry.isColorGradingData then
                table.insert(filteredEntries, entry)
            end
        end
        entries = filteredEntries
    end

    if #entries == 0 then
        return false
    end

    for _, entry in ipairs(entries) do
        maximumTime = math.max(maximumTime, entry.time)
    end

    for _, entry in ipairs(entries) do
        entry.time = self:normalizeTime(entry.time, maximumTime)
    end
    table.sort(entries, function(a, b)
        return a.time < b.time
    end)

    if #entries == 1 then
        setColorGradingSettings(entries[1].filename, entries[1].filename, 0)
        return true
    end

    local dayTime = self.environment.dayTime
    local currentHour = type(dayTime) == "number"
        and self:normalizeTime(dayTime, dayTime)
        or self.environment.currentHour or 12
    local lowerEntry = nil
    local upperEntry = nil
    local lowerTime = nil
    local upperTime = nil

    for index = 1, #entries - 1 do
        if currentHour >= entries[index].time and currentHour <= entries[index + 1].time then
            lowerEntry = entries[index]
            upperEntry = entries[index + 1]
            lowerTime = lowerEntry.time
            upperTime = upperEntry.time
            break
        end
    end

    if lowerEntry == nil then
        lowerEntry = entries[#entries]
        upperEntry = entries[1]
        lowerTime = lowerEntry.time
        upperTime = upperEntry.time + 24
        if currentHour < upperEntry.time then
            currentHour = currentHour + 24
        end
    end

    local blendWeight = 0
    local duration = upperTime - lowerTime
    if duration > 0 then
        blendWeight = math.max(0, math.min(1, (currentHour - lowerTime) / duration))
    end

    setColorGradingSettings(lowerEntry.filename, upperEntry.filename, blendWeight)
    return true
end

function ScreenshotColorAdjustment:endSession()
    if not self.active then
        return
    end

    for _, profile in ipairs(self.allProfiles) do
        if type(profile.container) == "table" and profile.key ~= nil then
            profile.container[profile.key] = profile.originalFilename
        end
    end

    self:refreshEnvironment()

    for _, filename in ipairs(self.generatedFiles) do
        if fileExists(filename) then
            deleteFile(filename)
        end
    end

    self.active = false
    self.applyPending = false
    self.applyDelay = 0
    self.rescanOnUpdate = false
    self.rescanDelay = 0
    self.environment = nil
    self.activeProfiles = {}
    self.allProfiles = {}
    self.profileLookup = {}
    self.generatedSources = {}
    self.generatedFiles = {}
    self.generatedFileLookup = {}
end
