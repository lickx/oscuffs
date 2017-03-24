//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//Collar Cuff Menu

string g_sParentMenu = "Apps";
string g_sSubMenu = "Cuffs";

string g_sScript = "cuffs_";

//MESSAGE MAP
integer CMD_ZERO = 0;
integer CMD_OWNER = 500;
//integer CMD_TRUST = 501;
//integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
//integer CMD_EVERYONE = 504;

//integer CMD_OBJECT = 506;
//integer CMD_RLV_RELAY = 507;
integer CMD_SAFEWORD = 510;  // new for safeword

integer NOTIFY = 1002;
integer LINK_AUTH = 2;
integer LINK_DIALOG = 3;
integer LINK_RLV = 4;
integer LINK_SAVE = 5;
integer LINK_UPDATE = -10;
integer REBOOT = -1000;

integer LM_SETTING_SAVE = 2000;
integer LM_SETTING_REQUEST = 2001;
integer LM_SETTING_RESPONSE = 2002;
integer LM_SETTING_DELETE = 2003;
integer LM_SETTING_EMPTY = 2004;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;
integer RLV_CLEAR = 6002;

integer RLV_OFF = 6100;
integer RLV_ON = 6101;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

string UPMENU = "BACK"; //when your menu hears this, give the parent menu

// ********** constants *************

string AuthGroup = "auth" ;
string ColorGroup = "color";
string TextureGroup = "texture";
string ShinyGroup = "shininess";
//string RlvGroup = "rlvmain";

// Commands to be send from the collar
string g_sRequestCollarInfo = "OpenCollar_RequestSettings"; // command for the collar
string g_sCollarMenu = "OpenCollar_ShowMenu"; // command for the collar to show the menu

//string g_sOwnerChangeCollarInfo = "OpenCuff_OwnerChanged"; // command for the collar to reset owner system

// Commands to be send to the Cuffs
string g_sRLVCmd = "RLV";
string g_sAuthCmd = "AUTH";
string g_sColorCmd = "COLOR";
string g_sTextureCmd = "TEXTURE";
string g_sShineCmd = "SHINE";
string g_sMenuCmd = "MENU";
string g_sLockCmd = "LOCK";
string g_sUnLockCmd = "UNLOCK";
string g_sShowCmd = "SHOW";
string g_sHideCmd = "HIDE";

// chat command for opening the menu of the cuffs directly
string g_sOpenCuffMenuCommand = "cuffmenu";

// variables for automativ updating collor and appearance in the cuffs
string g_sUpdateActive_ON = "☒ SyncPaint";
string g_sUpdateActive_OFF = "☐ SyncPaint";
string g_sSyncToken = "autosync";

string g_sAutoLock_ON = "☒ AutoLock";
string g_sAutoLock_OFF = "☐ AutoLock";
string g_sAutoLockToken = "autolock";

string CuffMenuBtn = "Cuffs Menu" ;
string LockCuffsBtn = "Lock Cuffs" ;
string UnLockCuffsBtn = "UnLock Cuffs" ;
string ShowBtn = "Show Cuffs" ;
string HideBtn = "Hide Cuffs" ;
string UpdBtn = "Upd.Paints";

//list g_lLocalButtons = [LockCuffsBtn, ShowBtn, CuffMenuBtn, UnLockCuffsBtn, HideBtn];//, UpdBtn];
list g_lLocalButtons = ["Lock Cuffs", "Show Cuffs", "Cuffs Menu", "UnLock Cuffs", "Hide Cuffs"];//, UpdBtn];

string g_sCollarToken = "occ";
string g_sCuffToken = "rlac";

integer g_iSyncActive = TRUE;
integer g_iAutoLock = FALSE;

integer g_iChannelOffset = 0xCC0CC; // offset to be used to make sure we do not interfere with other items using the same technique for
integer g_iCmdChannel = -190890; // command channel for sending commands to the main cuff

key g_kWearer;

list g_lColorSettings = [] ;
list g_lTextureSettings = [] ;
list g_lShinySettings = [] ;

string g_sTempOwner;
string g_sOwner;
string g_sTrust;
string g_sBlock;
string g_sGroup ;
string g_sPublic;
string g_sLimitRange ;

list g_lMenuIDs;
integer g_iMenuStride=2;

/*
integer g_iProfiled;
Debug(string sStr) {
    //if you delete the first // from the preceeding and following  lines,
    //  profiling is off, debug is off, and the compiler will remind you to
    //  remove the debug calls from the code, we're back to production mode
    if (!g_iProfiled){
        g_iProfiled=1;
        llScriptProfiler(1);
    }
    llOwnerSay(llGetScriptName() + "(min free:"+(string)(llGetMemoryLimit()-llGetSPMaxMemory())+")["+(string)llGetFreeMemory()+"] :\n" + sStr);
}
*/

Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID];
    //Debug("Made "+sName+" menu.");
}

DoMenu(key kAv, integer iAuth) {
    string sPrompt = "\nPick an option.\n";
    list lMyButtons ;
    //fill in your button list here

    if (g_iAutoLock) {
        sPrompt += "\n* Cuffs are locked when they put on.";
        lMyButtons+=[g_sAutoLock_ON];
    } else {
        sPrompt += "\n* Cuffs will not be locked when they put on.";
        lMyButtons+=[g_sAutoLock_OFF];
    }
    if (g_iSyncActive) {
        sPrompt += "\n* Colors and textures will be sycronized automatically to your cuffs, when you change them on the collar.";
        lMyButtons+=[g_sUpdateActive_ON];
    } else {
        sPrompt += "\n* Colors and textures will NOT be sycronized automatically to your cuffs, when you change them on the collar.";
        lMyButtons+=[g_sUpdateActive_OFF];        
    }
    lMyButtons+=[UPMENU];
    Dialog(kAv, sPrompt, g_lLocalButtons, lMyButtons, 0, iAuth);
}

integer iGetOwnerChannel(integer iOffset) {
    integer chan = (integer)("0x"+llGetSubString((string)g_kWearer,3,8)) + iOffset;
    if (chan > 0) chan = chan*(-1);
    if (chan > -10000) chan -= 30000;
    return chan;
}

SendCmd(string sSendTo, string sCmd, key keyID) {
    llRegionSayTo(g_kWearer, g_iCmdChannel, g_sCollarToken + "|" + sSendTo + "|" + sCmd + "|" + (string)keyID);
}

list AddSetting(list cache, string token, string value) {
    integer i = llListFindList(cache, [token]);
    if (~i) cache = llListReplaceList(cache, [token, value], i, i+1);
    else cache += [token, value];
    return cache ;
}

list DelSetting(list cache, string token, string value) {
    if (token == "all") cache = [];
    else {
        integer i = llListFindList(cache, [token]);
        if (~i) cache = llDeleteSubList(cache, i, i + 1);
    }
    return cache ;
}

string StripNames(string in) {
    return llDumpList2String(llList2ListStrided(llCSV2List(in),0,-1,2),",");
}

SendAllSettings() {
    SendCmd(g_sCuffToken, g_sAuthCmd+"=tempowner="+g_sTempOwner, g_kWearer);
    SendCmd(g_sCuffToken, g_sAuthCmd+"=owner="+g_sOwner, g_kWearer);
    SendCmd(g_sCuffToken, g_sAuthCmd+"=trust="+g_sTrust, g_kWearer);
    SendCmd(g_sCuffToken, g_sAuthCmd+"=block="+g_sBlock, g_kWearer);
    SendCmd(g_sCuffToken, g_sAuthCmd+"=group="+g_sGroup, g_kWearer);
    SendCmd(g_sCuffToken, g_sAuthCmd+"=public="+g_sPublic, g_kWearer);
    SendCmd(g_sCuffToken, g_sAuthCmd+"=limitrange="+g_sLimitRange, g_kWearer);
    /*
    if (g_iSyncActive) {
        SendSettings(g_lTextureSettings,g_sTextureCmd);
        SendSettings(g_lColorSettings,g_sColorCmd);
        SendSettings(g_lShinySettings,g_sShineCmd);
    }*/

    if (g_iAutoLock) SendCmd(g_sCuffToken, g_sLockCmd, g_kWearer);
}

SendSettings(list lSettings, string sCmd) {
    string cmd;
    integer iCount = llGetListLength(lSettings);
    integer i;
    for (i = 0; i < iCount; i = i + 2) {
        string element = llList2String(lSettings,i) ;
        string value = llList2String(lSettings,i+1) ;
        cmd += sCmd+"="+element+"="+value+"~";
    }
    lSettings = [];
    SendCmd(g_sCuffToken, cmd, g_kWearer);
    cmd = "";
}


//=============================================================================
//== OC Cuff - slave listen module
//== receives messages from exernal objects
//==
//== 2009-01-16 Jenny Sigall - 1. draft
//=============================================================================

integer LM_CUFF_CMD  = -551001;
integer LM_CUFF_ANIM = -551002;
integer LM_CUFF_CUFFPOINTNAME = -551003;
integer LM_CUFF_SET = -551010;

list lstTokens = ["Not","chest","skull","lshoulder","rshoulder","lhand","rhand","lfoot","rfoot","spine","ocpants","mouth","chin","lear","rear","leye","reye","nose","ruac","rlac","luac","llac","rhip","rulc","rllc","lhip","lulc","lllc","ocbelt","rpec","lpec","HUD Center 2","HUD Top Right","HUD Top","HUD Top Left","HUD Center","HUD Bottom Left","HUD Bottom","HUD Bottom Right","neck","avatar center"]; // list of attachment point to resolcve the names for the cuffs system, addition cuff chain point will be transamitted via LMs
// attention, belt is twice in the list, once for stomach. , once for pelvis as there are version for both points

list g_lCuffPoints = ["*"]; // valid token for this module

key g_kCollarKey  = NULL_KEY;       // key of the cuff

integer g_iLockGuardChannel = -9119;
integer g_iCuffChannel = -190889;    // command channel to recieve command


// external command syntax
// sender|receiver|command1=value1~command2=value2|UUID
// occ|rwc|chain=on~lock=on|aaa-bbb-2222...

CheckCmd(key kID, string sMsg) {
    list parsed = llParseString2List(sMsg, ["|"], []);
    // first part should be sender token
    // second part the receiver token
    // third part = command
    if (llList2String(parsed,0) == g_sCuffToken && llGetListLength(parsed) > 2) {
        if (~llListFindList(g_lCuffPoints,[llList2String(parsed,1)])) ParseCmdString(kID, llList2String(parsed,2));
    }
    parsed = [];
}

ParseCmdString(key kID, string sMsg) {
    list parsed = llParseString2List(sMsg, ["~"], []);
    integer n = llGetListLength(parsed);
    integer i = 0;
    for (i = 0; i < n; i++ ) {
        ParseSingleCmd(kID, llList2String(parsed, i));
    }
    parsed = [];
}

ParseSingleCmd(key kID, string sMsg) {
    list parsed = llParseString2List(sMsg, ["="], []);
    string Cmd = llList2String(parsed,0);
    if (Cmd == "chain" && llGetListLength(parsed) == 4 && kID != g_kCollarKey)
        llMessageLinked(LINK_SET, LM_CUFF_CMD, sMsg, g_kCollarKey );
    else llMessageLinked(LINK_SET, LM_CUFF_CMD, sMsg, kID);
    parsed = [];
}


///***************************
UserCommand(integer iAuth, string sStr, key kAv) {
    if (iAuth > CMD_WEARER || iAuth < CMD_OWNER) return ; // sanity check

    list lParams = llParseString2List(sStr, [" "], []);
    string sCommand = llToLower(llList2String(lParams, 0));

    if (sStr == "menu "+g_sSubMenu) DoMenu(kAv, iAuth);
    else if (llToLower(sStr) == llToLower(g_sSubMenu)) DoMenu(kAv, iAuth);

    else if (sStr == g_sOpenCuffMenuCommand) SendCmd(g_sCuffToken, g_sMenuCmd, kAv);
    else if (sStr == "runaway" && (iAuth == CMD_OWNER || kAv == g_kWearer) ) {
        SendCmd(g_sCuffToken, g_sAuthCmd+"=owner", g_kWearer);
    }
    else if (sStr == "cmenu") SendCmd(g_sCuffToken, g_sMenuCmd+"="+(string)kAv, g_kWearer);
}

default {

    on_rez(integer param) {
        llMessageLinked(LINK_SET, LM_CUFF_CMD, "reset", "");
        llMessageLinked(LINK_SET, LM_CUFF_SET, "LINK_CUFFS", "");
        if (g_kWearer != llGetOwner()) llResetScript();
    }

    state_entry() {
        llMessageLinked(LINK_SET, LM_CUFF_CMD, "reset", "");
        llMessageLinked(LINK_SET, LM_CUFF_SET, "LINK_CUFFS", "");
        g_kWearer = llGetOwner();
        g_kCollarKey = llGetKey();
        
        // get name of the cuff from the attachment point, this is absolutly needed for the system to work,
        // other chain point wil be received via LMs
        g_lCuffPoints = [llList2String(lstTokens,llGetAttached())];        

        g_iCmdChannel = iGetOwnerChannel(g_iChannelOffset);
        g_iCuffChannel = iGetOwnerChannel(g_iChannelOffset)+1;
        llListen(g_iCmdChannel, "", "", "");
        llListen(g_iCuffChannel, "", "", "");
        llListen(g_iLockGuardChannel,"","",""); // listen to LockGuard requests
    }

    listen(integer iChannel, string sName, key kID, string sMsg) {
        sMsg = llStringTrim(sMsg, STRING_TRIM);

        // commands sent on cmd channel
        if (iChannel == g_iCuffChannel && llGetOwnerKey(kID) == g_kWearer) {
            if (llGetSubString(sMsg,0,8)=="lockguard") llMessageLinked(LINK_SET, g_iLockGuardChannel, sMsg, kID);
            else CheckCmd(kID, sMsg); // check if external or maybe for this module
        }
        else if (iChannel == g_iLockGuardChannel) llMessageLinked(LINK_SET, g_iLockGuardChannel, sMsg, kID);
        else if (iChannel == g_iCmdChannel && llGetOwnerKey(kID) == g_kWearer) {
            list parsed = llParseString2List( sMsg, [ "=" ], [] );
            string Cmd = llList2String(parsed,0);
            if (Cmd == g_sCollarMenu) llMessageLinked(LINK_AUTH, CMD_ZERO,"menu main",(key)llList2String(parsed,1));
            else if (Cmd == g_sRequestCollarInfo) SendAllSettings();
        }
    }

    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum <= CMD_WEARER && iNum >= CMD_OWNER) UserCommand(iNum, sStr, kID);
        else if (iNum == LM_CUFF_CUFFPOINTNAME) {
            if (llListFindList(g_lCuffPoints,[sStr]) == -1) g_lCuffPoints += [sStr];
        } else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu) {
            llMessageLinked(iSender, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        } else if (iNum == LM_SETTING_RESPONSE || iNum == LM_SETTING_EMPTY || iNum == LM_CUFF_SET) {
            list lParams = llParseString2List(sStr, ["_","="], []);
            string sGroup = llList2String(lParams, 0);
            string sToken = llList2String(lParams, 1);
            string sValue = llList2String(lParams, 2);

            if (iNum == LM_SETTING_RESPONSE) {
                if (sStr == "settings=sent") SendAllSettings();
                else {
                    if (sGroup == g_sScript) {
                        if (sToken == g_sSyncToken) g_iSyncActive = (integer)sValue;
                        else if (sToken == g_sAutoLockToken) g_iAutoLock = (integer)sValue;
                    }
                    else if (sGroup == AuthGroup) {
                        if (sToken == "tempowner") g_sTempOwner = StripNames(sValue);
                        else if (sToken == "owner") g_sOwner = StripNames(sValue);
                        else if (sToken == "trust") g_sTrust = StripNames(sValue);
                        else if (sToken == "block") g_sBlock = StripNames(sValue);
                        else if (sToken == "group") g_sGroup = sValue;
                        else if (sToken == "public") g_sPublic = sValue;
                        else if (sToken == "limitrange") g_sLimitRange = sValue;
                    }
                    else if (sGroup == ColorGroup) g_lColorSettings = AddSetting(g_lColorSettings, sToken, sValue) ;
                    else if (sGroup == TextureGroup) g_lTextureSettings = AddSetting(g_lTextureSettings, sToken, sValue) ;
                    else if (sGroup == ShinyGroup) g_lShinySettings = AddSetting(g_lShinySettings, sToken, sValue) ;
                }
            } else if (iNum == LM_SETTING_EMPTY) {
                if (sGroup == AuthGroup) {
                    if (sToken == "tempowner") g_sTempOwner = "";
                    else if (sToken == "owner") g_sOwner = "";
                    else if (sToken == "trust") g_sTrust = "";
                    else if (sToken == "block") g_sBlock = "";
                    else if (sToken == "group") g_sGroup = "";
                    else if (sToken == "public") g_sPublic = "";
                    else if (sToken == "limitrange") g_sLimitRange = "";
                }
            } else if (iNum == LM_CUFF_SET) {
                if (sGroup == AuthGroup) {
                    if (sToken == "tempowner") {
                        g_sTempOwner = StripNames(sValue);
                        SendCmd(g_sCuffToken, g_sAuthCmd+"=tempowner="+g_sTempOwner, g_kWearer);
                    }
                    else if (sToken == "owner") {
                        g_sOwner = StripNames(sValue);
                        SendCmd(g_sCuffToken, g_sAuthCmd+"=owner="+g_sOwner, g_kWearer);
                    }
                    else if (sToken == "trust") {
                        g_sTrust = StripNames(sValue);
                        SendCmd(g_sCuffToken, g_sAuthCmd+"=trust="+g_sTrust, g_kWearer);
                    }
                    else if (sToken == "block") {
                        g_sBlock = StripNames(sValue);
                        SendCmd(g_sCuffToken, g_sAuthCmd+"=block="+g_sBlock, g_kWearer);
                    }
                    else if (sToken == "group") {
                        g_sGroup = sValue;
                        SendCmd(g_sCuffToken, g_sAuthCmd+"=group="+g_sGroup, g_kWearer);
                    }
                    else if (sToken == "public") {
                        g_sPublic = sValue;
                        SendCmd(g_sCuffToken, g_sAuthCmd+"=public="+g_sPublic, g_kWearer);
                    }
                    else if (sToken == "limitrange") {
                        g_sLimitRange = sValue;
                        SendCmd(g_sCuffToken, g_sAuthCmd+"=limitrange="+g_sLimitRange, g_kWearer);
                    }
                } else if (sGroup == ColorGroup) {
                    g_lColorSettings = AddSetting(g_lColorSettings, sToken, sValue) ;
                    SendCmd(g_sCuffToken, g_sColorCmd+"="+sToken+"="+sValue, g_kWearer);
                } else if (sGroup == TextureGroup) {
                    g_lTextureSettings = AddSetting(g_lTextureSettings, sToken, sValue) ;
                    SendCmd(g_sCuffToken, g_sTextureCmd+"="+sToken+"="+sValue, g_kWearer);
                } else if (sGroup == ShinyGroup) {
                    g_lShinySettings = AddSetting(g_lShinySettings, sToken, sValue) ;
                    SendCmd(g_sCuffToken, g_sShineCmd+"="+sToken+"="+sValue, g_kWearer);
                }
            }
        }
        // check for RLV changes from auth system
        else if (iNum == RLV_OFF) SendCmd(g_sCuffToken, g_sRLVCmd+"=off", g_kWearer);
        else if (iNum == RLV_ON) SendCmd(g_sCuffToken, g_sRLVCmd+"=on", g_kWearer);
        else if (iNum == CMD_SAFEWORD) SendCmd(g_sCuffToken, "SAFEWORD", g_kWearer);
        else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (~iMenuIndex) {
                //got a menu response meant for us.  pull out values
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iPage = (integer)llList2String(lMenuParams, 2);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                if (sMessage == UPMENU) {//give id the parent menu
                    llMessageLinked(LINK_ROOT, iAuth, "menu " + g_sParentMenu, kAv);
                    return;
                } else if (~llListFindList(g_lLocalButtons, [sMessage])) {//we got a response for something we handle locally
                    if (sMessage == CuffMenuBtn) {
                        SendCmd(g_sCuffToken,g_sMenuCmd, kAv);
                        return;
                    } else if (sMessage == LockCuffsBtn) SendCmd(g_sCuffToken, g_sLockCmd, kAv);
                    else if (sMessage == UnLockCuffsBtn) SendCmd(g_sCuffToken, g_sUnLockCmd, kAv);
                    else if (sMessage == ShowBtn) SendCmd(g_sCuffToken, g_sShowCmd, kAv);
                    else if (sMessage == HideBtn) SendCmd(g_sCuffToken, g_sHideCmd, kAv);
                    else if (sMessage == UpdBtn) {
                        SendSettings(g_lColorSettings,g_sColorCmd);
                        SendSettings(g_lTextureSettings,g_sTextureCmd);
                        SendSettings(g_lShinySettings,g_sShineCmd);
                    }
                } else if (sMessage == g_sUpdateActive_OFF) {
                    g_iSyncActive = TRUE;
                    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sScript+g_sSyncToken+"="+(string)g_iSyncActive, "");
                    SendSettings(g_lColorSettings,g_sColorCmd);
                    SendSettings(g_lTextureSettings,g_sTextureCmd);
                    SendSettings(g_lShinySettings,g_sShineCmd);
                } else if (sMessage == g_sUpdateActive_ON) {
                    g_iSyncActive = FALSE;
                    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sScript+g_sSyncToken+"="+(string)g_iSyncActive, "");
                } else if (sMessage == g_sAutoLock_OFF) {
                    g_iAutoLock = TRUE;
                    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sScript+g_sAutoLockToken+"="+(string)g_iAutoLock, "");
                } else if (sMessage == g_sAutoLock_ON) {
                    g_iAutoLock = FALSE;
                    llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, g_sScript+g_sAutoLockToken+"="+(string)g_iAutoLock, "");
                }
                DoMenu(kAv,iAuth);
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (~iMenuIndex) g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
        } else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_REQUEST") llMessageLinked(LINK_ALL_OTHERS, LM_CUFF_SET, "LINK_CUFFS","");
            else if (sStr == "LINK_AUTH") LINK_AUTH = iSender;
            else if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sStr == "LINK_RLV") LINK_RLV = iSender;
            else if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
        } else if (iNum == REBOOT && sStr == "reboot") llResetScript();
    }

    changed (integer change) {
        if (change & CHANGED_OWNER) llResetScript();
    }
}
