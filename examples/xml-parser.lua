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

local XMLParser = luatext.MakeParser([[
	<attrib> :=
		{name}( <word> )
		!`=` Expected!
		`=`
		!Value expected!
		{value}( <string> ) ;

	<rawNormalNode> :=
		`<`
			{tagBegin}( <word> )
			( {attribs[]}( <attrib> ) )*
		`>`
		!Unfinished tag!
		{children[]}( <node> | $(`<`) )*
		`</`
			{tagEnd}( <word> )
		`>`
		;

	<normalNode> :=
		{translateNode()}( <rawNormalNode> ) ;

	<commentNode> :=
		`<!--`
		!Unfinished comment tag!
		{}( $(`-->`) )
		`-->` ;

	<node> :=
		{commentNode()}( <commentNode> ) | <normalNode> ;
]])
local XMLActions = {
	translateNode = function(node)
		if node.tagBegin ~= node.tagEnd then
			error("Tag mismatch <"..node.tagBegin.."> ... </"..node.tagEnd..">")
		end
		local nd = {tag=node.tagBegin}
		if node.attribs then
			for inx, attrib in pairs(node.attribs) do
				nd[attrib.name] = attrib.value
			end
		end
		nd.children = node.children or {}
		return nd
	end,
	commentNode = function(commentText)
		return {tag='comment', children={commentText}}
	end,
}

while true do
	io.write("> ")
	local str = io.read()
	local st, err = pcall(function()
		print("\t"..ToString(XMLParser('node', str, XMLActions)))
	end)
	if err then
		print("\tError: "..err)
	end
end