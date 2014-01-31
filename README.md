# LuaText

A YACC-like parser generator for Lua.

All of the code in this repository was originally authored by
[stravant][author]. So make sure you get your attributions correct! This
repository was created so that myself and others may reap the benefits of Git
and GitHub upon this project.

This README was adapted from a post made by stravant, which describes how
LuaText is used.

See the [Links](#links) section for various links to original sources.

## Usage

The follow example gives an overview of how to use LuaText:

	luatext = require 'luatext'
	parser = luatext.MakeParser(definition)
	parser(rule, input, actions)

The `luatext` module contains a single function called `MakeParser`. This
function accepts one argument, which is a string. This is a grammar
definition, whose syntax is described in the next section. MakeParser returns
a parser function, which is used to parse input. This function accepts three
arguments.

The first argument is a string, which is the name of a rule defined in the
grammar. Input will be parsed starting from this rule.

The second argument is the input string to parse.

The third, optional, argument is a table of "actions", which are functions
that may be executed while input is parsed. Actions are described in the next
section.

The value returned by the parser function depends on the grammar definition.
If the definition contains captures (see next section), then the function will
return the results of these captures. If not, then it will return as much of
the input as it was able to parse. The function will return nil if it was
unable to parse the input.

## Syntax

The syntax of the grammar files is close to that of YACC.

### Rules

The grammar definition is a made up of a set of **rules**, with the syntax:

	<ruleName> := rules ;

More complex rules are made by combining a sequence of base rules, and rules
which can be defined using a set of operators. The base rules to start out
with are:

- `<number>`: Any number, possibly with decimal places and exponents on it.
- `<string>`: A string delimited with either double or single quotes.
- `<ident>`: Any valid programming identifier.
- `<word>`: Any sequence of numbers/letters. Like ident, but may start with a
  digit.
- `<eof>`: Matches the end of the input string.

### Operators

You can build up the base rules using the following operators, as well as
using parentheses to specify order of operations.

	<rule> <rule> ...

The *sequence* operator (plain whitespace). If all of the rules match, then it
matches.

	<rule> | <rule> | ... :=

The *or* operator. If any of the rules match, then it matches.

	[ <rule> ]

The *maybe* operator. Matches either the rule or not the rule.

	<rule>*

The *any-number-of* operator. Matches any number of the rule, including zero.

	<rule>+

The *one-or-more* operator. Matches one or more of the rule, but not zero.

	`text`

The *literal* rule. Matches the given text exactly and nothing else.

	$( rule )

The *everything-up-to* rule. Matches everything up to, but not including, the
contained rule.

### Error points

The next concept is an error-point. An error point is a type of rule which
turns a non-match into an error. If any of the rules after an error point fail
to match, then the error specified in the error point will be thrown. An error
point is written as a string delimited with exclamation points:

	!Error: Code after me failed.!

### Captures

The final concept is that of a **capture**. It would be relatively useless if
all the parser could do was verify that something matched. A capture lets you
execute some sort of action or build some sort of data structure when
something matches, rather than just simply matching it. Each top-level rule
has a piece of data associated with it, and the following captures can be used
to manipulate it:

	{}( <rule> )

The *simple* capture. It sets the piece of data to what the rule matched. i.e.
`data = match`

	{name}( <rule> )

The *named* capture.  It sets the field `name` of data to what the rule
matched. i.e. `data.name = match`

	{[]}( <rule> )

The *array* capture. It appends what the rule matched to the data. i.e.
`data[#data+1] = match`

	{name[]}( <rule> )

The *named-array* capture. It appends what the rule matched to the `name`
field of the data. i.e. `data.name[#data.name+1] = match`

There is one more special kind of capture. This is the **action capture**,
which calls one of the functions in the table of actions passed to the
generated parser function ([Usage](#usage)). The action capture is written
like so:

	{name()}( <rule> )

The action capture calls the function `name` in the actions table, with what
the rule matched as the argument. The rule's data will be set to whatever the
function returns. i.e. `data = name(match)`

## Examples

Here are some example grammars:

	<vector> := <number> `,` <number> `,` <number> ;

Matches any set of three numbers separated by commas.


	<print> := `print` ( <string> | `(` <string> `)` ) ;

Matches a simple Lua print statement. That is, a "print" followed by either a
plain string, or a string and brackets.


	<vector> := {x}( <number> ) `,` {y}( <number> ) `,` {z}( <number> ) ;

Same as the first vector match, but captures the three coordinates into the
data struct. The data struct for the vector rule starts out empty, and then
the named-captures will set the x, y, and z fields of the data table to three
coordinates.


	<printVectorCommand> := `print` {printVector()}( <vector> ) ;

Here's an example of a complete top level rule. Using the rule from that last
example, we can also use an action-capture to do something with the captured
coordinates. Now if you added a "printVector" function to the actions table
when you call this rule, the printVector function would be called with the
table of x/y/z coordinates that the vector rule captured.

See the [examples](/examples) directory for more complicated examples.

## Links

- [Original LuaText source][source]
- [Original minified version][source-min]
- [Original explanation post][documentation]

[author]: https://github.com/stravant
[source]: http://wiki.roblox.com/index.php/User:XLEGOx/luatext
[source-min]: http://wiki.roblox.com/index.php/User:XLEGOx/luatext-min
[documentation]: http://www.roblox.com/Forum/ShowPost.aspx?PostID=54131432
