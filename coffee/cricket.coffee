if exports?
	ns = exports
else
	ns = window.cricket = {}

WHITESPACE_CHARS = [" ", "\n", "\r", "\t"]
isWhitespace = (char) ->
	WHITESPACE_CHARS.indexOf(char) isnt -1

isNumber = (n) ->
	!isNaN(parseFloat(n)) and isFinite(n)

ns.tokenize = (text) ->
	tokens	= []
	token	= null

	while text.length isnt 0
		char	= text[0]

		# TODO Handle strings
		if isWhitespace char
			if token?
				tokens.push token
				token = null
		else
			if not token?
				token = char
			else
				token += char

		text = text.substring(1)

	if token?
		tokens.push token

	return tokens

ns.read = (text) ->
	tokens	= ns.tokenize text
	program	= []
	while tokens.length isnt 0
		token = tokens.shift()

		if isNumber token
			program.push Number(token)
		else
			throw new Error "Don't know how to read #{token}"

	return program

ns.parse = (text) ->
	return ns.read text
