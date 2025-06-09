rockspec_format = "3.0"
package = "with-rockspec-settings"
version = "0.1-1"

source = {
	url = "",
}

build = {
	type = "lls-addon",
	settings = {
		["hover.enable"] = true
	}
}
