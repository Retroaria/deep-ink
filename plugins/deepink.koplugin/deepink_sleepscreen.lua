--[[--
Deep Ink sleep screen.

Android does not let apps intercept the power button, so this is how the
"lock screen" works:
- the activity is allowed to show over the lock screen (showWhenLocked);
- when the screen turns off while Deep Ink is open, this widget is shown;
- when the screen turns on again, it appears over Android's lock screen;
- a swipe or tap asks Android to unlock (PIN/fingerprint if set). The widget
  only closes once the device is really unlocked, so the book stays private.

@module koplugin.deepink.sleepscreen
--]]

local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local ImageWidget = require("ui/widget/imagewidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local TextBoxWidget = require("ui/widget/textboxwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Blitbuffer = require("ffi/blitbuffer")
local logger = require("logger")
local Screen = Device.screen

local SleepScreen = {
    PHRASE = "“Não é só a luz: é a letra. A experiência das telas e-ink, trazida para o seu Android.”",
    CREDIT = "Desenvolvido por Retroaria",
    LINK = "youtube.com/retroaria",
    HINT = "Deslize para desbloquear",
    widget = nil,
}

-- JNI helpers (methods added to MainActivity by deepink/android/patch_launcher.sh)
local function jniVoid(method, signature, ...)
    local ok, android = pcall(require, "android")
    if not ok then return false end
    local args = { ... }
    local done, err = pcall(function()
        android.jni:context(android.app.activity.vm, function(jni)
            jni:callVoidMethod(android.app.activity.clazz, method, signature, unpack(args))
        end)
    end)
    if not done then logger.warn("Deep Ink:", method, "failed:", err) end
    return done
end

local function jniInt(method)
    local ok, android = pcall(require, "android")
    if not ok then return nil end
    local done, res = pcall(function()
        return android.jni:context(android.app.activity.vm, function(jni)
            return jni:callIntMethod(android.app.activity.clazz, method, "()I")
        end)
    end)
    if not done then
        logger.warn("Deep Ink:", method, "failed:", res)
        return nil
    end
    return tonumber(res)
end

function SleepScreen:setShowWhenLocked(enable)
    local ffi = require("ffi")
    jniVoid("deepInkShowWhenLocked", "(I)V", ffi.new("int32_t", enable and 1 or 0))
end

function SleepScreen:isScreenOn()
    local v = jniInt("deepInkIsScreenOn")
    return v == nil or v == 1
end

function SleepScreen:isLocked()
    return jniInt("deepInkIsLocked") == 1
end

function SleepScreen:requestUnlock()
    jniVoid("deepInkDismissKeyguard", "()V")
end

local SleepWidget = InputContainer:extend{
    name = "DeepInkSleepScreen",
    logo_path = nil,
    covers_fullscreen = true,
}

function SleepWidget:init()
    local w, h = Screen:getWidth(), Screen:getHeight()
    local full = Geom:new{ x = 0, y = 0, w = w, h = h }
    self.ges_events = {
        Tap = { GestureRange:new{ ges = "tap", range = full } },
        Swipe = { GestureRange:new{ ges = "swipe", range = full } },
        Hold = { GestureRange:new{ ges = "hold", range = full } },
    }
    self.key_events = {} -- swallow keys: nothing behind us is reachable

    local content_w = math.floor(w * 0.82)
    local group = VerticalGroup:new{ align = "center" }

    if self.logo_path then
        local logo_w = math.floor(w * 0.72)
        table.insert(group, ImageWidget:new{
            file = self.logo_path,
            width = logo_w,
            height = math.floor(logo_w * 0.25),
            scale_factor = 0,
            alpha = true,
        })
    end
    table.insert(group, VerticalSpan:new{ width = Screen:scaleBySize(36) })

    local phrase_face = Font:getFace("NotoSerif-Italic.ttf", 20) or Font:getFace("infofont", 20)
    table.insert(group, TextBoxWidget:new{
        text = SleepScreen.PHRASE,
        face = phrase_face,
        width = content_w,
        alignment = "center",
    })
    table.insert(group, VerticalSpan:new{ width = Screen:scaleBySize(48) })
    table.insert(group, TextBoxWidget:new{
        text = SleepScreen.CREDIT .. "\n" .. SleepScreen.LINK,
        face = Font:getFace("smallinfofont", 16),
        width = content_w,
        alignment = "center",
        fgcolor = Blitbuffer.COLOR_DARK_GRAY,
    })
    table.insert(group, VerticalSpan:new{ width = Screen:scaleBySize(56) })
    table.insert(group, TextBoxWidget:new{
        text = SleepScreen.HINT,
        face = Font:getFace("x_smallinfofont", 13),
        width = content_w,
        alignment = "center",
        fgcolor = Blitbuffer.COLOR_GRAY,
    })

    self.dimen = full
    self[1] = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = 0,
        margin = 0,
        width = w,
        height = h,
        CenterContainer:new{
            dimen = Geom:new{ w = w, h = h },
            group,
        },
    }
end

function SleepWidget:onShow()
    UIManager:setDirty(self, "full")
    return true
end

function SleepWidget:onCloseWidget()
    UIManager:setDirty(nil, "full")
end

function SleepWidget:unlock()
    if not SleepScreen:isLocked() then
        SleepScreen:hide()
        return true
    end
    SleepScreen:requestUnlock()
    -- Close only once Android reports the device as unlocked.
    local tries = 0
    local function check()
        tries = tries + 1
        if not SleepScreen.widget then return end
        if not SleepScreen:isLocked() then
            SleepScreen:hide()
        elseif tries < 120 then
            UIManager:scheduleIn(0.5, check)
        end
    end
    UIManager:unschedule(check)
    UIManager:scheduleIn(0.5, check)
    return true
end

SleepWidget.onTap = SleepWidget.unlock
SleepWidget.onSwipe = SleepWidget.unlock
SleepWidget.onHold = SleepWidget.unlock

function SleepScreen:show(logo_path)
    if self.widget then return end
    self.widget = SleepWidget:new{ logo_path = logo_path }
    UIManager:show(self.widget)
    -- Paint right away: the screen is turning off and the next thing the
    -- user sees, when it turns on, must already be this page.
    UIManager:forceRePaint()
end

function SleepScreen:hide()
    if not self.widget then return end
    UIManager:close(self.widget)
    self.widget = nil
end

--- Called when the app resumes: if the device was unlocked some other way
--- (e.g. fingerprint straight from the off screen), don't keep the widget.
function SleepScreen:onResume()
    if self.widget and not self:isLocked() then
        self:hide()
    end
end

return SleepScreen
