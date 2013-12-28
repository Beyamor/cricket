if exports?
	ns = exports
else
	ns = window.cricket = {}

ns.parse = (text) -> alert text
