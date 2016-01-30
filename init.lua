local load_time_start = os.clock()


local playerdata = {}
local tool_active

-- the tool
minetest.register_tool("linemaker:tool", {
	description = "pull lines",
	inventory_image = "linemaker.png",
	stack_max = 1,
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

		minetest.sound_play("superpick", {pos = pt.above})
	end,
})

-- used when setting up an object
local function textures_for_entity(nodename)
	local textures
	local def = minetest.registered_nodes[nodename]
	if def then
		textures = def.tiles or def.tile_images
	end
	textures = textures or {"unknown_node.png"}
	if #textures == 6 then
		return textures
	end
	local ltex = textures[#textures]
	for i = #textures+1, 6 do
		textures[i] = ltex
	end
	return textures
end

-- an entity for seeing the ps
minetest.register_entity("linemaker:entity", {
	collisionbox = {0,0,0,0,0,0},
	visual = "cube",
	visual_size = {x=0.5, y=0.5},
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
local function update_objects(pname, player)
	local ops = objects[pname] or {}
	local ps = playerdata[pname].ps
	if #ops == #ps then
		return
	end
	if #ops < #ps then
		--for i = #ops+1,#ps do
		local textures
		for i = 1,#ps do
			if not ops[i] then
				textures = textures or textures_for_entity(
					player:get_inventory():get_stack(
						"main",
						player:get_wield_index()+1
					):to_string()
				)
				local p = ps[i]
				local obj = minetest.add_entity(p, "linemaker:entity")
				obj:set_properties({textures = textures})
				local ent = obj:get_luaentity()
				ent.pname = pname
				ent.id = i
				ops[i] = obj
			end
		end
		objects[pname] = ops
		return
	end
	for i = #ps+1,#ops do
		ops[i] = nil
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
			update_objects(pname, player)
		end

		if player:get_wielded_item():to_string() == "linemaker:tool"
		and player:get_player_control().RMB then
			active = true
		else
			local inv = player:get_inventory()
			local stackid = player:get_wield_index()+1
			ps[0] = pt.under
			for i = 1,#ps do
				local item, success = minetest.item_place(
					inv:get_stack("main", stackid),
					player,
					{under = ps[i-1], above = ps[i], type = "node"}
				)
				if success then
					inv:set_stack("main", stackid, item)
				end
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
