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
    pGrana          // Grana (dinheiro) do jogador
};

// Array que armazena os dados dos jogadores em runtime
new player[MAX_PLAYERS][PlayerDados];

// TextDraws para a tela de login personalizada
new Text:tdBackground[MAX_PLAYERS];
new Text:tdHeader[MAX_PLAYERS];
// "tdInfo" e "tdButton" não são mais utilizados após a atualização do layout

// Para layout inspirado em formulário (campos e botões)
new Text:tdLabelLogin[MAX_PLAYERS];
new Text:tdLabelSenha[MAX_PLAYERS];
new Text:tdBoxLogin[MAX_PLAYERS];
new Text:tdBoxSenha[MAX_PLAYERS];
new Text:tdButtonEnter[MAX_PLAYERS];
new Text:tdButtonClear[MAX_PLAYERS];

// Guarda se o jogador possui conta (usado na tela de login)
new bool:playerHasAccount[MAX_PLAYERS];

// Definições de cores (RGBA) para mensagens enviadas pelo servidor
#define COLOR_RED  0xFF0000FF
#define COLOR_BLUE 0x0000FFFF
#define COLOR_GRAY 0x808080FF
#define COLOR_WHITE 0xFFFFFFFF

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
    SetGameModeText("GM com Login");

    // Garante que a tabela de jogadores exista
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
    // Define se o jogador possui conta e mostra a tela de login personalizada
    playerHasAccount[playerid] = (cache_num_rows() > 0);
    ShowLoginScreen(playerid);
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
    /*
        Esta versão desenha uma interface parecida com um formulário
        web, inspirada na imagem de referência fornecida pelo usuário.
        São utilizados vários TextDraws: um plano de fundo escuro,
        um título "Login", duas caixas brancas representando os campos
        de usuário e senha (apenas decorativas, pois a entrada real
        ainda será feita via diálogos) e dois botões: um para entrar
        (ou registrar) e outro para limpar.
    */
    // Fundo cinza escuro cobrindo a tela
    tdBackground[playerid] = TextDrawCreate(0.0, 0.0, "_");
    TextDrawLetterSize(tdBackground[playerid], 0.0, 40.0);
    TextDrawUseBox(tdBackground[playerid], true);
    TextDrawBoxColor(tdBackground[playerid], 0x222222DD); // cinza escuro semi-transparente
    TextDrawColor(tdBackground[playerid], COLOR_WHITE);
    TextDrawShowForPlayer(playerid, tdBackground[playerid]);

    // Título "Login" no topo
    tdHeader[playerid] = TextDrawCreate(320.0, 80.0, "Login");
    TextDrawAlignment(tdHeader[playerid], 2);
    TextDrawFont(tdHeader[playerid], 2);
    TextDrawLetterSize(tdHeader[playerid], 0.6, 2.2);
    TextDrawColor(tdHeader[playerid], COLOR_WHITE);
    TextDrawShowForPlayer(playerid, tdHeader[playerid]);

    // Rótulo "Login:"
    tdLabelLogin[playerid] = TextDrawCreate(180.0, 160.0, "Login:");
    TextDrawAlignment(tdLabelLogin[playerid], 1);
    TextDrawFont(tdLabelLogin[playerid], 1);
    TextDrawLetterSize(tdLabelLogin[playerid], 0.3, 1.0);
    TextDrawColor(tdLabelLogin[playerid], COLOR_WHITE);
    TextDrawShowForPlayer(playerid, tdLabelLogin[playerid]);

    // Caixa de login como retângulo branco
    tdBoxLogin[playerid] = TextDrawCreate(260.0, 185.0, " ");
    TextDrawUseBox(tdBoxLogin[playerid], true);
    // Define as coordenadas finais (x2, y2) para largura e altura do campo
    TextDrawTextSize(tdBoxLogin[playerid], 460.0, 210.0);
    TextDrawBoxColor(tdBoxLogin[playerid], 0xF5F5F5FF);
    TextDrawColor(tdBoxLogin[playerid], COLOR_WHITE);
    TextDrawShowForPlayer(playerid, tdBoxLogin[playerid]);

    // Rótulo "Senha:"
    tdLabelSenha[playerid] = TextDrawCreate(180.0, 230.0, "Senha:");
    TextDrawAlignment(tdLabelSenha[playerid], 1);
    TextDrawFont(tdLabelSenha[playerid], 1);
    TextDrawLetterSize(tdLabelSenha[playerid], 0.3, 1.0);
    TextDrawColor(tdLabelSenha[playerid], COLOR_WHITE);
    TextDrawShowForPlayer(playerid, tdLabelSenha[playerid]);

    // Caixa de senha como retângulo branco
    tdBoxSenha[playerid] = TextDrawCreate(260.0, 245.0, " ");
    TextDrawUseBox(tdBoxSenha[playerid], true);
    TextDrawTextSize(tdBoxSenha[playerid], 460.0, 270.0);
    TextDrawBoxColor(tdBoxSenha[playerid], 0xF5F5F5FF);
    TextDrawColor(tdBoxSenha[playerid], COLOR_WHITE);
    TextDrawShowForPlayer(playerid, tdBoxSenha[playerid]);

    // Texto do botão Entrar/Registrar (verde) dependendo se o jogador possui conta
    new btnText[16];
    if (playerHasAccount[playerid])
    {
        format(btnText, sizeof btnText, "Entrar");
    }
    else
    {
        format(btnText, sizeof btnText, "Registrar");
    }
    tdButtonEnter[playerid] = TextDrawCreate(250.0, 330.0, btnText);
    TextDrawAlignment(tdButtonEnter[playerid], 2);
    TextDrawFont(tdButtonEnter[playerid], 1);
    TextDrawLetterSize(tdButtonEnter[playerid], 0.4, 1.6);
    TextDrawUseBox(tdButtonEnter[playerid], true);
    // Largura do botão verde
    TextDrawTextSize(tdButtonEnter[playerid], 140.0, 0.0);
    TextDrawBoxColor(tdButtonEnter[playerid], 0x008000FF); // verde
    TextDrawColor(tdButtonEnter[playerid], COLOR_WHITE);
    TextDrawSetSelectable(tdButtonEnter[playerid], true);
    TextDrawShowForPlayer(playerid, tdButtonEnter[playerid]);

    // Texto do botão Limpar (cinza)
    tdButtonClear[playerid] = TextDrawCreate(390.0, 330.0, "Limpar");
    TextDrawAlignment(tdButtonClear[playerid], 2);
    TextDrawFont(tdButtonClear[playerid], 1);
    TextDrawLetterSize(tdButtonClear[playerid], 0.4, 1.6);
    TextDrawUseBox(tdButtonClear[playerid], true);
    TextDrawTextSize(tdButtonClear[playerid], 140.0, 0.0);
    TextDrawBoxColor(tdButtonClear[playerid], 0x666666FF); // cinza para limpar
    TextDrawColor(tdButtonClear[playerid], COLOR_WHITE);
    TextDrawSetSelectable(tdButtonClear[playerid], true);
    TextDrawShowForPlayer(playerid, tdButtonClear[playerid]);

    // Permite que botões sejam clicáveis
    SelectTextDraw(playerid, COLOR_WHITE);
    return 1;
}

/*
    Esconde e destrói todos os TextDraws da tela de login para um
    jogador específico. Deve ser chamado após o jogador clicar no
    botão para abrir a caixa de diálogo de login/registro.
*/
stock HideLoginScreen(playerid)
{
    // Cancela modo de seleção
    CancelSelectTextDraw(playerid);
    // Esconde e destrói textdraws se existirem
    TextDrawHideForPlayer(playerid, tdBackground[playerid]);
    TextDrawHideForPlayer(playerid, tdHeader[playerid]);
    TextDrawHideForPlayer(playerid, tdLabelLogin[playerid]);
    TextDrawHideForPlayer(playerid, tdLabelSenha[playerid]);
    TextDrawHideForPlayer(playerid, tdBoxLogin[playerid]);
    TextDrawHideForPlayer(playerid, tdBoxSenha[playerid]);
    TextDrawHideForPlayer(playerid, tdButtonEnter[playerid]);
    TextDrawHideForPlayer(playerid, tdButtonClear[playerid]);

    TextDrawDestroy(tdBackground[playerid]);
    TextDrawDestroy(tdHeader[playerid]);
    TextDrawDestroy(tdLabelLogin[playerid]);
    TextDrawDestroy(tdLabelSenha[playerid]);
    TextDrawDestroy(tdBoxLogin[playerid]);
    TextDrawDestroy(tdBoxSenha[playerid]);
    TextDrawDestroy(tdButtonEnter[playerid]);
    TextDrawDestroy(tdButtonClear[playerid]);
    return 1;
}

/*
    Chamado quando um jogador se desconecta. Se ele estiver logado,
    persiste as informações no banco de dados.
*/
public OnPlayerDisconnect(playerid, reason)
{
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

/*
    Comando simples de teste: /bixera envia uma mensagem ao jogador. Outro
    comando /dararma dá ao jogador uma submetralhadora com munição. Os
    comandos são executados apenas se o jogador estiver logado.
*/
public OnPlayerCommandText(playerid, cmdtext[])
{
    if (!logado[playerid])
    {
        SendClientMessage(playerid, COLOR_GRAY, "Voce precisa estar logado para usar comandos.");
        return 1;
    }
    if (strcmp("/bixera", cmdtext, true, 10) == 0)
    {
        SendClientMessage(playerid, COLOR_BLUE, "ja era");
        return 1;
    }
    if (strcmp("/dararma", cmdtext, true, 10) == 0)
    {
        SendClientMessage(playerid, COLOR_BLUE, "arminha");
        GivePlayerWeapon(playerid, 28, 999);
        return 1;
    }
    return SendClientMessage(playerid, COLOR_GRAY, "Comando inexistente.");
}

/*
    Funções padrão de callback que não realizam nenhuma ação personalizada.
    Permanecem aqui para manter compatibilidade com o gamemode base.
*/
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
    // Verifica se o jogador clicou em um dos botões da tela de login
    if (clickedid == tdButtonEnter[playerid])
    {
        // Esconde a tela de login personalizada
        HideLoginScreen(playerid);
        // Exibe o diálogo correspondente ao estado do jogador
        if (playerHasAccount[playerid])
        {
            // Jogador já possui conta: pede a senha
            ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD,
                COR_VERMELHO "Cidade Alerta:" COR_BRANCO,
                COR_CINZA "Insira sua senha para acessar a conta:",
                "Entrar", "Sair");
        }
        else
        {
            // Jogador ainda não possui conta: cria nova conta
            ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD,
                COR_VERMELHO "Cidade Alerta:" COR_BRANCO,
                COR_CINZA "Crie uma senha para registrar sua conta:",
                "Registrar", "Sair");
        }
        return 1;
    }
    // Botão "Limpar" apenas redesenha a tela de login, sem modificar dados
    if (clickedid == tdButtonClear[playerid])
    {
        HideLoginScreen(playerid);
        ShowLoginScreen(playerid);
        return 1;
    }
    return 0;
}