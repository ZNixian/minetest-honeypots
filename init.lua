honeypots = {
	poses = {
	},
	players = {
	},
	actives = {
	},
}

local function setpts(cnt, name)
	honeypots.players[name] = cnt
	print(name .. " set to " .. cnt)
	if cnt > 10 then
		minetest.after(math.random(300, 600), function()
			minetest.ban_player(name)
		end
	end
end

local function getpts(name)
	local pts = honeypots.players[name] or 0
	return pts
end

local function addpts(cnt, name)
	local pts = getpts(name)
	pts = pts + cnt
	setpts(pts, name)
	--print(name .. "'s honeypot points set to " .. pts)
end

minetest.register_privilege("honeypot", {
	description = "Player can make honeypots.",
	give_to_singleplayer = false,
})

local function ondig(p, node, digger)
	for i=1, #honeypots.poses do
		if vector.equals(honeypots.poses[i], p) then
			local name = digger:get_player_name()
			local priv, missing = minetest.check_player_privs(name, {honeypot=true})
			if priv==false then
				addpts(1, name)
			end
		end
	end
end
minetest.register_on_dignode(ondig)

local function split(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	t={}
	i=1
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		t[i] = str
		i = i + 1
	end
	return t
end

minetest.register_chatcommand("honeypot", {
	params = "",
	privs = {honeypot = true},
	description = "Do honeypot stuff. Usage: honeypot 'set'/'get'/'pts 'add'/'set' player points'",
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then
			return
		end
		
		--local found, _, command = param:find('^([^ ]+) (.+)$')
		local args = split(param)
		local command = args[1]

		if not command then
			minetest.chat_send_player(name, "Incorrect usage, see /help honeypot")
			return
		end
		
		if command == "set" then
			honeypots.actives[name] = not honeypots.actives[name]
			if honeypots.actives[name]==true then
				minetest.chat_send_player(name, "Set " .. name .. " honeypot mode on")
			else
				minetest.chat_send_player(name, "Set " .. name .. " honeypot mode off")
			end
		end
		
		if command == "get" then
			local p = player:getpos()
			for i=1, #honeypots.poses do
				local pp = honeypots.poses[i]
				if vector.distance(pp, p) < 20 then
					local zero = vector.new(0,0,0)
					minetest.add_particlespawner(
						30,		-- amount
						30,		-- time
					    vector.add(pp, {x=0.4, z=0.4, y=0}), vector.add(pp, {x=-0.4, z=-0.4, y=0}),  -- min and max pos
					    {x=0,y=1,z=0}, {x=0,y=2,z=0},	-- vel
					    zero, zero,						-- acc
					    2, 2,		-- min and max pxtime
					    1, 1.3,		-- min and max size
					    false, "honeypots_honey_pot.png", name)
				end
			end
		end
		
		if command == "pts" then
			local tplayer = minetest.get_player_by_name(args[3])
			if not tplayer then
				minetest.chat_send_player(name, "Invalid player " .. args[3])
				return
			end
			if args[2] == "get" then
				minetest.chat_send_player(name, args[3].." has " .. getpts(args[3]) .. " honeypot points")
				return
			end
			local count = tonumber(args[4])
			if args[2] == "add" then
				addpts(count, args[3])
				return
			end
			if args[2] == "set" then
				setpts(count, args[3])
				return
			end
		end
	end,
})

minetest.register_on_punchnode(function(pos, node, puncher)
	if honeypots.actives[puncher:get_player_name()]==true then
		honeypots.poses[#honeypots.poses + 1] = {x=pos.x, y=pos.y, z=pos.z}
		print(dump(pos))
	end
end)

minetest.register_on_joinplayer(function(player)
	honeypots.actives[player:get_player_name()] = false
end)


------------------  LOADING AND SAVING  -----------------------
local loadSettingsFromFile = function()
	local worldpath = minetest.get_worldpath()
	local buffer = ""
	
	if io.open(worldpath.."/honeypots.txt","r") ~= nil then
		io.input(worldpath.."/honeypots.txt")
	
		local size = 2^13      -- good buffer size (8K)
		while true do
			local block = io.read(size)
			if not block then break end
			buffer = buffer .. block
		end
		
		local table = minetest.deserialize(buffer)
		if table~=nil then
			honeypots = table
		end
		print("loaded honeypots")
	end
end

local saveSettingsToFile = function()
	local worldpath = minetest.get_worldpath()
	io.output(worldpath.."/honeypots.txt")
	io.write(minetest.serialize(honeypots))
	print("saved honeypots")
end

loadSettingsFromFile()

minetest.register_on_shutdown(function()
	saveSettingsToFile()
end)

local run = nil

run = function()
	minetest.after(300, function()
		saveSettingsToFile()
		run()
	end)
end

run()