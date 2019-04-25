/*
 * shavit's Timer - Playertime Recorder
 * by: whocodes
 *
 * This file is NOT part of shavit's timer.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.	See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.	If not, see <http://www.gnu.org/licenses/>.
 *
*/

#include <sourcemod>
#include <shavit>

#pragma newdecls required
#pragma semicolon 1


int g_iTime[MAXPLAYERS+1];
float g_fJoinTime[MAXPLAYERS+1];


Database g_hSQL = null;
char gS_MySQLPrefix[32];

bool g_bStats = false;
ConVar g_CVPlaytimeLimit = null;


public Plugin myinfo = {
	name = "[shavit] Playtime Recorder",
	author = "whocodes",
	description = "Playtime recorder for shavit's timer.",
	version = "1.0.4",
	url = "https://github.com/whocodes/shavit-playtime"
}

public void OnAllPluginsLoaded(){
	if(!LibraryExists("shavit"))
		SetFailState("shavit-core is required for the plugin to work.");

	if(g_hSQL == null)
		Shavit_OnDatabaseLoaded();

	g_bStats = LibraryExists("shavit-stats");
}

public void OnPluginStart(){
	RegConsoleCmd("sm_playtime", Command_Playtime, "Shows the playtime for all users, or a specific user (if arguments provided). Usage: sm_playtime [target]");

	g_CVPlaytimeLimit = CreateConVar("shavit_playtime_limit", "100", "Sets the limit of user playtimes to retrieve for sm_playtime", 0, true, 1.0, false);

	LoadTranslations("shavit-playtime.phrases");
}

public void Shavit_OnDatabaseLoaded(){
	g_hSQL = Shavit_GetDatabase();
	FormatEx(gS_MySQLPrefix, 32, "");
}

public void OnClientPutInServer(int client){
	g_fJoinTime[client] = GetEngineTime();

	if((client == 0) || !IsClientConnected(client) || IsFakeClient(client) || g_hSQL == null)
		return;

	UpdateClientCache(client);
}

void UpdateClientCache(int client){
	char sAuthID[32];
	GetClientAuthId(client, AuthId_Steam3, sAuthID, 32);

	char sQuery[256];
	FormatEx(sQuery, 256, "SELECT playtime FROM %susers WHERE auth = '%s';", gS_MySQLPrefix, sAuthID);
	g_hSQL.Query(SQL_UpdateCache_Callback, sQuery, GetClientSerial(client), DBPrio_High);
}

public void SQL_UpdateCache_Callback(Database db, DBResultSet results, const char[] error, any data){
	if(results == null){
		LogError("[shavit-playtime] Failed to load player time 1; Reason: %s", error);
		return;
	}

	int client = GetClientFromSerial(data);

	if((client == 0) || !IsClientConnected(client))
		return;

	if(!results.FetchRow())
		return;

	g_iTime[client] = results.FetchInt(0);

	return;
}

public void OnClientDisconnect(int client){
	if((client == 0) || !IsClientConnected(client) || IsFakeClient(client) || g_hSQL == null)
		return;

	char sAuthID[32];
	GetClientAuthId(client, AuthId_Steam3, sAuthID, 32);

	char sQuery[256];
	FormatEx(sQuery, 256, "UPDATE %susers SET playtime = playtime + %d WHERE auth='%s';",
		gS_MySQLPrefix,
		RoundToFloor(GetEngineTime() - g_fJoinTime[client]),
		sAuthID);
	g_hSQL.Query(SQL_UpdatePlayTime_Callback, sQuery, GetClientSerial(client), DBPrio_High);
}

public void SQL_UpdatePlayTime_Callback(Database db, DBResultSet results, const char[] error, any data){
	if(results == null){
		LogError("[shavit-playtime] Failed to update player time 1; Reason: %s", error);
		return;
	}
}


public Action Command_Playtime(int client, int args){
	if((client == 0) || !IsClientConnected(client) || IsFakeClient(client) || g_hSQL == null)
		return Plugin_Handled;

	char sQuery[256];
	if(args == 0){
		FormatEx(sQuery, 256, "SELECT playtime, name, auth FROM %susers LIMIT 0, %d;", gS_MySQLPrefix, g_CVPlaytimeLimit.IntValue);
	}else{
		char sArgs[64];
		GetCmdArgString(sArgs, 64);


		int target = FindTarget(client, sArgs, true, false);

		if((target == 0) || !IsClientConnected(target)){
			Shavit_PrintToChat(client, "%T", "PlaytimeNotFound", client, sArgs);
			return Plugin_Handled;
		}


		char sAuthID[32];
		GetClientAuthId(target, AuthId_Steam3, sAuthID, 32);

		FormatEx(sQuery, 256, "SELECT playtime, name, auth FROM %susers WHERE auth = '%s' LIMIT 0, 100;",
			gS_MySQLPrefix,
			sAuthID);
	}

	Shavit_PrintToChat(client, "%T", "LoadingPlaytime", client);
	g_hSQL.Query(SQL_Command_PlayTime_Callback, sQuery, GetClientSerial(client), DBPrio_High);

	return Plugin_Handled;
}

public void SQL_Command_PlayTime_Callback(Database db, DBResultSet results, const char[] error, any data){
	if(results == null){
		LogError("[shavit-playtime] Failed to display playtime 1; Reason: %s", error);
		return;
	}

	int client = GetClientFromSerial(data);
	char sName[MAX_NAME_LENGTH];
	char sAuthID[32];
	int playtime;
	char sPlayTime[64];

	if(results.RowCount == 1){
		if(!results.FetchRow()){
			LogError("[shavit-playtime] Failed to display playtime 2; results.FetchRow() returned false");
			return;
		}

		playtime = results.FetchInt(0);

		results.FetchString(1, sName, MAX_NAME_LENGTH);
		results.FetchString(2, sAuthID, 32);
		FormatSeconds(float(playtime), sPlayTime, 64, false);

		Shavit_PrintToChat(client, "%T", "UserHasPlayedFor", client, sName, sAuthID, sPlayTime);
	}else{
		Menu menu = new Menu(MenuHandler_PlayTime);
		FormatSeconds(float(g_iTime[client]), sPlayTime, 64, false);
		menu.SetTitle("%T\n%T", "UserPlaytimes", client, "YourPlayTime", client, sPlayTime);


		while(results.FetchRow()){
			char sMenuItem[128];

			playtime = results.FetchInt(0);
			results.FetchString(1, sName, MAX_NAME_LENGTH);
			results.FetchString(2, sAuthID, 32);

			FormatSeconds(float(playtime), sPlayTime, 64, false);
			FormatEx(sMenuItem, 128, "%s (%s)", sName, sPlayTime);


			menu.AddItem(sAuthID, sMenuItem, (g_bStats ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED));
		}

		menu.ExitButton = true;
		menu.Display(client, 60);
	}

	return;
}

public int MenuHandler_PlayTime(Menu menu, MenuAction action, int param1, int param2){
	if(action == MenuAction_Select){
		if(!g_bStats)
			return 0;

		char sAuthID[32];
		menu.GetItem(param2, sAuthID, 32);

		Shavit_OpenStatsMenu(param1, sAuthID);
	}else if(action == MenuAction_End){
		delete menu;
	}

	return 0;
}
