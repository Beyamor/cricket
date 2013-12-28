if exports?
	ns = exports
else
	ns = window.cricket = {}

isNumber = (n) ->
	!isNaN(parseFloat(n)) and isFinite(n)

ns.isNumber = isNumber

ns.parse = (text) ->
	if isNumber text
		Number(text)
	else
		throw new Error "Can't parse text"
