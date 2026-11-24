--[[--
Deep Ink: Deep Immersion (DI) menu and toggle.

The rendering itself lives in deepink/immersion.lua; this plugin installs the
screen hook, adds the menu entries and a dispatcher action, so DI can be
toggled from a gesture.

@module koplugin.deepink
--]]

local Device = require("device")

if not Device:isAndroid() then
    return { disabled = true, }
end

local Dispatcher = require("dispatcher")
local Immersion = require("deepink/immersion")
local InfoMessage = require("ui/widget/infomessage")
local SpinWidget = require("ui/widget/spinwidget")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local T = require("ffi/util").template

local DeepInk = WidgetContainer:extend{
    name = "deepink",
    is_doc_only = false,
}

local DPI_CHOICES = {
    { 300, _("300 ppi (Kindle Paperwhite)") },
    { 220, _("220 ppi (Xteink X4)") },
    { 167, _("167 ppi (classic Kindle)") },
    { 0,   _("Native (no resolution change)") },
}

local LEVEL_CHOICES = { 4, 8, 16 }

local PAPER_CHOICES = {
    { "eink",  _("E-ink gray") },
    { "light", _("Light") },
    { "warm",  _("Warm") },
}

function DeepInk:init()
    Immersion:loadSettings()
    Immersion:install(Device.screen)
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
end

function DeepInk:onDispatcherRegisterActions()
    Dispatcher:registerAction("deep_immersion_toggle", {
        category = "none",
        event = "ToggleDeepImmersion",
        title = _("Toggle Deep Immersion"),
        screen = true,
    })
end

local function redraw()
    UIManager:setDirty("all", "full")
end

function DeepInk:onToggleDeepImmersion()
    local on = not Immersion:isEnabled()
    Immersion:set("enabled", on)
    redraw()
    UIManager:show(InfoMessage:new{
        text = on and _("Deep Immersion on") or _("Deep Immersion off"),
        timeout = 1,
    })
    return true
end

-- Changes a setting and redraws, so the effect is visible right away.
local function setAndRedraw(key, value, touchmenu_instance)
    Immersion:set(key, value)
    if touchmenu_instance then touchmenu_instance:updateItems() end
    redraw()
end

local function percentItem(key, title, info)
    return {
        text_func = function()
            return T(_("%1: %2 %"), title, Immersion:get(key))
        end,
        enabled_func = function() return Immersion:isEnabled() end,
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            UIManager:show(SpinWidget:new{
                title_text = title,
                info_text = info,
                value = Immersion:get(key),
                default_value = Immersion.DEFAULTS[key],
                value_min = 0,
                value_max = 100,
                value_step = 5,
                value_hold_step = 20,
                unit = "%",
                ok_always_enabled = true,
                callback = function(spin)
                    setAndRedraw(key, spin.value, touchmenu_instance)
                end,
            })
        end,
    }
end

function DeepInk:getMenu()
    local dpi_items = {}
    for idx = 1, #DPI_CHOICES do
        local choice = DPI_CHOICES[idx]
        table.insert(dpi_items, {
            text = choice[2],
            radio = true,
            checked_func = function() return Immersion:get("dpi") == choice[1] end,
            callback = function(touchmenu_instance)
                setAndRedraw("dpi", choice[1], touchmenu_instance)
            end,
        })
    end

    local level_items = {}
    for idx = 1, #LEVEL_CHOICES do
        local levels = LEVEL_CHOICES[idx]
        table.insert(level_items, {
            text = T(_("%1 gray levels"), levels),
            radio = true,
            checked_func = function() return Immersion:get("levels") == levels end,
            callback = function(touchmenu_instance)
                setAndRedraw("levels", levels, touchmenu_instance)
            end,
        })
    end

    local paper_items = {}
    for idx = 1, #PAPER_CHOICES do
        local choice = PAPER_CHOICES[idx]
        table.insert(paper_items, {
            text = choice[2],
            radio = true,
            checked_func = function() return Immersion:get("paper") == choice[1] end,
            callback = function(touchmenu_instance)
                setAndRedraw("paper", choice[1], touchmenu_instance)
            end,
        })
    end

    local function dpiLabel()
        local dpi = Immersion:get("dpi")
        if not dpi or dpi == 0 then return _("native") end
        return T(_("%1 ppi"), dpi)
    end

    local function paperLabel()
        local paper = Immersion:get("paper")
        for idx = 1, #PAPER_CHOICES do
            local choice = PAPER_CHOICES[idx]
            if choice[1] == paper then return choice[2] end
        end
        return paper
    end

    return {
        text = _("Deep Immersion (DI)"),
        checked_func = function() return Immersion:isEnabled() end,
        sub_item_table = {
            {
                text = _("Enable Deep Immersion"),
                checked_func = function() return Immersion:isEnabled() end,
                keep_menu_open = true,
                callback = function(touchmenu_instance)
                    setAndRedraw("enabled", not Immersion:isEnabled(), touchmenu_instance)
                end,
                separator = true,
            },
            {
                text_func = function() return T(_("Simulated resolution: %1"), dpiLabel()) end,
                enabled_func = function() return Immersion:isEnabled() end,
                sub_item_table = dpi_items,
            },
            {
                text_func = function() return T(_("Gray levels: %1"), Immersion:get("levels")) end,
                enabled_func = function() return Immersion:isEnabled() end,
                sub_item_table = level_items,
            },
            {
                text = _("Dithering"),
                enabled_func = function() return Immersion:isEnabled() end,
                checked_func = function() return Immersion:get("dither") end,
                keep_menu_open = true,
                callback = function(touchmenu_instance)
                    setAndRedraw("dither", not Immersion:get("dither"), touchmenu_instance)
                end,
            },
            percentItem("spread", _("Ink spread"),
                _("Makes letter edges slightly irregular, like ink absorbed by paper.")),
            percentItem("grain", _("Paper grain"),
                _("Adds a subtle, static paper texture.")),
            {
                text_func = function() return T(_("Paper tone: %1"), paperLabel()) end,
                enabled_func = function() return Immersion:isEnabled() end,
                sub_item_table = paper_items,
                separator = true,
            },
            {
                text = _("Reset Deep Immersion settings"),
                keep_menu_open = true,
                callback = function(touchmenu_instance)
                    Immersion:resetSettings()
                    if touchmenu_instance then touchmenu_instance:updateItems() end
                    redraw()
                end,
            },
            {
                text = _("About Deep Immersion"),
                keep_menu_open = true,
                callback = function()
                    UIManager:show(InfoMessage:new{
                        text = _([[Deep Immersion simulates an e-ink screen: lower pixel density, few gray levels, ink spread on letter edges and paper grain.

Tip: assign "Toggle Deep Immersion" to a gesture (Settings → Taps and gestures → Gesture manager) to compare it with the normal screen in one tap.]]),
                    })
                end,
            },
        },
    }
end

function DeepInk:addToMainMenu(menu_items)
    menu_items.deep_immersion = self:getMenu()
end

return DeepInk
