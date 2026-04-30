local logger = require("logger")
local Settings = require("utils/settings")

local OpdsUtil = {}

function OpdsUtil.getStreamAcquisition(item)
    if not item or not item.acquisitions then return nil end
    for _, acq in ipairs(item.acquisitions) do
        if acq.count then
            return acq
        end
    end
    return nil
end

function OpdsUtil.isContinueItem(item)
    if not item or not item.title then return false end
    local title = item.title:lower()
    if string.find(title, "continue reading from", 1, true) then return true end
    -- Some providers mark read items with a checkmark or [Read] prefix
    if string.find(title, "[read]", 1, true) then return true end
    if string.find(title, "✔", 1, true) then return true end
    return false
end

function OpdsUtil.getRealIndex(browser, current_item)
    if not current_item then return nil end
    if not browser or not browser.item_table then return current_item.idx end

    local current_idx = tonumber(current_item.idx)
    local acq = OpdsUtil.getStreamAcquisition(current_item)

    -- Some OPDS sources do not keep idx on items consistently. Recover it.
    if not current_idx then
        for i = 1, #browser.item_table do
            local item = browser.item_table[i]
            if item == current_item then
                current_idx = i
                break
            end
        end
    end

    if not current_idx and acq and acq.href then
        for i = 1, #browser.item_table do
            local item = browser.item_table[i]
            local item_acq = OpdsUtil.getStreamAcquisition(item)
            if item_acq and item_acq.href == acq.href then
                current_idx = i
                break
            end
        end
    end

    if not current_idx and current_item.title then
        for i = 1, #browser.item_table do
            local item = browser.item_table[i]
            if item and item.title == current_item.title then
                current_idx = i
                break
            end
        end
    end

    if not current_idx then return tonumber(current_item.idx) end

    if not acq or not acq.href then return current_idx end

    local skip_continue = Settings:shouldSkipContinue()

    if not skip_continue then
        return current_idx
    end

    for i = 1, #browser.item_table do
        if i ~= current_idx then
            local other_item = browser.item_table[i]
            if other_item then
                local other_acq = OpdsUtil.getStreamAcquisition(other_item)
                -- If we found another item with the same href, and we are currently at a low index (top of list),
                -- we assume the higher index is the "real" chronological position.
                if other_acq and other_acq.href == acq.href then
                    if i > current_idx then
                        logger.info("OPDSNav: Mapping duplicate item from idx", current_idx, "to", i)
                        return i
                    end
                end
            end
        end
    end

    logger.info("OPDSNav: No duplicate found in current catalog page for idx", current_idx)
    return current_idx
end

return OpdsUtil
