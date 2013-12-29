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

class CThing
	eval: -> this

	isTruthy: -> true

class CNil extends CThing
	toString: -> "nil"

	isTruthy: -> false
NIL = new CNil


class CNumber extends CThing
	constructor: (token) ->
		@value = Number(token)

	toString: ->
		@value.toString()

	@value: (x) ->
		if x instanceof CNumber
			return x.value
		else
			throw new Error "Can't coerce #{x.constructor.name} to CNumber"

class CList extends CThing
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

class CSymbol extends CThing
	constructor: (@name) ->

	eval: (env) ->
		env[@name]

	toString: ->
		@name

class CSpecialForm extends CThing
	constructor: (@definition) ->

	apply: (env, args) ->
		if @definition[args.length]?
			@definition[args.length].call(this, env, args)
		else if @definition.more?
			@definition.more.call(this, env, args)
		else
			throw new Error "No form definition for #{args.length} arguments"

class CFn extends CThing
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
		els = readList tokens, "[", "]"
		return new CList [new CSymbol "list"].concat els
	else
		if token is "nil"
			return NIL
		else if isNumberString token
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
	"if": new CSpecialForm
		2: (env, [pred, ifTrue]) ->
			@apply env, [pred, ifTrue, NIL]
		3: (env, [pred, ifTrue, ifFalse]) ->
			if pred.eval(env).isTruthy()
				return ifTrue.eval(env)
			else
				return ifFalse.eval(env)
	"def": new CSpecialForm
		2: (env, [symbol, definition]) ->
			definition = definition.eval(env)
			env[symbol.name] = definition
			return definition
	
	"fn": new CSpecialForm
		2: (env, [argList, body]) ->
			fnEnv		= Object.create(env)
			argNames	= (symbol.name for symbol in argList.tail().elements)
			argCount	= argNames.length

			definition = {}
			definition[argCount] = (args) ->
				for i in [0...argCount]
					fnEnv[argNames[i]] = args[i]
				return body.eval(fnEnv)

			return new CFn definition

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
		s += (ns.eval el, env) + "\n"
	return s
