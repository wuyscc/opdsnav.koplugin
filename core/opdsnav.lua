local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local ImageViewer = require("ui/widget/imageviewer")
local logger = require("logger")
local _ = require("gettext")

local OpdsUtil = require("utils/opds_util")
local Menu = require("ui/settings")
local Settings = require("utils/settings")

local OPDSBrowser
local OPDSPSE

local OpdsNav = WidgetContainer:extend {
    name = "opdsnav",
    is_general = true,
    is_loading = false,
}

local function getNextStartPage(acq)
    local force_first_page = Settings:getSettings().opds_nav_force_first_page
    if force_first_page then
        return 1
    end

    local count = tonumber(acq and acq.count)
    local last_read = tonumber(acq and acq.last_read)
    if not count or count < 1 then
        return nil
    end

    if not last_read or last_read < 1 then
        return nil
    end

    if last_read >= count then
        return count
    end

    return last_read
end

function OpdsNav:init()
    logger.info("Initializing OPDSNav Plugin")
    -- Require OPDS modules after all plugins are loaded and added to package.path
    OPDSBrowser = require("opdsbrowser")
    OPDSPSE = require("opdspse")

    self:_hookOPDSBrowser()
    self:_hookOPDSPSE()
    self:_hookImageViewer()
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
end

function OpdsNav:onDispatcherRegisterActions()
    local Dispatcher = require("dispatcher")
    Dispatcher:registerAction("opdsnav_settings", {
        category = "none",
        event = "OpdsNavSettings",
        title = _("OPDSNav Settings"),
        general = true,
    })
end

function OpdsNav:onOpdsNavSettings()
    Menu:showStandaloneDialog()
    return true
end

function OpdsNav:addToMainMenu(menu_items)
    Menu.addToMainMenu(self, menu_items)
end

function OpdsNav:_hookOPDSBrowser()
    if OPDSBrowser.showDownloads_opds_nav_hooked then return end

    local orig_showDownloads = OPDSBrowser.showDownloads
    OPDSBrowser.showDownloads = function(browser_self, item)
        -- Save the current browser instance and item when user clicks to download/stream
        _G.OPDS_NAV_BROWSER = browser_self
        _G.OPDS_NAV_LAST_ITEM = item
        return orig_showDownloads(browser_self, item)
    end
    OPDSBrowser.showDownloads_opds_nav_hooked = true
end

function OpdsNav:_hookOPDSPSE()
    if OPDSPSE.streamPages_opds_nav_hooked then return end

    local orig_streamPages = OPDSPSE.streamPages
    OPDSPSE.streamPages = function(pse_self, remote_url, count, continue, username, password, last_page_read)
        -- Temporarily hook UIManager.show to inject a flag into the created ImageViewer
        local orig_show = UIManager.show
        local intercepted_viewer = nil
        UIManager.show = function(mgr_self, widget, ...)
            if widget and widget.switchToImageNum and not intercepted_viewer then
                intercepted_viewer = widget
                widget.is_opds_stream = true
            end
            return orig_show(mgr_self, widget, ...)
        end

        local ok, err = pcall(orig_streamPages, pse_self, remote_url, count, continue, username, password, last_page_read)

        -- Restore original UIManager.show
        UIManager.show = orig_show

        if not ok then
            error(err)
        end
    end
    OPDSPSE.streamPages_opds_nav_hooked = true
end

function OpdsNav:_hookImageViewer()
    if ImageViewer.onShowNextImage_opds_nav_hooked then return end
    local opds_nav_instance = self

    local orig_onShowNextImage = ImageViewer.onShowNextImage
    ImageViewer.onShowNextImage = function(viewer_self)
        if not Settings:isEnabled() then return orig_onShowNextImage(viewer_self) end
        if viewer_self.is_opds_stream then
            logger.info("OPDSNav current image viewer file:", viewer_self.file, "folder:", viewer_self.folder)
        end
        if viewer_self._images_list_cur == viewer_self._images_list_nb and viewer_self.is_opds_stream then
            local browser = _G.OPDS_NAV_BROWSER
            local current_item = _G.OPDS_NAV_LAST_ITEM
            if browser and current_item then
                if Settings:shouldPreventPrematureNav() then
                    local current_acq = OpdsUtil.getStreamAcquisition(current_item)
                    if current_acq and current_acq.count then
                        local count = tonumber(current_acq.count)
                        if count and viewer_self._images_list_nb < count then
                            logger.info("OPDSNav: Stream not fully loaded, preventing next book navigation")
                            return orig_onShowNextImage(viewer_self)
                        end
                    end
                end
                local current_idx = OpdsUtil.getRealIndex(browser, current_item)
                if not current_idx then
                    logger.warn("OPDSNav: Could not resolve current index for next navigation")
                    return orig_onShowNextImage(viewer_self)
                end

                local skip_continue = Settings:shouldSkipContinue()

                local next_idx = current_idx + 1
                local next_item = browser.item_table[next_idx]

                if skip_continue then
                    while next_item and OpdsUtil.isContinueItem(next_item) do
                        logger.info("OPDSNav: Skipping 'Continue Reading' item on next at idx", next_idx)
                        next_idx = next_idx + 1
                        next_item = browser.item_table[next_idx]
                    end
                end

                -- OPDS cross-pagination support
                if not next_item and browser.item_table.hrefs and browser.item_table.hrefs.next then
                    logger.info("OPDSNav: Fetching next catalog page")
                    if browser:appendCatalog(browser.item_table.hrefs.next) then
                        next_item = browser.item_table[next_idx]
                        if skip_continue then
                            while next_item and OpdsUtil.isContinueItem(next_item) do
                                logger.info("OPDSNav: Skipping 'Continue Reading' item on next at idx", next_idx)
                                next_idx = next_idx + 1
                                next_item = browser.item_table[next_idx]
                            end
                        end
                    end
                end

                if next_item then
                    local acq = OpdsUtil.getStreamAcquisition(next_item)
                    if acq then
                        if opds_nav_instance.is_loading then return true end
                        opds_nav_instance.is_loading = true

                        logger.info("OPDSNav: Scheduling next item", next_item.title)
                        local load_msg = nil
                        if Settings:shouldNotifyNextLoad() then
                            local InfoMessage = require("ui/widget/infomessage")
                            load_msg = InfoMessage:new {
                                text = _("Loading next book...") .. "\n" .. next_item.title,
                            }
                            UIManager:show(load_msg)
                        end

                        UIManager:scheduleIn(0.1, function()
                            UIManager:close(viewer_self)
                            if load_msg then
                                UIManager:close(load_msg)
                            end
                            _G.OPDS_NAV_LAST_ITEM = next_item
                            opds_nav_instance.is_loading = false
                            local start_page = getNextStartPage(acq)
                            OPDSPSE:streamPages(acq.href, acq.count, false, browser.root_catalog_username,
                                browser.root_catalog_password, start_page)
                        end)
                        return true
                    end
                else
                    logger.info("OPDSNav: No next item found in OPDS catalog")
                    local InfoMessage = require("ui/widget/infomessage")
                    UIManager:show(InfoMessage:new {
                        text = _("Already at the very end of the catalog."),
                    })
                end
            end
        end
        return orig_onShowNextImage(viewer_self)
    end
    ImageViewer.onShowNextImage_opds_nav_hooked = true

    local orig_onShowPrevImage = ImageViewer.onShowPrevImage
    ImageViewer.onShowPrevImage = function(viewer_self)
        if not Settings:isEnabled() then return orig_onShowPrevImage(viewer_self) end
        if viewer_self._images_list_cur == 1 and viewer_self.is_opds_stream then
            local browser = _G.OPDS_NAV_BROWSER
            local current_item = _G.OPDS_NAV_LAST_ITEM
            if browser and current_item then
                if Settings:shouldPreventPrematureNav() then
                    local current_acq = OpdsUtil.getStreamAcquisition(current_item)
                    if current_acq and current_acq.count then
                        local count = tonumber(current_acq.count)
                        if count and viewer_self._images_list_nb < count then
                            logger.info("OPDSNav: Stream not fully loaded, preventing prev book navigation")
                            return orig_onShowPrevImage(viewer_self)
                        end
                    end
                end
                local current_idx = OpdsUtil.getRealIndex(browser, current_item)
                if not current_idx then
                    logger.warn("OPDSNav: Could not resolve current index for previous navigation")
                    return orig_onShowPrevImage(viewer_self)
                end

                local skip_continue = Settings:shouldSkipContinue()

                if current_idx > 1 then
                    local prev_idx = current_idx - 1
                    local prev_item = browser.item_table[prev_idx]

                    if skip_continue then
                        while prev_item and OpdsUtil.isContinueItem(prev_item) do
                            logger.info("OPDSNav: Skipping 'Continue Reading' item on prev at idx", prev_idx)
                            prev_idx = prev_idx - 1
                            prev_item = prev_idx >= 1 and browser.item_table[prev_idx] or nil
                        end
                    end

                    if prev_item then
                        local acq = OpdsUtil.getStreamAcquisition(prev_item)
                        if acq then
                            if opds_nav_instance.is_loading then return true end
                            opds_nav_instance.is_loading = true

                            logger.info("OPDSNav: Scheduling previous item", prev_item.title)
                            local InfoMessage = require("ui/widget/infomessage")
                            local load_msg = InfoMessage:new {
                                text = _("Loading previous book...") .. "\n" .. prev_item.title,
                            }
                            UIManager:show(load_msg)

                            UIManager:scheduleIn(0.1, function()
                                UIManager:close(viewer_self)
                                UIManager:close(load_msg)
                                _G.OPDS_NAV_LAST_ITEM = prev_item
                                opds_nav_instance.is_loading = false
                                -- Open previous item and start at its last page
                                OPDSPSE:streamPages(acq.href, acq.count, false, browser.root_catalog_username,
                                    browser.root_catalog_password, acq.count)
                            end)
                            return true
                        end
                    else
                        logger.info("OPDSNav: No previous item found (after skipping)")
                        local InfoMessage = require("ui/widget/infomessage")
                        UIManager:show(InfoMessage:new {
                            text = _("Already at the very beginning of the catalog."),
                        })
                    end
                else
                    logger.info("OPDSNav: Already at the first item in OPDS catalog")
                    local InfoMessage = require("ui/widget/infomessage")
                    UIManager:show(InfoMessage:new {
                        text = _("Already at the very beginning of the catalog."),
                    })
                end
            end
        end
        return orig_onShowPrevImage(viewer_self)
    end
    ImageViewer.onShowPrevImage_opds_nav_hooked = true

    local orig_onClose = ImageViewer.onClose
    ImageViewer.onClose = function(viewer_self)
        local ret
        if type(orig_onClose) == "function" then
            ret = orig_onClose(viewer_self)
        end

        if viewer_self.is_opds_stream and Settings:shouldRefreshOnExit() then
            local browser = _G.OPDS_NAV_BROWSER
            if browser then
                local delay = 0.2
                -- Automatically check for custom sync provider to determine delay
                local kosync_settings = G_reader_settings:readSetting("kosync")
                if kosync_settings and kosync_settings.auto_sync and kosync_settings.custom_server then
                    logger.info("OPDSNav: Custom sync provider detected, waiting longer for progress sync...")
                    delay = 2.0
                end


                UIManager:scheduleIn(delay, function()
                    -- Refresh the current catalog view
                    if type(browser.updateCatalog) == "function" and browser.paths and #browser.paths > 0 then
                        local current_url = browser.paths[#browser.paths].url
                        if current_url then
                            logger.info("OPDSNav: Refreshing OPDS catalog URL: " .. tostring(current_url))
                            browser:updateCatalog(current_url, true)
                        end
                    elseif type(browser.onRefresh) == "function" then
                        logger.info("OPDSNav: Refreshing OPDS browser via onRefresh")
                        browser:onRefresh()
                    elseif type(browser.updateItems) == "function" then
                        logger.info("OPDSNav: Updating OPDS browser items via updateItems")
                        browser:updateItems()
                    end
                end)
            end
        end

        return ret
    end
end

return OpdsNav
