if exports?
	ns = exports
else
	ns = window.cricket = {}

WHITESPACE_CHARS = [" ", "\n", "\r", "\t"]
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
		else if char is "("
			push "("
		else if char is ")"
			push ")"
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
	constructor: (@call) ->

	apply: (env, args) ->
		args = (arg.eval(env) for arg in args)
		@call(args)

readEl = (tokens) ->
	token = tokens.shift()

	if token is "("
		list = []
		while true
			if tokens.length is 0
				throw new Error "Unmatched ("
			else if tokens[0] is ")"
				tokens.shift()
				break
			else
				list.push readEl(tokens)
		return new CList list
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
	new CFn (args) ->
		if args.length is 0
			if identity?
				new CNumber identity
			else
				throw new Error "Not enough args"
		else if args.length is 1
			return args[0]
		else if args.length is 2
			[x, y] = args
			return new CNumber(op(CNumber.value(x), CNumber.value(y)))
		else
			[x, y, args...] = args
			z = @call [x, y]
			args.unshift z
			return @call args

defaultEnvironment = ->
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
