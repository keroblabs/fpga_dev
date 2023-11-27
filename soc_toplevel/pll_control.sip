set_global_assignment -entity "pll_control" -library "lib_pll_control" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "pll_control" -library "lib_pll_control" -name IP_TOOL_VERSION "20.1"
set_global_assignment -entity "pll_control" -library "lib_pll_control" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_pll_control" -name SPD_FILE [file join $::quartus(sip_path) "pll_control.spd"]

set_global_assignment -library "lib_pll_control" -name MISC_FILE [file join $::quartus(sip_path) "pll_control_sim/pll_control.vho"]
