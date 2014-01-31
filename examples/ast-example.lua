-- Example using the luatext parser. Demonstrates building of a simple AST,
-- including constant folding of numeric calculations.

local luatext = require 'luatext'

function ToString(obj)
	local t = type(obj)
	if t == 'table' then
		local s = '{\n'
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
			s = s..(k and ",\n" or "\n}")
		end
		return s
	elseif t == 'string' then
		return "'"..obj.."'"
	else
		return tostring(obj)
	end
end

local ParseOperators = luatext.MakeParser([[

<literal> := | {makeast_numberliteral()}( <number> )
             | {makeast_stringliteral()}( <string> )
             | {makeast_booleanliteral()}( `true` | `false` )
             | `(` {}( <term> ) `)`
             | {makeast_ident()}( <ident> )
             ;

<factor>     := {makeast_binop_leftassoc()}( <factor_int> );
<factor_int> :=     {[]}( <literal> )
                    (
            	        {[]}( `*` | `/` )
            	        !Incomplete Expression!
            	        {[]}( <literal> )
                    )* ;

<term>     := {makeast_binop_leftassoc()}( <term_int> );
<term_int> :=       {[]}( <factor> )
                    (
                    	{[]}( `+` | `-` )
                    	!Incomplete Expression!
                    	{[]}( <factor> )
                    )* ;

<expr> := <term>;

]])

local ParseOperatorsActions = {
	makeast_numberliteral = function(num)
		return {
			type = 'numberliteral';
			value = tonumber(num);
		}
	end;
	makeast_stringliteral = function(str)
		return {
			type = 'stringliteral';
			value = str;
		}
	end;
	makeast_booleanliteral = function(bool)
		return {
			type = 'booleanliteral';
			value = (bool == 'true');
		}
	end;
	makeast_ident = function(id)
		return {
			type = 'ident';
			value = id;
		}
	end;
	makeast_binop_leftassoc = function(dat)
		--unflatten the list into a bunch of bin-op nodes, in a left-associative fashion.
		--will work the same for all left-associating operators.
		local node = dat[1]
		for i = 2, #dat-1 do
			if node.type == 'numberliteral' and dat[i+1].type == 'numberliteral' then
				local op = dat[i]
				local a,b = node.value,dat[i+1].value
				if op == '+' then
					a = a+b
				elseif op == '-' then
					a = a-b
				elseif op == '*' then
					a = a*b
				elseif op == '/' then
					a = a/b
				end
				node.value = a
			else
				node = {
					type = 'binop';
					rhs = node;
					op = dat[i];
					lhs = dat[i+1];
				}
			end
		end
		return node
	end;
}

local a = ParseOperators('expr', "a + b", ParseOperatorsActions)
print("OUTPUT:")
print(ToString(a))
