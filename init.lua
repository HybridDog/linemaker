local load_time_start = os.clock()


local creative_enabled = minetest.setting_getbool("creative_mode")

local playerdata = {}
local tool_active

minetest.register_tool("linemaker:tool", {
	description = "pull lines",
	inventory_image = "linemaker.png",
	stack_max = 1,
	--node_placement_prediction = nil,
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
			ps = {[0] = pt.under, pt.above},
		}

		minetest.after(0.5, function(player)
			tool_active = true

		end, player)
--[[
		local keys = placer:get_player_control()
		local name = placer:get_player_name()

		if keys.aux1 then
			local item = itemstack:to_table()
			local node, mode = get_data(item)
			mode = modes[modes[mode]%#modes+1]
			set_data(item, node, mode)
			itemstack:replace(item)
			inform(name, "Mode changed to: "..mode..": "..mode_infos[mode])
			return itemstack
		end

		-- just place the stored node if now new one is to be selected
		if not keys.sneak then
			return replacer.replace(itemstack, placer, pt, true)
		end


		if pt.type ~= "node" then
			inform(name, "	Error: No node selected.")
			return
		end

		local item = itemstack:to_table()
		local node, mode = get_data(item)

		node = minetest.get_node_or_nil(pt.under) or node

		set_data(item, node, mode)
		itemstack:replace(item)]]
	end,
})

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
			ops[i] = 1--add_object(p)
		end
		return
	end
	for i = #ps+1,#ops do
		local p = ps[i]
		ops[i] = nil--add_object(p)
	end
end

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
			local under = ps[0]
			ps = vector.line(ps[1], wantedpos)
			ps[0] = under
			playerdata[pname].ps = ps
			update_objects(pname)
		end

		if player:get_wielded_item():to_string() == "linemaker:tool"
		and player:get_player_control().RMB then
			active = true
		else
			for i = 1,#ps do
				minetest.set_node(ps[i], {name="default:wood"})
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
