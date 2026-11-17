ScreenshotModeOverlay = {}

local ScreenshotModeOverlay_mt = Class(ScreenshotModeOverlay, ScreenElement)
ScreenshotModeOverlay.COLOR_PANEL_X = 0.72
ScreenshotModeOverlay.COLOR_PANEL_WIDTH = 0.28
ScreenshotModeOverlay.COLOR_SLIDER_MARKER_RED = 184 / 255
ScreenshotModeOverlay.COLOR_SLIDER_MARKER_GREEN = 249 / 255
ScreenshotModeOverlay.COLOR_SLIDER_X = 0.755
ScreenshotModeOverlay.COLOR_SLIDER_WIDTH = 0.215
ScreenshotModeOverlay.COLOR_SLIDER_START_Y = 0.835
ScreenshotModeOverlay.COLOR_SLIDER_STEP_Y = 0.077
ScreenshotModeOverlay.COLOR_RESET_X = 0.755
ScreenshotModeOverlay.COLOR_RESET_Y = 0.055
ScreenshotModeOverlay.COLOR_RESET_WIDTH = 0.215
ScreenshotModeOverlay.COLOR_RESET_HEIGHT = 0.04
ScreenshotModeOverlay.CAMERA_ZOOM_FACTOR = 1.1
ScreenshotModeOverlay.CAMERA_MIN_ZOOM_RATIO = 0.25
ScreenshotModeOverlay.CAMERA_MAX_ZOOM_RATIO = 2
ScreenshotModeOverlay.CAMERA_BASE_SPEED = 5
ScreenshotModeOverlay.CAMERA_SPEED_MULTIPLIERS = {0.25, 0.5, 1, 1.5, 2}
ScreenshotModeOverlay.CAMERA_SPEED_OPTIONS = {"25%", "50%", "100%", "150%", "200%"}
ScreenshotModeOverlay.DOF_FOCUS_MIN = 0.5
ScreenshotModeOverlay.DOF_FOCUS_MAX = 100
ScreenshotModeOverlay.DOF_FOCUS_SLIDER_Y = 0.75
ScreenshotModeOverlay.DOF_STRENGTH_SLIDER_Y = 0.57

ScreenshotModeOverlay.COLOR_SLIDERS = {
    {key = "contrastDelta", textKey = "FS25_SCREENSHOT_COLOR_CONTRAST"},
    {key = "brightnessDayDelta", textKey = "FS25_SCREENSHOT_COLOR_BRIGHTNESS_DAY"},
    {key = "brightnessNightDelta", textKey = "FS25_SCREENSHOT_COLOR_BRIGHTNESS_NIGHT"},
    {key = "saturationDayDelta", textKey = "FS25_SCREENSHOT_COLOR_SATURATION_DAY"},
    {key = "saturationNightDelta", textKey = "FS25_SCREENSHOT_COLOR_SATURATION_NIGHT"},
    {key = "temperatureDayDelta", textKey = "FS25_SCREENSHOT_COLOR_TEMPERATURE_DAY"},
    {key = "temperatureNightDelta", textKey = "FS25_SCREENSHOT_COLOR_TEMPERATURE_NIGHT"},
    {key = "gammaDayDelta", textKey = "FS25_SCREENSHOT_COLOR_GAMMA_DAY"},
    {key = "gammaNightDelta", textKey = "FS25_SCREENSHOT_COLOR_GAMMA_NIGHT"},
    {key = "shadowBrightnessDayDelta", textKey = "FS25_SCREENSHOT_COLOR_SHADOWS_DAY"}
}

function ScreenshotModeOverlay.new(target, customMt)
    return ScreenElement.new(target, customMt or ScreenshotModeOverlay_mt)
end

function ScreenshotModeOverlay:onOpen()
    ScreenshotModeOverlay:superClass().onOpen(self)

    local environment = g_currentMission.environment
    self.weatherOptions = {
        g_i18n:getText("FS25_SCREENSHOT_WEATHER_SUN"),
        g_i18n:getText("FS25_SCREENSHOT_WEATHER_RAIN"),
        g_i18n:getText("FS25_SCREENSHOT_WEATHER_CLOUDY"),
        g_i18n:getText("FS25_SCREENSHOT_WEATHER_HAIL")
    }
    self.seasonPeriodOptions = {
        g_i18n:getText("FS25_SCREENSHOT_SEASON_EARLY_SPRING"),
        g_i18n:getText("FS25_SCREENSHOT_SEASON_MID_SPRING"),
        g_i18n:getText("FS25_SCREENSHOT_SEASON_LATE_SPRING"),
        g_i18n:getText("FS25_SCREENSHOT_SEASON_EARLY_SUMMER"),
        g_i18n:getText("FS25_SCREENSHOT_SEASON_MID_SUMMER"),
        g_i18n:getText("FS25_SCREENSHOT_SEASON_LATE_SUMMER"),
        g_i18n:getText("FS25_SCREENSHOT_SEASON_EARLY_AUTUMN"),
        g_i18n:getText("FS25_SCREENSHOT_SEASON_MID_AUTUMN"),
        g_i18n:getText("FS25_SCREENSHOT_SEASON_LATE_AUTUMN"),
        g_i18n:getText("FS25_SCREENSHOT_SEASON_EARLY_WINTER"),
        g_i18n:getText("FS25_SCREENSHOT_SEASON_MID_WINTER"),
        g_i18n:getText("FS25_SCREENSHOT_SEASON_LATE_WINTER")
    }
    self.weatherData = {
        {typeName = "SUN", variation = 1},
        {typeName = "RAIN", variation = 1},
        {typeName = "CLOUDY", variation = 1},
        {typeName = "HAIL", variation = 1}
    }
    self.dayTimeOptions = {}
    for hour = 0, 23 do
        self.dayTimeOptions[hour + 1] = string.format("%02d:00", hour)
    end

    self.currentWeather = 1
    self.currentDayTime = math.floor(environment.currentHour) + 1
    self.currentSeasonPeriod = environment.currentPeriod
    self.weather:setTexts(self.weatherOptions)
    self.seasonPeriod:setTexts(self.seasonPeriodOptions)
    self.dayTime:setTexts(self.dayTimeOptions)
    self.weather:setState(self.currentWeather, true, false)
    self.seasonPeriod:setState(self.currentSeasonPeriod, true, false)
    self.dayTime:setState(self.currentDayTime, true, false)
    self.cameraSpeed:setTexts(self.CAMERA_SPEED_OPTIONS)
    self.cameraSpeed:setState(3, true, false)
    self.cameraSpeedMultiplier = self.CAMERA_SPEED_MULTIPLIERS[3]
    self.hideScreenshotUi:setIsChecked(true, true, false)
    self.captureHideInterface = true
    self.showDepthOfFieldControls = false
    self.depthOfFieldFocusDistance = 5
    self.depthOfFieldStrength = 0
    self.depthOfFieldApiAvailable = g_depthOfFieldManager ~= nil
        and type(g_depthOfFieldManager.createInfo) == "function"
        and type(g_depthOfFieldManager.applyInfo) == "function"
        and type(g_depthOfFieldManager.reset) == "function"
    self.canAdjustDepthOfField = false
    self.depthOfFieldButton:setDisabled(true)
    self.depthOfFieldWarning:setVisible(not self.depthOfFieldApiAvailable)

    self.isMultiplayer = g_currentMission.missionDynamicInfo.isMultiplayer
    self.canChangeEnvironment = not self.isMultiplayer and self:backupEnvironment()
    self.weather:setDisabled(not self.canChangeEnvironment)
    self.seasonPeriod:setDisabled(not self.canChangeEnvironment)
    self.dayTime:setDisabled(not self.canChangeEnvironment)
    self.multiplayerWarning:setVisible(self.isMultiplayer)
    self.backupWarning:setVisible(not self.isMultiplayer and not self.canChangeEnvironment)

    self.canAdjustColor = ScreenshotColorAdjustment:beginSession(environment, self.isMultiplayer)
    self.colorWarning:setVisible(not self.canAdjustColor)
    self.showColorControls = false

    self.controlledVehicle = nil
    if g_localPlayer ~= nil and type(g_localPlayer.getCurrentVehicle) == "function" then
        self.controlledVehicle = g_localPlayer:getCurrentVehicle()
    end
    self:initializeVehicleControls()

    if self.canChangeEnvironment then
        g_currentMission:setManualPause(true)
        self.pausedByPhotoMode = true
    end

    if g_localPlayer == nil or type(g_localPlayer.getCurrentCameraNode) ~= "function" then
        print("[FS25 Screenshot] The local player is not available.")
        return
    end

    self.previousCamera = g_localPlayer:getCurrentCameraNode()
    if self.previousCamera == nil then
        print("[FS25 Screenshot] Could not find the current camera.")
        return
    end

    local previousCameraInfo = g_cameraManager.cameraInfo ~= nil
        and g_cameraManager.cameraInfo[self.previousCamera]
        or nil
    self.previousDepthOfFieldInfo = previousCameraInfo ~= nil and previousCameraInfo.dofInfo or nil
    self.previousFovY = getFovY(self.previousCamera)
    self.cameraZoomFovY = self.previousFovY
    self.cameraTarget = createTransformGroup("FS25ScreenshotCameraTarget")
    self.camera = createCamera("FS25ScreenshotCamera", self.previousFovY, 1, 10000)
    link(getRootNode(), self.cameraTarget)
    link(self.cameraTarget, self.camera)
    setWorldTranslation(self.cameraTarget, getWorldTranslation(self.previousCamera))
    setWorldRotation(self.cameraTarget, getWorldRotation(self.previousCamera))
    g_cameraManager:addCamera(self.camera, nil, false)
    g_cameraManager:setActiveCamera(self.camera)

    self.cameraRotationX, self.cameraRotationY, self.cameraRotationZ = getWorldRotation(self.cameraTarget)
    self.captureCooldown = 0
    self.canAdjustDepthOfField = self.depthOfFieldApiAvailable
    self.depthOfFieldButton:setDisabled(not self.canAdjustDepthOfField)
    self:registerPhotoModeActionEvents()
end

function ScreenshotModeOverlay:onClickBack()
    self:changeScreen()
end

function ScreenshotModeOverlay:onClickCapture()
    if self.captureCooldown == 0 then
        ScreenshotColorAdjustment:flushPending()
        self.captureHideInterface = self.hideScreenshotUi:getIsChecked()
        self.captureCooldown = 10
    end
end

function ScreenshotModeOverlay:registerPhotoModeActionEvents()
    self.photoModeActionEventIds = {}

    local actions = {
        {name = "FS25_SCREENSHOT_COLORS", callback = ScreenshotModeOverlay.onClickColors},
        {name = "FS25_SCREENSHOT_DOF", callback = ScreenshotModeOverlay.onClickDepthOfField},
        {name = "FS25_SCREENSHOT_ZOOM_RESET", callback = ScreenshotModeOverlay.onClickResetZoom}
    }

    for _, action in ipairs(actions) do
        local actionId = InputAction[action.name]
        if actionId == nil then
            print(string.format("[FS25 Screenshot] Input action '%s' is unavailable.", action.name))
        else
            local success, eventId = g_inputBinding:registerActionEvent(
                actionId,
                self,
                action.callback,
                false,
                true,
                false,
                true,
                nil,
                true
            )

            if success and eventId ~= nil then
                g_inputBinding:setActionEventTextVisibility(eventId, false)
                table.insert(self.photoModeActionEventIds, eventId)
            else
                print(string.format("[FS25 Screenshot] Could not register input action '%s'.", action.name))
            end
        end
    end
end

function ScreenshotModeOverlay:unregisterPhotoModeActionEvents()
    if self.photoModeActionEventIds == nil then
        return
    end

    for _, eventId in ipairs(self.photoModeActionEventIds) do
        g_inputBinding:removeActionEvent(eventId)
    end
    self.photoModeActionEventIds = nil
end

function ScreenshotModeOverlay:onClickColors()
    if self.canAdjustColor then
        self.showColorControls = not self.showColorControls
        if self.showColorControls then
            self.showDepthOfFieldControls = false
        end
        self.colorSliderDraggingIndex = nil
        self.depthOfFieldSliderDraggingIndex = nil
    end
end

function ScreenshotModeOverlay:onClickDepthOfField()
    if not self.canAdjustDepthOfField then
        return
    end

    self.showDepthOfFieldControls = not self.showDepthOfFieldControls
    if self.showDepthOfFieldControls then
        self.showColorControls = false
        self.colorSliderDraggingIndex = nil
    end
    self.depthOfFieldSliderDraggingIndex = nil
end

function ScreenshotModeOverlay:onClickResetDepthOfField()
    self.depthOfFieldStrength = 0
    self:applyDepthOfField()
end

function ScreenshotModeOverlay:applyDepthOfField()
    if not self.canAdjustDepthOfField then
        return
    end

    local strength = self.depthOfFieldStrength / 100
    if strength <= 0 then
        g_depthOfFieldManager:reset()
        return
    end

    local focusDistance = self.depthOfFieldFocusDistance
    local nearBlurEnd = math.max(0.1, focusDistance * 0.8)
    local farBlurStart = focusDistance * 1.2
    local farBlurEnd = math.max(farBlurStart + 0.5, focusDistance * 3)
    local dofInfo = g_depthOfFieldManager:createInfo(
        5 * strength,
        nearBlurEnd,
        4 * strength,
        farBlurStart,
        farBlurEnd,
        false
    )
    g_depthOfFieldManager:applyInfo(dofInfo)
end

function ScreenshotModeOverlay:onCameraSpeedChanged(selection)
    local multiplier = self.CAMERA_SPEED_MULTIPLIERS[selection]
    if multiplier == nil then
        return
    end

    self.cameraSpeedMultiplier = multiplier
end

function ScreenshotModeOverlay:onClickHideScreenshotUi()
    self.captureHideInterface = self.hideScreenshotUi:getIsChecked()
end

function ScreenshotModeOverlay:onClickResetZoom()
    if self.camera == nil or self.previousFovY == nil then
        return
    end

    self.cameraZoomFovY = self.previousFovY
    setFovY(self.camera, self.cameraZoomFovY)
end

function ScreenshotModeOverlay:restoreDepthOfField()
    if not self.canAdjustDepthOfField then
        return
    end

    if self.previousDepthOfFieldInfo ~= nil then
        g_depthOfFieldManager:applyInfo(self.previousDepthOfFieldInfo)
    else
        g_depthOfFieldManager:reset()
    end
end

function ScreenshotModeOverlay:onClickResetColors()
    if self.canAdjustColor then
        ScreenshotColorAdjustment:reset()
    end
end

function ScreenshotModeOverlay:initializeVehicleControls()
    local vehicle = self.controlledVehicle
    self.vehicleCategory:setVisible(vehicle ~= nil)
    self.content:invalidateLayout()

    if vehicle == nil then
        self.vehicleCharacter:setDisabled(true)
        self.beaconLights:setDisabled(true)
        self.defaultLights:setDisabled(true)
        self.highBeamLights:setDisabled(true)
        self.frontLights:setDisabled(true)
        self.backLights:setDisabled(true)
        return
    end

    self.vehicleCharacter:setIsChecked(true, true, false)
    local canChangeCharacter = type(vehicle.restoreVehicleCharacter) == "function"
        and type(vehicle.deleteVehicleCharacter) == "function"
    self.vehicleCharacter:setDisabled(self.isMultiplayer or not canChangeCharacter)

    local spec = vehicle.spec_lights
    local canChangeBeacon = spec ~= nil
        and type(spec.getBeaconLightsVisibility) == "function"
        and type(spec.setBeaconLightsVisibility) == "function"
    local canChangeLightTypes = spec ~= nil
        and type(spec.lightsTypesMask) == "number"
        and type(vehicle.setLightsTypesMask) == "function"
        and Lights ~= nil
        and type(Lights.LIGHT_TYPE_DEFAULT) == "number"
        and type(Lights.LIGHT_TYPE_HIGHBEAM) == "number"
        and type(Lights.LIGHT_TYPE_WORK_FRONT) == "number"
        and type(Lights.LIGHT_TYPE_WORK_BACK) == "number"
        and type(bitAND) == "function"
        and type(bitXOR) == "function"

    self.previousBeaconLights = nil
    if canChangeBeacon then
        self.previousBeaconLights = spec:getBeaconLightsVisibility()
    end

    self.previousLightsTypesMask = nil
    if canChangeLightTypes then
        self.previousLightsTypesMask = spec.lightsTypesMask
    end

    self.beaconLights:setIsChecked(self.previousBeaconLights == true, true, false)
    self.beaconLights:setDisabled(self.isMultiplayer or not canChangeBeacon)

    local lightsTypesMask = canChangeLightTypes and spec.lightsTypesMask or 0
    self.defaultLights:setIsChecked(
        canChangeLightTypes and bitAND(lightsTypesMask, 2 ^ Lights.LIGHT_TYPE_DEFAULT) ~= 0 or false,
        true,
        false
    )
    self.highBeamLights:setIsChecked(
        canChangeLightTypes and bitAND(lightsTypesMask, 2 ^ Lights.LIGHT_TYPE_HIGHBEAM) ~= 0 or false,
        true,
        false
    )
    self.frontLights:setIsChecked(
        canChangeLightTypes and bitAND(lightsTypesMask, 2 ^ Lights.LIGHT_TYPE_WORK_FRONT) ~= 0 or false,
        true,
        false
    )
    self.backLights:setIsChecked(
        canChangeLightTypes and bitAND(lightsTypesMask, 2 ^ Lights.LIGHT_TYPE_WORK_BACK) ~= 0 or false,
        true,
        false
    )
    self.defaultLights:setDisabled(self.isMultiplayer or not canChangeLightTypes)
    self.highBeamLights:setDisabled(self.isMultiplayer or not canChangeLightTypes)
    self.frontLights:setDisabled(self.isMultiplayer or not canChangeLightTypes)
    self.backLights:setDisabled(self.isMultiplayer or not canChangeLightTypes)
end

function ScreenshotModeOverlay:onClickVehicleCharacter()
    local vehicle = self.controlledVehicle
    if self.isMultiplayer or vehicle == nil then
        return
    end

    if self.vehicleCharacter:getIsChecked() then
        if type(vehicle.restoreVehicleCharacter) == "function" then
            vehicle:restoreVehicleCharacter()
        end
    elseif type(vehicle.deleteVehicleCharacter) == "function" then
        vehicle:deleteVehicleCharacter()
    end
end

function ScreenshotModeOverlay:onClickBeaconLights()
    local vehicle = self.controlledVehicle
    local spec = vehicle ~= nil and vehicle.spec_lights or nil
    if self.isMultiplayer or spec == nil or type(spec.setBeaconLightsVisibility) ~= "function" then
        return
    end

    spec:setBeaconLightsVisibility(self.beaconLights:getIsChecked(), true, true)
end

function ScreenshotModeOverlay:setVehicleLightType(control, lightType)
    local vehicle = self.controlledVehicle
    local spec = vehicle ~= nil and vehicle.spec_lights or nil
    if self.isMultiplayer
        or spec == nil
        or type(spec.lightsTypesMask) ~= "number"
        or type(vehicle.setLightsTypesMask) ~= "function"
        or Lights == nil
        or type(lightType) ~= "number"
        or type(bitAND) ~= "function"
        or type(bitXOR) ~= "function" then
        return
    end

    local mask = spec.lightsTypesMask
    local lightFlag = 2 ^ lightType
    local isEnabled = bitAND(mask, lightFlag) ~= 0
    if control:getIsChecked() ~= isEnabled then
        vehicle:setLightsTypesMask(bitXOR(mask, lightFlag), true, true)
    end
end

function ScreenshotModeOverlay:onClickDefaultLights()
    self:setVehicleLightType(self.defaultLights, Lights.LIGHT_TYPE_DEFAULT)
end

function ScreenshotModeOverlay:onClickHighBeamLights()
    self:setVehicleLightType(self.highBeamLights, Lights.LIGHT_TYPE_HIGHBEAM)
end

function ScreenshotModeOverlay:onClickFrontLights()
    self:setVehicleLightType(self.frontLights, Lights.LIGHT_TYPE_WORK_FRONT)
end

function ScreenshotModeOverlay:onClickBackLights()
    self:setVehicleLightType(self.backLights, Lights.LIGHT_TYPE_WORK_BACK)
end

function ScreenshotModeOverlay:restoreVehicleSettings()
    local vehicle = self.controlledVehicle
    if self.isMultiplayer or vehicle == nil then
        return
    end

    if not self.vehicleCharacter:getIsChecked() and type(vehicle.restoreVehicleCharacter) == "function" then
        vehicle:restoreVehicleCharacter()
    end

    if self.previousBeaconLights ~= nil then
        if type(vehicle.setBeaconLightsVisibility) == "function" then
            vehicle:setBeaconLightsVisibility(self.previousBeaconLights, true, true)
        elseif vehicle.spec_lights ~= nil and type(vehicle.spec_lights.setBeaconLightsVisibility) == "function" then
            vehicle.spec_lights:setBeaconLightsVisibility(self.previousBeaconLights, true, true)
        end
    end

    if self.previousLightsTypesMask ~= nil and type(vehicle.setLightsTypesMask) == "function" then
        vehicle:setLightsTypesMask(self.previousLightsTypesMask, true, true)
    end
end

function ScreenshotModeOverlay:backupEnvironment()
    local backupDirectory = getUserProfileAppPath() .. "modSettings/FS25_Screenshot/"
    createFolder(backupDirectory)

    local xmlFile = createXMLFile(
        "FS25ScreenshotEnvironment",
        backupDirectory .. "environment.xml",
        "environment"
    )
    if xmlFile == nil or xmlFile == 0 then
        print("[FS25 Screenshot] Could not create the environment backup.")
        return false
    end

    g_currentMission.environment:saveToXMLFile(xmlFile, "environment")
    self.previousEnvironmentXmlFile = xmlFile
    return true
end

function ScreenshotModeOverlay:onWeatherChanged(selection)
    if not self.canChangeEnvironment then
        return
    end

    local weather = self.weatherData[selection]
    if weather == nil then
        return
    end

    local environment = g_currentMission.environment
    environment.weather:consoleCommandWeatherSet(weather.typeName, weather.variation)
    environment:update(1, true)
    environment.lighting:update(9999, true)
    ScreenshotColorAdjustment:refreshProfiles()
    self.currentWeather = selection
end

function ScreenshotModeOverlay:onDayTimeChanged(selection)
    if not self.canChangeEnvironment then
        return
    end

    if selection > 24 then
        selection = 1
    elseif selection < 1 then
        selection = 24
    end

    local environment = g_currentMission.environment
    local hour = selection - 1
    environment:setEnvironmentTime(
        environment.currentMonotonicDay,
        environment.currentDay,
        math.floor(hour * 1000 * 60 * 60),
        environment.daysPerPeriod,
        false
    )
    environment:update(1, true)
    environment.lighting:update(9999, true)
    ScreenshotColorAdjustment:refreshProfiles()
    self.currentDayTime = selection
end

function ScreenshotModeOverlay:onSeasonPeriodChanged(selection)
    if not self.canChangeEnvironment or selection < 1 or selection > #self.seasonPeriodOptions then
        return
    end

    local environment = g_currentMission.environment
    environment:setFixedPeriod(selection)
    environment:update(1, true)
    environment.lighting:update(9999, true)
    ScreenshotColorAdjustment:refreshProfiles()
    self.currentSeasonPeriod = selection
end

function ScreenshotModeOverlay:update(dt)
    ScreenshotModeOverlay:superClass().update(self, dt)
    ScreenshotColorAdjustment:update(dt)

    if self.camera == nil then
        return
    end

    if self.captureCooldown == 0 then
        self:updateCamera(dt)

        if Input.isKeyPressed(Input.KEY_return) then
            self:onClickCapture()
        end
    else
        self:updateCapture()
    end
end

function ScreenshotModeOverlay:updateCamera(dt)
    local moveX = 0
    local moveY = 0
    local moveZ = 0

    if Input.isKeyPressed(Input.KEY_a) then moveX = moveX - 1 end
    if Input.isKeyPressed(Input.KEY_d) then moveX = moveX + 1 end
    if Input.isKeyPressed(Input.KEY_q) then moveY = moveY + 1 end
    if Input.isKeyPressed(Input.KEY_e) then moveY = moveY - 1 end
    if Input.isKeyPressed(Input.KEY_w) then moveZ = moveZ - 1 end
    if Input.isKeyPressed(Input.KEY_s) then moveZ = moveZ + 1 end

    local worldX, worldY, worldZ = localDirectionToWorld(self.camera, moveX, moveY, moveZ)
    local x, y, z = getWorldTranslation(self.cameraTarget)
    local distance = self.CAMERA_BASE_SPEED * self.cameraSpeedMultiplier * dt / 1000
    setWorldTranslation(
        self.cameraTarget,
        x + worldX * distance,
        y + worldY * distance,
        z + worldZ * distance
    )

    local rotationSpeed = 1.5 * self.cameraSpeedMultiplier * dt / 1000

    if Input.isKeyPressed(Input.KEY_up) then self.cameraRotationX = self.cameraRotationX + rotationSpeed end
    if Input.isKeyPressed(Input.KEY_down) then self.cameraRotationX = self.cameraRotationX - rotationSpeed end
    if Input.isKeyPressed(Input.KEY_left) then self.cameraRotationY = self.cameraRotationY + rotationSpeed end
    if Input.isKeyPressed(Input.KEY_right) then self.cameraRotationY = self.cameraRotationY - rotationSpeed end

    setWorldRotation(self.cameraTarget, self.cameraRotationX, self.cameraRotationY, self.cameraRotationZ)
end

function ScreenshotModeOverlay:zoomCamera(zoomIn)
    if self.camera == nil or self.cameraZoomFovY == nil or self.previousFovY == nil then
        return
    end

    local zoomFactor = self.CAMERA_ZOOM_FACTOR
    if zoomIn then
        zoomFactor = 1 / zoomFactor
    end

    self.cameraZoomFovY = math.max(
        self.previousFovY * self.CAMERA_MIN_ZOOM_RATIO,
        math.min(
            self.previousFovY * self.CAMERA_MAX_ZOOM_RATIO,
            self.cameraZoomFovY * zoomFactor
        )
    )
    setFovY(self.camera, self.cameraZoomFovY)
end

function ScreenshotModeOverlay:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
    ScreenshotModeOverlay:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)

    if isDown and self.camera ~= nil and not self:isPointerOnGui(posX, posY)
        and not self:isPointerOnColorPanel(posX, posY) then
        if Input.MOUSE_BUTTON_WHEEL_UP ~= nil and button == Input.MOUSE_BUTTON_WHEEL_UP then
            self:zoomCamera(true)
            return
        elseif Input.MOUSE_BUTTON_WHEEL_DOWN ~= nil and button == Input.MOUSE_BUTTON_WHEEL_DOWN then
            self:zoomCamera(false)
            return
        end
    end

    if self.showDepthOfFieldControls then
        if isUp and button == Input.MOUSE_BUTTON_LEFT then
            self.depthOfFieldSliderDraggingIndex = nil
        elseif isDown and button == Input.MOUSE_BUTTON_LEFT then
            if self:isPointerOnColorReset(posX, posY) then
                self:onClickResetDepthOfField()
                return
            end

            local sliderIndex = self:getDepthOfFieldSliderAtPosition(posX, posY)
            if sliderIndex ~= nil then
                self.depthOfFieldSliderDraggingIndex = sliderIndex
                self:setDepthOfFieldValueFromMouse(sliderIndex, posX)
                return
            end

            if self:isPointerOnColorPanel(posX, posY) then
                return
            end
        end

        if self.depthOfFieldSliderDraggingIndex ~= nil then
            self:setDepthOfFieldValueFromMouse(self.depthOfFieldSliderDraggingIndex, posX)
            return
        end
    elseif self.showColorControls then
        if isUp and button == Input.MOUSE_BUTTON_LEFT then
            self.colorSliderDraggingIndex = nil
        elseif isDown and button == Input.MOUSE_BUTTON_LEFT then
            if self:isPointerOnColorReset(posX, posY) then
                self:onClickResetColors()
                return
            end

            local sliderIndex = self:getColorSliderAtPosition(posX, posY)
            if sliderIndex ~= nil then
                self.colorSliderDraggingIndex = sliderIndex
                self:setColorValueFromMouse(sliderIndex, posX)
                return
            end

            if self:isPointerOnColorPanel(posX, posY) then
                return
            end
        end

        if self.colorSliderDraggingIndex ~= nil then
            self:setColorValueFromMouse(self.colorSliderDraggingIndex, posX)
            return
        end
    end

    if isDown and button == Input.MOUSE_BUTTON_LEFT and not self:isPointerOnGui(posX, posY) then
        self.mouseDragActive = true
        self.lastMousePosX = posX
        self.lastMousePosY = posY
    end

    if isUp and button == Input.MOUSE_BUTTON_LEFT then
        self.mouseDragActive = false
    end

    if not self.mouseDragActive or self.cameraTarget == nil then
        return
    end

    local deltaX = posX - self.lastMousePosX
    local deltaY = posY - self.lastMousePosY
    self.lastMousePosX = posX
    self.lastMousePosY = posY

    local sensitivity = math.pi * 2 * self.cameraSpeedMultiplier
    self.cameraRotationX = self.cameraRotationX + deltaY * sensitivity
    self.cameraRotationY = self.cameraRotationY - deltaX * sensitivity
    setWorldRotation(
        self.cameraTarget,
        self.cameraRotationX,
        self.cameraRotationY,
        self.cameraRotationZ
    )
end

function ScreenshotModeOverlay:draw()
    ScreenshotModeOverlay:superClass().draw(self)

    if self.showDepthOfFieldControls then
        self:drawDepthOfFieldControls()
        return
    end

    if not self.showColorControls then
        return
    end

    drawFilledRect(self.COLOR_PANEL_X, 0, self.COLOR_PANEL_WIDTH, 1, 0, 0, 0, 0.88)

    for index, slider in ipairs(self.COLOR_SLIDERS) do
        local y = self.COLOR_SLIDER_START_Y - (index - 1) * self.COLOR_SLIDER_STEP_Y
        local value = ScreenshotColorAdjustment:getValue(slider.key)
        local ratio = (value + 100) / 200
        local markerX = self.COLOR_SLIDER_X + ratio * self.COLOR_SLIDER_WIDTH

        drawFilledRect(self.COLOR_SLIDER_X, y, self.COLOR_SLIDER_WIDTH, 0.008, 0.25, 0.25, 0.25, 1)
        drawFilledRect(self.COLOR_SLIDER_X + self.COLOR_SLIDER_WIDTH * 0.5, y - 0.004, 0.0015, 0.016, 0.7, 0.7, 0.7, 1)
        drawFilledRect(
            markerX - 0.003,
            y - 0.006,
            0.006,
            0.02,
            self.COLOR_SLIDER_MARKER_RED,
            self.COLOR_SLIDER_MARKER_GREEN,
            0,
            1
        )
    end

    drawFilledRect(self.COLOR_RESET_X, self.COLOR_RESET_Y, self.COLOR_RESET_WIDTH, self.COLOR_RESET_HEIGHT, 0.25, 0.25, 0.25, 1)

    if type(renderText) ~= "function" then
        if not self.colorTextWarningLogged then
            print("[FS25 Screenshot] Color controls are visible, but text rendering is unavailable.")
            self.colorTextWarningLogged = true
        end
        return
    end

    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
    renderText(self.COLOR_SLIDER_X, 0.93, 0.025, g_i18n:getText("FS25_SCREENSHOT_COLOR_TITLE"))
    renderText(self.COLOR_SLIDER_X, 0.895, 0.012, g_i18n:getText("FS25_SCREENSHOT_COLOR_HELP"))

    for index, slider in ipairs(self.COLOR_SLIDERS) do
        local y = self.COLOR_SLIDER_START_Y - (index - 1) * self.COLOR_SLIDER_STEP_Y
        local value = ScreenshotColorAdjustment:getValue(slider.key)
        renderText(self.COLOR_SLIDER_X, y + 0.023, 0.014, g_i18n:getText(slider.textKey))
        setTextAlignment(RenderText.ALIGN_RIGHT)
        renderText(self.COLOR_SLIDER_X + self.COLOR_SLIDER_WIDTH, y + 0.023, 0.014, string.format("%+d%%", value))
        setTextAlignment(RenderText.ALIGN_LEFT)
    end

    setTextAlignment(RenderText.ALIGN_CENTER)
    renderText(
        self.COLOR_RESET_X + self.COLOR_RESET_WIDTH * 0.5,
        self.COLOR_RESET_Y + 0.012,
        0.015,
        g_i18n:getText("FS25_SCREENSHOT_COLOR_RESET")
    )
    setTextAlignment(RenderText.ALIGN_LEFT)
end

function ScreenshotModeOverlay:drawDepthOfFieldControls()
    drawFilledRect(self.COLOR_PANEL_X, 0, self.COLOR_PANEL_WIDTH, 1, 0, 0, 0, 0.88)

    local focusRatio = math.log(self.depthOfFieldFocusDistance / self.DOF_FOCUS_MIN)
        / math.log(self.DOF_FOCUS_MAX / self.DOF_FOCUS_MIN)
    local focusMarkerX = self.COLOR_SLIDER_X + focusRatio * self.COLOR_SLIDER_WIDTH
    local strengthRatio = self.depthOfFieldStrength / 100
    local strengthMarkerX = self.COLOR_SLIDER_X + strengthRatio * self.COLOR_SLIDER_WIDTH

    for _, sliderY in ipairs({self.DOF_FOCUS_SLIDER_Y, self.DOF_STRENGTH_SLIDER_Y}) do
        drawFilledRect(self.COLOR_SLIDER_X, sliderY, self.COLOR_SLIDER_WIDTH, 0.008, 0.25, 0.25, 0.25, 1)
    end

    drawFilledRect(
        focusMarkerX - 0.003,
        self.DOF_FOCUS_SLIDER_Y - 0.006,
        0.006,
        0.02,
        self.COLOR_SLIDER_MARKER_RED,
        self.COLOR_SLIDER_MARKER_GREEN,
        0,
        1
    )
    drawFilledRect(
        strengthMarkerX - 0.003,
        self.DOF_STRENGTH_SLIDER_Y - 0.006,
        0.006,
        0.02,
        self.COLOR_SLIDER_MARKER_RED,
        self.COLOR_SLIDER_MARKER_GREEN,
        0,
        1
    )
    drawFilledRect(
        self.COLOR_RESET_X,
        self.COLOR_RESET_Y,
        self.COLOR_RESET_WIDTH,
        self.COLOR_RESET_HEIGHT,
        0.25,
        0.25,
        0.25,
        1
    )

    if type(renderText) ~= "function" then
        return
    end

    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
    renderText(self.COLOR_SLIDER_X, 0.93, 0.025, g_i18n:getText("FS25_SCREENSHOT_DOF_TITLE"))
    renderText(self.COLOR_SLIDER_X, 0.895, 0.012, g_i18n:getText("FS25_SCREENSHOT_DOF_HELP"))
    renderText(
        self.COLOR_SLIDER_X,
        self.DOF_FOCUS_SLIDER_Y + 0.023,
        0.014,
        g_i18n:getText("FS25_SCREENSHOT_DOF_FOCUS")
    )
    setTextAlignment(RenderText.ALIGN_RIGHT)
    renderText(
        self.COLOR_SLIDER_X + self.COLOR_SLIDER_WIDTH,
        self.DOF_FOCUS_SLIDER_Y + 0.023,
        0.014,
        string.format("%.1f m", self.depthOfFieldFocusDistance)
    )
    setTextAlignment(RenderText.ALIGN_LEFT)
    renderText(
        self.COLOR_SLIDER_X,
        self.DOF_STRENGTH_SLIDER_Y + 0.023,
        0.014,
        g_i18n:getText("FS25_SCREENSHOT_DOF_STRENGTH")
    )
    setTextAlignment(RenderText.ALIGN_RIGHT)
    renderText(
        self.COLOR_SLIDER_X + self.COLOR_SLIDER_WIDTH,
        self.DOF_STRENGTH_SLIDER_Y + 0.023,
        0.014,
        string.format("%d%%", self.depthOfFieldStrength)
    )
    setTextAlignment(RenderText.ALIGN_CENTER)
    renderText(
        self.COLOR_RESET_X + self.COLOR_RESET_WIDTH * 0.5,
        self.COLOR_RESET_Y + 0.012,
        0.015,
        g_i18n:getText("FS25_SCREENSHOT_DOF_RESET")
    )
    setTextAlignment(RenderText.ALIGN_LEFT)
end

function ScreenshotModeOverlay:getDepthOfFieldSliderAtPosition(posX, posY)
    if posX < self.COLOR_SLIDER_X or posX > self.COLOR_SLIDER_X + self.COLOR_SLIDER_WIDTH then
        return nil
    end

    if math.abs(posY - self.DOF_FOCUS_SLIDER_Y) <= 0.025 then
        return 1
    elseif math.abs(posY - self.DOF_STRENGTH_SLIDER_Y) <= 0.025 then
        return 2
    end

    return nil
end

function ScreenshotModeOverlay:setDepthOfFieldValueFromMouse(sliderIndex, posX)
    local ratio = math.max(
        0,
        math.min(1, (posX - self.COLOR_SLIDER_X) / self.COLOR_SLIDER_WIDTH)
    )

    if sliderIndex == 1 then
        self.depthOfFieldFocusDistance = self.DOF_FOCUS_MIN
            * math.pow(self.DOF_FOCUS_MAX / self.DOF_FOCUS_MIN, ratio)
    elseif sliderIndex == 2 then
        self.depthOfFieldStrength = math.floor(ratio * 100 + 0.5)
    else
        return
    end

    self:applyDepthOfField()
end

function ScreenshotModeOverlay:getColorSliderAtPosition(posX, posY)
    if posX < self.COLOR_SLIDER_X or posX > self.COLOR_SLIDER_X + self.COLOR_SLIDER_WIDTH then
        return nil
    end

    for index, _ in ipairs(self.COLOR_SLIDERS) do
        local y = self.COLOR_SLIDER_START_Y - (index - 1) * self.COLOR_SLIDER_STEP_Y
        if posY >= y - 0.012 and posY <= y + 0.034 then
            return index
        end
    end

    return nil
end

function ScreenshotModeOverlay:setColorValueFromMouse(sliderIndex, posX)
    local slider = self.COLOR_SLIDERS[sliderIndex]
    if slider == nil then
        return
    end

    local ratio = math.max(0, math.min(1, (posX - self.COLOR_SLIDER_X) / self.COLOR_SLIDER_WIDTH))
    ScreenshotColorAdjustment:setValue(slider.key, -100 + ratio * 200)
end

function ScreenshotModeOverlay:isPointerOnColorPanel(posX, posY)
    return posX >= self.COLOR_PANEL_X and posX <= self.COLOR_PANEL_X + self.COLOR_PANEL_WIDTH
        and posY >= 0 and posY <= 1
end

function ScreenshotModeOverlay:isPointerOnColorReset(posX, posY)
    return posX >= self.COLOR_RESET_X and posX <= self.COLOR_RESET_X + self.COLOR_RESET_WIDTH
        and posY >= self.COLOR_RESET_Y and posY <= self.COLOR_RESET_Y + self.COLOR_RESET_HEIGHT
end

function ScreenshotModeOverlay:isPointerOnGui(posX, posY)
    local root = self:getRootElement()
    if root == nil then
        return false
    end

    for _, element in ipairs(root.elements) do
        local left = element.absPosition[1]
        local bottom = element.absPosition[2]
        local right = left + element.absSize[1]
        local top = bottom + element.absSize[2]

        if posX >= left and posX <= right and posY >= bottom and posY <= top then
            return true
        end
    end

    return false
end

function ScreenshotModeOverlay:updateCapture()
    if self.captureCooldown == 10 then
        if self.captureHideInterface then
            self:setVisible(false)
            self:setAlpha(0)
        end
    elseif self.captureCooldown == 5 then
        self:saveScreenshot()
    end

    self.captureCooldown = self.captureCooldown - 1

    if self.captureCooldown == 0 then
        self:setVisible(true)
        self:setAlpha(1)
    end
end

function ScreenshotModeOverlay:saveScreenshot()
    local directory = g_screenshotsDirectory
    if directory == nil then
        directory = getUserProfileAppPath() .. "screenshots/"
        createFolder(directory)
    end

    local timestamp = getDate("%Y_%m_%d_%H_%M_%S")
    local index = 1
    local filePath

    repeat
        filePath = string.format("%sFS25_Map_%s_%02d.png", directory, timestamp, index)
        index = index + 1
    until not fileExists(filePath)

    saveScreenshot(filePath)
    print(string.format("[FS25 Screenshot] Screenshot salvo: %s", filePath))
end

function ScreenshotModeOverlay:onClose()
    self:unregisterPhotoModeActionEvents()
    self:restoreVehicleSettings()
    ScreenshotColorAdjustment:endSession()

    if self.previousEnvironmentXmlFile ~= nil and g_currentMission ~= nil then
        local environment = g_currentMission.environment
        environment:loadFromXMLFile(self.previousEnvironmentXmlFile, "environment")
        environment:setFixedPeriod(nil)
        environment:update(1, true)
        environment.lighting:update(9999, true)
        delete(self.previousEnvironmentXmlFile)
        self.previousEnvironmentXmlFile = nil
    end

    if self.pausedByPhotoMode and g_currentMission ~= nil then
        g_currentMission:setManualPause(false)
        self.pausedByPhotoMode = false
    end

    if self.camera ~= nil then
        g_cameraManager:setActiveCamera(self.previousCamera)
        self:restoreDepthOfField()
        g_cameraManager:removeCamera(self.camera)
        delete(self.camera)
        delete(self.cameraTarget)
        self.camera = nil
        self.cameraTarget = nil
    end

    ScreenshotModeOverlay:superClass().onClose(self)
end
