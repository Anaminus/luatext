local luatext = require 'luatext'

function ToString(obj)
	local t = type(obj)
	if t == 'table' then
		local s = '{'
		local k = next(obj)
		if not k then s = '{}' end
		while k do
			if type(k) == 'number' then
				s = s..ToString(obj[k])
			elseif type(k) == 'string' then
				s = s..k.."="..ToString(obj[k])
			else
				s = s..ToString(k).."="..ToString(obj[k])
			end
			k = next(obj, k)
			s = s..(k and "," or "}")
		end
		return s
	elseif t == 'string' then
		return "'"..obj.."'"
	else
		return tostring(obj)
	end
end

local CommandParser = luatext.MakeParser([[
	<coords> := {x}( <number> ) [`,`] {y}( <number> ) [`,`] {z}( <number> );

	<vector> := | {}( <coords> )
			    | `(` {}( <coords> ) `)`
			    | `[` {}( <coords> ) `]`
			    | `{` {}( <coords> ) `}`
			    ;

	<target> := <word> | <string>;

	<targetList> :=
		{[]}( <target> )
		[ (
			(`,` | `and`)
			{[]}( <target> )
		)* ]
		;

	<cmd_Teleport_PlayersToLocation> :=
		{targetPlayers}( <targetList> )
		[`to`]
		{location}( <vector> )
		;

	<cmd_Teleport_PlayersToTarget> :=
		{targetPlayers}( <targetList> )
		[`to`]
		{target}( <word> )
		;

	<cmdGroup_Teleport> :=
		(`teleport` | `tele`)
		!Bad teleport command!
		(
			| {teleport_loc()}( <cmd_Teleport_PlayersToLocation> )
			| {teleport_target()}( <cmd_Teleport_PlayersToTarget> )
		)
		;

	<cmd_Kill> :=
		(`kill` | `delete` | `ban`)
		!Bad kill command!
		{targetPlayers}( <targetList> )
		;

	<cmd> :=
		!Bad Command, expected `teleport` or `kill`!
		(
			| <cmdGroup_Teleport>
			| {kill()}( <cmd_Kill> )
			| {help()}( (`help` | `Help`) [`!` | `?` | `()`] )
			| {default()}( <ident> )
		)
		;
]])

local CommandActions = {
	kill = function(killCmd)
		print("Kill:", ToString(killCmd))
	end,
	teleport_loc = function(teleCmd)
		print("Tele to location:", ToString(teleCmd))
	end,
	teleport_target = function(teleCmd)
		print("Tele to target:", ToString(teleCmd))
	end,
	help = function()
		print("\tCommands:")
		print("\ttele / teleport:\n\t\tTeleport a group of players to a either a target, given as\
		x, y, z coordinates, or to a target, which can either be another\
		player, or `me` to teleport players to yourself. EG:\n\
		teleport me, player1 and player2 to 123, 0, 100\
		tele 'player1' and player2 to me\
		teleport me to [ 2, 3, 7 ])\n\
	kill:\
		Kills a player or group of players. You can specify yourself in\
		that group using `me`. EG:\n\
		kill me\
		kill me and player2\
		kill player1, 'player2' and player3\
	\n")
	end,
	default = function(defaultCmd)
		print("Unknown command:", defaultCmd)
	end,
}

while true do
	io.write("> ")
	local str = io.read()
	local st, err = pcall(function()
		CommandParser('cmd', str, CommandActions)
	end)
	if err then
		print("\tError: "..err)
	end
end