extends MenuBar

func createShortcut(letter: Key, ctrl: bool = false, shift: bool = false, alt: bool = false) -> Shortcut:
	var shortcut = Shortcut.new()

	var input_event = InputEventKey.new()

	input_event.keycode = letter
	input_event.ctrl_pressed = ctrl
	input_event.shift_pressed = shift
	input_event.alt_pressed = alt

	shortcut.events = [input_event]

	return shortcut

var menuItems = {
	'File': {
		'New Composition': {
			'shortcut': createShortcut(KEY_N, true),
			'callback': func(_args = {}): print('New Composition'),
		},
		'Open Composition': {
			'shortcut': createShortcut(KEY_O, true),
			'callback': func(_args = {}): print('Open Composition'),
		},
		'Save Composition': {
			'shortcut': createShortcut(KEY_S, true),
			'callback': func(_args = {}): print('Save Composition'),
			'add_seperator': true,
		},
		'Import Motion': {
			'shortcut': createShortcut(KEY_I, true),
			'callback': func(_args = {}): print('Import Motion'),
		},
		'Export Motion': {
			'shortcut': createShortcut(KEY_E, true),
			'callback': func(_args = {}): print('Export Motion'),
		},
	},
	'Help': {
		'About MoLab': {
			'icon': preload("res://res/icons/CharacterBody3D.png")
		}
	}
}

func _ready():
	for menu in menuItems:
		add_child(createSubmenu(menu, menuItems[menu]))

func createSubmenu(submenu_name: String, data: Dictionary) -> PopupMenu:
	var popup_menu = PopupMenu.new()
	popup_menu.name = submenu_name

	var index = 0
	for menu_item_name in data:
		var menu_item_data = data[menu_item_name]

		popup_menu.add_item(menu_item_name, index)

		if 'shortcut' in menu_item_data: popup_menu.set_item_shortcut(index, menu_item_data['shortcut'])

		if 'tooltip' in menu_item_data: popup_menu.set_item_tooltip(index, menu_item_data['tooltip'])

		if 'icon' in menu_item_data: popup_menu.set_item_icon(index, menu_item_data['icon'])

		if 'icon_max_width' in menu_item_data:
			popup_menu.set_item_icon_max_width(index, menu_item_data['icon_max_width'])
		else:
			popup_menu.set_item_icon_max_width(index, 30)

		if 'check_state' in menu_item_data:
			popup_menu.set_item_as_checkable(index, true)
			popup_menu.set_item_checked(index, menu_item_data['check_state'])

		if 'children' in menu_item_data:
			var submenu = createSubmenu(menu_item_name + '_sub-menu', menu_item_data['children'])
			popup_menu.set_item_submenu(index, submenu.name)
			popup_menu.add_child(submenu)

		var index_pressed_callback = func(pressed_index):
			if pressed_index == index:
				var isChecked = popup_menu.is_item_checked(index)

				if 'callback' in menu_item_data:
					menu_item_data['callback'].call({
						'checked': isChecked,
						'popup_menu': popup_menu,
						'index': index
					})

		popup_menu.index_pressed.connect(index_pressed_callback)

		# Dependant
		var dependant_callback = func():
			var isEnabled = menu_item_data['condition'].call()
			popup_menu.set_item_disabled(index, !isEnabled)

		if 'condition' in menu_item_data:
			dependant_callback.call()

			if 'depends_on' in menu_item_data:
				menu_item_data['depends_on'].call(dependant_callback)

		if 'add_seperator' in menu_item_data:
			if menu_item_data['add_seperator']:
				index += 1
				popup_menu.add_separator('', index)

		index += 1

	return popup_menu
