local mp = require 'mp'
local msg = require 'mp.msg'


local function search()
    local search_dialog = NumberInputter()
    local screen_w,screen_h,_ = mp.get_osd_size()

    local function tick_callback()
        local ass=assdraw.ass_new()
        ass:append(search_dialog:get_ass(screen_w,screen_h).text)
        mp.set_osd_ass(screen_w,screen_h,ass.text)
    end
    mp.register_event("tick", tick_callback)

    local function cancel_callback()
        search_dialog:stop()
        mp.set_osd_ass(screen_w,screen_h,"")
        mp.unregister_event(tick_callback)
    end
    local function callback(e,v)
        cancel_callback()
        msg.verbose("searching for: "..v)
        mp.commandv("loadfile", "ytdl://ytsearch50:"..v)

        local function trigger_gallery(prop,count)
            if count > 1 then
                msg.verbose("triggering gallery-view")
                mp.unobserve_property(trigger_gallery)
                mp.commandv("script-message", "gallery-view", "true")
            end
        end
        mp.observe_property("playlist-count", "number", trigger_gallery)
    end

    search_dialog:start({{"search","Search Youtube:",nil,"text"}}, callback, cancel_callback)
end

mp.add_forced_key_binding("/", "youtube-search", search)
