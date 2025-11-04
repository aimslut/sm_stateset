# sm_stateset sourcemod plugin for CS:S
display the state of user defined variables on the hud (repositionable)
### features:
  - user is able to display the values of multiple variables
  - enable/disable existing variables that the specific user has registered
  - able to remove existing variables from the list
  - move existing variables and determine where on the screen they're displayed
  - customizable move increments (0.01, 0.05, 0.1) for fine control
  - uses cookies to save whether variables are enabled/disabled, along with their position and increment settings
  - alter text alignment between left aligned, centered and right aligned
  - chat trigger !states to open menu
  - menu-based management system
### commands:
| **Command**                        | **Description**                                                                                                                           |
| ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `sm_stateset <variable> <value>`   | Registers the variable if it doesn't already exist; sets the value for the variable; use `{empty}` as value to hide text (shows a space). |
| `sm_state_menu`                    | Opens the variable management menu.                                                                                                       |
| `sm_state_remove <variable>`       | Removes a variable.                                                                                                                       |
| `sm_state_enable <variable>`       | Enables/shows a variable.                                                                                                                 |
| `sm_state_disable <variable>`      | Disables/hides a variable.                                                                                                                |
| `sm_state_move <variable> <x> <y>` | Moves a variable to specific coordinates.                                                                                                 |
| `sm_state_align <variable> <left/center/right>` | Changes text alignment. |
| `sm_state_position <variable>`     | Outputs the current position as an `sm_state_move` command.                                                                               |
| `!states` *(chat command)*         | Opens the variable management menu.                                                                                                       |

### examples:
  - sm_stateset yawspeed 80
    - displays the value of yawspeed on the screen, updates when the value is changed
    - the user can change the value at any time by using the same command with a different value
  - sm_stateset pov {empty}
    - hides the pov text (shows a space)

yawspeed example:
  ```
  alias text_yaw80     "sm_stateset yaw 80"
  alias text_yaw120    "sm_stateset yaw 120"
  alias "toggleyaw"    "yawspeed_120"
  alias "yawspeed_80"  "cl_yawspeed 80; alias toggleyaw yawspeed_120; text_yaw80"
  alias "yawspeed_120" "cl_yawspeed 120; alias toggleyaw yawspeed_80; text_yaw120"
  bind  "mouse3"       "toggleyaw"
  ```
turnbind example:
  ```
  alias "text_turnbinds" "sm_stateset binds turnbinds"
  alias "text_flashes"   "sm_stateset binds flashes"
  alias "togglespin"     "spin_on"
  alias "spin_on"        "bind mouse1 +left;   bind mouse2 +right; -attack; -attack2; alias togglespin spin_off; text_turnbinds"
  alias "spin_off"       "bind mouse1 +attack; bind mouse2 +attack2; -left; -right;   alias togglespin spin_on;  text_flashes"
  bind  "mouse5"         "togglespin"
  ```
+pov example:
  ```
  alias "+pov_text" "+pov; sm_stateset pov teammate" // shows teammate text
  alias "-pov_text" "-pov; sm_stateset pov {empty}" // shows no text
  bind  "c"         "+pov_text"
  ```



