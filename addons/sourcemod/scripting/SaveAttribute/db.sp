void Custom_SQLite()
{
	KeyValues hKv = new KeyValues("");
	hKv.SetString("driver", "sqlite");
	hKv.SetString("host", "localhost");
	hKv.SetString("database", "SaveAttribute");
	hKv.SetString("user", "root");
	hKv.SetString("pass", "");
	
	char sError[255];
	hDatabase = SQL_ConnectCustom(hKv, sError, sizeof(sError), true);

	if(sError[0])
	{
		SetFailState("Ошибка подключения к локальной базе SQLite: %s", sError);
	}
	hKv.Close();

	First_ConnectionSQLite();
}

void First_ConnectionSQLite()
{
	SQL_LockDatabase(hDatabase);
	char sQuery[1024];
	Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `save_attribute` (\
		`id` INTEGER PRIMARY KEY,\
		`steam_id` VARCHAR(32),\
		'cash' INTEGER(5),\
		'frags' INTEGER(4),\
		'deaths' INTEGER(4),\
		`time_out` INTEGER(15))");

	hDatabase.Query(First_ConnectionSQLite_Callback, sQuery);

	SQL_UnlockDatabase(hDatabase);
	hDatabase.SetCharset("utf8");
}

public void First_ConnectionSQLite_Callback(Database hDb, DBResultSet results, const char[] sError, any iUserID)
{
	if (hDb == null || sError[0])
	{
		SetFailState("[First_Connection] Ошибка подключения к базе: %s", sError);
		return;
	}
}

Action Timer_CheckClientOut(Handle hTimer)
{
	if(!cvEnable.BoolValue)
		return Plugin_Continue;

	char sQuery[RequestLength];
	FormatEx(sQuery, sizeof(sQuery), "SELECT `id`, `time_out` FROM `save_attribute`");
	hDatabase.Query(CheckClient_Callback, sQuery, false);

	return Plugin_Continue;
}

public void DisconnectClient_Callback(Database hDb, DBResultSet hResults, const char[] sError, DataPack hPack)
{
	if (hDb == null || sError[0])
	{
		SetFailState("[DisconnectClient_Callback] Ошибка подключения к базе: %s", sError);
		return;
	}

	hPack.Reset();
	char sSteam[32];
    hPack.ReadString(sSteam, sizeof(sSteam));
	int iCash = hPack.ReadCell();
	int iFrags = hPack.ReadCell();
	int iDeaths = hPack.ReadCell();
	int iDisTime = hPack.ReadCell();
	char sName[42];
    hPack.ReadString(sName, sizeof(sName));
	delete hPack;

	char sQuery[RequestLength];

	if(hResults.FetchRow())
	{
		FormatEx(sQuery, sizeof(sQuery), "UPDATE `save_attribute` SET\
		`cash` = '%d',\
		`frags` = '%d',\
		`deaths` = '%d',\
		`time_out` = '%d'\
		WHERE `steam_id` = '%s';",
		iCash, iFrags, iDeaths, iDisTime, sSteam);
		hDatabase.Query(ClietnEditData_Callback, sQuery);
	}
	else
	{
		FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `save_attribute`\
		(`steam_id`, `cash`, `frags`, `deaths`, `time_out`)\
		 VALUES ( '%s', '%d', '%d', '%d', '%d');",
		sSteam, iCash, iFrags, iDeaths, iDisTime);
		hDatabase.Query(ClietnEditData_Callback, sQuery);
	}
}

public void ClietnEditData_Callback(Database hDb, DBResultSet results, const char[] sError, any iUserID)
{
	if (hDb == null || sError[0])
	{
		SetFailState("[ClietnEditData_Callback] Ошибка подключения к базе: %s", sError);
		return;
	}
}

public void ConnectClient_Callback(Database hDb, DBResultSet hResults, const char[] sError, any iUserID)
{
	if (hDb == null || sError[0])
	{
		SetFailState("[ConnectClient_Callback] Ошибка подключения к базе: %s", sError);
		return;
	}

	int client = GetClientOfUserId(iUserID);

	if(!IsValidClient(client))
		return;

	if(hResults.FetchRow())
	{
		Attribute[client].iCash = hResults.FetchInt(0);
		Attribute[client].iFrags = hResults.FetchInt(1);
		Attribute[client].iDeaths = hResults.FetchInt(2);
		Attribute[client].iDisTime = hResults.FetchInt(3);

		if(cvAttributeEnable[0].BoolValue)
			SetEntData(client, m_iAccount, Attribute[client].iCash, _, true);

		if(cvAttributeEnable[1].BoolValue)
			SetEntProp(client, Prop_Data, "m_iFrags", Attribute[client].iFrags);

		if(cvAttributeEnable[2].BoolValue)
			SetEntProp(client, Prop_Data, "m_iDeaths", Attribute[client].iDeaths);
	}
}

public void CheckClient_Callback(Database hDb, DBResultSet hResults, const char[] sError, any End)
{
	if (hDb == null || sError[0])
	{
		SetFailState("[CheckClient_Callback] Ошибка подключения к базе: %s", sError);
		return;
	}

	int iRows = hResults.RowCount;		//Строки
	//LogToFile(sFile, "Строк -> [%d]", iRows);

	if(!iRows)
		return;

	//int iFields = hResults.FieldCount;		//Поля
	//LogToFile(sFile, "Полей -> [%d]", iFields);

	while(hResults.FetchRow())
	{
		if(!End)
		{
			int time = hResults.FetchInt(1);

			if(time + cvTimeOut.IntValue <= GetTime())
			{
				DeleteData(hResults.FetchInt(0));
			}
		}
		else
		{
			DeleteData(hResults.FetchInt(0));
		}
	}
}

void DeleteData(int id)
{
	char sQuery[RequestLength];
	FormatEx(sQuery, sizeof(sQuery), "DELETE FROM `save_attribute` WHERE id = '%d'", id);
	hDatabase.Query(Delete_Callback, sQuery);
}

public void Delete_Callback(Database hDb, DBResultSet hResults, const char[] sError, any Data)
{
	if (hDb == null || sError[0])
	{
		SetFailState("[Delete_Callback] Ошибка подключения к базе: %s", sError);
		return;
	}
}