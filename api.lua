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
--   Nested Dynamic Tables
---------------------------------------------------------------------------
vehicles.showed_seats_fspecs = {}     --  pair: ["playername"] and objectref

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
	seats = base_props.obj.seats,       -- table fields: {["is_busy"] = playername, [dplayer_obj] = ObjectRef, ["pos"]  = position, ["rot"] = rotation, ["getout_coords"] = coords from seat, ["type"] = ("driver" or "passenger"), ["model"] = <name>}
         --ctrl_vals = base_props.ctrl_vals,     -- table fields: {["move"] = float (acc_len), ["turn"] = float (degs)}
	traction_force = base_props.obj.traction_force or 5000,    -- in Neutons
	wheels = base_props.obj.wheels,      -- table fields: {["type"] = ("front" or "rear"), ["pos"] = position, ["rot"] = rotation, ["radius"] = wheel radius}
	max_speed = base_props.obj.max_speed or 25000,    -- in m/s
    stepheight = base_props.obj.stepheight or 0.5,
	on_activate = function(self, staticdata, dtime_s)
		self.seats = table.copy(base_props.obj.seats)
        local vehpos = self.object:get_pos()
        for i, seat in ipairs(self.seats) do
            seat.rot = seat.rot or {x=0, y=0, z=0}
            seat.radius = seat.radius or 0.5
        end
		self.wheels = {}
		self.move_dir = 0   -- specifies direction of the vehicle movement (1 is forward, -1 is backward)
        self.tracf = 0      -- specifies direction of the traction force and contains its value (> 0 is forward, < 0 is backward, =0 is stay)
		
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
		local vehrot = self.object:get_rotation()
		for i, whl in ipairs(base_props.obj.wheels) do
			local whl_obj = minetest.add_entity({x=vehpos.x+whl.pos.x, y=vehpos.y+whl.pos.y, z=vehpos.z+whl.pos.z}, MOD_NAME .. ":" .. name .. "_wheel")
			whl_obj:set_attach(self.object,  "", whl.pos, whl.rot or {0, 0, 0})
			self.wheels[i] = {object=whl_obj, type=whl.type, pos=whl.pos, rot=whl.rot or {0, 0, 0}, radius=whl.radius}
		end
		vehicles.set_gravity(self)
		--self.acc_v2d = vehicles.v2d_coords(base_props.traction_force/base_props.mass, vehrot.y)        -- keep own vehicle 2d acceleration along horizontal plane that doesn`t depend to external impacts
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
            --[[if not ctrls.up or not ctrls.down then
                self.tracf = 0
            end]]
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
                
        --local tdir_sign = vehicles.get_sign(self.tracf_dir)
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
        --[[local sf_fforce_sign = vehicles.get_sign(sf_fforce)
		if tdir_sign == sf_fforce_sign then 
            sf_fforce = -sf_fforce 
            air_rforce = -air_rforce 
        end]]
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
		--local acc_sum = (self.tracf_dir + sf_fforce + air_rforce)/edef.mass
        --minetest.debug(acc_sum)
		--local acc2d = vehicles.v2d_coords(acc_sum, self.object:get_yaw())
        --minetest.debug(dump(acc2d))
        --[[v2d_vl = (sf_fforce_sign < 0 and -v2d_vl or v2d_vl)
        local new_vel = vehicles.v2d_coords(v2d_vl, self.object:get_yaw())
        new_vel.y = v2d_v.y
        self.object:set_velocity(new_vel)]]
        self.object:set_acceleration(acc)
		--self.object:set_acceleration({x=acc2d.x, y=self.object:get_acceleration().y, z=acc2d.z})
		
		for i, d in ipairs(self.wheels) do
			d.object:set_rotation({x=vehicles.calc_angle_vel(vehicles.v2d_length(self.object:get_velocity()), d.radius)*dtime, y=0, z=0})
            --minetest.debug("wheels rotation: " .. dump(d.object:get_rotation()))
		end
		
	end,
	on_death = function(self, killer)
		for i, sdata in ipairs(self.seats) do
            if sdata.is_busy then
                vehicles.get_out(self, sdata.dplayer_obj:get_luaentity(), i)
            end
		end
		for n, obj in pairs(vehicles.showed_seats_fspecs) do
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
    
    
    vehicles.showed_seats_fspecs[playername] = self.object
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
      --local anim = player_api.get_animation(player)
      --[[local pl_appear = minetest.registered_entities[self.name].player_sit_appearance
      local pl_data = {}
      if pl_appear then
            local old_mesh = player:get_properties().mesh
            local old_anim = table.pack(player:get_animation()) 
            if sel_seat.type == "driver" and pl_appear.driver then 
                pl_data.prev_model = old_mesh 
                pl_data.prev_anim = old_anim
                dummy_player:set_properties({mesh=pl_appear.driver.mesh})
                dummy_player:set_animation(table.unpack(pl_appear.driver.animation))
            elseif sel_seat.type == "passenger" and pl_appear.passenger then
                pl_data.prev_model = old_mesh
                pl_data.prev_anim = old_anim
                dummy_player:set_properties({mesh=pl_appear.passenger})
                dummy_player:set_animation(table.unpack(pl_appear.passenger.animation))
            end
      end]]
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
     --[[ if pl_data.prev_model then
            player_api.set_model(player, pl_data.prev_model)
      end
      if pl_data.prev_anim then
            player_api.set_animation(player, pl_data.prev_anim)
      end
      local seat = self.seats[pl_data.seat_id]
      seat.is_busy = nil
      plmeta:set_string("prev_data", "")]]
end
      
vehicles.on_formspec_event = function(player, formname, fields)
      if formname ~= MOD_NAME .. ":vehicle_seats" then 
             return 
      end
      
      local plname = player:get_player_name()
      local obj = vehicles.showed_seats_fspecs[plname]
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
               vehicles.close_seats_formspec(self, plname, formname)
               return true
           end
      else     --   supposed that vehicle is died while the player is viewing the formspec
           vehicles.close_seats_formspec(self, plname, formname)
      end
end
      
--   Returns traction force along according direction or nil if no player as a driver or any driving keys are not pressed
--[[vehicles.on_move = function(self)
      local drv_name = self.seats[vehicles.get_driver_i(self)].is_busy
      if not drv_name then return end
      local player = minetest.get_player_by_name(drv_name)
      local ctrls = player:get_player_control()
      local entity_def = minetest.registered_entities[self.name]
      local v2d_vl = vehicles.v2d_length(self.object:get_velocity())
      if ctrls.up then
            self.tracf_dir = entity_def.traction_force
      else
            self.tracf_dir = 0
      end
      if ctrls.down then
            self.tracf_dir = -entity_def.traction_force
      elseif not ctrls.down and not ctrls.up then
            self.tracf_dir = 0
      end
      
      if not ctrls.up or not ctrls.down then
          self.tracf_dir = 0
      end
      
end]]
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
    vehicles.showed_seats_fspecs[playername] = nil
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
      

      
      
      
      
         


