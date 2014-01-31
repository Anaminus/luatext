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

local JSONParser = luatext.MakeParser([[
	<boolLiteral> := {toBool()}( `true` | `false` ) ;
	<stringLiteral> := <string> ;
	<nullLiteral> := {toNil()}( `null` ) ;
	<numberLiteral> := <number> ;

	<arrayLiteral> :=
		| {emptyObject()}( `[` `]` )
		| `[`
				!Expected set of values!
				{[]}( <value> )
				( `,` {[]}( <value> ) )*
				!Expected `]`!
		  `]`
		;

	<keyvalPair> :=
		{key}( <stringLiteral> ) `:` {value}( <value> ) ;

	<rawObjectLiteral> :=
		| {emptyObject()}( `{` `}` )
		| `{`
				!Expected set of key-value pairs!
				{[]}( <keyvalPair> )
				( `,` {[]}( <keyvalPair> ) )*
				!Expected `}`!
		  `}`
		;

	<objectLiteral> :=
		{translateObject()}( <rawObjectLiteral> ) ;

	<value> :=
		!Expected Value!
		| <boolLiteral>
		| <stringLiteral>
		| <nullLiteral>
		| <numberLiteral>
		| <arrayLiteral>
		| <objectLiteral>
		;

]])
local JSONActions = {
	emptyObject = function()
		return {}
	end,
	toBool = function(capture)
		return capture == 'true'
	end,
	toNil = function()
		return nil;
	end,
	translateObject = function(capture)
		local obj = {}
		for inx, kvPair in pairs(capture) do
			obj[kvPair.key] = kvPair.value
		end
		return obj
	end,
}

while true do
	io.write("> ")
	local str = io.read()
	local st, err = pcall(function()
		print("\t"..ToString(JSONParser('value', str, JSONActions)))
	end)
	if err then
		print("\tError: "..err)
	end
end
