FS25Screenshot = {
    gui = nil,
    modDirectory = g_currentModDirectory
}

function FS25Screenshot:showScreenshotModeOverlay()
    if g_currentMission == nil or g_gui == nil then
        return
    end

    if self.gui == nil then
        if self.modDirectory == nil then
            print("[FS25 Screenshot] Could not locate the mod folder.")
            return
        end

        self.gui = {}
        self.gui.screenshotModeOverlay = ScreenshotModeOverlay.new(nil, nil)
        g_gui:loadGui(
            self.modDirectory .. "ScreenshotModeOverlay.xml",
            "FS25ScreenshotModeGUI",
            self.gui.screenshotModeOverlay
        )
    end

    g_gui:showGui("FS25ScreenshotModeGUI")
end

if PlayerInputComponent ~= nil and type(PlayerInputComponent.registerGlobalPlayerActionEvents) == "function" then
    PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(
        PlayerInputComponent.registerGlobalPlayerActionEvents,
        function()
            local actionId = InputAction.FS25_SCREENSHOT_MODE
            if actionId == nil then
                return
            end

            local success, eventId = g_inputBinding:registerActionEvent(
                actionId,
                FS25Screenshot,
                FS25Screenshot.showScreenshotModeOverlay,
                false,
                true,
                false,
                true,
                nil,
                true
            )

            if success and eventId ~= nil then
                g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_VERY_LOW)
                g_inputBinding:setActionEventTextVisibility(eventId, true)
            end
        end
    )
end
