//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//Cuff Command Interpreter

//=============================================================================
//== OC Cuff - Command forwarder to listen for commands in OpenCollar
//== receives messages from linkmessages send within the collar
//== sends the needed commands out to the cuffs
//=============================================================================

// entry for main menu
string g_sParentmenu = "Main";
string g_sMenuEntry = " Collar Menu";

//MESSAGE MAP Collar Scripts
integer CMD_NOAUTH = 0;
integer CMD_OWNER = 500;
//integer CMD_TRUST = 501;
//integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
//integer CMD_EVERYONE = 504;

integer CMD_SAFEWORD = 510;

integer LM_SETTING_SAVE = 2000;
integer LM_SETTING_REQUEST = 2001;
integer LM_SETTING_RESPONSE = 2002;
integer LM_SETTING_DELETE = 2003;
//integer LM_SETTING_EMPTY = 2004;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;

integer RLV_REFRESH = 6001;
integer RLV_OFF = 6100;
integer RLV_ON = 6101;

// Message Mapper Cuff Communication
integer LM_CUFF_CMD  = -551001;
//integer LM_CUFF_ANIM = -551002;
integer LM_CUFF_CUFFPOINTNAME = -551003;
integer LM_CUFF_SEND = -555000;


// Commands to be send from the collar
string g_sRequestCollarInfo = "OpenCollar_RequestSettings"; // command for the collar
string g_sCollarMenu = "OpenCollar_ShowMenu"; // command for the collar to show the menu

string g_sCuffMenuCmd = "MENU";
string g_sRLVChangeCmd = "RLV";
string g_sOwnerChangeCmd = "AUTH";
string g_sColorChangeCmd = "COLOR";
string g_sTextureChangeCmd = "TEXTURE";
string g_sShineChangeCmd = "SHINE";

string g_sLockCMD = "LOCK";
string g_sUnLockCMD = "UNLOCK";
string g_sShowCmd = "SHOW";
string g_sHideCmd = "HIDE";

string g_sInfoRequest = "SendLockInfo"; // request info about RLV and Lock status from main cuff

string g_sOwnerToken = "owner";
string g_sLockToken = "locked";
string g_sRLVToken = "rlvon";
string g_sAutoLockToken = "autolock";

string g_sSubOwnerMsg = "Owners";
string g_sLockCmd = "Lock";
string g_sAutoLockCmd = "AutoLock";
//string g_sResetScripts = "resetscripts";

string g_sModToken = "rlac"; // valid token for this module, should be mabye requested by LM to be more independent
list g_lExtPrefix = ["occ","ruac","rlac","luac","llac","rulc","rllc","lulc","lllc","ocbelt","chest","ocpants"];
list g_lModTokens = ["rlac"]; // valid token for this module



float g_fStartTime = 3;
integer g_iStarted = FALSE;
integer g_iResend = FALSE;

integer g_iCollarBackchannel = -1812221819; // channel for sending back owner changes to the collar
integer g_iLockGuardChannel = -9119;

integer g_iCmdChannel = -190890;
integer g_iCmdChannelOffset = 0xCC0CC; // offset to be used to make sure we do not interfere with other items using the same technique for
integer g_iCuffChannel = -190889;   // cuff channel // used for LG chains from the cuffs


key g_kWearer; // wearer(owner of the cuf for saving script time

string g_sSubOwners ; // stores the owner of the sub

integer g_iAutoLock; // are the cuffs logged
integer g_iLocked; // are the cuffs logged
integer g_iUseRLV = FALSE; // is RLV to be used
integer g_iCuffs_Visible = TRUE; // visiblity value of the cuffs


SendToCollar(string sStr, key kID) {
    llRegionSayTo(g_kWearer, g_iCmdChannel, sStr+"="+(string)kID);
}

SendCuffCmd(string sStr) {
    if (sStr) llRegionSayTo(g_kWearer, g_iCuffChannel, g_sModToken + "|*|" + sStr);
}

integer iGetOwnerChannel(integer offset) {
    integer chan = (integer)("0x"+llGetSubString((string)g_kWearer,3,8)) + offset;
    if (chan > 0) chan = chan*(-1);
    if (chan > -10000) chan -= 30000;
    return chan;
}

AddOwners(string token, string value) {
    if (value == " " || value == "") llMessageLinked(LINK_THIS, LM_SETTING_DELETE, token, "");
    else llMessageLinked(LINK_THIS, LM_SETTING_SAVE, token+"="+value, "");
    llMessageLinked(LINK_THIS, LM_SETTING_REQUEST, token, "");
}

CheckCmd(key kID, string sMsg) {
    list parsed = llParseString2List( sMsg, [ "|" ], [] );
    if (llGetListLength(parsed) < 3) return;
    if (llListFindList(g_lExtPrefix, [llList2String(parsed,0)]) == -1) return ; // a unknown external sender
    string receiver = llList2String(parsed,1);  // second part the receiver token
    // we are the receiver
    if (llListFindList(g_lModTokens,[receiver]) != -1 || receiver == "*" ) {
        if (llGetListLength(parsed) < 4) ParseCmdString(llList2String(parsed,2), llGetOwnerKey(kID));
        else ParseCmdString(llList2String(parsed,2), llList2String(parsed,3));
    }
}

ParseCmdString(string sMsg, key kID) {
    list parsed = llParseString2List(sMsg,["~"],[]);
    integer n = llGetListLength(parsed);
    integer i;
    for (i = 0; i < n; i++ ) {
        //llMessageLinked(LINK_SET, LM_CUFF_CMD, llList2String(parsed,i), kID);
        Analyse_LM_CUFF_CMD(llList2String(parsed,i), kID);
    }
}

Analyse_LM_CUFF_CMD(string sMsg, key kID) {
    //if (sMsg == "reset") llResetScript();
    if (sMsg == g_sInfoRequest) {
        // a cuff requested info about the lock status
        g_iResend = TRUE;
        llResetTime();
        llSetTimerEvent(g_fStartTime);
    } else if (sMsg == "menu"|| sMsg == "cmenu" || sMsg == g_sCuffMenuCmd) llMessageLinked(LINK_THIS, CMD_NOAUTH, "menu", kID);
    else if (sMsg == g_sLockCMD) llMessageLinked(LINK_THIS, CMD_NOAUTH, "lock", kID);
    else if (sMsg == g_sUnLockCMD) llMessageLinked(LINK_THIS, CMD_NOAUTH, "unlock", kID);
    else if (sMsg == g_sShowCmd) llMessageLinked(LINK_THIS, CMD_NOAUTH, "ShowCuffs", kID);
    else if (sMsg == g_sHideCmd) llMessageLinked(LINK_THIS, CMD_NOAUTH, "HideCuffs", kID);
    else if (sMsg == "SAFEWORD" && kID == g_kWearer) llMessageLinked(LINK_THIS, CMD_SAFEWORD, "", "");
    else {
        list lstCmdList = llParseString2List( sMsg, ["="], [] );
        string sCmd = llList2String(lstCmdList,0);
        string sValue = llList2String(lstCmdList,1);
        string sValue2 = llList2String(lstCmdList,2);

        if (sCmd == g_sOwnerChangeCmd) AddOwners(sValue, sValue2);
        else if (sCmd == g_sColorChangeCmd) llMessageLinked(LINK_THIS, CMD_NOAUTH, "setcolor "+sValue+" "+sValue2, kID);
        else if (sCmd == g_sTextureChangeCmd) llMessageLinked(LINK_THIS, CMD_NOAUTH, "settexture "+sValue+" "+sValue2, kID);
        else if (sCmd == g_sShineChangeCmd) llMessageLinked(LINK_THIS, CMD_NOAUTH, "setshine "+sValue+" "+sValue2, kID);
        else if (sCmd == g_sRLVChangeCmd) llMessageLinked(LINK_THIS, CMD_NOAUTH, "rlv"+sValue, kID);
        else llMessageLinked(LINK_THIS, CMD_NOAUTH, sMsg, kID);
    }
}

Analyse_LM_SETTING_RESPONSE(string sMsg) {
    // split the message into token and message
    list lstParams = llParseString2List(sMsg, ["="], []);
    string token = llList2String(lstParams, 0);
    string value = llList2String(lstParams, 1);

    if (token == g_sOwnerToken) g_sSubOwners = value;
    else if (token == g_sLockToken) g_iLocked = (integer)value ;
    else if (token == g_sAutoLockToken) {
        g_iAutoLock = (integer)value ;
        if (g_iAutoLock) g_iLocked = g_iAutoLock;
    } else if (token == g_sRLVToken) g_iUseRLV = (integer)value;
    else if (sMsg == "settings=sent") {
        g_iResend = TRUE;
        llResetTime();
        llSetTimerEvent(g_fStartTime);
    }
}

Analyse_LM_SETTING_SAVE(string sMsg) {
    // split the message into token and message
    list lstParams = llParseString2List(sMsg, ["="], []);
    string token = llList2String(lstParams, 0);
    string value = llList2String(lstParams, 1);

    if (token == g_sOwnerToken) {
        // primary owner reuqested or changed
        g_sSubOwners = value;
        SendCuffCmd(g_sSubOwnerMsg+"="+g_sSubOwners);
    } else if (token == g_sLockToken) {
        g_iLocked = (integer)value ;
        SendCuffCmd(g_sLockCmd+"="+value);
    } else if (token == g_sAutoLockToken) {
        g_iAutoLock = (integer)value ;
        SendCuffCmd(g_sAutoLockCmd+"="+value);
    } else if (token == g_sRLVToken) {
        g_iUseRLV = (integer)value;
        SendCuffCmd("RLV="+value);
    }
}

Analyse_LM_SETTING_Delete(string sMsg) {
    if (sMsg == g_sOwnerToken) {
        g_sSubOwners = "" ;
        SendCuffCmd(g_sSubOwnerMsg+"="+g_sSubOwners);
    } else if (sMsg == g_sRLVToken) {
        g_iUseRLV = 0;
        SendCuffCmd("RLV=0");
    } else if (sMsg == g_sLockToken) {
        g_iLocked = 0;
        SendCuffCmd(g_sLockCmd+"=0");
    } else if (sMsg == g_sAutoLockToken) {
        g_iAutoLock = 0;
        SendCuffCmd(g_sAutoLockCmd+"=0");
    }
}

SendInfoToCuffs() {
    string sSendMsg = "RLV="+(string)g_iUseRLV;
    sSendMsg += "~"+g_sAutoLockCmd+"="+(string)g_iAutoLock;
    sSendMsg += "~"+g_sSubOwnerMsg+"="+g_sSubOwners;
    if (g_iLocked) sSendMsg += "~"+g_sLockCmd+"="+(string)g_iLocked;
    SendCuffCmd(sSendMsg);
}


default {
    on_rez(integer start_param) {
        llResetScript();
    }

    state_entry() {
        g_kWearer = llGetOwner();
        g_sSubOwners = (string)g_kWearer; // till we know better, the wearer is the owner
        g_iCmdChannel = iGetOwnerChannel(g_iCmdChannelOffset); // get the owner defined channel
        g_iCuffChannel = g_iCmdChannel + 1;
        // setup user specific backchannel

        llListen(g_iCmdChannel, "", "", "");
        llListen(g_iCuffChannel, "", "", "");
        llListen(g_iLockGuardChannel,"","","");

        //g_iCollarBackchannel = (integer)("0x" + llGetSubString(g_kWearer,30,-1));
        //if (g_iCollarBackchannel > 0) g_iCollarBackchannel = -g_iCollarBackchannel;

        g_iCollarBackchannel = -llAbs((integer)("0x"+llGetSubString((string)g_kWearer,2,7)) + 1111);
        if (g_iCollarBackchannel > -10000) g_iCollarBackchannel -= 30000;

        llSetTimerEvent(1);
    }

    link_message(integer iSender, integer iNum, string sMsg, key kID) {
        if (iNum == LM_CUFF_CMD) Analyse_LM_CUFF_CMD(sMsg, kID);
        else if (iNum == LM_CUFF_CUFFPOINTNAME) {
            if (llListFindList(g_lModTokens,[sMsg]) == -1) g_lModTokens += [sMsg];
        } else if (iNum == LM_CUFF_SEND) {
            if (sMsg =="") return;
            llRegionSayTo(g_kWearer, g_iCuffChannel, g_sModToken + "|" + sMsg + "|" + (string)kID);
        }
        else if (iNum == LM_SETTING_RESPONSE) Analyse_LM_SETTING_RESPONSE(sMsg);
        else if (iNum == LM_SETTING_SAVE) Analyse_LM_SETTING_SAVE(sMsg);
        else if (iNum == LM_SETTING_DELETE) Analyse_LM_SETTING_Delete(sMsg);
        else if (iNum == RLV_ON) {
            g_iUseRLV = TRUE;
            SendCuffCmd("RLV=1");
        } else if (iNum == RLV_OFF) {
            g_iUseRLV = FALSE;
            SendCuffCmd("RLV=0");
        } else if (iNum == RLV_REFRESH) {
            if(g_iUseRLV) SendCuffCmd("RLV=1");
            else SendCuffCmd("RLV=0");
        } else if (iNum == MENUNAME_REQUEST && sMsg == g_sParentmenu) {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, g_sParentmenu + "|" + g_sMenuEntry, "");
        } else if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) {
            if (sMsg == "menu "+ g_sMenuEntry) SendToCollar(g_sCollarMenu, kID);
        }
    }

    listen(integer iChannel, string sName, key kID, string sMsg) {
        //sMsg = llStringTrim(sMsg, STRING_TRIM);
        // check if external or maybe for this module
        if (iChannel == g_iCmdChannel && llGetOwnerKey(kID) == g_kWearer) CheckCmd(kID, sMsg);
        else if (iChannel == g_iCuffChannel && llGetOwnerKey(kID) == g_kWearer) {
            //commands sent on cuff channel, in thes case only lockguard
            if (llGetSubString(sMsg,0,8)=="lockguard") llMessageLinked(LINK_SET, g_iLockGuardChannel, sMsg, kID);
        } else if (iChannel == g_iLockGuardChannel) llMessageLinked(LINK_SET, g_iLockGuardChannel, sMsg, kID);
    }

    timer() {
        llSetTimerEvent(0);
        if (!g_iStarted) {
            g_iStarted = TRUE;
            SendToCollar(g_sRequestCollarInfo, g_kWearer);
            g_iResend = FALSE;
        }
        if (g_iResend) {
            g_iResend = FALSE;
            SendInfoToCuffs();
            llMessageLinked(LINK_THIS, CMD_WEARER, "resend_appearance", g_kWearer);
        }
    }
}