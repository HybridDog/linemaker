local load_time_start = os.clock()


-- how many nodes are allowed to be set at once
local max_nodes = 10000

local max_objects = 40 -- should fix forced deletion

local function infolog(txt)
	minetest.log("info", "[linemaker] "..txt)
end

local playerdata = {}
local tool_active

-- the tool
minetest.register_tool("linemaker:tool", {
	description = "Linemaker",
	inventory_image = "linemaker.png",
	stack_max = 1,
	on_place = function(_, player, pt)
		if not player
		or not pt then
			return
		end

		local pname = player:get_player_name()
		if playerdata[pname] then
			return
		end

		if player:get_player_control().aux1 then
			minetest.sound_play("linemaker_config", {pos = pt.above})
			pt.under, pt.above = pt.above, pt.under
		end

		local playerpos = player:getpos()
		playerpos.y = playerpos.y+1.625

		playerdata[pname] = {
			range = vector.length(vector.subtract(playerpos, pt.above)),
			ps = {pt.above},
			pt = pt,
			disabletimer = 0.5,
		}
		tool_active = true

		minetest.sound_play("linemaker_place", {pos = pt.above})

		infolog(pname.." places with linemaker "..dump(playerdata[pname]))
	end,
})

-- update startpos when punching sth
minetest.register_on_punchnode(function(_,_, player, pt)
	if not pt
	or player:get_wielded_item():to_string() ~= "linemaker:tool" then
		return
	end

	local pname = player:get_player_name()
	if not playerdata[pname] then
		return
	end
	local pcontrol = player:get_player_control()

	if pcontrol.aux1 then
		minetest.sound_play("linemaker_config", {pos = pt.above})
		pt.under, pt.above = pt.above, pt.under
	end

	if pcontrol.sneak then
		playerdata[pname].pt = pt
		minetest.sound_play("linemaker_place", {pos = pt.above})
		infolog(pname.." changed pt to "..dump(pt))
		return
	end

	minetest.sound_play("linemaker_range", {pos = pt.above})
	local playerpos = player:getpos()
	playerpos.y = playerpos.y+1.625
	local range = vector.length(vector.subtract(playerpos, pt.above))
	playerdata[pname].range = range
	infolog(pname.." changed range to "..range)
end)

-- used when setting up an object
local function textures_for_entity(nodename)
	local textures
	local def = minetest.registered_items[nodename]
	if def then
		textures = def.tiles or def.tile_images
			or (def.inventory_image and {def.inventory_image})
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
	--automatic_rotate = math.pi*2 /-(60*24), -- 1 rotation every hour
	automatic_face_movement_dir = 90,
	automatic_face_movement_max_rotation_per_sec = 360*2,
	makes_footstep_sound = true,
	on_step = function(self)
		if not self.pname
		or not self.id
		or not playerdata[self.pname]
		or not playerdata[self.pname].ps[self.id] then
			self.object:remove()
			return
		end
		local ps = playerdata[self.pname].ps
		local ditadd = #ps / max_objects
		local id = self.id
		if ditadd > 1 then
			id = math.ceil(id * ditadd)
		end
		local shpos = ps[id]
		if not shpos then
			--print(id, #ps)
			self.object:remove()
			return
		end
		local ispos = self.object:getpos()
		if vector.equals(shpos, vector.divide(
			vector.round(vector.multiply(ispos, 100)),
			100
		)) then
			if self.object:getyaw() ~= 0 then
				self.object:setacceleration(vector.zero)
				self.object:setvelocity(vector.zero)
				self.object:setyaw(0)
			end
			return
		end

		--[[
		x = at²+v0t+x0
		v = 2at+v0

		v = f*(px-x)
		2at+v0 = f*(px-(at²+v0t+x0))
		2at = f*(px-at²-v0t-x0)-v0
		2at+f*at² = f*(px-v0t-x0)-v0
		a = (f*(px-v0t-x0)-v0)/(2t+ft²)

		a = (f*(shpos[c]-vel[c]*t-ispos[c])-vel[c])/(t*(2+f*t))
		]]

		-- [[ accelerate to its goal
		--shpos = vector.divide(vector.add(shpos, ispos), 2)
		local acc = {}
		local vel = self.object:getvelocity()
		--local t = vector.length(vel)/200 + 0.01
		local t = 0.2
		local f = 80
		for c,v in pairs(shpos) do
			acc[c] = (f*(v-vel[c]*t-ispos[c])-vel[c])/(t*(2+f*t))
			--acc[c] =(v-ispos[c]-vel[c]*t)/(t*t)
		end

		-- [[ avoid those crashes
		local accstrength = vector.length(acc)
		if accstrength > 50 then
			acc = vector.multiply(acc, 50/accstrength)
		end
		--]]

		self.object:setacceleration(acc)--]]

		-- self.object:moveto(shpos)
	end,
	on_serialize = function(self)
		self.object:remove()
		infolog("obj removed because it wanted to serialize")
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
		local textures, spawnpos
		for i = 1,math.min(#ps, max_objects) do
			if not ops[i] then
				textures = textures or textures_for_entity(
					player:get_inventory():get_stack(
						"main",
						player:get_wield_index()+1
					):get_name()
				)
				spawnpos = spawnpos or playerdata[pname].pt.above --player:getpos()

				local obj = minetest.add_entity(spawnpos, "linemaker:entity")
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
		if ops[i] then
			ops[i]:remove()
			ops[i] = nil
		end
	end
	objects[pname] = ops
end

local function get_line_ps(p1, p2)
	--local t1 = minetest.get_us_time()
	local round_goal = vector.round(p2)
	local range = vector.distance(p1, p2)+1
	local dir = vector.direction(p1, p2)
	local ps,n = {},1
	for pos in vector.rayIter(p1, dir) do
		ps[n] = pos
		if vector.equals(round_goal, pos)
		or (vector.distance(p2, pos) < 3 and vector.distance(p1, pos) > range)
		or n > max_nodes then
			break
		end
		n = n+1
	end
	--print((minetest.get_us_time() - t1) / 1000000) -- takes less than a millisecond
	return ps
end

-- what happens when it's active
local update_lines = 0
local function do_linemaker_step(dtime)
	local lineupdate
	update_lines = update_lines+dtime
	-- 300 ms nyan
	if update_lines > 0.3 then
		update_lines = 0
		lineupdate = true
	end
	local active
	for pname,data in pairs(playerdata) do
		local player = minetest.get_player_by_name(pname)
		local pcontrol = player:get_player_control()

		local pt = data.pt
		local ps = data.ps
		local disabletimer = data.disabletimer

		-- update objects and positions
		local playerpos = player:getpos()
		playerpos.y = playerpos.y+1.625
		local wantedpos = vector.add(
			playerpos,
			vector.multiply(player:get_look_dir(), data.range)
		)
		if pcontrol.right
		and pcontrol.left then
			local pdif = vector.subtract(pt.above, wantedpos)
			local _,o1,o2 = vector.get_max_coords(vector.apply(pdif, math.abs))
			wantedpos[o1] = pt.above[o1]
			wantedpos[o2] = pt.above[o2]
		elseif pcontrol.aux1 then
			local pdif = vector.subtract(pt.above, wantedpos)
			local _,_,o = vector.get_max_coords(vector.apply(pdif, math.abs))
			wantedpos[o] = pt.above[o]
		end
		--local wantedpos = vector.round(fine_wantedpos)
		if not vector.equals(ps[#ps], vector.round(wantedpos))
		or lineupdate then
		--and vector.distance(ps[#ps], fine_wantedpos) > 0.7 then
			minetest.sound_play("linemaker_update", {pos = wantedpos})
			playerdata[pname].ps = get_line_ps(pt.above, wantedpos)
			update_objects(pname, player)
		end

		-- place if not longer holding RMB etc.
		if player:get_wielded_item():to_string() == "linemaker:tool"
		and pcontrol.RMB then
			active = true
		elseif disabletimer then
			active = true
			disabletimer = disabletimer-dtime
			if disabletimer < 0 then
				disabletimer = nil
			end
			playerdata[pname].disabletimer = disabletimer
		else
			playerdata[pname] = nil
			local abortonfail = pcontrol.up and pcontrol.down
			local inv = player:get_inventory()
			local stackid = player:get_wield_index()+1
			ps[0] = pt.under
			local pt_current = {type = "node"}
			for i = 1,#ps do
				local curitem = inv:get_stack("main", stackid)
				local on_place = minetest.registered_items[curitem:get_name()]
				if on_place then
					on_place = on_place.on_place
				end
				if not on_place then
					-- item can't be placed
					break
				end
				pt_current.under = ps[i-1]
				pt_current.above = ps[i]
				local item, success = on_place(curitem, player, pt_current)
				if success == false then
					if abortonfail then
						break
					end
				elseif item then
					inv:set_stack("main", stackid, item)
				end
			end
			minetest.sound_play("linemaker_set", {pos = ps[#ps]})
		end
	end

	-- disable the function if noone currently uses it to reduce lag
	if not active then
		tool_active = false
	end
end

minetest.register_globalstep(function(dtime)
	-- only execute function if sb uses the tool
	if tool_active then
		do_linemaker_step(dtime)
	end
end)

-- register craft recipe if string exists
if minetest.registered_items["farming:cotton"] then
	minetest.register_craft({
		output = "linemaker:tool",
		recipe = {
			{"farming:cotton", "group:stick", "farming:cotton"},
			{"group:stick", "group:stick", ""},
		}
	})
end


local time = math.floor(tonumber(os.clock()-load_time_start)*100+0.5)/100
local msg = "[linemaker] loaded after ca. "..time
if time > 0.05 then
	print(msg)
else
	minetest.log("info", msg)
end
