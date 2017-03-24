//handle appearance menu

string g_sMainMenu = "Main";
string g_sAppMenu = " Appearance";

//MESSAGE MAP
integer CMD_NOAUTH = 0;
integer CMD_OWNER = 500;
//integer CMD_TRUST = 501;
//integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
//integer CMD_EVERYONE = 504;

integer LM_SETTING_SAVE = 2000;
integer LM_SETTING_REQUEST = 2001;
integer LM_SETTING_RESPONSE = 2002;
integer LM_SETTING_DELETE = 2003;
integer LM_SETTING_EMPTY = 2004;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

// Message Mapper Cuff Communication
//integer LM_CUFF_CMD = -551001;
//integer LM_CUFF_ANIM = -551002;
integer LM_CUFF_CHAINTEXTURE = -551003;   // used as channel for linkedmessages - sending the choosen texture to the cuff

string g_sAppLockToken = "AppLock";
string s_LockTRUE = "▣ LooksLock";
string s_LockFALSE = "☐ LooksLock";

string g_sChainMenu = "Chains";

// name of buttons for the different chains in the chain  menu
list g_lChainButtons = ["Thin Gold","OC Standard","Pink Chain","Black Chain","Rope"];
// LG command sequence to be send
list g_lChainCommands = ["texture 6993a4d6-9155-d5cd-8434-a009b822d5a0 size 0.08 0.08 life 1 gravity 0.3","texture 245ea72d-bc79-fee3-a802-8e73c0f09473 size 0.07 0.07 life 1 gravity 0.3","texture 4c762c43-87d4-f6ba-55f4-f978b3cc4169 size 0.07 0.07 life 0.5 gravity 0.4 color 0.8 0.0 0.8","texture 4c762c43-87d4-f6ba-55f4-f978b3cc4169 size 0.07 0.07 life 0.5 gravity 0.4 color 0.1 0.1 0.1","texture 9de57a7d-b9d7-1b11-9be7-f0a42651755e size 0.07 0.07 life 0.5 gravity 0.3"];

string g_sChainToken = "chaindefault";

string UPMENU = "▲";//when your menu hears this, give the parent menu
string RESYNC = "Redraw" ;
string RESYNC_CHAINS = "Resend" ;

integer g_iAppLock = FALSE;
integer g_iChainCurrent = -1; // Currenlty used default for chains, has to be resubmitted on every rez of a cuff

list g_lButtons;

key g_kWearer ;

list g_lMenuIDs;  //three strided list of avkey, dialogid, and menuname
integer g_iMenuStride = 3;

Dialog(key kID, string sPrompt, list lChoices, list lUtility, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_THIS, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtility, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}

Notify(key kID, string sMsg, integer iAlsoNotifyWearer) {
    if (kID == g_kWearer) llOwnerSay(sMsg);
    else {
        if (llGetAgentSize(kID)!=ZERO_VECTOR) llRegionSayTo(kID,0,sMsg);
        else llInstantMessage(kID, sMsg);
        if (iAlsoNotifyWearer) llOwnerSay(sMsg);
    }
}

AppearanceMenu(key id, integer auth) {
    string prompt = "\nAppearance menu.\n\nPick an option.";
    list buttons = [s_LockFALSE];
    if (g_iAppLock == TRUE) buttons = [s_LockTRUE];
    buttons += llListSort(g_lButtons, 1, TRUE) + [g_sChainMenu, RESYNC] ;
    Dialog(id, prompt, buttons, [UPMENU], 0, auth, "main");
}

ChainMenu(key id, integer auth) {
    string prompt = "Choose the standard chains for the collar.\nUse 'Resend' to resend the chain standards if they got out of sync (due to lag or asyncronus attaching). \nCurrent Chain: ";
    if (g_iChainCurrent==-1) {
        prompt+="Default from cuff";
    } else if ((g_iChainCurrent>=0) && (g_iChainCurrent<llGetListLength(g_lChainButtons))) {
        prompt+=llList2String(g_lChainButtons,g_iChainCurrent);
    } else {
        prompt+="Undefined, please choose a new standard texture!";
        g_iChainCurrent=-1;
    }
    Dialog(id, prompt, g_lChainButtons, [UPMENU], 0, auth, "chain");
}

SendDefChainCommand() {
    //    llWhisper(g_nLockGuardChannel,"lockguard "+(string)llGetKey()+" "+ChainTarget+" "+llList2String(g_lChainCommands,g_iChainCurrent));
    string out;
    if ((g_iChainCurrent>=0) && (g_iChainCurrent<llGetListLength(g_lChainButtons))) {
        out = llList2String(g_lChainCommands,g_iChainCurrent);
    } else out = "";
    llMessageLinked(LINK_SET,LM_CUFF_CHAINTEXTURE,out,NULL_KEY);
}

integer nStartsWith(string sHaystack, string sNeedle) {
    return (llDeleteSubString(sHaystack, llStringLength(sNeedle), -1) == sNeedle);
}

UserCommand(integer iAuth, string sStr, key id) {
    if (iAuth < CMD_OWNER || iAuth > CMD_WEARER) return;

    if (sStr == g_sAppMenu || sStr == "menu "+g_sAppMenu) {
        if(g_iAppLock == FALSE) AppearanceMenu(id, iAuth);
        else if(g_iAppLock == TRUE && iAuth == CMD_OWNER) AppearanceMenu(id, iAuth);
        if(g_iAppLock == TRUE && iAuth != CMD_OWNER) Notify(id, "Only Owner can change appearance.", FALSE) ;
    } else if (sStr == g_sChainMenu || sStr == "menu "+g_sChainMenu) {
        if(g_iAppLock == FALSE) ChainMenu(id, iAuth);
        else if(g_iAppLock == TRUE && iAuth == CMD_OWNER) ChainMenu(id, iAuth);
        if(g_iAppLock == TRUE && iAuth != CMD_OWNER) Notify(id, "Only Owner can change appearance.", FALSE) ;
    } else if (sStr == s_LockTRUE) {
        g_iAppLock = FALSE ;
        llMessageLinked(LINK_THIS, LM_SETTING_SAVE, g_sAppLockToken + "=" + (string)g_iAppLock, "");
        AppearanceMenu(id, iAuth);
    } else if (sStr == s_LockFALSE) {
        g_iAppLock = TRUE ;
        llMessageLinked(LINK_THIS, LM_SETTING_SAVE, g_sAppLockToken + "=" + (string)g_iAppLock, "");
        if(iAuth == CMD_OWNER) AppearanceMenu(id, iAuth);
        else llMessageLinked(LINK_THIS, iAuth, "menu "+g_sMainMenu, id);
    } else if (sStr == RESYNC) {
        llMessageLinked(LINK_THIS, iAuth, "resend_appearance", id);
        SendDefChainCommand();
    }
}

default {
    state_entry() {
        g_kWearer = llGetOwner();
    }

    on_rez(integer param) {
        llResetScript();
    }

    link_message(integer sender, integer iNum, string sStr, key kID) {
        if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) UserCommand(iNum, sStr, kID);
        else if (iNum == LM_SETTING_RESPONSE) {
            list params = llParseString2List(sStr, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if (token == g_sAppLockToken) {
                g_iAppLock = (integer)value;
            }
            if (token == g_sChainToken) {
                g_iChainCurrent = (integer)value;
                SendDefChainCommand();
            }
        }
        else if (iNum == MENUNAME_REQUEST && sStr == g_sMainMenu) {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, g_sMainMenu + "|" + g_sAppMenu, "");
            g_lButtons = [];
            llMessageLinked(LINK_THIS, MENUNAME_REQUEST, g_sAppMenu, "");
        }
        else if (iNum == MENUNAME_RESPONSE) {
            list parts = llParseString2List(sStr, ["|"], []);
            if (llList2String(parts, 0) == g_sAppMenu) {
                //someone wants to stick something in our menu
                string button = llList2String(parts, 1);
                if (llListFindList(g_lButtons, [button]) == -1) {
                    g_lButtons = llListSort(g_lButtons + [button], 1, TRUE);
                }
            }
        }
        else if (iNum == DIALOG_RESPONSE) {
            integer index = llListFindList(g_lMenuIDs, [kID]);
            if (~index) {
                list params = llParseString2List(sStr, ["|"], []);
                key AV = (key)llList2String(params, 0);
                string button = llList2String(params, 1);
                //integer page = (integer)llList2String(params, 2);
                integer auth = (integer)llList2String(params, 3);

                string sMenu = llList2String(g_lMenuIDs, index+1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, index-1, index-2+g_iMenuStride);

                if (sMenu == "main") {
                    if (button == UPMENU) {
                        llMessageLinked(LINK_THIS, auth, "menu "+g_sMainMenu, AV);
                    } else if (~llListFindList(g_lButtons, [button])) {
                        llMessageLinked(LINK_THIS, auth, "menu "+button, AV);
                    } else UserCommand(auth, button, AV);
                }
                else if (sMenu == "chain") {
                    if (button == UPMENU) {
                        llMessageLinked(LINK_THIS, auth, "menu "+g_sAppMenu, AV);
                    } else if (button == RESYNC_CHAINS) {
                        SendDefChainCommand();
                        ChainMenu(AV, auth);
                    } else if (~llListFindList(g_lChainButtons, [button])) {
                        g_iChainCurrent = llListFindList(g_lChainButtons, [button]);
                        SendDefChainCommand();
                        llMessageLinked(LINK_THIS, LM_SETTING_SAVE, g_sChainToken + "=" + (string)g_iChainCurrent, "");
                        ChainMenu(AV, auth);
                    }
                }
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer index = llListFindList(g_lMenuIDs, [kID]);
            if (~index) g_lMenuIDs = llDeleteSubList(g_lMenuIDs, index-1, index-2+g_iMenuStride);
        }
    }
}