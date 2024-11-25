extends HBoxContainer

# var status: String = ""
# var progress: int = 100
# var indeterminate: bool = false

func set_status(status: String, progress: int, indeterminate: bool):
	%StatusLineEdit.text = status
	%ProgressBar.value = progress
	%ProgressBar.indeterminate = indeterminate
