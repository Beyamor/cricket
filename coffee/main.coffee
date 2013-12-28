$ ->
	$("#go").click ->
		input = $("#input").val()

		output =
			try
				cricket.run input
			catch e
				e

		$("#output").text output
