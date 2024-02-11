# Save_Attribute
Сохранение денег/фрагов/смертей при выходе с сервера


Файл настроек создатся автоматически по пути /cfg/sourcemod/SaveAttribute.cfg

Список переменных:
```C#
// Включить/Выключить установку денег
// -
sm_saveattribute_cash "1"

// Включить/Выключить установку смертей
// -
sm_saveattribute_deaths "1"

// Через сколько секунд будут выданы деньги игроку при заходе за команду Т/КТ
// -
sm_saveattribute_delayed "0.1"

// Включить/Выключить плагин
// -
sm_saveattribute_enable "1"

// Включить/Выключить установку фрагов
// -
sm_saveattribute_frags "1"

// Проверять базу данных каждые N секунд (для удаления истёкших)
// -
sm_saveattribute_time_check "10.0"

// Через сколько секунд плагин удалит вышедшего игрока из памяти
// -
sm_saveattribute_time_out "300"
```

База данных создаётся автоматически по пути /cstrike/addons/sourcemod/data/sqlite/SaveAttribute.sq3

Требования Sourcemod 1.10 и выше
