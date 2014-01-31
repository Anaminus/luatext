function lookupify(tb)
	for _, v in pairs(tb) do
		tb[v] = true
	end
	return tb
end

local whiteChars = lookupify{' ', '\n', '\t', '\r'}
local translateWhiteTb = {[''] = '<null>', [' '] = '\\s', ['\n'] = '\\n', ['\t'] = '\\t'}
local lowerChars = lookupify{'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i',
							 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r',
							 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'}
local upperChars = lookupify{'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I',
							 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R',
							 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'}
local digits = lookupify{'0', '1', '2', '3', '4', '5', '6', '7', '8', '9'}
function MakeParser(grammar)
	local p = 1

	local glbError = error
	local function error(err)
		--find position
		local line = 1
		local char = 1
		for pt = 1, p do
			if grammar:sub(pt,pt) == '\n' then
				line = line + 1
				char = 0
			else
				char = char + 1
			end
		end

		--find line in question
		local lineBegin = p
		while lineBegin > 0 and grammar:sub(lineBegin,lineBegin) ~= '\n' do
			lineBegin = lineBegin-1
		end
		lineBegin = lineBegin + 1
		local lineEnd = p
		while lineEnd <= (#grammar) and grammar:sub(lineEnd,lineEnd) ~= '\n' do
			lineEnd = lineEnd + 1
		end
		lineEnd = lineEnd-1
		local lineText = grammar:sub(lineBegin, lineEnd)
		local offs = p-lineBegin

		--construct error
		glbError(
			"LuaTextError:"..line..":"..char..": "..err..":\n"
			..lineText:gsub("\t", " ").."\n"..string.rep(" ", offs).."^--Here")
	end

	local glbPrint = print
	local function print(...)
		--glbPrint(...)
	end

	----
	local function white()
		while whiteChars[grammar:sub(p,p)] do p = p + 1 end
	end

	-----
	local function eof()
		return p > #grammar
	end
	local function isWhite(a)
		a = a or grammar:sub(p,p)
		return whiteChars[a] or false
	end
	local function translateWhite(a)
		local s = ""
		for i = 1, #a do
			if isWhite(a) or a == '' then
				s = s..translateWhiteTb[a]
			else
				s = s..a
			end
		end
		return s
	end
	local function isAlpha(a)
		a = a or grammar:sub(p,p)
		return lowerChars[a] or upperChars[a] or false
	end
	local function isDigit(a)
		a = a or grammar:sub(p,p)
		return digits[a] or false
	end
	local function isAlnum(a)
		a = a or grammar:sub(p,p)
		return isAlpha(a) or isDigit(a) or (a=='_') or false
	end
	local function is(c)
		return grammar:sub(p,p+(#c)-1) == c
	end
	local function get(n)
		n = n or 1
		local str = grammar:sub(p,p+n-1)
		p = p + n
		return str
	end
	local function peek()
		return grammar:sub(p,p)
	end

	-----
	local function lexIdent()
		local start = p
		while isAlnum() do p = p + 1 end
		return grammar:sub(start, p-1)
	end
	local function lexRule()
		get() --get <
		local start = p
		while isAlnum() do p = p + 1 end
		local tok = grammar:sub(start, p-1)
		if not is('>') then error("Expected `>`") end
		get() --get >
		return tok
	end
	local function lexLiteral()
		get() --get `
		local start = p
		while not is('`') do p = p + 1 end
		local tok = grammar:sub(start, p-1)
		get() --get `
		return tok
	end
	local function lexErrorPoint()
		get() --get !
		local start = p
		while not is('!') do p = p + 1 end
		local tok = grammar:sub(start, p-1)
		get() --get !
		return tok
	end

	-----
	local globalRules = {}

	local function MakeParseCtx(input)
		local ctx = {}
		ctx.source = input
		ctx.pos = 1
		ctx.capture = {}
		ctx.white = function()
			while isWhite(input:sub(ctx.pos,ctx.pos)) do
				ctx.pos = ctx.pos + 1
			end
		end
		ctx.peek = function(n)
			n = n or 1
			return input:sub(ctx.pos, ctx.pos+n-1)
		end
		ctx.get = function(n)
			n = n or 1
			local s = input:sub(ctx.pos, ctx.pos+n-1)
			ctx.pos = ctx.pos + n
			return s
		end
		return ctx
	end

	--returns: success: Bool, matchedText: String, capture: Object
	local function MakeOrRule(rules)
		return function(ctx)
			print("Rule::Or")
			for inx, rule in pairs(rules) do
				local oldPos = ctx.pos
				local success, match, capture = rule(ctx)
				if success then
					return true, match, capture
				end
				ctx.pos = oldPos
			end
			return false
		end
	end
	local function MakeGlobalRefRule(name)
		return function(ctx)
			print("Rule::GlobalRef<"..name..">")
			return (globalRules[name] or glbError("Rule <"..name.."> not found."))(ctx)
		end
	end
	local function MakeGlobalRule(name, childRule)
		return function(ctx)
			print("Rule::Global<"..name..">")
			--save the old capture and create a new object to capture into
			local oldCapture = ctx.capture
			ctx.capture = nil
			local success, match, capture = childRule(ctx)
			if success then
				--restore the old capture and return the captured stuff
				--if an explicit capture was constructed then return it,
				--otherwise return the capture of the body rule.
				local captureToReturn = ctx.capture or capture
				ctx.capture = oldCapture
				return true, match, captureToReturn
			else
				--restore the old capture
				ctx.capture = oldCapture
				return false
			end
		end
	end
	local function MakeMaybeRule(rule)
		return function(ctx)
			print("Rule::Maybe")
			local oldPos = ctx.pos
			local success, match, capture = rule(ctx)
			if success then
				return success, match, capture
			else
				ctx.pos = oldPos
				return true, "", "" --didn't match anythig, but still successfull
			end
		end
	end
	local function MakeLiteralRule(str)
		return function(ctx)
			print("Rule::Literal<"..str..">")
			ctx.white()
			if ctx.source:sub(ctx.pos, ctx.pos+(#str)-1) == str then
				ctx.pos = ctx.pos + (#str)
				return true, str, str
			else
				return false
			end
		end
	end
	local function MakeNumberRule()
		return function(ctx)
			print("Rule::Number")
			ctx.white()
			local oldPos = ctx.pos
			if ctx.peek() == '-' then ctx.get(1) end
			while isDigit(ctx.peek()) do
				ctx.get(1)
			end
			if ctx.peek() == '.' then
				ctx.get(1)
				while isDigit(ctx.peek()) do
					ctx.get(1)
				end
			end
			if ctx.pos ~= oldPos then
				local n = ctx.source:sub(oldPos,ctx.pos-1)
				return true, n, tonumber(n)
			else
				return false
			end
		end
	end
	local function MakeIdentRule()
		return function(ctx)
			print("Rule::Ident")
			ctx.white()
			local oldPos = ctx.pos
			if isAlpha(ctx.peek()) then
				while isAlnum(ctx.peek()) do
					ctx.get(1)
				end
				local s = ctx.source:sub(oldPos, ctx.pos-1)
				return true, s, s
			else
				return false
			end
		end
	end
	local function MakeStringRule()
		return function(ctx)
			print("Rule::String")
			ctx.white()
			if ctx.peek() == '"' or ctx.peek() == "'" then
				local delim = ctx.get(1)
				local oldPos = ctx.pos
				while true do
					if ctx.pos > #ctx.source then
						return false
					elseif ctx.peek() == delim then
						local s = ctx.source:sub(oldPos, ctx.pos-1)
						ctx.get(1) --get closing delim
						return true, s, s
					end
					ctx.get(1)
				end
			else
				return false
			end
		end
	end
	local function MakeWordRule()
		return function(ctx)
			print("Rule::Word")
			ctx.white()
			if isAlnum(ctx.peek()) then
				local oldPos = ctx.pos
				while isAlnum(ctx.peek()) do ctx.get(1) end
				local s = ctx.source:sub(oldPos, ctx.pos-1)
				return true, s, s
			else
				return false
			end
		end
	end
	local function MakeEofRule()
		return function(ctx)
			if ctx.pos > #ctx.source then
				return true, "", ""
			else
				return false
			end
		end
	end
	local function MakeErrorPointRule(err, rule)
		return function(ctx)
			print("Rule::ErrorPoint")
			local success, match, capture = rule(ctx)
			if not success then
				glbError(err)
			end
			return true, match, capture
		end
	end
	local function MakeRepeatRule(rule, acceptZero)
		return function(ctx)
			print("Rule::Repeat")
			local startPos = ctx.pos
			local success, match, capture = rule(ctx)
			if success then
				while true do
					local oldPos = ctx.pos
					local new_success, new_match, new_capture = rule(ctx)
					if new_success then
						success, match, capture = true, new_match, new_capture
					else
						ctx.pos = oldPos
						return true, ctx.source:sub(startPos, oldPos-1), capture
					end
				end
			else
				if acceptZero then
					ctx.pos = startPos
					return true, "", ""
				else
					return false
				end
			end
		end
	end
	local function MakeSeriesRule(rules)
		return function(ctx)
			print("Rule::Series")
			local success, match, capture
			local oldPos = ctx.pos
			for inx, rule in pairs(rules) do
				success, match, capture = rule(ctx)
				if not success then
					ctx.pos = oldPos
					return false
				end
			end
			local s = ctx.source:sub(oldPos, ctx.pos-1)
			return true, s, s
		end
	end
	local function MakeCaptureRule(capture, body)
		return function(ctx)
			print("Rule::Capture")
			local success, match, captured = body(ctx)
			if success then
				captured = capture.handler(ctx, captured)
				return true, match, captured
			else
				return false
			end
		end
	end
	local function MakeExclusiveRule(rule)
		return function(ctx)
			print("Rule::Exclusive")
			local oldPos = ctx.pos
			while true do
				local beforeMatch = ctx.pos
				if rule(ctx) then
					ctx.pos = beforeMatch
					if ctx.pos == oldPos then
						return false --there wasn't anything to match
					else
						local s = ctx.source:sub(oldPos, ctx.pos-1)
						return true, s, s
					end
				end
				ctx.pos = beforeMatch
				if ctx.pos > #ctx.source then
					return false
				end
				ctx.pos = ctx.pos+1
			end
		end
	end

	globalRules['ident'] = MakeIdentRule()
	globalRules['number'] = MakeNumberRule()
	globalRules['string'] = MakeStringRule()
	globalRules['word'] = MakeWordRule()
	globalRules['eof'] = MakeEofRule()

	------
	--forwards decls
	local ParseCaptureGroup, ParseRules, ParseOrRule, ParseGlobalRule, ParseGrammar;
	ParseCaptureGroup = function(ctx)
		print("ParseCaptureGroup()")
		local capture = nil

		get(1) --get {
		white()
		if is('}') then
			capture = {type='anon', handler=function(ctx, captured)
				ctx.capture = captured
			end}
		elseif is('[') then
			get(1)
			if not is(']') then error("Expected `]`") end
			get(1)
			capture = {type='anon-list', handler=function(ctx, captured)
				ctx.capture = ctx.capture or {}
				ctx.capture[#ctx.capture+1] = captured
			end}
		else
			local captureName = lexIdent()
			white()
			if is('[') then --list capture
				get(1)
				if not is(']') then error("Expected `]`") end
				get(1)
				capture = {type='named-list', handler=function(ctx, captured)
					ctx.capture = ctx.capture or {}
					if not ctx.capture[captureName] then
						ctx.capture[captureName] = {}
					end
					local arr = ctx.capture[captureName]
					arr[#arr+1] = captured
				end}
			elseif is('(') then --action capture
				get(1)
				if not is(')') then error("Expected `)`") end
				get(1)
				capture = {type='named-action', handler=function(ctx, captured)
					if not ctx.actions[captureName] then
						error("Missing action `"..captureName.."()`")
					end
					return ctx.actions[captureName](captured)
				end}
			elseif is('}') then --named capture
				capture = {type='named', handler=function(ctx, captured)
					ctx.capture = ctx.capture or {}
					if not ctx.capture[captureName] then
						ctx.capture[captureName] = {}
					end
					ctx.capture[captureName] = captured
				end}
			else --error, bad capture
				error("Bad capture")
			end
		end

		--get end of capture
		white()
		if not is('}') then error("Expected `}`") end
		get(1)

		--get body
		white()
		if not is('(') then error("Expected `(`") end
		get(1)
		local bodyRule = ParseOrRule(ctx)
		white()
		if not is(')') then error("Expected `)`") end
		get(1)

		return MakeCaptureRule(capture, bodyRule)
	end
	ParseRules = function(ctx)
		print("ParseRules()")
		white()
		local rules = {}
		--parse rules
		while true do
			local rule = nil
			white()
			if is('{') then --capture group
				rule = ParseCaptureGroup(ctx)
			elseif is('[') then --maybe-group
				get(1) --get [
				rule = ParseOrRule(ctx)
				if not is(']') then error("Unfinished maybe block, `]` expected") end
				get(1) --get ]
				rule = MakeMaybeRule(rule)
			elseif is('$') then
				get(1)
				if not is('(') then error("Expected `(`") end
				get(1)
				rule = ParseOrRule(ctx)
				if not is(')') then error("Expected `)`") end
				get(1)
				rule = MakeExclusiveRule(rule)
			elseif is('`') then --literal
				rule = MakeLiteralRule(lexLiteral())
			elseif is('(') then --precedence specification
				get(1) --get (
				rule = ParseOrRule(ctx)
				if not is(')') then error("Unfinished group block, `)` expected") end
				get(1) --get )
			elseif is('<') then --global rule
				local ruleName = lexRule()
				rule = globalRules[ruleName] or MakeGlobalRefRule(ruleName)
			elseif is('!') then --error point
				local err = lexErrorPoint()
				rule = ParseOrRule(ctx)
				rule = MakeErrorPointRule(err, rule)
			else
				print("BreakParseRules on:", translateWhite(peek(4)))
				break
			end
			white()
			if is('*') then --try a repeat group
				get(1) --get *
				rule = MakeRepeatRule(rule, true)
			elseif is('+') then
				get(1) --get +
				rule = MakeRepeatRule(rule, false)
			end
			rules[#rules+1] = rule
		end
		--return rules
		if #rules > 1 then
			return MakeSeriesRule(rules)
		elseif #rules == 1 then
			return rules[1]
		else
			error("Rule expected")
		end
	end
	ParseOrRule = function(ctx)
		print("ParseOrRule()")
		local clauses = {}
		--
		white()
		if is('|') then get(1) end --get spurious `|`
		white()
		--
		local firstRule = ParseRules(ctx)
		clauses[#clauses+1] = firstRule
		white()
		while is('|') do
			get(1)
			local rule = ParseRules(ctx)
			clauses[#clauses+1] = rule
			white()
		end
		if #clauses > 1 then
			return MakeOrRule(clauses)
		else
			return firstRule
		end
	end
	ParseGlobalRule = function()
		print("ParseGlobalRule()")
		local ctx = {}
		--
		white()
		if not is('<') then error("Expected rule") end
		local ruleName = lexRule()
		white()
		if not is(':=') then error("Expected `:=`") end
		get(2) --get :=
		white()
		local child = ParseOrRule(ctx)
		white()
		if not is(';') then error("Expected `;` after rule") end
		get(1) --get ;
		--
		--figure out captures

		--
		local rule = MakeGlobalRule(ruleName, child)
		globalRules[ruleName] = rule
		return rule
	end
	ParseGrammar = function()
		while true do
			white()
			if eof() then break end
			--print("aa:", peek(), p, #grammar)
			ParseGlobalRule()
		end
	end
	ParseGrammar()

	--print("GlobalRules:")
	--for name, rule in pairs(globalRules) do
	--	print("  <"..name..">")
	--end

	return function(baseRule, input, actions)
		local rule = globalRules[baseRule]
		if not rule then
			error("Base rule `<"..baseRule..">` is missing")
		end
		local ctx = MakeParseCtx(input)
		ctx.actions = actions
		local success, match, capture = rule(ctx)
		return capture
	end
end

return {
	MakeParser = MakeParser;
}
