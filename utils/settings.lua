local Settings = {}

-- Key for storing settings in KOReader global settings
local SETTINGS_KEY = "opds_nav_settings"

local DEFAULTS = {
    opds_nav_enabled               = true, -- master toggle for auto next/prev
    opds_nav_skip_continue         = true, -- skip "Continue From" as navigation targets
    opds_nav_force_first_page      = true, -- always start next book at page 1
    opds_nav_notify_next_load      = true, -- show "Loading next book" notification
    opds_nav_prevent_premature_nav = true, -- prevent navigation if current stream is not fully loaded
    opds_nav_refresh_on_exit       = true, -- refresh OPDS catalog after exiting stream
}



local function getSettingsStore()
    return G_koreader_settings or G_reader_settings
end

-- Ensure default settings exist
local function initSettings()
    local store = getSettingsStore()
    if store and not store:has(SETTINGS_KEY) then
        store:saveSetting(SETTINGS_KEY, DEFAULTS)
    end
end

-- Get current settings, merging with defaults in case of new keys
function Settings:getSettings()
    initSettings()
    local store = getSettingsStore()
    local saved = (store and store:readSetting(SETTINGS_KEY)) or {}
    local current = {}
    for k, v in pairs(DEFAULTS) do
        if saved[k] ~= nil then
            current[k] = saved[k]
        else
            current[k] = v
        end
    end
    return current
end

function Settings:saveSettings(settings)
    local store = getSettingsStore()
    if store then
        store:saveSetting(SETTINGS_KEY, settings)
    end
end

function Settings:toggle(key)
    local settings = self:getSettings()
    settings[key] = not settings[key]
    self:saveSettings(settings)
    return settings[key]
end

function Settings:isEnabled()
    return self:getSettings().opds_nav_enabled
end

function Settings:shouldSkipContinue()
    return self:getSettings().opds_nav_skip_continue
end

function Settings:shouldNotifyNextLoad()
    return self:getSettings().opds_nav_notify_next_load
end

function Settings:shouldPreventPrematureNav()
    return self:getSettings().opds_nav_prevent_premature_nav
end

function Settings:shouldRefreshOnExit()
    return self:getSettings().opds_nav_refresh_on_exit
end



return Settings
