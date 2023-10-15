local mod = require 'core/mods'
local nb = require('tg/lib/nb/lib/nb')
local music = require('lib/musicutil')
local hook = require 'core/hook'
local tab = require 'tabutil'
-- Begin post-init hack block
if hook.script_post_init == nil and mod.hook.patched == nil then
    mod.hook.patched = true
    local old_register = mod.hook.register
    local post_init_hooks = {}
    mod.hook.register = function(h, name, f)
        if h == "script_post_init" then
            post_init_hooks[name] = f
        else
            old_register(h, name, f)
        end
    end
    mod.hook.register('script_pre_init', '!replace init for fake post init', function()
        local old_init = init
        init = function()
            old_init()
            for i, k in ipairs(tab.sort(post_init_hooks)) do
                local cb = post_init_hooks[k]
                print('calling: ', k)
                local ok, error = pcall(cb)
                if not ok then
                    print('hook: ' .. k .. ' failed, error: ' .. error)
                end
            end
        end
    end)
end
-- end post-init hack block


local scale = music.generate_scale(12, "Major", 8)

local scale_names = {}
for i = 1, #music.SCALES do
    table.insert(scale_names, music.SCALES[i].name)
end

local function n(i, s)
    return "tg_" .. s .. "_" .. i
end

function add_voice(i)
    params:add_group(n(i, "voicegroup"), "voice " .. i, 6)
    nb:add_param(n(i, "voice"), "voice " .. i)
    params:add_number(n(i, "note"), "note", 12, 127, 36, function(p)
        local snapped = music.snap_note_to_array(p:get(), scale)
        return music.note_num_to_name(snapped, true)
    end)
    local note = nil
    params:add_binary(n(i, "gate"), "gate " .. i, "momentary")
    params:set_action(n(i, "gate"), function(b)
        local player = params:lookup_param(n(i, "voice")):get_player()
        local vel = 1.0
        if b > 0 then
            if note ~= nil or params:get(n(i, "note")) ~= note then
                player:note_off(note)
            end
            note = params:get(n(i, "note"))
            player:note_on(note, vel)
        else
            player:note_off(note)
        end
    end)
    params:add_trigger(n(i, "trigger"), "trigger " .. i)
    params:set_action(n(i, "trigger"), function()
        local player = params:lookup_param(n(i, "voice")):get_player()
        local note = params:get(n(i, "note"))
        local length = params:get(n(i, "length"))
        local vel = 1.0
        player:play_note(note, vel, length)
    end)
    params:add_control(n(i, "length"), "length " .. i, controlspec.DELAY)
end

function pre_init()
    nb:init()
end

mod.hook.register("script_pre_init", "tg pre init", pre_init)
mod.hook.register("script_post_init", "tg post init", function()
    params:add_separator("tg")
    params:add_number("tg_root", "root", 1, 12, 12, function(p)
        return music.note_num_to_name(p:get())
    end)
    params:add_option("tg_scale", "scale", scale_names, 1)
    params:set_action("tg_scale", function()
        local s = scale_names[params:get("tg_scale")]
        scale = music.generate_scale(params:get("tg_root"), s, 8)
    end)
    params:set_action("tg_root", function()
        local s = scale_names[params:get("tg_scale")]
        scale = music.generate_scale(params:get("tg_root"), s, 8)
    end)
    local tg_root = params:lookup_param("tg_root")
    clock.run(function()
        clock.sleep(0)
        tg_root:bang()
    end)
    for v = 1, 4 do
        add_voice(v)
    end
    nb:add_player_params()
end)