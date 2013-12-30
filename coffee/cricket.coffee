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
	tokens		= []
	token		= null
	char		= null

	readChar = ->
		c = text[0]
		text = text.substring(1)
		return c

	addToken = ->
		if token?
			tokens.push token
			token = null

	push = (something) ->
		addToken()
		token = something
		addToken()

	while text.length isnt 0
		char = readChar()

		if isWhitespaceChar char
			addToken()
		else if BRACES.indexOf(char) isnt -1
			push char
		else if char is "\""
			addToken()
			token = char

			while true
				throw new Error "Mismatched \"" if text.length is 0

				char = readChar()
				token += char

				if char is "\""
					break
		else
			token = if token? then token + char else char

	addToken()

	return tokens

class List
	constructor: (@elements) ->

	head: ->
		@elements[0]

	tail: ->
		new List @elements.slice(1)

	prepend: (head) ->
		new List [head].concat(@elements)

	toString: ->
		s = "("
		for i in [0...@elements.length]
			s += ns.stringify @elements[i]
			if i < @elements.length - 1
				s += " "
		s += ")"
		return s

class Symbol
	constructor: (@name) ->

	toString: ->
		@name

class SpecialForm
	constructor: (@definition) ->

	apply: (env, args) ->
		if @definition[args.length]?
			@definition[args.length].call(this, env, args)
		else if @definition.more?
			@definition.more.call(this, env, args)
		else
			throw new Error "No form definition for #{args.length} arguments"

class Fn
	constructor: (@definition) ->

	call: (args) ->
		if @definition[args.length]?
			@definition[args.length].call(this, args)
		else if @definition.more?
			@definition.more.call(this, args)
		else
			throw new Error "No function definition for #{args.length} arguments"

	apply: (env, args) ->
		return @call args

	@define: (env, argList, body) ->
		fnEnv		= Object.create(env)
		argNames	= (symbol.name for symbol in argList)
		argCount	= argNames.length

		definition = {}
		definition[argCount] = (args) ->
			for i in [0...argCount]
				fnEnv[argNames[i]] = args[i]
			return ns.eval(body, fnEnv)

		return new Fn definition

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
		return new List readList tokens, "(", ")"
	if token is "["
		return readList tokens, "[", "]"
	else if token is "nil"
		return null
	else if token is "true"
		return true
	else if token is "false"
		return false
	else if isNumberString token
		return Number token
	else if token[0] is "'"
		return ns.read "(quote #{token.substr(1)})"
	else if token[0] is "\""
		return token.substring(1, token.length - 1)
	else
		return new Symbol token

ns.read = (text) ->
	readEl ns.tokenize text

ns.readProgram = (text) ->
	ns.read "(do #{text})"


resolve = (symbol, env) ->
	throw new Error "Can only resolve symbols" unless symbol instanceof Symbol
	if symbol.name of env
		return env[symbol.name]
	else
		throw new Error "Can't resolve #{symbol.name}"

ns.eval = (thing, env) ->
	return null unless thing?

	if thing instanceof Symbol
		return resolve thing, env

	else if thing instanceof List
		head	= ns.eval(thing.elements[0], env)
		args	= thing.elements.slice(1)
		
		if head instanceof Fn and not head.isMacro
			args = (ns.eval(arg, env) for arg in args)

		result = head.apply(env, args)

		if head instanceof Fn and head.isMacro
			result = ns.eval result, env
		return result

	else if Array.isArray thing
		return (ns.eval el, env for el in thing)

	else
		return thing

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

	new Fn definition

isTruthy = (thing) ->
	if thing is false or thing is null
		return false
	else
		return true

ns.stringify = (thing) ->
	if not thing?
		"nil"
	else if Array.isArray(thing)
		s = "["
		for i in [0...thing.length]
			s += ns.stringify(thing[i])
			s += " " if i < thing.length - 1
		s += "]"
		return s
	else if thing? and thing.constructor is String
		return "\"#{thing}\""
	else
		thing.toString()
	
prelude = ->
	env =
		"if": new SpecialForm
			2: (env, [pred, ifTrue]) ->
				@apply env, [pred, ifTrue, null]
			3: (env, [pred, ifTrue, ifFalse]) ->
				if isTruthy ns.eval(pred, env)
					return ns.eval(ifTrue, env)
				else
					return ns.eval(ifFalse, env)
		"def": new SpecialForm
			2: (env, [symbol, definition]) ->
				definition = ns.eval(definition, env)
				env[symbol.name] = definition
				return definition
		
		"quote": new SpecialForm
			1: (env, [list]) ->
				list

		"eval": new SpecialForm
			1: (env, [expr]) ->
				ns.eval(ns.eval(expr, env), env)

		"fn": new SpecialForm
			2: (env, [argList, body]) ->
				return Fn.define env, argList, body

		"macro": new SpecialForm
			2: (env, [argList, body]) ->
				fn = Fn.define env, argList, body
				fn.isMacro = true
				return fn

		"do": new SpecialForm
			more: (env, exprs) ->
				for i in [0...exprs.length]
					result = ns.eval(exprs[i], env)
				return result

		"cons":	new Fn
				2: ([head, list]) ->
					list.prepend head
		"head":	new Fn
				1:	([clist]) ->
						clist.head()
		"tail":	new Fn
				1:	([clist]) ->
						clist.tail()
		"list":	new Fn
				more: (args) ->
					new List args
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

		"println": new Fn
			more: (args) ->
				s = ""
				for i in [0...args.length]
					s += ns.stringify(args[i])
					s += " " if i < args.length - 1
				console.log s

		"str": new Fn
			more: (args) ->
				s = ""
				for arg in args
					s += ns.stringify arg
				return s

	lispDefinitions = [
		"(def defmacro
		   (macro [name arg-list body]
		     (list 'def name
		       (list 'macro arg-list body))))"

		"(defmacro defn
		    [name arg-list body]
		    (list 'def name
		      (list 'fn arg-list body)))"

		"(defn inc
		   [x]
		   (+ x 1))"

		"(defn dec
		   [x]
		   (- x 1))"

		"(defmacro unless
		   [pred? if-false if-true]
		   (list 'if pred? if-true if-false))"
	]

	for definition in lispDefinitions
		ns.eval ns.read(definition), env

	return env

ns.run = (text) ->
	s	= ""
	env	= prelude()

	return ns.stringify(ns.eval(ns.readProgram(text), env))
