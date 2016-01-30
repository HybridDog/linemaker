local load_time_start = os.clock()


-- a node for playing sound when
minetest.register_node("linemaker:soundnode", {
	sounds = {place = "default_place_node"},
	on_construct = function(pos)
		minetest.after(0, function(pos)
			if minetest.get_node(pos).name == "linemaker:soundnode" then
				minetest.remove_node(pos)
			end
		end, pos)
	end,
})

local playerdata = {}
local tool_active

-- the tool
minetest.register_tool("linemaker:tool", {
	description = "pull lines",
	inventory_image = "linemaker.png",
	stack_max = 1,
	node_placement_prediction = "linemaker:soundnode",
	on_place = function(itemstack, player, pt)
		if not player
		or not pt then
			return
		end

		local pname = player:get_player_name()

		if playerdata[pname] then
			return
		end

		playerdata[pname] = {
			range = 6,--vector.subtract()
			ps = {pt.above},
			pt = pt,
		}

		minetest.after(0.5, function()
			-- doesn't work mltiplayer this way I guess
			tool_active = true
		end)
	end,
})

-- an entity for seeing the ps
minetest.register_entity("linemaker:entity", {
	collisionbox = {0,0,0,0,0,0},
	visual = "cube",
	visual_size = {x=0.5, y=0.5},
	textures = {
		"default_stone.png", "default_stone.png", "default_stone.png", "default_stone.png", "default_stone.png", "default_stone.png",
	},
	timer = 0,
	on_step = function(self)
		if not self.pname
		or not self.id
		or not playerdata[self.pname]
		or not playerdata[self.pname].ps[self.id] then
			self.object:remove()
			return
		end
		local shpos = playerdata[self.pname].ps[self.id]
		local ispos = vector.round(self.object:getpos())
		if vector.equals(shpos, ispos) then
			return
		end
		self.object:moveto(shpos)
	end,
	on_serialize = function(self)
		self.object:remove()
	end,
})

-- updates object existencies
local objects = {}
local function update_objects(pname)
	local ops = objects[pname] or {}
	local ps = playerdata[pname].ps
	if #ops == #ps then
		return
	end
	if #ops < #ps then
		for i = #ops+1,#ps do
			local p = ps[i]
			local obj = minetest.add_entity(p, "linemaker:entity")
			local ent = obj:get_luaentity()
			ent.pname = pname
			ent.id = i
			ops[i] = obj
		end
		objects[pname] = ops
		return
	end
	for i = #ps+1,#ops do
		local p = ps[i]
		ops[i] = nil--add_object(p)
	end
	objects[pname] = ops
end

local creative_enabled = minetest.setting_getbool("creative_mode")

-- update to new positions
minetest.register_globalstep(function(dtime)
	-- abort if noone uses it
	if not tool_active then
		return
	end

	--[[ abort that it doesn't shoot too often (change it if your pc runs faster)
	timer = timer+dtime
	if timer < 0.1 then
		return
	end
	timer = 0 --]]

	local active
	for pname,data in pairs(playerdata) do
		local player = minetest.get_player_by_name(pname)

		local pt = data.pt
		local ps = data.ps
		local playerpos = player:getpos()
		playerpos.y = playerpos.y+1.625
		local wantedpos = vector.round(
			vector.add(
				playerpos,
				vector.multiply(player:get_look_dir(), data.range)
			)
		)
		if not vector.equals(ps[#ps], wantedpos) then
			playerdata[pname].ps = vector.line(pt.above, wantedpos)
			update_objects(pname)
		end

		if player:get_wielded_item():to_string() == "linemaker:tool"
		and player:get_player_control().RMB then
			active = true
		else
			local inv = player:get_inventory()
			local stackid = player:get_wield_index()+1
			ps[0] = pt.under
			for i = 1,#ps do
				local item, success = minetest.item_place_node(
					inv:get_stack("main", stackid),
					player,
					{under = ps[i-1], aboce = ps[i]}
				)
				print(tostring(success)) -- why is success always false?
				inv:set_stack("main",
					stackid,
					item
				)
			end
			playerdata[pname] = nil
		end
	end

	-- disable the function if noone currently uses it to reduce lag
	if not active then
		tool_active = false
	end
end)


local time = math.floor(tonumber(os.clock()-load_time_start)*100+0.5)/100
local msg = "[linemaker] loaded after ca. "..time
if time > 0.05 then
	print(msg)
else
	minetest.log("info", msg)
end
