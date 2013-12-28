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

	toString: ->
		@value.toString()

class CList
	constructor: (@elements) ->

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

ns.run = (text) ->
	s = ""
	for el in ns.read text
		s += el.toString() + "\n"
	return s
