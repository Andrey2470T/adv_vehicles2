MOD_NAME = "adv_vehicles2"    --   global macro
local modpath = minetest.get_modpath(MOD_NAME)
dofile(modpath .. "/api.lua")

--[[minetest.register_entity("cars_api:car", {
	mass = 2000,   -- in kg
	physical = true,
	visual = "cube",
	on_activate = function(self, staticdata, dtime_s)
	      self.mass = 2000
	      self.step = function(self, dtime)
	             cars.set_gravity(self)
	      end
	end
})

minetest.register_craftitem("cars_api:car", {
	description = "Car",
	on_place = function(itemstack, placer, pointed_thing)
	      if pointed_thing.type == "node"  then
	            minetest.add_entity(pointed_thing.above, "cars_api:car")
	      end
	end
})

minetest.register_globalstep(function(dtime)
      minetest.debug(dump(minetest.luaentities))
      for i, self in pairs(minetest.luaentities) do
            minetest.debug(i .. ": " .. dump(self))
            if self.step then 
                  self.step(self, dtime)
            end
      end
end)]]

--    Test car
--[[vehicles.register_vehicle("cube_car", {
	vehicle_type = "ground",
	visual = "cube",
	mass = 2000,
	bounding_box = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
	seats = {{type = "driver", pos = {0, 0.3, 0}}}
	}, {
		description = "Cube car"
    }
)]]

vehicles.register_vehicle("bmw", {
    obj = {
        vehicle_type = "ground",
        mass = 2000,
        bounding_box = {-1.7, -0.5, -4.5, 1.6, 2.2, 2.7},
        visual = "mesh",
        visual_size = {x=3.5, y=3.5, z=3.5},
        mesh = "bmw_fw.b3d",
        textures = {"bmw.png"},
        seats = {
                 {
                  ["pos"] = {x=-2.5, y=-1.5, z=-3.0},
                  ["type"] = "driver"
                 },
                 {
                  ["pos"] = {x=2.5, y=-1.5, z=-3.0},
                  ["type"] = "passenger"
                 },
                 {
                  ["pos"] = {x=0.0, y=-1.5, z=5.5},
                  ["type"] = "passenger"
                 }
        },
        traction_force = 5000,
        wheels = {
                  {
                   ["type"] = "front",
                   ["pos"] = {x=-3.1, y=-0.05, z=-7.55},
                   ["radius"] = 0.5
                  },
                  {
                   ["type"] = "front",
                   ["pos"] = {x=2.9, y=-0.05, z=-7.55},
                   ["rot"] = {x=0, y=180, z=0},
                   ["radius"] = 0.5
                  },
                  {
                   ["type"] = "rear",
                   ["pos"] = {x=-3.1, y=-0.05, z=4.85},
                   ["radius"] = 0.5
                  },
                  {
                   ["type"] = "rear",
                   ["pos"] = {x=2.9, y=-0.05, z=4.85},
                   ["rot"] = {x=0, y=180, z=0},
                   ["radius"] = 0.5
                  }
        },
        max_speed = 50000,
        stepheight = 0.5
    },
    item = {
        description = "BMW Spawner",
        inv_image = "bmw_inv.png"
    }
},  {
    obj = {
        visual = "mesh",
        visual_size = {x=1, y=1, z=1},
        mesh = "bmw_wheel.b3d",
        textures = {"bmw.png"}
    },
    item = {
        description = "BMW wheel",
        inventory_image = "bmw_wheel.png"
    }
}  
)
	
	
