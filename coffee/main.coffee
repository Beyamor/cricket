$ ->
	$("#go").click ->
		input = $("#input").val()

		output =
			try
				cricket.run input
			catch e
				e
				throw e

		$("#output").text output
