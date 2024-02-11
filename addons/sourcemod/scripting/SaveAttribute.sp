#pragma semicolon 1
#pragma newdecls required

Database
	hDatabase;

Handle
	hTimerCheck;

ConVar
	cvEnable,
	cvTimeOut,
	cvDelayed,
	cvTimeCheck,
	cvAttributeEnable[3];

int
	m_iAccount = -1;

char
	sFile[PLATFORM_MAX_PATH];

#define RequestLength 512

enum struct ClientData
{
	char sSteam[32];
	int iCash;
	int iFrags;
	int iDeaths;
	int iDisTime;
}

ClientData Attribute[MAXPLAYERS+1];

#include "SaveAttribute/db.sp"

public Plugin myinfo = 
{
	name = "[Any] Save Attribute",
	author = "Nek.'a 2x2 | ggwp.site ",
	description = "Сохранение денег/фрагов/смертей при выходе с сервера",
	version = "1.0.0",
	url = "https://ggwp.site/"
};

public APLRes AskPluginLoad2()
{
	m_iAccount = FindSendPropInfo("CCSPlayer", "m_iAccount");
	if (m_iAccount < 1)
	{
		SetFailState("Couldnt find the m_iAccount offset!");
	}
		
	return APLRes_Success;
}

public void OnPluginStart()
{
	cvEnable = CreateConVar("sm_saveattribute_enable", "1", "Включить/Выключить плагин", _, true, _, true, 1.0);

	cvTimeOut = CreateConVar("sm_saveattribute_time_out", "300", "Через сколько секунд плагин удалит вышедшего игрока из памяти", _, true, 0.0, true, 99999.0);

	cvDelayed = CreateConVar("sm_saveattribute_delayed", "0.1", "Через сколько секунд будут выданы деньги игроку при заходе за команду Т/КТ", _, true, 0.0, true, 60.0);

	cvTimeCheck = CreateConVar("sm_saveattribute_time_check", "10.0", "Проверять базу данных каждые N секунд (для удаления истёкших)", _, true, 0.0, true, 9999.0);

	cvAttributeEnable[0] = CreateConVar("sm_saveattribute_cash", "1", "Включить/Выключить установку денег", _, true, _, true, 1.0);

	cvAttributeEnable[1] = CreateConVar("sm_saveattribute_frags", "1", "Включить/Выключить установку фрагов", _, true, _, true, 1.0);

	cvAttributeEnable[2] = CreateConVar("sm_saveattribute_deaths", "1", "Включить/Выключить установку смертей", _, true, _, true, 1.0);

	AddCommandListener(Command_JoinTeam, "jointeam");

	HookConVarChange(FindConVar("mp_restartgame"), CheckCvar);

	HookEvent("player_disconnect", Event_Disconnect, EventHookMode_Pre);

	BuildPath(Path_SM, sFile, sizeof(sFile), "logs/save_attribute.log");

	AutoExecConfig(true, "SaveAttribute");
}

public void OnConfigsExecuted()
{
	Custom_SQLite();
	hTimerCheck = CreateTimer(cvTimeCheck.FloatValue, Timer_CheckClientOut, _, TIMER_REPEAT);
}

public void OnMapEnd()
{
    delete hTimerCheck;
}

public void OnMapStart()
{
	ResetData();
}

void CheckCvar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(!cvEnable.BoolValue || !StringToInt(newValue))
		return;
	
	float fTime = StringToFloat(newValue);

	if(fTime >= 1.0)
	{
		CreateTimer(StringToFloat(newValue) - 1.0, Timer_ResetAttribute);
	}
	else if(fTime <= 1.0)
	{
		CreateTimer(StringToFloat(newValue) - 0.3, Timer_ResetAttribute);
	}
}

Action Timer_ResetAttribute(Handle hTimer)
{
	ResetData();
	return Plugin_Stop;
}

void ResetData()
{
	char sQuery[RequestLength];
	FormatEx(sQuery, sizeof(sQuery), "SELECT `id`, `time_out` FROM `save_attribute`");
	hDatabase.Query(CheckClient_Callback, sQuery, true);
}

public void OnClientPostAdminCheck(int client)
{
	if(!cvEnable.BoolValue)
		return;

	if(!IsValidClient(client))
		return;

	char sSteam[32];
	GetClientAuthId(client, AuthId_Steam2, sSteam, sizeof(sSteam));
	Attribute[client].sSteam = sSteam;

	char sQuery[RequestLength];
	FormatEx(sQuery, sizeof(sQuery), "SELECT `cash`, `frags`, `deaths`, `time_out` FROM `save_attribute` WHERE `steam_id` = '%s'", Attribute[client].sSteam);
	hDatabase.Query(ConnectClient_Callback, sQuery, GetClientUserId(client));
}

void Event_Disconnect(Event hEvent, const char[] name, bool dontBroadcast)
{
	if(!cvEnable.BoolValue)
		return;

	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if(!IsValidClient(client))
		return;

	GetAttribute(client);

	char sName[42];
	GetClientName(client, sName, sizeof(sName));

	DataPack hPack = new DataPack();
	hPack.WriteString(Attribute[client].sSteam);
	hPack.WriteCell(Attribute[client].iCash);
	hPack.WriteCell(Attribute[client].iFrags);
	hPack.WriteCell(Attribute[client].iDeaths);
	hPack.WriteCell(Attribute[client].iDisTime);
	hPack.WriteString(sName);

	char sQuery[RequestLength];
	FormatEx(sQuery, sizeof(sQuery), "SELECT `steam_id` FROM `save_attribute` WHERE `steam_id` = '%s'", Attribute[client].sSteam);
	hDatabase.Query(DisconnectClient_Callback, sQuery, hPack);
}

Action Command_JoinTeam(int client, char[] sCommand, int args)
{
	if(!cvEnable.BoolValue)
		return Plugin_Continue;

	char sArg[8];
	GetCmdArg(1, sArg, sizeof(sArg));
	int iNewTeam = StringToInt(sArg);
	int iOldTeam = GetClientTeam(client);

	if(iOldTeam > 1 && iNewTeam < 2)	//При переходе из T/CT в спектора
	{
		Attribute[client].iCash = GetClientMoney(client);
	}
	else if(iOldTeam < 2 && iNewTeam > 1 && Attribute[client].iCash)	//При переходе из спекторов в игру
	{
		CreateTimer(cvDelayed.FloatValue, Timer_SetClientMoney, client);
	}
	
	return Plugin_Changed;
}

Action Timer_SetClientMoney(Handle hTimer, int client)
{
	SetEntData(client, m_iAccount, Attribute[client].iCash, _, true);

	return Plugin_Stop;
}

stock int GetClientMoney(int client)
{
	if(IsValidClient(client))
		return GetEntData(client, m_iAccount, 4);
	else
		return -1;
}

bool IsValidClient(int client)
{
	return 0 < client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client);
}

stock void GetAttribute(int client)
{
	Attribute[client].iCash = GetClientMoney(client);
	Attribute[client].iFrags = GetEntProp(client, Prop_Data, "m_iFrags");
	Attribute[client].iDeaths = GetEntProp(client, Prop_Data, "m_iDeaths");
	Attribute[client].iDisTime = GetTime();
}