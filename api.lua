-----------------‐---------------------------------------------------------------------------------
--                Advanced Vehicles II API by Andrey01
-----‐---------------------------------------------------------------------------------------------

vehicles = {}

gravity = -9.8

local showed_seats_fspecs = {}     --  pair: ["playername"] and objectref

local ngroups_friction_coefs = {   -- friction coefficients of some groups of nodes.
	["sand"] = 1.5,
	["soil"] = 0.6,
	["snowy"] = 0.9,
	["slippery"] = 0.1,
    ["default"] = 0.8
}

-- Air resistance force is calculated for now only along the horizontal plane!
local air_rcoef = 0.3       -- air resistance coefficient


-----‐---------------------------------------------------------------------
--   API functions
---------------------------------------------------------------------------
vehicles.set_gravity = function(self)
     local obj = self.object
     local acc = obj:get_acceleration()
     local vel = obj:get_velocity()
     local m = minetest.registered_entities[self.name].mass
     obj:set_acceleration({x=acc.x, y=gravity, z=acc.z}) 
end

--[[ Registers new vehicle (base and wheel)
base_props and wheel_props should contain def props for entity ('obj') and its item ('item')
]]
vehicles.register_vehicle = function(name, base_props, wheel_props)
     minetest.register_entity(MOD_NAME .. ":" .. name .. "_base", {
	vehicle_type = base_props.obj.vehicle_type,
	physical = true,
	mass = base_props.obj.mass or 2000,     -- in kgs
	collide_with_objects = true,
	collisionbox = base_props.obj.bounding_box or {-0.5, 0.0, -0.5, 0.5, 1.0, 0.5},
	selectionbox = base_props.obj.bounding_box or {-0.5, 0.0, -0.5, 0.5, 1.0, 0.5},
	visual = base_props.obj.visual,
	visual_size = base_props.obj.visual_size or {x=1, y=1, z=1},
	mesh = (base_props.obj.visual == "mesh" and base_props.obj.mesh),
	textures = base_props.obj.textures or {""},
    use_texture_alpha = base_props.obj.use_texture_alpha,
	seats = base_props.obj.seats,       -- table fields: {["is_busy"] = playername, ["pos"]  = position, ["rot"] = rotation, ["type"] = ("driver" or "passenger"), ["model"] = <name>}
         --ctrl_vals = base_props.ctrl_vals,     -- table fields: {["move"] = float (acc_len), ["turn"] = float (degs)}
	traction_force = base_props.obj.traction_force or 5000,    -- in Neutons
	wheels = base_props.obj.wheels,      -- table fields: {["type"] = ("front" or "rear"), ["pos"] = position, ["rot"] = rotation, ["radius"] = wheel radius}
	max_speed = base_props.obj.max_speed or 25000,    -- in m/s
    stepheight = base_props.obj.stepheight or 0.5,
	on_activate = function(self, staticdata, dtime_s)
		self.seats = table.copy(base_props.obj.seats)
        
        for i, seat in ipairs(self.seats) do
            seat.rot = seat.rot or {x=0, y=0, z=0}
            seat.radius = seat.radius or 0.5
        end
		self.wheels = {}
		self.tracf_dir = 0   -- specifies a modulo and direction of the vehicle traction force (> 0 on forward, < 0 on backward, = 0 on stay)
		
        --[[if base_props.obj.player_model_def then
            self.player_models = {}
            if base_props.obj.player_model_def.driver then
                player_api.register_model(base_props.obj.player_model_def.driver.name, table.derive_elems(base_props.obj.player_model_def.driver, 2, #base_props.obj.player_model_def.driver))
                self.player_models.driver = base_props.obj.player_model_def.driver.name
            end
            if base_props.obj.player_model_def.passenger then
                player_api.register_model(base_props.obj.player_model_def.passenger.name, table.derive_elems(base_props.obj.player_model_def.passenger, 2, #base_props.obj.player_model_def.passenger))
                self.player_models.passenger = base_props.obj.player_model_def.passenger.name
            end
        end]]
		local rel_vehpos = self.object:get_pos()
		local vehrot = self.object:get_rotation()
		for i, whl in ipairs(base_props.obj.wheels) do
			local whl_obj = minetest.add_entity({x=rel_vehpos.x+whl.pos.x, y=rel_vehpos.y+whl.pos.y, z=rel_vehpos.z+whl.pos.z}, MOD_NAME .. ":" .. name .. "_wheel")
			whl_obj:set_attach(self.object,  "", whl.pos, whl.rot or {0, 0, 0})
			self.wheels[i] = {object=whl_obj, type=whl.type, pos=whl.pos, rot=whl.rot or {0, 0, 0}, radius=whl.radius}
		end
		vehicles.set_gravity(self)
		--self.acc_v2d = vehicles.v2d_coords(base_props.traction_force/base_props.mass, vehrot.y)        -- keep own vehicle 2d acceleration along horizontal plane that doesn`t depend to external impacts
	end,
	on_step = function(self, dtime)
		local max_fcoef = vehicles.max_fric_coef(self)
		local edef = minetest.registered_entities[self.name]
		local acc = self.object:get_acceleration()
		local sf_fforce = vehicles.surface_fric_force(max_fcoef, edef.mass, acc.y*edef.mass)
		local vel = self.object:get_velocity()
		local v2d_vl = vehicles.v2d_length(vel)
		local air_rforce = vehicles.air_resist_force(v2d_vl)
		vehicles.on_move(self)
		if v2d_vl == 0 then self.tracf_dir = 0 sf_fforce = 0 end
		if self.tracf_dir > 0 then sf_fforce = -sf_fforce air_rforce = -air_rforce end
		
		local acc_sum = (self.tracf_dir + sf_fforce + air_rforce)/edef.mass
		local acc2d = vehicles.v2d_coords(acc_sum, self.object:get_yaw())
        minetest.debug(dump(acc2d))
		self.object:set_acceleration({x=acc2d.x, y=acc.y, z=acc2d.z})
		
		for i, d in ipairs(self.wheels) do
			d.object:set_rotation(vehicles.calc_angle_vel(vel, d.radius))
		end
		
	end,
	on_death = function(self, killer)
		for i, sdata in ipairs(self.seats) do
			vehicles.get_out(self, sdata.is_busy and minetest.get_player_by_name(sdata.is_busy))
		end
		for n, obj in pairs(showed_seats_fspecs) do
			if obj == self.object then
				vehicles.close_seats_formspec(self, n, MOD_NAME .. ":vehicle_seats")
			end
		end
		for i, whl in ipairs(self.wheels) do
			whl.object:remove()
		end
	end,
	on_rightclick = function(self, clicker)
		vehicles.show_seats_formspec(self, MOD_NAME .. ":vehicle_seats", clicker:get_player_name())
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

vehicles.show_seats_formspec = function(self, formspec_name, playername)
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
    
    
    showed_seats_fspecs[playername] = self.object
    minetest.show_formspec(playername, formspec_name, formspec)
end
    
--[[vehicles.show_seats_formspec = function(self, formspec_name, playername)
    local seats_n = #self.seats
    local min_sbut_s = {x=1, y=0.5}   -- min seat button size
    local max_sbut_s = {x=4, y=2}
    local buts_space_w = 0.3    -- space button size doesn`t depend on buttons` sizes
    local buts_space_h = 0.2  
    local w_sbut, h_sbut = 0.5, 0.5     -- distance between window edge and button doesn`t depend on buttons` sizes
    
    local sizedowns_n = math.ceil(math.sqrt(seats_n))   -- number of button sizedowns
    local but_new_x_s = max_sbut_s.x-0.5*sizedowns_n
    local but_new_y_s = max_sbut_s.y-0.5*sizedowns_n
    
    local wsize_chx = 0
    local wsize_chy = 0
    if but_new_x_s < min_sbut_s.x or but_new_y_s < min_sbut_s.y then
        but_new_x_s = min_sbut_s.x
        but_new_y_s = min_sbut_s.y
        
        wsize_chx = 1.5*sizedowns_n-(max_sbut_s.x-min_sbut_s.x)
        wsize_chy = 1.5*sizedowns_n-(max_sbut_s.y-min_sbut_s.y)
    end
    
    local wsize_x = sizedowns_n*but_new_x_s + 2*w_sbut + (sizedowns_n-1)*buts_space_w + wsize_chx
    local wsize_y = sizedowns_n*but_new_y_s + 2*h_sbut + (sizedowns_n-1)*buts_space_h + wsize_chy + 2    -- '+ 2' is a space for label text
    local is_player_sit = vehicles.is_player_sit(minetest.get_player_by_name(playername))
    wsize_y = is_player_sit and wsize_y + 2 or wsize_y
    
    local formspec = "formspec_version[3]size[" .. wsize_x .. ", " .. wsize_y .. "]label[" .. wsize_x/4 .. ",1;" .. minetest.formspec_escape("Select a seat to sit down or press to get up:") .. "]"
    
    local bpos_x = w_sbut
    local bpos_y = 2
    
    for i = 1, seats_n do
        minetest.debug(i)
        bpos_x = ((i <= sizedowns_n or i > (math.pow(sizedowns_n, 2)-sizedowns_n)) and bpos_x + w_sbut) or bpos_x + buts_space_w
        bpos_y = ((i%sizedowns_n == 0) and bpos_y + h_sbut) or (((i-1)%sizedowns_n == 0) and 2 + h_sbut) or bpos_y + buts_space_h
        
        local i_busy = self.seats[i].is_busy
        formspec = formspec .. ((i_busy and "style[seat_" .. i .. ";bgcolor=#FF0000]") or "")
        formspec = formspec .. "button[" .. 
                bpos_x .. "," .. bpos_y .. ";" ..
                but_new_x_s .. "," .. but_new_y_s .. 
                ";seat_" .. i .. ";" .. minetest.formspec_escape("#" .. i .. ((i_busy and "\n" .. playername) or "")) .. "]"
        
        bpos_x = (i ~= 1 and (i-1)%sizedowns_n == 0 and bpos_x + but_new_x_s) or bpos_x
        bpos_y = bpos_y + but_new_y_s
        
        bpos_x = i == (math.pow(sizedowns_n, 2)-sizedowns_n+1) and bpos_x + w_sbut or (i-1)%sizedowns_n == 0 and bpos_x + buts_space_w
        bpos_y = i%sizedowns_n == 0 and 2 or bpos_y + buts_space_h
    end
    
    formspec = (is_player_sit and (formspec .. "button[" .. 
            wsize_x/2 - ((but_new_x_s+2)/2) .. "," .. bpos_y .. ";" ..
            but_new_x_s+2 .. "," .. wsize_y - bpos_y - (buts_space_h + 0.5 + h_sbut) ..
            ";get_up;" .. minetest.formspec_escape("Get up") .. "]")) or formspec
    
    
    showed_seats_fspecs[playername] = self.object
    minetest.show_formspec(playername, formspec_name, formspec)
        
    
    
end]]
--[[vehicles.show_seats_formspec = function(self, formspec_name, playername)
      local seats_n = #self.seats
      --minetest.debug(seats_n)
      local buts_space_w = 0.2
      local buts_space_h = 0.3     -- space between buttons along width and height
      local int = math.modf(seats_n/8)
      local columns_n = (seats_n % 8 == 0 and int) or int + 1
      local max_col_cells_n = (seats_n >= 8 and 8) or seats_n
      local w_sbut, h_sbut = 2, 0.5
      local fspec_size_w = columns_n * w_sbut + (columns_n + 1) * buts_space_w
      local fspec_size_h = max_col_cells_n * h_sbut + (max_col_cells_n+1) * buts_space_h + 2    -- + 2 is a space for label text
      local is_player_sit = vehicles.is_player_sit(minetest.get_player_by_name(playername))
      fspec_size_h = (is_player_sit and fspec_size_h + 2) or fspec_size_h    -- if player sits the vehicle, heighten the formspec window still at 2 units
      local formspec = "size[" .. fspec_size_w .. ", " .. fspec_size_h .. "]label[2,1;" .. minetest.formspec_escape("Select a vacant seat inside the vehicle below:") .. "]"
      
      local bpos_x = buts_space_w
      minetest.debug(bpos_x)
      local bpos_y = buts_space_h+2
      for i = 1, seats_n do
          formspec = formspec .. "button[" .. 
                  tostring(bpos_x) .. "," .. bpos_y .. ";" .. 
                  w_sbut .. "," .. h_sbut .. 
                  ";seat_" .. i .. ";" .. minetest.formspec_escape("Seat #" .. i) .. "]"
          bpos_x = ((i - 1) % 8 == 0) and bpos_x + w_sbut + buts_space_w
          bpos_y = (((i - 1) % 8 == 0) and buts_space_h+2) or bpos_y + h_sbut + buts_space_h
      end
      
      formspec = (is_player_sit and (formspec .. "button[" .. fspec_size_w / 2 - w_sbut / 2 .. ", " .. fspec_size_h - 1.5 .. ";" .. w_sbut .. ", " .. h_sbut .. ";get_out;" .. minetest.formspec_escape("Get out") .. "]")) or formspec
      --minetest.debug(formspec)
      showed_seats_fspecs[playername] = self.object
      minetest.show_formspec(playername, formspec_name, formspec)
end]]
      
vehicles.sit = function(self, player, seat_id)     -- seat_id is an id of a seat table of 'self.seats'
      local sel_seat = self.seats[seat_id]
      local plname = player:get_player_name()
      if type(sel_seat.is_busy) == "string" and sel_seat.is_busy ~= plname then
            minetest.chat_send_player(plname, "Seat #" .. seat_id .. " is busy by " .. sel_seat.is_busy .. "!")
            return 
      end
      
      local cur_seat = vehicles.is_player_sit(player)
      if cur_seat then
          self.seats[cur_seat.seat_id].is_busy = nil
      end
      
      sel_seat.is_busy = player:get_player_name()
      local plmeta = player:get_meta()
      local anim = player_api.get_animation(player)
      local pl_mdefs = minetest.registered_entities[self.name].player_mdefs
      local pl_data = {}
      if pl_mdefs then
            if sel_seat.type == "driver" and pl_mdefs.driver then 
                pl_data.prev_model = anim.model
                pl_data.prev_anim = anim.animation
                player_api.set_model(player, pl_mdefs.driver.model_name)
            elseif sel_seat.type == "passenger" and pl_mdefs.passenger then
                pl_data.prev_model = anim.model
                pl_data.prev_anim = anim.animation
                player_api.set_model(player, pl_mdefs.passenger.model_name)
            end
      end
      
      pl_data.prev_pos = player:get_pos()
      pl_data.prev_rot = player:get_rotation()
      pl_data.seat_id = seat_id
      plmeta:set_string("prev_data", minetest.serialize(pl_data))
      player:set_attach(self.object, "", sel_seat.pos, sel_seat.rot)
      player:set_eye_offset(sel_seat.pos, sel_seat.pos)
      player:set_look_horizontal(self.object:get_yaw()+180)
      player_api.player_attached[player:get_player_name()] = true
end

vehicles.get_out = function(self, player)
      if not player or not self.object:get_luaentity() then 
            return 
      end
      
      player:set_detach()
      local plmeta = player:get_meta()
      local pl_data = minetest.deserialize(plmeta:get_string("prev_data"))
      if pl_data.prev_model then
            player_api.set_model(player, pl_data.prev_model)
      end
      if pl_data.prev_anim then
            player_api.set_animation(player, pl_data.prev_anim)
      end
      local seat = self.seats[pl_data.seat_id]
      seat.is_busy = nil
end
      
vehicles.on_formspec_event = function(player, formname, fields)
      if formname ~= MOD_NAME .. ":vehicle_seats" then 
             return 
      end
      
      local plname = player:get_player_name()
      local obj = showed_seats_fspecs[plname]
      local self = obj:get_luaentity()
      if self then
           for i, sdata in ipairs(self.seats) do
                  local but_name = "seat_" .. i
                  if fields[but_name] then
                       vehicles.close_seats_formspec(self, plname, formname, "sit", i)
                       return true
                  end
           end
           
           if fields["get_up"] then
                vehicles.close_seats_formspec(self, plname, formname, "get_up")
                return true
           end
      else     --   supposed that vehicle is died while the player is viewing the formspec
           vehicles.close_seats_formspec(self, plname, formname)
      end
end
      
--   Returns traction force along according direction or nil if no player as a driver or any driving keys are not pressed
vehicles.on_move = function(self)
      local drv_name = self.seats[vehicles.get_driver_i(self)].is_busy
      if not drv_name then return end
      minetest.debug("Driver is available!")
      local player = minetest.get_player_by_name(drv_name)
      local ctrls = player:get_player_control()
      local entity_def = minetest.registered_entities[self.name]
      if ctrls.up then
           self.tracf_dir = entity_def.traction_force
      end
      if ctrls.down then
           self.tracf_dir = -entity_def.traction_force
      end
      
end
      --[[if ctrls.up and vehicles.v2d_length(self.acc_v2d) == 0 then
           local new_acc = vector.add(acc, {x=self.acc_v2d.x, y=0, z=self.acc_v2d.z})
           self.object:set_acceleration(new_acc)
      else
           self.acc_v2d = {x=0, z=0}
      end
      
      if ctrls.down and vehicles.v2d_length(self.acc_v2d) == 0 then
           local new_acc = vector.add(acc, {x=-self.acc_v2d.x, y=0, z=-self.acc_v2d.z})
           self.object:set_acceleration(new_acc)
      else
           self.acc_v2d = {x=0, z=0}
      end]]
         --[[  local acc_len = vector.length(acc)
           if acc_len <= ctrl_vals.up then
                 new_acc.x = acc.x
                 new_acc.z = acc.z
           local v_and_a_codir = vehicles.are_horiz_codirectional(acc, vel)
           if type(v_and_a_codir) == "number" then]]

--[[vehicles.force_brake = function(self)
       local max_fcoef = vehicles.max_fric_coef(self)
       local edef = minetest.registered_entities[self.name]
       local fric_force = vehicles.friction_force(max_fcoef, edef.mass, math.abs(self.object:get_acceleration().y))
       local acc = self.object:get_acceleration()
       local tracforce = edef.mass*vehicles.v2d_length({x=acc.x, z=acc.z})
       local new_acc_len = (tracforce-fric_force)/edef.mass
       local new_acc_coords = vector
       
       local brake_vec = vehicles.get_acc_vect(vehicles.v2d_length({x=acc.x, z=acc.z})/max_fcoef, acc.y, self.object:get_yaw()+math.rad(180))]]
       
       
                
      
      
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

vehicles.is_player_sit = function(player)
      local obj = player:get_attach()
      if not obj then return false end
      
      local prev_data = minetest.deserialize(player:get_meta():get_string("prev_data"))
      return prev_data
end

--   'seat_id' is optional
--   'action' is supposed what to do with the player after closing (sit or go out off the vehicle)  [optional]
vehicles.close_seats_formspec = function(self, playername, formname, action, seat_id)      
    local player = minetest.get_player_by_name(playername)
    if action == "sit" then
        local is_busy = self.seats[seat_id].is_busy
        if is_busy then return end
        vehicles.sit(self, player, seat_id)
    elseif action == "get_up" then
        vehicles.get_out(self, player)
        local pl_meta = player:get_meta()
        local pl_data = minetest.deserialize(pl_meta:get_string("prev_data"))
        player:set_pos(pl_data.prev_pos)
        player:set_rotation(pl_data.prev_rot)
        pl_data = nil
        pl_meta:set_string("prev_data", "")
    end
      
    minetest.close_formspec(playername, formname)
    showed_seats_fspecs[playername] = nil
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

--   checks if given vectors are co-directional along the horizontal plane; returns true, if they are, otherwise angle between them
--[[vehicles.are_horiz_codirectional = function(acc, vel)  
     local vec1 = vector.new(acc.x, 0, acc.z)
     local vec2 = vector.new(vel.x, 0, vel.z)
     local angle = math.deg(vector.angle(vec1, vec2))
     
     return (angle == 0) or (angle
end]]
     
--   Calculates an angle speed (in rads) of the wheel
vehicles.calc_angle_vel = function(vel, radius)    
       return {x=vel.x/radius, y=vel.y/radius, z=vel.z/radius}
end

--vehicles.rotate_acc_vect = function(old_acc, turn_ang)
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
              if max_friction_coef < ngroups_friction_coefs[group] then
                    max_friction_coef = ngroups_friction_coefs[group] 
              end
        end
        
        return max_friction_coef
end

--   Calculates a modulo of a friction force of the surface under the vehicle
vehicles.surface_fric_force = function(fric_coef, mass, g)
       return fric_coef*mass*-g
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
      for group, coef in pairs(ngroups_friction_coefs) do
             if groups[group] then
                  return group
             end
      end
      return "default"
end

--   Calculates a modulo of an air resistance force (only along horizontal plane currently)
vehicles.air_resist_force = function(v_l)
      return air_rcoef * math.abs(v_l)^2
end
                            
                            
                      
                            
                            
-----------------------------------------------------------------------------
--   Callback Registrations
-----------------------------------------------------------------------------


minetest.register_on_player_receive_fields(vehicles.on_formspec_event)

minetest.register_on_leaveplayer(function(obj, timed_out)
        local is_player_sit = vehicles.is_player_sit(obj:get_luaentity())
        if is_player_sit then
                local parent = obj:get_attach()
                local self = parent:get_luaentity()
                self.seats[is_player_sit.seat_id].is_busy = nil
        end
end)
      
      
      
      
      
         


