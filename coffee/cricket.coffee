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

ns.read = (text) ->
	tokens	= ns.tokenize text
	program	= []
	while tokens.length isnt 0
		token = tokens.shift()

		if isNumberString token
			program.push Number(token)
		else
			throw new Error "Don't know how to read #{token}"

	return program

ns.parse = (text) ->
	return ns.read text
