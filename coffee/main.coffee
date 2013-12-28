$ ->
	$("#go").click ->
		input = $("#input").val()

		output =
			try
				cricket.parse input
			catch e
				e

		$("#output").text output
