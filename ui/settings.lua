local _ = require("gettext")
local UIManager = require("ui/uimanager")
local Settings = require("utils/settings")

local Menu = {}

local function refreshMenu(menu_widget)
    if menu_widget and menu_widget.updateItems then
        menu_widget:updateItems()
        return
    end
    if Menu.dialog and Menu.dialog.updateItems then
        Menu.dialog:updateItems()
    end
end

-- Builds the menu table for the main menu or standalone dialog
function Menu:getMenuTable()
    return {
        {
            text = _("Enable OPDSNav"),
            checked_func = function()
                return Settings:getSettings().opds_nav_enabled
            end,
            keep_menu_open = true,
            callback = function(menu_widget)
                Settings:toggle("opds_nav_enabled")
                refreshMenu(menu_widget)
                return true
            end,
        },
        {
            text = _("Skip 'Continue From' item(s)"),
            checked_func = function()
                return Settings:getSettings().opds_nav_skip_continue
            end,
            keep_menu_open = true,
            callback = function(menu_widget)
                Settings:toggle("opds_nav_skip_continue")
                refreshMenu(menu_widget)
                return true
            end,
        },
        {
            text = _("Start next book at page 1"),
            checked_func = function()
                return Settings:getSettings().opds_nav_force_first_page
            end,
            keep_menu_open = true,
            callback = function(menu_widget)
                Settings:toggle("opds_nav_force_first_page")
                refreshMenu(menu_widget)
                return true
            end
        },
        {
            text = _("Notify when loading next book"),
            checked_func = function()
                return Settings:getSettings().opds_nav_notify_next_load
            end,
            keep_menu_open = true,
            callback = function(menu_widget)
                Settings:toggle("opds_nav_notify_next_load")
                refreshMenu(menu_widget)
                return true
            end
        }
    }
end

-- For KOReader main menu integration
function Menu.addToMainMenu(instance, menu_items)
    menu_items.opds_nav = {
        text = _("OPDSNav"),
        sub_item_table = Menu:getMenuTable(),
    }
end

-- Shows a standalone dialog containing the settings
function Menu:showStandaloneDialog()
    local Device = require("device")
    local MenuClass = Device:isTouchDevice() and require("ui/widget/touchmenu") or require("ui/widget/menu")

    self.dialog = MenuClass:new {
        title = _("OPDSNav Settings"),
        item_table = self:getMenuTable(),
        onClose = function()
            UIManager:close(self.dialog)
        end,
    }
    UIManager:show(self.dialog)
end

return Menu
