--[[--
Deep Immersion (DI): simulates the look of an e-ink screen on a regular
(LCD/OLED) Android display.

The page is rendered by KOReader exactly as usual. Right before it is copied
to the Android window, this module post-processes it:

1. Downsample to the simulated pixel density (e.g. 220 ppi, like the Xteink X4).
2. Ink spread: soften glyph edges and roughen them with a fixed "paper fiber"
   noise, so letters lose the mathematically perfect outline of LCD text.
3. Quantize to a few gray levels (16 by default, like e-ink), optionally with
   ordered dithering.
4. Map to e-ink tones (ink is not pure black, paper is not pure white) and add
   a subtle static paper grain.
5. Upscale back with nearest neighbour, which brings back the visible pixel grid.

Everything works on raw FFI buffers so it stays fast enough for page turns,
even on old devices.

@module deepink.immersion
--]]

local ffi = require("ffi")
local logger = require("logger")

local floor = math.floor

local Immersion = {
    installed = false,
    -- runtime settings (see DEFAULTS)
    settings = nil,
    -- cached buffers, rebuilt when sizes or settings change
    cache = nil,
}

Immersion.DEFAULTS = {
    enabled = true,     -- on by default: Deep Ink is about this
    dpi = 167,          -- simulated pixel density; 0 = native resolution
    levels = 16,        -- gray levels
    dither = true,      -- ordered dithering between gray levels
    spread = 50,        -- ink spread, 0-100
    grain = 25,         -- paper grain, 0-100
    paper = "eink",     -- tint: "eink", "light" (neutral) or "warm"
    shade = 3,          -- paper darkness, 1 (lightest) to 5 (darkest)
    flash = "normal",   -- page refresh flash: "off", "rare", "normal", "frequent"
    transition = true,  -- e-ink page turn: old and new letters dissolve into each other
}

-- Refresh flash: a gray (not black) frame with faint inverted text, as on
-- a Kindle. FLASH_BASE is its gray level, FLASH_TEXT how much text shows.
Immersion.FLASH_MS = 80
Immersion.FLASH_BASE = 96
Immersion.FLASH_TEXT = 0.22

-- Page turn dissolve: intermediate frames, the share of pixels already
-- switched to the new page in each, and how long each frame stays.
Immersion.TRANSITION_STEPS = { 0.3, 0.55, 0.8 }
Immersion.TRANSITION_MS = 30

-- Paper white level per shade (1 = lightest).
Immersion.SHADES = { 234, 222, 210, 198, 186 }

-- Pages between two refresh flashes: random in [min, max].
Immersion.FLASH_INTERVALS = {
    rare     = { 12, 20 },
    normal   = { 6, 12 },
    frequent = { 2, 5 },
}

Immersion.PAPERS = {
    -- ink black level, tint multipliers for r, g, b (white comes from the shade)
    eink  = { black = 30, r = 1.00, g = 1.00, b = 0.98 },
    light = { black = 26, r = 1.00, g = 1.00, b = 1.00 },
    warm  = { black = 34, r = 1.00, g = 0.97, b = 0.90 },
}

local SETTINGS_KEY = "deep_ink"

-- 4x4 Bayer matrix, as thresholds in [0, 1)
local BAYER = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 }
local bayer_t = ffi.new("float[16]")
for i = 1, 16 do
    bayer_t[i - 1] = (BAYER[i] + 0.5) / 16
end

function Immersion:loadSettings()
    local saved = G_reader_settings:readSetting(SETTINGS_KEY) or {}
    local s = {}
    for k, v in pairs(self.DEFAULTS) do
        if saved[k] ~= nil then
            s[k] = saved[k]
        else
            s[k] = v
        end
    end
    if not self.PAPERS[s.paper] then s.paper = self.DEFAULTS.paper end
    if not self.SHADES[s.shade] then s.shade = self.DEFAULTS.shade end
    if s.flash ~= "off" and not self.FLASH_INTERVALS[s.flash] then s.flash = self.DEFAULTS.flash end
    self.settings = s
    self.cache = nil
    return s
end

function Immersion:saveSettings()
    G_reader_settings:saveSetting(SETTINGS_KEY, self.settings)
    self.cache = nil
    self.pages_until_flash = nil
end

function Immersion:get(key)
    if not self.settings then self:loadSettings() end
    return self.settings[key]
end

function Immersion:set(key, value)
    if not self.settings then self:loadSettings() end
    self.settings[key] = value
    self:saveSettings()
end

function Immersion:resetSettings()
    local enabled = self:get("enabled")
    self.settings = {}
    for k, v in pairs(self.DEFAULTS) do self.settings[k] = v end
    self.settings.enabled = enabled
    self:saveSettings()
end

--- Called by the plugin on every page turn.
function Immersion:notePageTurn()
    self.pending_turn = true
end

--- Decides whether this page turn gets a refresh flash (random interval).
function Immersion:flashDue()
    local range = self.FLASH_INTERVALS[self.settings.flash]
    if not range then return false end
    if not self.pages_until_flash then
        self.pages_until_flash = math.random(range[1], range[2])
    end
    self.pages_until_flash = self.pages_until_flash - 1
    if self.pages_until_flash <= 0 then
        self.pages_until_flash = math.random(range[1], range[2])
        return true
    end
    return false
end

function Immersion:isEnabled()
    return self:get("enabled") and true or false
end

-- Simple deterministic PRNG, so the paper fibers never "move" between pages.
local function makeNoise(n, seed)
    local buf = ffi.new("int8_t[?]", n)
    local x = seed
    for i = 0, n - 1 do
        x = (x * 1103515245 + 12345) % 2147483648
        buf[i] = floor(x / 8388608) - 128 -- top 8 bits, -128..127
    end
    return buf
end

function Immersion:buildCache(w, h, screen_dpi)
    local s = self.settings
    local f = 1
    if s.dpi and s.dpi > 0 and screen_dpi and screen_dpi > s.dpi then
        f = s.dpi / screen_dpi
    end
    local lw = math.max(1, floor(w * f))
    local lh = math.max(1, floor(h * f))
    local n = lw * lh

    local c = {
        w = w, h = h, lw = lw, lh = lh, f = f, dpi = screen_dpi,
        native = (lw == w and lh == h),
        lum = ffi.new("uint8_t[?]", n),
        tmp = ffi.new("uint8_t[?]", n),
        fiber = makeNoise(n, 1234567),
        grain = makeNoise(n, 7654321),
        -- final gray of the current page, the page on screen before it,
        -- and a scratch frame for flashes and transitions
        cur = ffi.new("uint8_t[?]", n),
        prev = ffi.new("uint8_t[?]", n),
        mix = ffi.new("uint8_t[?]", n),
        has_prev = false,
        dissolve = nil, -- built on first use

        -- source sample positions
        sxa = ffi.new("int32_t[?]", lw),
        sxb = ffi.new("int32_t[?]", lw),
        sya = ffi.new("int32_t[?]", lh),
        syb = ffi.new("int32_t[?]", lh),
        -- destination -> low-res maps
        xmap = ffi.new("int32_t[?]", w),
        ymap = ffi.new("int32_t[?]", h),
        pal32 = ffi.new("uint32_t[256]"),
        pal16 = ffi.new("uint16_t[256]"),
    }

    for lx = 0, lw - 1 do
        c.sxa[lx] = math.min(w - 1, floor((lx + 0.25) * w / lw))
        c.sxb[lx] = math.min(w - 1, floor((lx + 0.75) * w / lw))
    end
    for ly = 0, lh - 1 do
        c.sya[ly] = math.min(h - 1, floor((ly + 0.25) * h / lh))
        c.syb[ly] = math.min(h - 1, floor((ly + 0.75) * h / lh))
    end
    for x = 0, w - 1 do
        c.xmap[x] = math.min(lw - 1, floor(x * lw / w))
    end
    for y = 0, h - 1 do
        c.ymap[y] = math.min(lh - 1, floor(y * lh / h))
    end

    -- Palette: final gray value -> packed window pixel, with paper tint.
    local p = self.PAPERS[s.paper] or self.PAPERS.eink
    for g = 0, 255 do
        local r = math.min(255, floor(g * p.r + 0.5))
        local gg = math.min(255, floor(g * p.g + 0.5))
        local b = math.min(255, floor(g * p.b + 0.5))
        -- RGBA_8888 / RGBX_8888 in memory: r, g, b, a (little endian uint32)
        c.pal32[g] = ffi.cast("uint32_t", 0xFF000000 + b * 65536 + gg * 256 + r)
        c.pal16[g] = floor(r / 8) * 2048 + floor(gg / 4) * 32 + floor(b / 8)
    end

    self.cache = c
    return c
end

-- Blotchy, uniformly distributed noise: which pixels switch first during
-- a page turn. Smoothed so letters break into fragments, not single dots.
local function makeDissolve(lw, lh)
    local n = lw * lh
    local raw = ffi.new("uint8_t[?]", n)
    local x = 98765
    for i = 0, n - 1 do
        x = (x * 1103515245 + 12345) % 2147483648
        raw[i] = floor(x / 8388608)
    end
    local sm = ffi.new("uint8_t[?]", n)
    for pass = 1, 2 do
        for y = 0, lh - 1 do
            for xx = 0, lw - 1 do
                local sum, cnt = 0, 0
                for dy = -1, 1 do
                    local yy = y + dy
                    if yy >= 0 and yy < lh then
                        for dx = -1, 1 do
                            local x2 = xx + dx
                            if x2 >= 0 and x2 < lw then
                                sum = sum + raw[yy * lw + x2]
                                cnt = cnt + 1
                            end
                        end
                    end
                end
                sm[y * lw + xx] = sum / cnt
            end
        end
        if pass == 1 then ffi.copy(raw, sm, n) end
    end
    -- Histogram equalization, so thresholds 0..255 switch pixels evenly.
    local hist = ffi.new("uint32_t[256]")
    for i = 0, n - 1 do hist[sm[i]] = hist[sm[i]] + 1 end
    local map = ffi.new("uint8_t[256]")
    local acc = 0
    for v = 0, 255 do
        acc = acc + hist[v]
        map[v] = math.min(255, floor(acc * 256 / n))
    end
    for i = 0, n - 1 do sm[i] = map[sm[i]] end
    return sm
end

--[[--
Processes `src` (a BBRGB32 blitbuffer, physical orientation) into the
low-resolution e-ink gray frame `cache.cur`. Returns the cache.
--]]
function Immersion:compute(src, w, h, screen_dpi)
    local s = self.settings
    local c = self.cache
    if not c or c.w ~= w or c.h ~= h or c.dpi ~= screen_dpi then
        c = self:buildCache(w, h, screen_dpi)
    end

    local lw, lh = c.lw, c.lh
    local lum, tmp = c.lum, c.tmp
    local sdata = src.data
    local sstride = tonumber(src.pixel_stride)
    local sxa, sxb, sya, syb = c.sxa, c.sxb, c.sya, c.syb

    -- 1. Downsample to luminance (2x2 samples per low-res pixel).
    if c.native then
        for y = 0, lh - 1 do
            local row = y * sstride
            local orow = y * lw
            for x = 0, lw - 1 do
                local px = sdata[row + x]
                lum[orow + x] = (px.r * 77 + px.g * 151 + px.b * 28) / 256
            end
        end
    else
        for ly = 0, lh - 1 do
            local ra = sya[ly] * sstride
            local rb = syb[ly] * sstride
            local orow = ly * lw
            for lx = 0, lw - 1 do
                local xa, xb = sxa[lx], sxb[lx]
                local p1, p2 = sdata[ra + xa], sdata[ra + xb]
                local p3, p4 = sdata[rb + xa], sdata[rb + xb]
                local sum = (p1.r + p2.r + p3.r + p4.r) * 77
                          + (p1.g + p2.g + p3.g + p4.g) * 151
                          + (p1.b + p2.b + p3.b + p4.b) * 28
                lum[orow + lx] = sum / 1024
            end
        end
    end

    -- 2. Ink spread: blur a little, then roughen the edges with paper fibers.
    local spread = (s.spread or 0) / 100
    if spread > 0 and lw > 2 and lh > 2 then
        local blur = spread * 0.6
        local rough = spread * 0.9 / 16256 -- normalizes v*(255-v), max 16256
        local fiber = c.fiber
        ffi.copy(tmp, lum, lw * lh)
        for y = 1, lh - 2 do
            local row = y * lw
            for x = 1, lw - 2 do
                local i = row + x
                local v = tmp[i]
                local avg = (tmp[i - lw - 1] + tmp[i - lw] + tmp[i - lw + 1]
                           + tmp[i - 1] + v + tmp[i + 1]
                           + tmp[i + lw - 1] + tmp[i + lw] + tmp[i + lw + 1]) / 9
                local nv = v + (avg - v) * blur
                -- edge pixels (mid grays) get the strongest roughness
                nv = nv + fiber[i] * nv * (255 - nv) * rough
                if nv < 0 then nv = 0 elseif nv > 255 then nv = 255 end
                lum[i] = nv
            end
        end
    end

    -- 3. + 4. Quantize, dither, map to e-ink tones, add grain.
    local p = self.PAPERS[s.paper] or self.PAPERS.eink
    local black = p.black
    local white = self.SHADES[s.shade] or self.SHADES[self.DEFAULTS.shade]
    local range = white - black
    local levels = math.max(2, s.levels or 16)
    local lm1 = levels - 1
    local scale = lm1 / 255
    local dither = s.dither
    local grain_amp = (s.grain or 0) / 100 * 12 / 128
    local grain = c.grain
    local cur = c.cur
    for y = 0, lh - 1 do
        local row = y * lw
        local brow = (y % 4) * 4
        for x = 0, lw - 1 do
            local i = row + x
            local t = dither and bayer_t[brow + x % 4] or 0.5
            local q = floor(lum[i] * scale + t)
            if q > lm1 then q = lm1 end
            local g = black + q * range / lm1 + grain[i] * grain_amp
            if g < 0 then g = 0 elseif g > 255 then g = 255 end
            cur[i] = g
        end
    end
    return c
end

--- Builds the gray refresh-flash frame into `cache.mix`.
function Immersion:flashFrame(c)
    local n = c.lw * c.lh
    local cur, mix = c.cur, c.mix
    local base, k = self.FLASH_BASE, self.FLASH_TEXT
    for i = 0, n - 1 do
        mix[i] = base + (255 - cur[i]) * k
    end
    return mix
end

--- Builds a dissolve frame between the previous and current page into `cache.mix`.
function Immersion:transitionFrame(c, progress)
    if not c.dissolve then c.dissolve = makeDissolve(c.lw, c.lh) end
    local n = c.lw * c.lh
    local cur, prev, mix, dis = c.cur, c.prev, c.mix, c.dissolve
    local threshold = progress * 256
    for i = 0, n - 1 do
        if dis[i] < threshold then
            mix[i] = cur[i]
        else
            -- pixels still switching: old ink is already lightening
            local a, b = prev[i], cur[i]
            mix[i] = a < b and a + (b - a) * 0.35 or a
        end
    end
    return mix
end

--- Upscales a low-res gray frame (nearest neighbour) into the window buffer.
function Immersion:present(c, frame, win, is565)
    local lw = c.lw
    -- the window normally matches the page; never write past either
    local w = math.min(c.w, tonumber(win.width))
    local h = math.min(c.h, tonumber(win.height))
    local xmap, ymap = c.xmap, c.ymap
    local dstride = tonumber(win.stride)
    if is565 then
        local pal = c.pal16
        local dst = ffi.cast("uint16_t*", win.bits)
        for y = 0, h - 1 do
            local srow = ymap[y] * lw
            local drow = y * dstride
            for x = 0, w - 1 do
                dst[drow + x] = pal[frame[srow + xmap[x]]]
            end
        end
    else
        local pal = c.pal32
        local dst = ffi.cast("uint32_t*", win.bits)
        for y = 0, h - 1 do
            local srow = ymap[y] * lw
            local drow = y * dstride
            for x = 0, w - 1 do
                dst[drow + x] = pal[frame[srow + xmap[x]]]
            end
        end
    end
end

--[[--
Hooks into the Android framebuffer so every screen update goes through DI
when it is enabled. Safe to call more than once.
--]]
function Immersion:install(screen)
    if self.installed or not screen or not screen._updateWindow then return end
    local ok_android, android = pcall(require, "android")
    if not ok_android then return end
    local BB = require("ffi/blitbuffer")
    local usleep = require("ffi/util").usleep
    local C = ffi.C
    if not self.settings then self:loadSettings() end

    local imm = self
    local orig_updateWindow = screen._updateWindow

    screen._updateWindow = function(fb)
        if not imm.settings.enabled then
            return orig_updateWindow(fb)
        end
        local ext_bb = fb.full_bb or fb.bb
        -- Night mode (inverted) and unexpected buffer types: leave untouched.
        if ext_bb:getInverse() == 1 or ext_bb:getType() ~= BB.TYPE_BBRGB32 then
            return orig_updateWindow(fb)
        end
        if android.app.window == nil then
            return orig_updateWindow(fb)
        end

        local turn = imm.pending_turn
        imm.pending_turn = false
        local flash = turn and imm:flashDue()

        -- Locks the window, writes one frame, posts it.
        local function post(c, frame)
            local buffer = ffi.new("ANativeWindow_Buffer[1]")
            if android.lib.ANativeWindow_lock(android.app.window, buffer, nil) < 0 then
                android.LOGW("Deep Ink: unable to lock window buffer")
                return true
            end
            local fmt = buffer[0].format
            local is565 = fmt == C.WINDOW_FORMAT_RGB_565
            local ok, err = true, nil
            if is565 or fmt == C.WINDOW_FORMAT_RGBA_8888 or fmt == C.WINDOW_FORMAT_RGBX_8888 then
                ok, err = pcall(imm.present, imm, c, frame, buffer[0], is565)
            else
                ok, err = false, "unsupported window format " .. tostring(fmt)
            end
            android.lib.ANativeWindow_unlockAndPost(android.app.window)
            return ok, err
        end

        local function run()
            local c = imm:compute(ext_bb, tonumber(ext_bb.w), tonumber(ext_bb.h), fb:getDPI())
            local ok, err = true, nil
            if turn and c.has_prev then
                if flash then
                    ok, err = post(c, imm:flashFrame(c))
                    if not ok then return ok, err end
                    usleep(imm.FLASH_MS * 1000)
                end
                if imm.settings.transition then
                    for _, progress in ipairs(imm.TRANSITION_STEPS) do
                        ok, err = post(c, imm:transitionFrame(c, progress))
                        if not ok then return ok, err end
                        usleep(imm.TRANSITION_MS * 1000)
                    end
                end
            end
            ok, err = post(c, c.cur)
            ffi.copy(c.prev, c.cur, c.lw * c.lh)
            c.has_prev = true
            return ok, err
        end

        local pok, ok, err = pcall(run)
        if not pok then ok, err = false, ok end
        if not ok then
            -- Never leave the user with a broken screen: turn DI off and redraw normally.
            logger.warn("Deep Ink: Deep Immersion disabled:", err)
            imm.settings.enabled = false
            imm.cache = nil
            return orig_updateWindow(fb)
        end
    end

    self.installed = true
    logger.info("Deep Ink: Deep Immersion hook installed")
end

return Immersion
