/**
 * sm_stateset.sp
 *
 * Display user defined variables on permanent HUD
 *
 * commands:
 *   sm_stateset <variable> <value> - Set or register a variable
 *   sm_state_menu - Open variable management menu
 *   sm_state_remove <variable> - Remove a variable
 *   sm_state_enable <variable> - Enable a variable
 *   sm_state_disable <variable> - Disable a variable
 *   sm_state_move <variable> <x> <y> - Move a variable
 *   sm_state_align <variable> <left|center|right> - Change alignment
 *   sm_state_position <variable> - Get current position of a variable
 *
 * examples:
 *   sm_stateset binds turnbinds
 *   sm_stateset yaw 80
 *   (check README.md for more examples)
 *
 * author: aimslut
 * version: 1.1.0
 */

#include <sourcemod>
#include <clientprefs>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME "sm_stateset"
#define PLUGIN_VERSION "1.1.0"
#define PLUGIN_AUTHOR "aimslut"
#define PLUGIN_DESCRIPTION "Display user defined variables on permanent HUD"
#define PLUGIN_URL "https://github.com/aimslut/sm_stateset"

#define MAX_VARIABLES 32
#define MAX_VARIABLE_NAME 32
#define MAX_VARIABLE_VALUE 128
#define COOKIE_BUFFER_SIZE 4096


// text alignment
enum TextAlignment {
    ALIGN_LEFT = 0,
    ALIGN_CENTER = 1,
    ALIGN_RIGHT = 2
};

enum struct VariableData {
    char name[MAX_VARIABLE_NAME];
    char value[MAX_VARIABLE_VALUE];
    char lastValue[MAX_VARIABLE_VALUE];
    bool enabled;
    float x;
    float y;
    TextAlignment alignment;
    Handle hudSync;
    float moveIncrement;
}

enum struct ClientData {
    int variableCount;
}

// globals
ClientData g_ClientData[MAXPLAYERS + 1];
VariableData g_Variables[MAXPLAYERS + 1][MAX_VARIABLES];
Handle g_hVariableCookie = null;


public Plugin myinfo = {
    name        = PLUGIN_NAME,
    author      = PLUGIN_AUTHOR,
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    url         = PLUGIN_URL
};

// plugin initialization
public void OnPluginStart() {
    CreateConVar("sm_stateset_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

    RegConsoleCmd("sm_stateset", Command_StateSet, "Set or register a variable: sm_stateset <variable> <value>");
    RegConsoleCmd("sm_state_menu", Command_StateMenu, "Open variable management menu");
    RegConsoleCmd("sm_state_remove", Command_StateRemove, "Remove a variable");
    RegConsoleCmd("sm_state_enable", Command_StateEnable, "Enable a variable");
    RegConsoleCmd("sm_state_disable", Command_StateDisable, "Disable a variable");
    RegConsoleCmd("sm_state_move", Command_StateMove, "Move a variable");
    RegConsoleCmd("sm_state_align", Command_StateAlign, "Change alignment");
    RegConsoleCmd("sm_state_position", Command_StatePosition, "Get current position of a variable");

    AddCommandListener(Command_ChatTrigger, "say");
    AddCommandListener(Command_ChatTrigger, "say_team");

    LoadTranslations("common.phrases");
    g_hVariableCookie = RegClientCookie("stateset_variables", "StateSet Variables", CookieAccess_Protected);

    PrintToServer("[%s] Plugin v%s loaded successfully by %s", PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
}

public void OnClientPutInServer(int client) {
    g_ClientData[client].variableCount = 0;
    LoadClientVariables(client);

    for (int i = 0; i < g_ClientData[client].variableCount; i++) {
        if (g_Variables[client][i].enabled && g_Variables[client][i].hudSync == null) {
            g_Variables[client][i].hudSync = CreateHudSynchronizer();
        }
    }

    UpdateHUD(client);
}

public void OnClientDisconnect(int client) {
    for (int i = 0; i < g_ClientData[client].variableCount; i++) {
        if (g_Variables[client][i].hudSync != null) {
            CloseHandle(g_Variables[client][i].hudSync);
            g_Variables[client][i].hudSync = null;
        }
    }
    SaveClientVariables(client);
}

// variable management
void LoadClientVariables(int client) {
    char cookieData[COOKIE_BUFFER_SIZE];
    GetClientCookie(client, g_hVariableCookie, cookieData, sizeof(cookieData));
    if (strlen(cookieData) == 0) return;

    char variables[MAX_VARIABLES][256];
    int varCount = ExplodeString(cookieData, "|", variables, sizeof(variables), sizeof(variables[]));

    for (int i = 0; i < varCount && g_ClientData[client].variableCount < MAX_VARIABLES; i++) {
        char parts[7][128];
        int partCount = ExplodeString(variables[i], ",", parts, sizeof(parts), sizeof(parts[]));
        if (partCount >= 7) {
            int idx = g_ClientData[client].variableCount++;
            strcopy(g_Variables[client][idx].name, MAX_VARIABLE_NAME, parts[0]);
            strcopy(g_Variables[client][idx].value, MAX_VARIABLE_VALUE, parts[1]);
            strcopy(g_Variables[client][idx].lastValue, MAX_VARIABLE_VALUE, "");
            g_Variables[client][idx].enabled = StringToInt(parts[2]) != 0;
            g_Variables[client][idx].x = StringToFloat(parts[3]);
            g_Variables[client][idx].y = StringToFloat(parts[4]);
            g_Variables[client][idx].alignment = view_as<TextAlignment>(StringToInt(parts[5]));
            g_Variables[client][idx].moveIncrement = StringToFloat(parts[6]);
            g_Variables[client][idx].hudSync = null;
        } else if (partCount >= 6) {
            int idx = g_ClientData[client].variableCount++;
            strcopy(g_Variables[client][idx].name, MAX_VARIABLE_NAME, parts[0]);
            strcopy(g_Variables[client][idx].value, MAX_VARIABLE_VALUE, parts[1]);
            strcopy(g_Variables[client][idx].lastValue, MAX_VARIABLE_VALUE, "");
            g_Variables[client][idx].enabled = StringToInt(parts[2]) != 0;
            g_Variables[client][idx].x = StringToFloat(parts[3]);
            g_Variables[client][idx].y = StringToFloat(parts[4]);
            g_Variables[client][idx].alignment = view_as<TextAlignment>(StringToInt(parts[5]));
            g_Variables[client][idx].moveIncrement = 0.05;
            g_Variables[client][idx].hudSync = null;
        }
    }
}

void SaveClientVariables(int client) {
    if (g_ClientData[client].variableCount == 0) {
        SetClientCookie(client, g_hVariableCookie, "");
        return;
    }

    char cookieData[COOKIE_BUFFER_SIZE] = "";
    for (int i = 0; i < g_ClientData[client].variableCount; i++) {
        char varData[256];
        Format(varData, sizeof(varData), "%s,%s,%d,%.1f,%.1f,%d,%.2f",
            g_Variables[client][i].name,
            g_Variables[client][i].value,
            g_Variables[client][i].enabled ? 1 : 0,
            g_Variables[client][i].x,
            g_Variables[client][i].y,
            view_as<int>(g_Variables[client][i].alignment),
            g_Variables[client][i].moveIncrement
        );
        StrCat(cookieData, sizeof(cookieData), varData);
        if (i < g_ClientData[client].variableCount - 1) StrCat(cookieData, sizeof(cookieData), "|");
    }

    SetClientCookie(client, g_hVariableCookie, cookieData);
}

int FindVariableIndex(int client, const char[] name) {
    for (int i = 0; i < g_ClientData[client].variableCount; i++) {
        if (StrEqual(g_Variables[client][i].name, name, false)) return i;
    }
    return -1;
}


// HUD logic
void UpdateHUD(int client) {
    if (!IsClientInGame(client) || IsFakeClient(client)) return;

    for (int i = 0; i < g_ClientData[client].variableCount; i++) {
        if (!g_Variables[client][i].enabled) continue;

        if (g_Variables[client][i].hudSync == null) {
            g_Variables[client][i].hudSync = CreateHudSynchronizer();
        }

        if (!StrEqual(g_Variables[client][i].lastValue, g_Variables[client][i].value, false)) {
            SetHudTextParams(
                g_Variables[client][i].x,
                g_Variables[client][i].y,
                1.0,
                255, 255, 255, 255,
                view_as<int>(g_Variables[client][i].alignment),
                0.0, 0.0, 9999.0
            );

            if (strlen(g_Variables[client][i].value) == 0) {
                ShowSyncHudText(client, g_Variables[client][i].hudSync, "");
            } else {
                ShowSyncHudText(client, g_Variables[client][i].hudSync, g_Variables[client][i].value);
            }

            strcopy(g_Variables[client][i].lastValue, MAX_VARIABLE_VALUE, g_Variables[client][i].value);
        }
    }
}

// menus and helpers
int FindValidClient() {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            return i;
        }
    }
    return 0;
}

// validates client and returns client index or valid alternative
int IsValidClient(int client) {
    if (client > 0 && IsClientInGame(client) && !IsFakeClient(client)) {
        return client;
    }

    if (client == 0) {
        int validClient = FindValidClient();
        if (validClient == 0) {
            PrintToServer("[SM] Command requires a valid player.");
        }
        return validClient;
    }

    PrintToServer("[SM] Command requires a valid player.");
    return 0;
}

char[] GetAlignmentName(TextAlignment alignment) {
    static char name[16];
    int alignInt = view_as<int>(alignment);
    if (alignInt == 0) {
        strcopy(name, sizeof(name), "Left");
    } else if (alignInt == 1) {
        strcopy(name, sizeof(name), "Center");
    } else if (alignInt == 2) {
        strcopy(name, sizeof(name), "Right");
    } else {
        strcopy(name, sizeof(name), "Unknown");
    }
    return name;
}

void ShowVariableMenu(int client) {
    Menu menu = new Menu(MenuHandler_VariableMenu);
    menu.SetTitle("sm_stateset menu");

    char itemText[128];
    char itemInfo[32];

    for (int i = 0; i < g_ClientData[client].variableCount; i++) {
        Format(itemText, sizeof(itemText), "%s: %s",
            g_Variables[client][i].name,
            g_Variables[client][i].enabled ? "Enabled" : "Disabled");
        IntToString(i, itemInfo, sizeof(itemInfo));
        menu.AddItem(itemInfo, itemText);
    }

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_VariableMenu(Menu menu, MenuAction action, int client, int item) {
    if (action == MenuAction_Select) {
        char info[32];
        menu.GetItem(item, info, sizeof(info));
        int varIndex = StringToInt(info);
        ShowVariableActionMenu(client, varIndex);
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

void ShowVariableActionMenu(int client, int varIndex) {
    Menu menu = new Menu(MenuHandler_VariableAction);
    char title[128];
    Format(title, sizeof(title), "Manage: %s", g_Variables[client][varIndex].name);
    menu.SetTitle(title);

    char actionInfo[64];
    Format(actionInfo, sizeof(actionInfo), "%d_toggle", varIndex);
    menu.AddItem(actionInfo, g_Variables[client][varIndex].enabled ? "Hide Variable" : "Show Variable");

    Format(actionInfo, sizeof(actionInfo), "%d_move", varIndex);
    menu.AddItem(actionInfo, "Move Position");

    Format(actionInfo, sizeof(actionInfo), "%d_align", varIndex);
    menu.AddItem(actionInfo, "Change Alignment");

    Format(actionInfo, sizeof(actionInfo), "%d_remove", varIndex);
    menu.AddItem(actionInfo, "Remove Variable");

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_VariableAction(Menu menu, MenuAction action, int client, int item) {
    if (action == MenuAction_Select) {
        char info[64];
        menu.GetItem(item, info, sizeof(info));

        char parts[2][32];
        ExplodeString(info, "_", parts, sizeof(parts), sizeof(parts[]));
        int varIndex = StringToInt(parts[0]);
        char actionType[32];
        strcopy(actionType, sizeof(actionType), parts[1]);

        if (StrEqual(actionType, "toggle")) {
            g_Variables[client][varIndex].enabled = !g_Variables[client][varIndex].enabled;

            if (!g_Variables[client][varIndex].enabled) {
                if (g_Variables[client][varIndex].hudSync != null) {
                    SetHudTextParams(
                        g_Variables[client][varIndex].x,
                        g_Variables[client][varIndex].y,
                        0.0,
                        255, 255, 255, 255,
                        view_as<int>(g_Variables[client][varIndex].alignment),
                        0.0, 0.0, 0.0
                    );
                    ShowSyncHudText(client, g_Variables[client][varIndex].hudSync, " ");
                    CloseHandle(g_Variables[client][varIndex].hudSync);
                    g_Variables[client][varIndex].hudSync = null;
                }
            } else if (g_Variables[client][varIndex].enabled && g_Variables[client][varIndex].hudSync == null) {
                g_Variables[client][varIndex].hudSync = CreateHudSynchronizer();
                g_Variables[client][varIndex].lastValue[0] = '\0';
            }

            UpdateHUD(client);
            SaveClientVariables(client);
            PrintToChat(client, "[SM] Variable '%s' %s.", g_Variables[client][varIndex].name,
                g_Variables[client][varIndex].enabled ? "enabled" : "disabled");
            ShowVariableMenu(client);
        } else if (StrEqual(actionType, "move")) {
            ShowMoveMenu(client, varIndex);
        } else if (StrEqual(actionType, "align")) {
            ShowAlignMenu(client, varIndex);
        } else if (StrEqual(actionType, "remove")) {
            ShowRemoveConfirmMenu(client, varIndex);
        }
    } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
        ShowVariableMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

void ShowMoveMenu(int client, int varIndex) {
    Menu menu = new Menu(MenuHandler_MoveMenu);
    char title[128];
    Format(title, sizeof(title), "Move: %s (Current: %.2f, %.2f | Increment: %.2f)", g_Variables[client][varIndex].name,
        g_Variables[client][varIndex].x, g_Variables[client][varIndex].y, g_Variables[client][varIndex].moveIncrement);
    menu.SetTitle(title);

    char moveInfo[64];
    Format(moveInfo, sizeof(moveInfo), "%d_increment", varIndex);
    char incrementText[32];
    Format(incrementText, sizeof(incrementText), "Increment: %.2f", g_Variables[client][varIndex].moveIncrement);
    menu.AddItem(moveInfo, incrementText);

    Format(moveInfo, sizeof(moveInfo), "%d_up", varIndex);
    menu.AddItem(moveInfo, "Move Up");

    Format(moveInfo, sizeof(moveInfo), "%d_down", varIndex);
    menu.AddItem(moveInfo, "Move Down");

    Format(moveInfo, sizeof(moveInfo), "%d_left", varIndex);
    menu.AddItem(moveInfo, "Move Left");

    Format(moveInfo, sizeof(moveInfo), "%d_right", varIndex);
    menu.AddItem(moveInfo, "Move Right");

    Format(moveInfo, sizeof(moveInfo), "%d_reset", varIndex);
    menu.AddItem(moveInfo, "Reset to Center");

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_MoveMenu(Menu menu, MenuAction action, int client, int item) {
    if (action == MenuAction_Select) {
        char info[64];
        menu.GetItem(item, info, sizeof(info));

        char parts[2][32];
        ExplodeString(info, "_", parts, sizeof(parts), sizeof(parts[]));
        int varIndex = StringToInt(parts[0]);
        char direction[32];
        strcopy(direction, sizeof(direction), parts[1]);

        if (StrEqual(direction, "increment")) {
            if (g_Variables[client][varIndex].moveIncrement == 0.01) {
                g_Variables[client][varIndex].moveIncrement = 0.05;
            } else if (g_Variables[client][varIndex].moveIncrement == 0.05) {
                g_Variables[client][varIndex].moveIncrement = 0.1;
            } else {
                g_Variables[client][varIndex].moveIncrement = 0.01;
            }
            SaveClientVariables(client);
            PrintToChat(client, "[SM] Variable '%s' increment set to %.2f",
                g_Variables[client][varIndex].name, g_Variables[client][varIndex].moveIncrement);
        } else {
            float moveAmount = g_Variables[client][varIndex].moveIncrement;

            if (StrEqual(direction, "up")) {
                g_Variables[client][varIndex].y -= moveAmount;
            } else if (StrEqual(direction, "down")) {
                g_Variables[client][varIndex].y += moveAmount;
            } else if (StrEqual(direction, "left")) {
                g_Variables[client][varIndex].x -= moveAmount;
            } else if (StrEqual(direction, "right")) {
                g_Variables[client][varIndex].x += moveAmount;
            } else if (StrEqual(direction, "reset")) {
                g_Variables[client][varIndex].x = -1.0;
                g_Variables[client][varIndex].y = 0.1;
            }

            g_Variables[client][varIndex].lastValue[0] = '\0';
            UpdateHUD(client);
            SaveClientVariables(client);
            PrintToChat(client, "[SM] Variable '%s' moved to position %.2f, %.2f",
                g_Variables[client][varIndex].name, g_Variables[client][varIndex].x, g_Variables[client][varIndex].y);
        }
        ShowMoveMenu(client, varIndex);
    } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
        ShowVariableMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

void ShowAlignMenu(int client, int varIndex) {
    Menu menu = new Menu(MenuHandler_AlignMenu);
    char title[128];
    Format(title, sizeof(title), "Align: %s (Current: %s)", g_Variables[client][varIndex].name,
        GetAlignmentName(g_Variables[client][varIndex].alignment));
    menu.SetTitle(title);

    char alignInfo[64];
    Format(alignInfo, sizeof(alignInfo), "%d_left", varIndex);
    menu.AddItem(alignInfo, "Left Align");

    Format(alignInfo, sizeof(alignInfo), "%d_center", varIndex);
    menu.AddItem(alignInfo, "Center Align");

    Format(alignInfo, sizeof(alignInfo), "%d_right", varIndex);
    menu.AddItem(alignInfo, "Right Align");

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_AlignMenu(Menu menu, MenuAction action, int client, int item) {
    if (action == MenuAction_Select) {
        char info[64];
        menu.GetItem(item, info, sizeof(info));

        char parts[2][32];
        ExplodeString(info, "_", parts, sizeof(parts), sizeof(parts[]));
        int varIndex = StringToInt(parts[0]);
        char alignType[32];
        strcopy(alignType, sizeof(alignType), parts[1]);

        TextAlignment newAlignment;
        char alignName[16];

        if (StrEqual(alignType, "left")) {
            newAlignment = ALIGN_LEFT;
            strcopy(alignName, sizeof(alignName), "left");
        } else if (StrEqual(alignType, "center")) {
            newAlignment = ALIGN_CENTER;
            strcopy(alignName, sizeof(alignName), "center");
        } else {
            newAlignment = ALIGN_RIGHT;
            strcopy(alignName, sizeof(alignName), "right");
        }

        g_Variables[client][varIndex].alignment = newAlignment;
        g_Variables[client][varIndex].lastValue[0] = '\0';
        UpdateHUD(client);
        SaveClientVariables(client);
        PrintToChat(client, "[SM] Variable '%s' alignment set to %s.",
            g_Variables[client][varIndex].name, alignName);
        ShowAlignMenu(client, varIndex);
    } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
        ShowVariableMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

void ShowRemoveConfirmMenu(int client, int varIndex) {
    Menu menu = new Menu(MenuHandler_RemoveConfirm);
    char title[128];
    Format(title, sizeof(title), "Remove Variable: %s", g_Variables[client][varIndex].name);
    menu.SetTitle(title);

    char confirmInfo[64];
    Format(confirmInfo, sizeof(confirmInfo), "%d_yes", varIndex);
    menu.AddItem(confirmInfo, "Yes, Remove Variable");

    Format(confirmInfo, sizeof(confirmInfo), "%d_no", varIndex);
    menu.AddItem(confirmInfo, "No, Keep Variable");

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_RemoveConfirm(Menu menu, MenuAction action, int client, int item) {
    if (action == MenuAction_Select) {
        char info[64];
        menu.GetItem(item, info, sizeof(info));

        char parts[2][32];
        ExplodeString(info, "_", parts, sizeof(parts), sizeof(parts[]));
        int varIndex = StringToInt(parts[0]);
        char confirm[32];
        strcopy(confirm, sizeof(confirm), parts[1]);

        if (StrEqual(confirm, "yes")) {
            char varName[MAX_VARIABLE_NAME];
            strcopy(varName, sizeof(varName), g_Variables[client][varIndex].name);

            if (g_Variables[client][varIndex].hudSync != null) {
                CloseHandle(g_Variables[client][varIndex].hudSync);
                g_Variables[client][varIndex].hudSync = null;
            }

            for (int i = varIndex; i < g_ClientData[client].variableCount - 1; i++) {
                g_Variables[client][i] = g_Variables[client][i + 1];
            }
            g_ClientData[client].variableCount--;

            UpdateHUD(client);
            SaveClientVariables(client);
            PrintToChat(client, "[SM] Variable '%s' removed.", varName);
            ShowVariableMenu(client);
        } else {
            ShowVariableActionMenu(client, varIndex);
        }
    } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
        ShowVariableActionMenu(client, 0);
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

// commands
public Action Command_StateSet(int client, int args) {
    int actualClient = IsValidClient(client);
    if (actualClient == 0) {
        return Plugin_Handled;
    }

    if (args < 2) {
        PrintToChat(actualClient, "[SM] Usage: sm_stateset <variable> <value>");
        return Plugin_Handled;
    }

    char variableName[MAX_VARIABLE_NAME];
    GetCmdArg(1, variableName, sizeof(variableName));

    char value[MAX_VARIABLE_VALUE];
    GetCmdArgString(value, sizeof(value));

    char temp[256];
    strcopy(temp, sizeof(temp), value);

    int nameLen = strlen(variableName);
    if (nameLen + 1 < sizeof(temp) && strncmp(temp, variableName, nameLen) == 0 && temp[nameLen] == ' ') {
        strcopy(temp, sizeof(temp), temp[nameLen + 1]);
    }
    TrimString(temp);
    strcopy(value, sizeof(value), temp);

    if (StrEqual(value, "{empty}", false)) {
        strcopy(value, sizeof(value), " ");
    }

    int varIndex = FindVariableIndex(actualClient, variableName);

    if (varIndex == -1) {
        if (g_ClientData[actualClient].variableCount >= MAX_VARIABLES) {
            PrintToChat(actualClient, "[SM] Maximum number of variables reached.");
            return Plugin_Handled;
        }

        varIndex = g_ClientData[actualClient].variableCount++;
        strcopy(g_Variables[actualClient][varIndex].name, MAX_VARIABLE_NAME, variableName);
        strcopy(g_Variables[actualClient][varIndex].lastValue, MAX_VARIABLE_VALUE, "");
        g_Variables[actualClient][varIndex].enabled = true;
        g_Variables[actualClient][varIndex].x = -1.0;
        g_Variables[actualClient][varIndex].y = 0.1;
        g_Variables[actualClient][varIndex].alignment = ALIGN_LEFT;
        g_Variables[actualClient][varIndex].moveIncrement = 0.05;
        g_Variables[actualClient][varIndex].hudSync = null;
    }

    strcopy(g_Variables[actualClient][varIndex].value, MAX_VARIABLE_VALUE, value);
    g_Variables[actualClient][varIndex].lastValue[0] = '\0';
    if (g_Variables[actualClient][varIndex].hudSync == null && g_Variables[actualClient][varIndex].enabled) {
        g_Variables[actualClient][varIndex].hudSync = CreateHudSynchronizer();
    }

    UpdateHUD(actualClient);
    SaveClientVariables(actualClient);

    return Plugin_Handled;
}

public Action Command_StateRemove(int client, int args) {
    int actualClient = IsValidClient(client);
    if (actualClient == 0) {
        return Plugin_Handled;
    }

    if (args < 1) {
        PrintToChat(actualClient, "[SM] Usage: sm_state_remove <variable>");
        return Plugin_Handled;
    }

    char variableName[MAX_VARIABLE_NAME];
    GetCmdArg(1, variableName, sizeof(variableName));

    int varIndex = FindVariableIndex(actualClient, variableName);
    if (varIndex == -1) {
        PrintToChat(actualClient, "[SM] Variable '%s' not found.", variableName);
        return Plugin_Handled;
    }

    if (g_Variables[actualClient][varIndex].hudSync != null) {
        CloseHandle(g_Variables[actualClient][varIndex].hudSync);
        g_Variables[actualClient][varIndex].hudSync = null;
    }

    for (int i = varIndex; i < g_ClientData[actualClient].variableCount - 1; i++) {
        g_Variables[actualClient][i] = g_Variables[actualClient][i + 1];
    }
    g_ClientData[actualClient].variableCount--;

    UpdateHUD(actualClient);
    SaveClientVariables(actualClient);
    PrintToChat(actualClient, "[SM] Variable '%s' removed.", variableName);

    return Plugin_Handled;
}

public Action Command_StateEnable(int client, int args) {
    int actualClient = IsValidClient(client);
    if (actualClient == 0) {
        return Plugin_Handled;
    }

    if (args < 1) {
        PrintToChat(actualClient, "[SM] Usage: sm_state_enable <variable>");
        return Plugin_Handled;
    }

    char variableName[MAX_VARIABLE_NAME];
    GetCmdArg(1, variableName, sizeof(variableName));

    int varIndex = FindVariableIndex(actualClient, variableName);
    if (varIndex == -1) {
        PrintToChat(actualClient, "[SM] Variable '%s' not found.", variableName);
        return Plugin_Handled;
    }

    g_Variables[actualClient][varIndex].enabled = true;
    if (g_Variables[actualClient][varIndex].hudSync == null) {
        g_Variables[actualClient][varIndex].hudSync = CreateHudSynchronizer();
    }
    g_Variables[actualClient][varIndex].lastValue[0] = '\0';
    UpdateHUD(actualClient);
    SaveClientVariables(actualClient);
    PrintToChat(actualClient, "[SM] Variable '%s' enabled.", variableName);

    return Plugin_Handled;
}

public Action Command_StateDisable(int client, int args) {
    int actualClient = IsValidClient(client);
    if (actualClient == 0) {
        return Plugin_Handled;
    }

    if (args < 1) {
        PrintToChat(actualClient, "[SM] Usage: sm_state_disable <variable>");
        return Plugin_Handled;
    }

    char variableName[MAX_VARIABLE_NAME];
    GetCmdArg(1, variableName, sizeof(variableName));

    int varIndex = FindVariableIndex(actualClient, variableName);
    if (varIndex == -1) {
        PrintToChat(actualClient, "[SM] Variable '%s' not found.", variableName);
        return Plugin_Handled;
    }

    g_Variables[actualClient][varIndex].enabled = false;
    if (g_Variables[actualClient][varIndex].hudSync != null) {
        SetHudTextParams(
            g_Variables[actualClient][varIndex].x,
            g_Variables[actualClient][varIndex].y,
            0.0,
            255, 255, 255, 255,
            view_as<int>(g_Variables[actualClient][varIndex].alignment),
            0.0, 0.0, 0.0
        );
        ShowSyncHudText(actualClient, g_Variables[actualClient][varIndex].hudSync, " ");
        CloseHandle(g_Variables[actualClient][varIndex].hudSync);
        g_Variables[actualClient][varIndex].hudSync = null;
    }
    UpdateHUD(actualClient);
    SaveClientVariables(actualClient);
    PrintToChat(actualClient, "[SM] Variable '%s' disabled.", variableName);

    return Plugin_Handled;
}

public Action Command_StateMove(int client, int args) {
    int actualClient = IsValidClient(client);
    if (actualClient == 0) {
        return Plugin_Handled;
    }

    if (args < 3) {
        PrintToChat(actualClient, "[SM] Usage: sm_state_move <variable> <x> <y>");
        return Plugin_Handled;
    }

    char variableName[MAX_VARIABLE_NAME];
    GetCmdArg(1, variableName, sizeof(variableName));

    char xStr[16], yStr[16];
    GetCmdArg(2, xStr, sizeof(xStr));
    GetCmdArg(3, yStr, sizeof(yStr));

    float x = StringToFloat(xStr);
    float y = StringToFloat(yStr);

    int varIndex = FindVariableIndex(actualClient, variableName);
    if (varIndex == -1) {
        PrintToChat(actualClient, "[SM] Variable '%s' not found.", variableName);
        return Plugin_Handled;
    }

    g_Variables[actualClient][varIndex].x = x;
    g_Variables[actualClient][varIndex].y = y;
    g_Variables[actualClient][varIndex].lastValue[0] = '\0';
    UpdateHUD(actualClient);
    SaveClientVariables(actualClient);

    return Plugin_Handled;
}

public Action Command_StateAlign(int client, int args) {
    int actualClient = IsValidClient(client);
    if (actualClient == 0) {
        return Plugin_Handled;
    }

    if (args < 2) {
        PrintToChat(actualClient, "[SM] Usage: sm_state_align <variable> <left|center|right>");
        return Plugin_Handled;
    }

    char variableName[MAX_VARIABLE_NAME];
    GetCmdArg(1, variableName, sizeof(variableName));

    char alignStr[16];
    GetCmdArg(2, alignStr, sizeof(alignStr));

    int varIndex = FindVariableIndex(actualClient, variableName);
    if (varIndex == -1) {
        PrintToChat(actualClient, "[SM] Variable '%s' not found.", variableName);
        return Plugin_Handled;
    }

    if (StrEqual(alignStr, "left", false)) {
        g_Variables[actualClient][varIndex].alignment = ALIGN_LEFT;
    } else if (StrEqual(alignStr, "center", false)) {
        g_Variables[actualClient][varIndex].alignment = ALIGN_CENTER;
    } else if (StrEqual(alignStr, "right", false)) {
        g_Variables[actualClient][varIndex].alignment = ALIGN_RIGHT;
    } else {
        PrintToChat(actualClient, "[SM] Unknown alignment '%s'.", alignStr);
        return Plugin_Handled;
    }

    g_Variables[actualClient][varIndex].lastValue[0] = '\0';
    UpdateHUD(actualClient);
    SaveClientVariables(actualClient);
    PrintToChat(actualClient, "[SM] Variable '%s' alignment set to %s.", variableName, GetAlignmentName(g_Variables[actualClient][varIndex].alignment));

    return Plugin_Handled;
}

public Action Command_StatePosition(int client, int args) {
    int actualClient = IsValidClient(client);
    if (actualClient == 0) {
        return Plugin_Handled;
    }

    if (args < 1) {
        PrintToChat(actualClient, "[SM] Usage: sm_state_position <variable>");
        return Plugin_Handled;
    }

    char variableName[MAX_VARIABLE_NAME];
    GetCmdArg(1, variableName, sizeof(variableName));

    int varIndex = FindVariableIndex(actualClient, variableName);
    if (varIndex == -1) {
        PrintToChat(actualClient, "[SM] Variable '%s' not found.", variableName);
        return Plugin_Handled;
    }

    PrintToChat(actualClient, "[SM] sm_state_move %s %.2f %.2f",
        variableName, g_Variables[actualClient][varIndex].x, g_Variables[actualClient][varIndex].y);

    return Plugin_Handled;
}

public Action Command_ChatTrigger(int client, const char[] command, int args) {
    if (client == 0) return Plugin_Continue;

    char text[32];
    GetCmdArgString(text, sizeof(text));
    StripQuotes(text);
    TrimString(text);

    if (StrEqual(text, "!states", false)) {
        int actualClient = IsValidClient(client);
        if (actualClient == 0) {
            return Plugin_Handled;
        }

        if (g_ClientData[actualClient].variableCount == 0) {
            PrintToChat(actualClient, "[SM] No variables to manage. Use sm_stateset to add some first.");
            return Plugin_Handled;
        }

        ShowVariableMenu(actualClient);
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action Command_StateMenu(int client, int args) {
    int actualClient = IsValidClient(client);
    if (actualClient == 0) {
        return Plugin_Handled;
    }

    if (g_ClientData[actualClient].variableCount == 0) {
        PrintToChat(actualClient, "[SM] No variables to manage. Use sm_stateset to add some first.");
        return Plugin_Handled;
    }

    ShowVariableMenu(actualClient);
    return Plugin_Handled;
}

// cleanup
public void OnPluginEnd() {
    for (int cl = 1; cl <= MaxClients; cl++) {
        if (IsClientInGame(cl)) {
            for (int i = 0; i < g_ClientData[cl].variableCount; i++) {
                if (g_Variables[cl][i].hudSync != null) {
                    CloseHandle(g_Variables[cl][i].hudSync);
                    g_Variables[cl][i].hudSync = null;
                }
            }
        }
    }
    PrintToServer("[%s] Plugin unloaded.", PLUGIN_NAME);
}
