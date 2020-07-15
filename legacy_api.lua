--  OLD OR UNUSED CODE FRAGMENTS FROM api.lua

--[[
on_rightclick
    local pos = self.object:get_pos()
    local range = minetest.registered_items[""].range
    local ray_vec = vector.new(0, 0, range)
    ray_vec = vector.rotate(ray_vec, {x=clicker:get_look_vertical(), y=clicker:get_look_horizontal(), z=0})
    local ray = minetest.raycast(pos, vehicles.convert_pos_to_absolute(pos, ray_vec), true)
        
    for pointed_thing in ray do
        if pointed_thing.ref == self.object then
            local compart_edge = minetest.registered_entities[self.name].compartments_edge
            vehicles.show_seats_formspec(self, MOD_NAME .. ":vehicle_seats", clicker:get_player_name())]]

--[[vehicles.show_cabin_formspec = function(self, formspec_name, playername)
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


--   checks if given vectors are co-directional along the horizontal plane; returns true, if they are, otherwise angle between them
--[[vehicles.are_horiz_codirectional = function(acc, vel)  
     local vec1 = vector.new(acc.x, 0, acc.z)
     local vec2 = vector.new(vel.x, 0, vel.z)
     local angle = math.deg(vector.angle(vec1, vec2))
     
     return (angle == 0) or (angle
end]]
