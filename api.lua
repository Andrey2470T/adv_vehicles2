-----------------‐---------------------------------------------------------------------------------
--                Advanced Vehicles II API by Andrey01
-----‐---------------------------------------------------------------------------------------------

--GLOBAL TABLE
vehicles = {}

---------------------------------------------------------------------------
--   Constants
---------------------------------------------------------------------------
vehicles.gravity = -9.8     -- gravity constant

vehicles.air_rfac = 0.3    -- air resistance factor


---------------------------------------------------------------------------
--   Dynamic Tables
---------------------------------------------------------------------------
vehicles.showed_fspecs = {}     --  pair: ["playername"] and {self, formname, [invname, invlist]}

vehicles.ngroups_friction_coefs = {   -- friction coefficients of some groups of nodes.
	["sand"] = 1.5,
	["soil"] = 0.6,
	["snowy"] = 0.9,
	["slippery"] = 0.1,
    ["default"] = 0.8
}


-----‐---------------------------------------------------------------------
--   API functions
---------------------------------------------------------------------------
vehicles.set_gravity = function(self)
     local obj = self.object
     local acc = obj:get_acceleration()
     local vel = obj:get_velocity()
     local m = minetest.registered_entities[self.name].mass
     obj:set_acceleration({x=acc.x, y=vehicles.gravity, z=acc.z}) 
end

--[[ Registers new vehicle (base and wheel)
base_props and wheel_props should contain def props for entity ('obj') and its item ('item')
]]
vehicles.register_vehicle = function(name, base_props, wheel_props)
    minetest.register_entity(MOD_NAME .. ":" .. name .. "_base", {
        vehicle_type             = base_props.obj.vehicle_type,
        physical                 = true,
        mass                     = base_props.obj.mass or 2000,     -- in kgs
        collide_with_objects     = true,
        collisionbox             = base_props.obj.bounding_box or {-0.5, 0.0, -0.5, 0.5, 1.0, 0.5},
        selectionbox             = base_props.obj.bounding_box or {-0.5, 0.0, -0.5, 0.5, 1.0, 0.5},
        visual                   = base_props.obj.visual,
        visual_size              = base_props.obj.visual_size or {x=1, y=1, z=1},
        mesh                     = (base_props.obj.visual == "mesh" and base_props.obj.mesh),
        textures                 = base_props.obj.textures or {""},
        use_texture_alpha        = base_props.obj.use_texture_alpha,
        seats                    = base_props.obj.seats,                                          -- table fields: {["is_busy"] = playername, [dplayer_obj] = ObjectRef, ["pos"]  = position, ["rot"] = rotation, ["getout_coords"] = coords from seat, ["type"] = ("driver" or "passenger"), ["model"] = <name>}
         --ctrl_vals = base_props.ctrl_vals,                               -- table fields: {["move"] = float (acc_len), ["turn"] = float (degs)}
        traction_force           = base_props.obj.traction_force or 5000,                -- in Neutons
        trunk_inv                    = base_props.obj.trunk_inv                                                               
        wheels                   = base_props.obj.wheels,                                        -- table fields: {["type"] = ("front" or "rear"), ["pos"] = position, ["rot"] = rotation, ["radius"] = wheel radius}
        max_speed                = base_props.obj.max_speed or 25000,                         -- in m/s
        compartments_edge        = base_props.obj.compartments_edge                   --  rough edge between the base body and the trunk along local Z-axis (num)
        stepheight               = base_props.obj.stepheight or 0.5,
        on_activate              = function(self, staticdata, dtime_s)
            self.seats = table.copy(base_props.obj.seats)
            local vehpos = self.object:get_pos()
            for i, seat in ipairs(self.seats) do
                seat.rot = seat.rot or {x=0, y=0, z=0}
                seat.radius = seat.radius or 0.5
            end
            self.wheels = {}
            self.move_dir = 0                -- specifies direction of the vehicle movement (1 is forward, -1 is backward)
            self.tracf = 0                   -- specifies direction of the traction force and contains its value (> 0 is forward, < 0 is backward, =0 is stay)
                                             
            -- Create detached inventory of the vehicle trunk
            if base_props.obj.trunk_inv then
                local tr_inv = base_props.obj.trunk_inv
                self.trunk_inv = #self.trunk_inv > 0 and self.trunk_inv or {}
                minetest.create_detached_inventory(tr_inv.name, {
                    allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
                        return count
                    end,
                    allow_put = function(inv, listname, index, stack, player)
                        return stack:get_count() 
                    end,
                    allow_take = function(inv, listname, index, stack, player)
                        return stack:get_count()
                    end
                })
                                                                   
                local inv = minetest.get_inventory({type="detached", name=tr_inv.name})
                inv:set_size(tr_inv.listname, tr_inv.listsize.w*tr_inv.listsize.h)
                inv:set_list(tr_inv.listname, self.trunk_inv)
            end
            
            local vehrot = self.object:get_rotation()
            for i, whl in ipairs(base_props.obj.wheels) do
                local whl_obj = minetest.add_entity({x=vehpos.x+whl.pos.x, y=vehpos.y+whl.pos.y, z=vehpos.z+whl.pos.z}, MOD_NAME .. ":" .. name .. "_wheel")
                whl_obj:set_attach(self.object,  "", whl.pos, whl.rot or {0, 0, 0})
                self.wheels[i] = {object=whl_obj, type=whl.type, pos=whl.pos, rot=whl.rot or {0, 0, 0}, radius=whl.radius}
            end
            vehicles.set_gravity(self)
        end,
        on_step = function(self, dtime)
            local drv_name = self.seats[vehicles.get_driver_i(self)].is_busy
            if drv_name then
                local player = minetest.get_player_by_name(drv_name)
                local ctrls = player:get_player_control()
                if ctrls.up then
                    minetest.debug("Going forward...")
                    self.move_dir = 1
                    self.tracf = 1
                end
                if ctrls.down then
                    minetest.debug("Going backward...")
                    self.move_dir = -1
                    self.tracf = -1            
                end
                if not ctrls.up and not ctrls.down then
                    minetest.debug("Stopping...")
                    self.tracf = 0
                end
            end
        
            local v3d_v = self.object:get_velocity()
            local v2d_v = {x=v3d_v.x, y=0, z=v3d_v.z}
            --minetest.debug("yaw: " .. self.object:get_yaw())
            --minetest.debug("velocity: " .. dump(v3d_v))
            local v2d_vl = vehicles.v2d_length(v2d_v)
            if v2d_vl < 0.4 and v2d_vl > 0 and self.tracf == 0 then
                minetest.debug("Stopped!")
                self.move_dir = 0
            end
                                                                   
            local yaw = self.object:get_yaw()
            local entity_def = minetest.registered_entities[self.name]
            local tdir_v = vehicles.v2d_coords(self.tracf*entity_def.traction_force, yaw)
            tdir_v.y = 0
            local max_fcoef = vehicles.max_fric_coef(self)
            local unit_v2d_v = vector.normalize(v2d_v)
            unit_v2d_v = vehicles.check_for_nan(unit_v2d_v)
                
            local sf_fforce = (math.abs(vehicles.gravity)*entity_def.mass)*max_fcoef*(-self.move_dir)   -- surface friction force
            local sf_fforce_v = vector.multiply(unit_v2d_v, sf_fforce)
            sf_fforce_v = vehicles.check_for_nan(sf_fforce_v)
            local air_rforce = v2d_vl^2 * vehicles.air_rfac * (-self.move_dir)          -- air resistance force
            local air_rforce_v = vector.multiply(unit_v2d_v, air_rforce)  
            air_rforce_v = vehicles.check_for_nan(air_rforce_v)
            if self.move_dir == 0 then
                minetest.debug("tdir_v: " .. dump(tdir_v))
                minetest.debug("sf_fforce_v: " .. dump(sf_fforce_v))
                minetest.debug("air_rforce_v: " .. dump(air_rforce_v))
            end
            
            --[[if self.tracf_dir ~= 0 then
                minetest.debug("self.tracf_dir: " .. self.tracf_dir)
                minetest.debug("sf_fforce: " .. sf_fforce)
                minetest.debug("air_rforce: " .. air_rforce)
            end]]
            --[[minetest.debug("tdir_v: " .. dump(tdir_v))
            minetest.debug("sf_fforce: " .. sf_fforce)
            minetest.debug("sf_fforce_v: " .. dump(sf_fforce_v))
            minetest.debug("air_rforce: " .. dump(air_rforce))
            minetest.debug("air_rforce_v: " .. dump(air_rforce_v))
            minetest.debug("tdir_v+sf_fforce_v: " .. dump(vector.add(tdir_v, sf_fforce_v)))
            minetest.debug("(tdir_v+sf_fforce_v)+air_rforce_v: " .. dump(vector.add(vector.add(tdir_v, sf_fforce_v), air_rforce_v)))
            minetest.debug("((tdir_v+sf_fforce_v)+air_rforce_v)/edef.mass: " .. dump(vector.divide(vector.add(vector.add(tdir_v, sf_fforce_v), air_rforce_v), edef.mass)))]]
            local acc = vector.divide(vector.add(vector.add(tdir_v, sf_fforce_v), air_rforce_v), entity_def.mass)
            acc.y = vehicles.gravity
            
            self.object:set_acceleration(acc})
		
            for i, d in ipairs(self.wheels) do
                d.object:set_rotation({x=vehicles.calc_angle_vel(vehicles.v2d_length(self.object:get_velocity()), d.radius)*dtime, y=0, z=0})
                --minetest.debug("wheels rotation: " .. dump(d.object:get_rotation()))
            end
		
        end,
        on_death = function(self, killer)
            for pn, f in pairs(self.showed_fspecs) do
                vehicles.close_compartments_menu(self, pn)
            end
            for i, sdata in ipairs(self.seats) do
                if sdata.is_busy then
                    vehicles.get_out(self, sdata.dplayer_obj:get_luaentity(), i)
                end
            end
            for i, whl in ipairs(self.wheels) do
                whl.object:remove()
            end
        end,
        on_rightclick = function(self, clicker)
            local vel = self.object:get_velocity()
            if vector.length(vel) ~= 0 then 
                minetest.chat_send_player(clicker:get_player_name(), "The vehicle needs to be stopped at first!")
                return 
            end
                                                                  
            local is_player_sit = vehicles.is_player_sit(clicker)
            if is_player_sit then
                vehicles.show_cabin_formspec(self, clicker:get_player_name())
            else
                vehicles.show_compartments_menu(self, clicker:get_player_name())
            end
            --[[local pos = self.object:get_pos()
            local range = minetest.registered_items[""].range
            local ray_vec = vector.new(0, 0, range)
            ray_vec = vector.rotate(ray_vec, {x=clicker:get_look_vertical(), y=clicker:get_look_horizontal(), z=0})
            local ray = minetest.raycast(pos, vehicles.convert_pos_to_absolute(pos, ray_vec), true)
        
            for pointed_thing in ray do
                if pointed_thing.ref == self.object then
                    local compart_edge = minetest.registered_entities[self.name].compartments_edge
            vehicles.show_seats_formspec(self, MOD_NAME .. ":vehicle_seats", clicker:get_player_name())]]
        end
               
    })
     
     
    minetest.register_craftitem(MOD_NAME .. ":" .. name .. "_base", {
        description = base_props.item.description or "",
        inventory_image = base_props.item.inv_image or "",
        on_place = function(itemstack, placer, pointed_thing)
            if pointed_thing.type =="node" and pointed_thing.above.y >= pointed_thing.under.y then
                minetest.add_entity(pointed_thing.above, itemstack:get_name())
            end
        end
    })
     
    minetest.register_entity(MOD_NAME .. ":" .. name .. "_wheel", {
        visual_size = wheel_props.obj.visual_size or {x=1, y=1, z=1},
        pointable = false,
        visual = wheel_props.obj.visual,
        mesh = (wheel_props.obj.visual == "mesh" and wheel_props.obj.mesh),
        textures = wheel_props.obj.textures or {""},
        use_texture_alpha = wheel_props.obj.use_texture_alpha
    })
     
    minetest.register_craftitem(MOD_NAME .. ":" .. name .. "_wheel", {
        description = wheel_props.item.description or "",
        inventory_image = wheel_props.item.inventory_image or ""
    })
    
    if base_props.obj.player_mdefs then
        if base_props.obj.player_mdefs.driver then
            player_api.register_model(base_props.obj.player_mdefs.driver.model_name, base_props.obj.player_mdefs.driver.def)
        elseif base_props.obj.player_mdefs.passenger then
            player_api.register_model(base_props.obj.player_mdefs.passenger.model_name, base_props.obj.player_mdefs.passenger.def)
        end
    end
end

vehicles.show_compartments_menu = function(self, playername)
    local formspec = "formspec_version[3]size[6,7.5]label[2.5,0.5;Open:]button[1,1.5;4,2;seats_cabin;Seats Cabin]"
    local trunk = minetest.registered_entities[self.name].trunk_inv
    if trunk then
        formspec = formspec .. "button[1,4.5;4,2;trunk;Trunk]"
    end
    
    vehicles.showed_fspecs[playername] = {self=self, formname=MOD_NAME .. ":compartments_menu"} 
    minetest.show_formspec(playername, MOD_NAME .. ":compartments_menu", formspec)
end

vehicles.show_cabin_formspec = function(self, playername)
    local seats_n = #self.seats
    local sbut_size = {x=4, y=1.5}
    local pad = 0.5
    local visible_cbuts_n = (seats_n <= 4 and seats_n or 4)
    local scontainer_size = {x=2*0.3 + sbut_size.x, y=visible_cbuts_n*sbut_size.y + (visible_cbuts_n+1)*0.3}
    
    local wsize_x = pad*2 + scontainer_size.x
    local is_player_sit = vehicles.is_player_sit(minetest.get_player_by_name(playername))
    local wsize_y = 2 + scontainer_size.y + (is_player_sit and 2.5 or pad)    -- + 2.5 units for 'Get Up' button placement
    
    local formspec = "formspec_version[3]size[" .. wsize_x .. ", " .. wsize_y .. "]" ..
            "label[" .. pad + 0.2 .. "," .. pad + 0.5 .. ";" .. minetest.formspec_escape("Select a seat to sit down or press to get up:") .. "]" ..
            "box[" .. pad .. ",2;" .. scontainer_size.x .. "," .. scontainer_size.y .. ";#000]" ..
            "scrollbaroptions[thumbsize=1000]" ..
            "scrollbar[" .. scontainer_size.x + pad .. ",2;0.3," .. scontainer_size.y .. ";vertical;vseats_scrollbar;0]" .. 
            "scroll_container[" .. pad .. ",2;" .. scontainer_size.x .. "," .. scontainer_size.y .. ";vseats_scrollbar;vertical;]"
    
    local butpos_y = 0.3
    for i, sdata in ipairs(self.seats) do
        local i_busy = sdata.is_busy
        formspec = formspec .. (i_busy and "style[seat_" .. i .. ";bgcolor=#FF0000]" or "") .. "button[0.3," .. butpos_y .. ";" .. sbut_size.x .. "," .. sbut_size.y .. 
                ";seat_" .. i .. ";" .. minetest.formspec_escape("#" .. i .. ((i_busy and "\n(busy by " .. playername .. ")") or "")) .. "]"
        
        butpos_y = butpos_y + sbut_size.y + 0.3
    end
    
    formspec = formspec .. "scroll_container_end[]" .. 
            (is_player_sit and "button[" .. wsize_x/2 - sbut_size.x/2 .. "," .. (wsize_y - (2.5/4*3)) .. ";4,1.5;get_up;" .. minetest.formspec_escape("Get up") .. "]" or "")
    
    
    vehicles.showed_fspecs[playername] = {self=self, formname=MOD_NAME .. ":seats_cabin"}
    minetest.show_formspec(playername, MOD_NAME .. ":seats_cabin", formspec)
end
    
vehicles.show_trunk_formspec = function(self, playername, invname, listname, inv_size)
    local pad = 0.5
    local slots_sp = 0.3
    local wsize_x = pad*2 + slots_sp*(inv_size.w-1) + inv_size.w
    local wsize_y = pad*2 + slots_sp*(inv_size.h-1) + inv_size.h + 0.7 + 4 + 3*slots_sp
    local formspec = "formspec_version[3]size[" .. wsize_x .. "," .. wsize_y .. "]" ..
            "list[detached:" .. listname .. ";" .. pad .. "," .. pad .. ";" .. inv_size.w .. "," .. inv_size.h .. "]" ..
            "list[current_player;main;" .. pad .. "," .. (wsize_y - (4+3+slots_sp+pad)) .. ";8,4]"
    
    vehicles.showed_fspecs[playername] = {self=self, formname=MOD_NAME .. ":trunk", invname=invname, listname=listname}
    minetest.show_formspec(playername, MOD_NAME .. ":trunk", formspec)
end

vehicles.close_compartments_menu = function(self, playername, cabin_action)
    local fd = vehicles.showed_fspecs[playername]
    if fd.formname == MOD_NAME .. ":seats_cabin" then
        vehicles.close_seats_formspec(self, playername, fd.formname, cabin_action, vehicles.is_player_sit(minetest.get_player_by_name(playername)))
    elseif fd.formname == MOD_NAME .. ":trunk" then
        vehicles.close_trunk_formspec(self, playername, fd.formname, fd.invname, fd.listname)
    end
    
    minetest.close_formspec(playername, MOD_NAME .. ":compartments_menu")
    vehicles.showed_fspecs[playername] = nil
end

--   'seat_id' is optional
--   'action' is supposed what to do with the player after closing (sit or go out off the vehicle)  [optional]
vehicles.close_seats_formspec = function(self, playername, formname, action, seat_id)      
    local player = minetest.get_player_by_name(playername)
    if action == "sit" then
        minetest.debug("close_seats_formspec")
        local is_busy = self.seats[seat_id].is_busy
        if is_busy then return end
        vehicles.sit(self, player, seat_id)
    elseif action == "get_up" then
        minetest.debug(dump(self.seats[seat_id].dplayer_obj))
        vehicles.get_out(self, self.seats[seat_id].dplayer_obj:get_luaentity(), seat_id)
        local getout_coords = self.seats[seat_id].getout_coords
        local yaw = self.object:get_yaw()
        local pos = self.object:get_pos()
        local player = minetest.get_player_by_name(playername)
        local rel_getout_pos = vector.rotate(vector.add(self.seats[seat_id].pos, getout_coords), {x=0, y=self.object:get_yaw(), z=0})
        minetest.debug(dump(pos))
        minetest.debug(dump(rel_getout_pos))
        player:set_pos(vehicles.convert_pos_to_absolute(pos, rel_getout_pos))
        local rand_look = {-90, 90}
        player:set_look_horizontal(yaw+rand_look[math.random(1, 2)])
        
    end
      
    minetest.close_formspec(playername, formname)
    vehicles.showed_fspecs[playername] = nil
end
            
vehicles.close_trunk_formspec = function(self, playername, formname, inv_name, list_name)
    local self = self.object:get_luaentity()
    if self then
        local inv = minetest.get_inventory(type="detached", name=inv_name)
        self.trunk_inv = inv:get_list(list_name)
    end
    
    minetest.close_formspec(playername, formname)
    vehicles.showed_fspecs[playername] = nil
end
      
vehicles.sit = function(self, player, seat_id)     -- seat_id is an id of a seat table of 'self.seats'
    local sel_seat = self.seats[seat_id]
    local plname = player:get_player_name()
    if type(sel_seat.is_busy) == "string" and sel_seat.is_busy ~= plname then
        minetest.chat_send_player(plname, "Seat #" .. seat_id .. " is busy by " .. sel_seat.is_busy .. "!")
        return 
    end
      
    local cur_seat_i = vehicles.is_player_sit(player)
    if cur_seat_i then
        vehicles.get_out(self, self.seats[cur_seat_i].dplayer_obj:get_luaentity(), cur_seat_i)
    end
      
    sel_seat.is_busy = player:get_player_name()
    local dummy_player
    if sel_seat.type == "driver" then
        minetest.debug("adding_dummy_driver...")
        dummy_player = minetest.add_entity(vehicles.convert_pos_to_absolute(self.object:get_pos(), sel_seat.pos), MOD_NAME .. ":dummy_driver")
        minetest.debug("added_dummy_driver!")
    elseif sel_seat.type == "passenger" then
        dummy_player = minetest.add_entity(vehicles.convert_pos_to_absolute(self.object:get_pos(), sel_seat.pos), MOD_NAME .. ":dummy_passenger")
    end
      
        
    sel_seat.dplayer_obj = dummy_player
    dummy_player:set_attach(self.object, "", sel_seat.pos, {x=0, y=180, z=0})
    minetest.debug("attaching_dummy_player...")
    player:set_attach(dummy_player, "", {x=0, y=0, z=0}, {x=0, y=0, z=0})
    minetest.debug("dummy_player_attached!")
    local dplayer_self = dummy_player:get_luaentity()
    dplayer_self.attached_player = player
    dplayer_self.last_visual_size = player:get_properties().visual_size
    player:set_properties({visual_size = vector.new(0, 0, 0)})
    player:set_look_horizontal(self.object:get_yaw()+180)
end

vehicles.get_out = function(self, dplayer, seat_id)
      if not dplayer.object or not dplayer.attached_player or not self.object:get_luaentity() then 
            return 
      end
      
      
      dplayer.object:set_detach()
      dplayer.attached_player:set_detach()
      dplayer.attached_player:set_properties({visual_size = dplayer.last_visual_size})
      dplayer.object:remove()
      self.seats[seat_id].is_busy = nil
      self.seats[seat_id].dplayer_obj = nil

end
      
vehicles.on_formspec_event = function(player, formname, fields) 
    local plname = player:get_player_name()
    local self = vehicles.showed_fspecs[player:get_player_name()].self
    if formname == MOD_NAME .. ":context_menu" then
        if fields.quit then
            vehicles.close_compartments_menu(self, plname)
        elseif fields.
      if formname ~= MOD_NAME .. ":vehicle_seats" or formname ~= MOD_NAME .. ":vehicle_trunk" then 
             return 
      end
      
      local plname = player:get_player_name()
      local obj = vehicles.showed_vehicle_fspecs[plname]
      local self = obj:get_luaentity()
      if self then
           for i, sdata in ipairs(self.seats) do
                local but_name = "seat_" .. i
                if fields[but_name] then
                    vehicles.close_seats_formspec(self, plname, formname, "sit", i)
                    return true
                end
           
                if fields["get_up"] then
                    vehicles.close_seats_formspec(self, plname, formname, "get_up", i)
                    return true
                end
           end
           
           if fields.quit then
                if formname == MOD_NAME .. ":vehicle_seats" then
                    vehicles.close_seats_formspec(self, plname, formname)
                    return true
                elseif formname == MOD_NAME .. ":vehicle_trunk" then
                    local edef = minetest.registered_entities[self.name]
                    vehicles.close_trunk_formspec(self, plname, formname, edef.trunk.name, edef.trunk.listname)
                    return true
                end
           end
      else     --   supposed that vehicle is died while the player is viewing the formspec
            if formname == MOD_NAME .. ":vehicle_seats" then
                vehicles.close_seats_formspec(self, plname, formname)
            elseif formname == MOD_NAME .. ":vehicle_trunk" then
                vehicles.close_trunk_formspec(self, plname, formname)
            end
      end
end
      

       
       
      
-------‐---------------------------------------------------------------------
--   Helper functions
-----------------------------------------------------------------------------

--  Derives the elements from range 'i1' up to 'i2' of 't' table into new one
--  i1 and i2 can be only positive
--  NOTE: table keys can be not only integral 
table.derive_elems = function(t, i1, i2)
    local new_t = {}
    local elem_c = 0
    for k, v in pairs(t) do
        elem_c = elem_c + 1
        if elem_c > i2 then
            return new_t
        end
        new_t[k] = v
    end
    
    return new_t
end

--   Checks whether t[v] is nan and if yes, replaces to zero. Returns changed table 
vehicles.check_for_nan = function(t)
    for k, v in pairs(t) do
        if v ~= v then
            t[k] = 0
        end
    end
    return t
end

vehicles.is_player_sit = function(player)
      local obj = player:get_attach()
      if not obj then return false end
      local self = obj:get_attach():get_luaentity()
      
      for i, sdata in pairs(self.seats) do
         if sdata.is_busy == player:get_player_name() then
              return i
         end
      end
      
      return false
end


--   Returns index in seats table where driver data is.
vehicles.get_driver_i = function(self)
     if not self then return end
     for i, sdata in ipairs(self.seats) do
        if sdata.type == "driver" then
            return i
        end
     end
     return 
end

     
-- Get sign of 'n' value
vehicles.get_sign = function(n)
    if n == 0 then
        return 0 
    end
    return n/math.abs(n)
end

--   Calculates an angle speed (in rads) of the wheel
vehicles.calc_angle_vel = function(vel_l, radius)  
    return vel_l
end

--   Calculates new (relative) coords of the acceleration vector 
vehicles.v2d_coords = function(a_len, yaw)
       local x = -a_len * math.sin(yaw)
       local z = a_len * math.cos(yaw)
       return {x=x, z=z}
end
       
vehicles.v2d_length = function(v2d)
       return math.sqrt(v2d.x^2 + v2d.z^2)
end
       
--   Find out max friction coefficient of nodes locating beneath the entity
vehicles.max_fric_coef = function(self)
       local max_friction_coef = 0
       local vehpos = self.object:get_pos()
       for i, whl in ipairs(self.wheels) do
              local pos = whl.object:get_pos()
              pos = vehicles.convert_pos_to_absolute(vehpos, pos)
              local undernode = minetest.get_node({x=pos.x, y=pos.y-whl.radius-0.1, z=pos.z})
              local group = vehicles.get_node_groupname(undernode.name)
              if max_friction_coef < vehicles.ngroups_friction_coefs[group] then
                    max_friction_coef = vehicles.ngroups_friction_coefs[group] 
              end
        end
        
        return max_friction_coef
end

--   Calculates a modulo of a friction force of the surface under the vehicle
vehicles.surface_fric_force = function(fric_coef, mass)
       return fric_coef*mass*-vehicles.gravity
end
              
              
--   Convert the relative pos coords to absolute
vehicles.convert_pos_to_absolute = function(origin, pos)
       return {x=origin.x+pos.x, y=origin.y+pos.y, z=origin.z+pos.z}
end

--   Convert the absolute pos coords to relative (relatively to 'origin')
vehicles.convert_pos_to_relative = function(origin, pos)
       return {x=pos.x-origin.x, y=pos.y-origin.y, z=pos.z-origin.z}
end

--   Returns a node group that associated with its certain type (e.g. sand/desert sand are "sand" group, snow block/snow with grass are "snowy" group)
vehicles.get_node_groupname = function(name)
      local groups = minetest.registered_nodes[name].groups
      --minetest.debug("nodename:" .. name)
      --minetest.debug("nodegroups:" .. dump(groups))
      for group, coef in pairs(vehicles.ngroups_friction_coefs) do
             if groups[group] then
                  return group
             end
      end
      return "default"
end

--   Calculates a modulo of an air resistance force (only along horizontal plane currently)
vehicles.air_resist_force = function(v_l)
      return vehicles.air_rfac * math.abs(v_l)^2
end
                            
                            
                      
                            
                            
-----------------------------------------------------------------------------
--   Callback Registrations
-----------------------------------------------------------------------------


minetest.register_on_player_receive_fields(vehicles.on_formspec_event)

minetest.register_on_leaveplayer(function(obj, timed_out)
        local is_player_sit = vehicles.is_player_sit(obj:get_luaentity())
        if is_player_sit then
                local self = obj:get_attach():get_attach():get_luaentity()
                vehicles.get_out(self, self.dplayer_obj:get_luaentity(), is_player_sit)
        end
end)
      

      
      
      
      
         


