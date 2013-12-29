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

class CNumber
	constructor: (token) ->
		@value = Number(token)

	eval: ->
		this

	toString: ->
		@value.toString()

	@value: (x) ->
		if x instanceof CNumber
			return x.value
		else
			throw new Error "Can't coerce #{x.constructor.name} to CNumber"

class CList
	constructor: (@elements) ->

	eval: (env) ->
		return this if @elements.length is 0

		@elements[0].eval(env).apply(env, @elements.slice(1))

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

	eval: (env) ->
		env[@name]

	toString: ->
		@name

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
		args = (arg.eval(env) for arg in args)
		@call args
		
readEl = (tokens) ->
	token = tokens.shift()

	if token is "("
		els = []
		while true
			if tokens.length is 0
				throw new Error "Unmatched ("
			else if tokens[0] is ")"
				tokens.shift()
				break
			else
				els.push readEl(tokens)
		return new CList els
	if token is "["
		els = [new CSymbol "list"]
		while true
			if tokens.length is 0
				throw new Error "Unmatched ["
			else if tokens[0] is "]"
				tokens.shift()
				break
			else
				els.push readEl(tokens)
		return new CList els
	else
		if isNumberString token
			return new CNumber token
		else
			return new CSymbol token

ns.read = (text) ->
	tokens	= ns.tokenize text
	program	= []
	while tokens.length isnt 0
		program.push readEl tokens

	return program

ns.eval = (expression, env) ->
	return expression.eval(env)

binNumOp = ({identity, op}) ->
	definition =
		1: ([x]) ->
			x
		2: ([x, y]) ->
			return new CNumber(op(CNumber.value(x), CNumber.value(y)))
		more: ([x, y, args...]) ->
			z = @call [x, y]
			args.unshift z
			return @call args

	if identity?
		definition[0] = -> new CNumber identity

	new CFn definition
	
defaultEnvironment = ->
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
		s += ns.eval el, env
	return s
