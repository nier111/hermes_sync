#!/usr/bin/env lua
-- Run a Xiaomi band Lua watchface's main.lua on the PC against stubbed
-- lvgl / dataman / vibrator modules, so timer defaults, state migration and
-- tap wiring can be checked WITHOUT touching the band.
--
-- Usage:
--   lua simulate_lua_watchface.lua [path/to/app/lua/main.lua] [work-dir] [seed-state-file]
--
--   work-dir         becomes SCRIPT_PATH (default /tmp/wf-sim)
--   seed-state-file  optional file copied into work-dir as yao_focus_state.txt
--                    before the first run, to exercise loading/migration
--
-- It prints every label text painted during load, the number of dataman
-- subscriptions and timers, then invokes the tap handler of the first tall
-- (>= 100px) clickable container, then reloads from the same directory and
-- reports the resulting label texts and the on-disk state file. Read the output
-- and assert against YOUR face's expectations — this harness is generic.

local main_lua = arg[1] or "app/lua/main.lua"
local work_dir = arg[2] or "/tmp/wf-sim"
local seed_state = arg[3]

local lua_dir = main_lua:match("^(.*)/[^/]+$")
if lua_dir then package.path = lua_dir .. "/?.lua;" .. package.path end

os.execute("mkdir -p '" .. work_dir .. "'")

local texts, handlers, timers = {}, {}, {}

local function new_obj(props)
    local o = { props = props or {}, handlers = {}, text = props and props.text or nil }
    function o:set(t)
        for k, v in pairs(t) do
            if k == "text" then
                self.text = v
                texts[#texts + 1] = v
            end
            self.props[k] = v
        end
    end
    function o:clear_flag() end
    function o:add_flag() end
    function o:clean() end
    function o:delete() end
    function o:Anim() end
    function o:get_img_size() return 0, 0 end
    function o:onevent(ev, fn)
        self.handlers[ev] = fn
        handlers[#handlers + 1] = { obj = self, event = ev, fn = fn }
    end
    -- IMPORTANT: children are created as `parent:Label{...}`, i.e. a method
    -- call. The first argument is the parent, the props table is the SECOND.
    -- Writing this as `function child(p)` drops every props table silently.
    local function child(_, p) return new_obj(p) end
    o.Object, o.Label, o.Image, o.Button = child, child, child, child
    return o
end

local lvgl = {
    HOR_RES = function() return 212 end,
    VER_RES = function() return 520 end,
    OPA = function(v) return v end,
    ALIGN = setmetatable({}, { __index = function(_, k) return k end }),
    FLAG = setmetatable({}, { __index = function(_, k) return k end }),
    EVENT = setmetatable({}, { __index = function(_, k) return k end }),
    BUILTIN_FONT = { MONTSERRAT_14 = "stub-font" },
    -- fail on purpose so pcall'ing callers fall back, like an unknown face name
    Font = function() error("font face unavailable in stub") end,
}
function lvgl.Object(_, props) return new_obj(props) end
function lvgl.Timer(spec)
    local t = { period = spec.period, cb = spec.cb, paused = spec.paused }
    function t:pause() self.paused = true end
    function t:resume() self.paused = false end
    timers[#timers + 1] = t
    return t
end

local subs = {}
package.preload["lvgl"] = function() return lvgl end
package.preload["dataman"] = function()
    return { subscribe = function(channel, _, _) subs[channel] = true return true end }
end
package.preload["vibrator"] = function()
    return { type = { NOTIFICATION = 1, SUCCESS = 2, KEY_BOARD = 3 }, start = function() end }
end

local state_file = work_dir .. "yao_focus_state.txt"

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function read_state()
    local f = io.open(state_file, "r")
    if not f then return "(no state file)" end
    local body = f:read("a")
    f:close()
    return (body:gsub("\n", " "))
end

local function run(label)
    texts, handlers, timers, subs = {}, {}, {}, {}
    _G.SCRIPT_PATH = work_dir
    local ok, err = pcall(dofile, main_lua)
    print(string.format("== %s ==", label))
    if not ok then
        print("  ERROR: " .. tostring(err))
        return false
    end
    print(string.format("  subscriptions=%d  timers=%d  labels painted=%d",
        count(subs), #timers, #texts))
    for i, t in ipairs(texts) do print(string.format("    label[%d] = %q", i, t)) end
    print("  state: " .. read_state())
    return true
end

if seed_state then
    local src = io.open(seed_state, "r")
    if src then
        local body = src:read("a")
        src:close()
        local dst = io.open(state_file, "w")
        dst:write(body)
        dst:close()
        print("seeded state from " .. seed_state)
    else
        print("WARNING: seed state not found: " .. seed_state)
    end
end

if not run("load") then os.exit(1) end

-- Tap the first tall clickable container (a card), not the row buttons: handler
-- registration order in real layouts puts small row buttons first.
local tap_fn
for _, h in ipairs(handlers) do
    local box = h.obj.props or {}
    if h.event == "SHORT_CLICKED" and (box.h or 0) >= 100 and not tap_fn then
        tap_fn = h.fn
    end
end
print("")
if tap_fn then
    print("== tap tall container ==")
    local ok, err = pcall(tap_fn)
    if not ok then
        print("  ERROR: " .. tostring(err))
    else
        print("  state after tap: " .. read_state())
    end
else
    print("== tap tall container == skipped (none found) ==")
end

print("")
print("== reload from same directory ==")
run("reload")

print("")
print("Done. Assert on the label texts and state file above; the harness itself")
print("does not know what your face is supposed to show.")
