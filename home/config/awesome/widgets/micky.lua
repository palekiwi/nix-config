--------------------------------------------------------------> dependencies ;

local gears = require('gears')

-----------------------------------------------------------------> locals -- ;

local stay_classes = {
    awesome
    -- taskbar
}
--+ class names defined here would insist micky stays where
--> he is at.

-------------------------------------------------------------------> methods ;

local function set_contains(set, key)
    return set[key] ~= nil
end

local micky = function()
    gears.timer.weak_start_new(0.05, function()
        local c = client.focus
        local cgeometry = c:geometry()

        mouse.coords({
            x = cgeometry.x + cgeometry.width / 2,
            y = cgeometry.y + cgeometry.height / 2
        })
    end)
end
--+ relocate mouse after slightly waiting for focus to
--> complete. you can adjust the timer if you are on a slow
--> cpu to give more time for the client to appear.

---------------------------------------------------------------------> signal ;

client.connect_signal("focus", function(c)
    local focused_client = c
    --+ client the focus is going towards

    gears.timer.weak_start_new(0.15, function()
        local client_under_mouse = mouse.current_client
        local should_stay = set_contains(stay_classes, client_under_mouse.class)

        if should_stay then return false end
        --+ exclusions

        if not client_under_mouse then
            micky()
            return false
        end
        --+ nothing under the mouse, move directly

        if focused_client:geometry().x ~= client_under_mouse:geometry().x
            or focused_client:geometry().y ~= client_under_mouse:geometry().y
        then
            micky()
            return false
        end
        --+ no need to relocate the mouse if already over
        --> the client.
    end)
    --+ mouse.current_client would point to the previous
    --> client without the callback.
end)

client.connect_signal("unmanage", function(c)
    local client_under_mouse = mouse.current_client

    local killed_client = c
    --+ client the focus is going towards

    if not client_under_mouse then
        return false
    end

    if client_under_mouse ~= c then
        micky()
    end
    --+ no need for the callback here.
end)

---------------------------------------------------------------------> export ;

return micky
