if exports?
	ns = exports
else
	ns = window.cricket = {}

WHITESPACE_CHARS	= [" ", "\n", "\r", "\t"]
BRACES			= ["(", ")", "[", "]"]

isWhitespaceChar = (char) ->
	WHITESPACE_CHARS.indexOf(char) isnt -1

isNumberString = (n) ->
	!isNaN(parseFloat(n)) and isFinite(n)

ns.tokenize = (text) ->
	tokens	= []
	token	= null

	addToken = ->
		if token?
			tokens.push token
			token = null

	push = (something) ->
		addToken()
		token = something
		addToken()

	while text.length isnt 0
		char	= text[0]

		# TODO Handle strings
		if isWhitespaceChar char
			addToken()
		else if BRACES.indexOf(char) isnt -1
			push char
		else
			token = if token? then token + char else char

		text = text.substring(1)
	addToken()

	return tokens

class CList
	constructor: (@elements) ->

	head: ->
		@elements[0]

	tail: ->
		new CList @elements.slice(1)

	prepend: (head) ->
		new CList [head].concat(@elements)

	toString: ->
		s = "("
		for i in [0...@elements.length]
			s += @elements[i].toString()
			if i < @elements.length - 1
				s += " "
		s += ")"
		return s

class CSymbol
	constructor: (@name) ->

	toString: ->
		@name

class CSpecialForm
	constructor: (@definition) ->

	apply: (env, args) ->
		if @definition[args.length]?
			@definition[args.length].call(this, env, args)
		else if @definition.more?
			@definition.more.call(this, env, args)
		else
			throw new Error "No form definition for #{args.length} arguments"

class CFn
	constructor: (@definition) ->

	call: (args) ->
		if @definition[args.length]?
			@definition[args.length].call(this, args)
		else if @definition.more?
			@definition.more.call(this, args)
		else
			throw new Error "No function definition for #{args.length} arguments"

	apply: (env, args) ->
		args = (ns.eval(arg, env) for arg in args)
		@call args

readList = (tokens, begin, end) ->
	els = []
	while true
		if tokens.length is 0
			throw new Error "Unmatched #{begin}"
		else if tokens[0] is end
			tokens.shift()
			return els
		else
			els.push readEl tokens
		
readEl = (tokens) ->
	token = tokens.shift()

	if token is "("
		return new CList readList tokens, "(", ")"
	if token is "["
		return readList tokens, "[", "]"
	else
		if token is "nil"
			return null
		else if isNumberString token
			return Number token
		else
			return new CSymbol token

ns.read = (text) ->
	tokens	= ns.tokenize text
	program	= []
	while tokens.length isnt 0
		program.push readEl tokens

	return program

resolve = (symbol, env) ->
	throw new Error "Can only resolve symbols" unless symbol instanceof CSymbol
	if symbol.name of env
		return env[symbol.name]
	else
		throw new Error "Can't resolve #{symbol.name}"

ns.eval = (thing, env) ->
	return null unless thing?

	if thing instanceof CSymbol
		resolve thing, env
	else if thing instanceof CList
		ns.eval(thing.elements[0], env).apply(env, thing.elements.slice(1))
	else if Array.isArray thing
		(ns.eval el, env for el in thing)
	else
		thing

binNumOp = ({identity, op}) ->
	definition =
		1: ([x]) ->
			x
		2: ([x, y]) ->
			return op(x, y)
		more: ([x, y, args...]) ->
			z = @call [x, y]
			args.unshift z
			return @call args

	if identity?
		definition[0] = -> identity

	new CFn definition

isTruthy = (thing) ->
	if not thing?
		return false
	else
		return true

toString = (thing) ->
	if not thing?
		"nil"
	else if Array.isArray(thing)
		s = "["
		for i in [0...thing.length]
			s += toString(thing[i])
			s += " " if i < thing.length - 1
		s += "]"
		return s
	else
		thing.toString()
	
defaultEnvironment = ->
	"if": new CSpecialForm
		2: (env, [pred, ifTrue]) ->
			@apply env, [pred, ifTrue, null]
		3: (env, [pred, ifTrue, ifFalse]) ->
			if isTruthy ns.eval(pred, env)
				return ns.eval(ifTrue, env)
			else
				return ns.eval(ifFalse, env)
	"def": new CSpecialForm
		2: (env, [symbol, definition]) ->
			definition = ns.eval(definition, env)
			env[symbol.name] = definition
			return definition
	
	"fn": new CSpecialForm
		2: (env, [argList, body]) ->
			fnEnv		= Object.create(env)
			argNames	= (symbol.name for symbol in argList)
			argCount	= argNames.length

			definition = {}
			definition[argCount] = (args) ->
				for i in [0...argCount]
					fnEnv[argNames[i]] = args[i]
				return ns.eval(body, fnEnv)

			return new CFn definition

	"quote": new CSpecialForm
		1: (env, [list]) ->
			list

	"eval": new CSpecialForm
		1: (env, [expr]) ->
			ns.eval(ns.eval(expr, env), env)

	"cons":	new CFn
			2: ([head, list]) ->
				list.prepend head
	"head":	new CFn
			1:	([clist]) ->
					clist.head()
	"tail":	new CFn
			1:	([clist]) ->
					clist.tail()
	"list":	new CFn
			more: (args) ->
				new CList args
	"+": binNumOp
		op:		(x, y) -> x + y
		identity:	0
	"-": binNumOp
		op:		(x, y) -> x - y
	"*": binNumOp
		op:		(x, y) -> x * y
		identity:	1
	"/": binNumOp
		op:		(x, y) -> x / y

ns.run = (text) ->
	s	= ""
	env	= defaultEnvironment()

	for el in ns.read text
		s += toString(ns.eval el, env) + "\n"
	return s
