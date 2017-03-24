//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.
//See "OpenCollar License" for details.

//hide
string g_sHideMenu = " Show/Hide";
string g_sParentMenu = "Main";
//string g_sParentMenu = " Appearance";

//MESSAGE MAP
//integer CMD_NOAUTH = 0;
integer CMD_OWNER = 500;
//integer CMD_TRUST = 501;
//integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
//integer CMD_EVERYONE = 504;

integer LM_SETTING_SAVE = 2000;
//integer LM_SETTING_REQUEST = 2001;
integer LM_SETTING_RESPONSE = 2002;
//integer LM_SETTING_DELETE = 2003;
//integer LM_SETTING_EMPTY = 2004;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

string UPMENU = "▲";//when your menu hears this, give the parent menu

// Message Mapper Cuff Communication
integer LM_CUFF_SEND = -555000;

string g_sHideCmd = "HideElement";
string g_sHideAllCmd = "HideCuffs";

string g_sShowCMD = "ShowCuffs";
string g_sHideCMD = "HideCuffs";

string g_sHideLockToken = "hidelock";
string g_sStealthToken = "stealth";
string g_sHideToken = "hide";

string g_sLocked ="☒ Locked";
string g_sUnloced ="☐ Locked";

string g_sShow = "☒";
string g_sHide = "☐";
string g_sAll = "Cuffs";

integer g_iLocked = FALSE;
integer g_iHidden = FALSE;

list g_lHideSettings;
list g_lHideElements;
list g_lHidePrims;

list g_lButtons = [];

list g_lMenuIDs;  //three strided list of avkey, dialogid
integer g_iMenuStride = 2;

key g_kWearer;

/*
debug(string str) {
    llOwnerSay(llGetScriptName() + ": " + str);
}*/

Dialog(key kID, string sPrompt, list lChoices, list lUtility, integer iPage, integer iAuth) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_THIS, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtility, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID];
}


Notify(key kID, string sMsg, integer iAlsoNotifyWearer) {
    if (kID == g_kWearer) llOwnerSay(sMsg);
    else {
        if (llGetAgentSize(kID)) llRegionSayTo(kID,0,sMsg);
        else llInstantMessage(kID, sMsg);
        if (iAlsoNotifyWearer) llOwnerSay(sMsg);
    }
}

string ElementType(integer link, string type) {
    list params = llParseString2List(llGetLinkName(link),["~"],[]);
    if (~llListFindList(params, [type])) return llList2String(params, 0);
    params = llParseString2List(llList2String(llGetLinkPrimitiveParams(link,[PRIM_DESC]),0), ["~"], []);
    if (~llListFindList(params, [type])) return llList2String(params, 0) ;
    else return "";
}

BuildHideElementList() {
    g_lHideElements = [];
    g_lHidePrims = [] ;
    integer link;
    integer count = llGetNumberOfPrims();
    //root link is 1, so start at 2
    for (link = 2; link <= count; link++) {
        string element = ElementType(link,"hide");
        if (element != "") {
            integer i = llListFindList(g_lHideElements, [element]) ;
            if (i == -1) {
                g_lHideElements += [element];
                g_lHidePrims += [link];
            } else {
                string csvlinks = llList2CSV(llCSV2List(llList2String(g_lHidePrims,i))+[link]);
                g_lHidePrims = llListReplaceList(g_lHidePrims,[csvlinks],i,i);
            }
        }
    }
}

ShowHideAll() {
    llMessageLinked(LINK_THIS,LM_CUFF_SEND, "*|"+g_sHideAllCmd+"="+(string)g_iHidden, "");
    if (!g_iHidden) {
        llSetLinkAlpha(LINK_SET,1.0,ALL_SIDES);
        UpdateHide();
    } else llSetLinkAlpha(LINK_SET,0.0,ALL_SIDES);
}

UpdateHide() {
    if (g_iHidden) return ;
    integer i;
    for (i = 0; i<llGetListLength(g_lHideElements); ++i) {
        string element = (llList2String(g_lHideElements,i));
        integer hide = 0;
        integer ii = llListFindList(g_lHideSettings,[element]);
        if (ii!=-1) hide = llList2Integer(g_lHideSettings,ii+1);
        SetElementHide(element,hide);
    }
}

SetElementHide(string sElement, integer hide) {
    integer found = llListFindList(g_lHideElements, [sElement]);
    if (found != -1) {
        list csvlinks = llCSV2List(llList2String(g_lHidePrims,found));
        integer i;
        integer count = llGetListLength(csvlinks);
        for (i = 0; i < count; i++) {
            integer link = llList2Integer(csvlinks,i);
            if (link > 1) llSetLinkAlpha(link, !hide, ALL_SIDES);
        }
        llMessageLinked(LINK_THIS,LM_CUFF_SEND, "*|"+g_sHideCmd+"="+sElement+"="+(string)hide, "");
    }
}


DoButtons() {
    g_lButtons =[];
    list elements = llListSort(g_lHideElements, 1, TRUE) ;
    integer i;
    for(i = 0; i<llGetListLength(elements); ++i) {
        string element = (llList2String(elements,i));
        integer hide = 0;
        integer ii = llListFindList(g_lHideSettings,[element]);
        if (ii!=-1) hide = llList2Integer(g_lHideSettings,ii+1);

        if (hide == 1) g_lButtons += [g_sHide+" "+element];
        else g_lButtons += [g_sShow+" "+element];
    }

    if (g_iHidden) g_lButtons += [g_sHide+" "+g_sAll];
    else g_lButtons += [g_sShow+" "+g_sAll];
}

DoMenu(key id, integer auth) {
    string prompt = "Pick an option.";
    DoButtons();
    string lock ;
    if (g_iLocked) lock = g_sLocked ;
    else lock = g_sUnloced ;
    Dialog(id, prompt, g_lButtons+[lock], [UPMENU],0,auth);
}

ShowHide(string msg) {
    list lst = llParseString2List(msg, [ " " ], [] );
    string cmd = llList2String(lst,0) ;
    string element = llList2String(lst,1) ;

    integer hide = 0;
    if (cmd == g_sHide) hide = 0 ;
    if (cmd == g_sShow) hide = 1 ;

    if (element == g_sAll) {
        g_iHidden = hide;
        llMessageLinked(LINK_THIS,LM_SETTING_SAVE,g_sStealthToken+"="+(string)g_iHidden,"");
        ShowHideAll();
        return;
    } else {
        integer i = llListFindList(g_lHideSettings,[element]);
        if (i == -1) g_lHideSettings += [element, hide];
        else g_lHideSettings = llListReplaceList(g_lHideSettings, [hide], i + 1, i + 1);
        if (!g_iHidden) SetElementHide(element,hide);
    }
    llMessageLinked(LINK_THIS, LM_SETTING_SAVE, g_sHideToken + "=" + llDumpList2String(g_lHideSettings, "~"), "");
}

SendSettings() {
    string cmd = g_sHideAllCmd+"="+(string)g_iHidden;

    if (!g_iHidden) {
        integer i;
        for (i = 0; i<llGetListLength(g_lHideElements); ++i) {
            string element = (llList2String(g_lHideElements,i));
            integer hide = 0;
            integer n = llListFindList(g_lHideSettings,[element]);
            if (n!=-1) hide = llList2Integer(g_lHideSettings,n+1);
            cmd += "~"+g_sHideCmd+"="+element+"="+(string)hide;
        }
        llMessageLinked(LINK_THIS,LM_CUFF_SEND,"*|"+cmd, "");
    }
}

UserCommand(integer iNum, string sStr, key kID) {
    if (iNum < CMD_OWNER || iNum > CMD_WEARER) return;

    if (sStr == "menu "+g_sHideMenu || sStr == g_sHideMenu) {
        if (g_iLocked == FALSE) DoMenu(kID,iNum);
        else if (g_iLocked == TRUE && iNum == CMD_OWNER) DoMenu(kID,iNum);
        if (g_iLocked && iNum != CMD_OWNER) Notify(kID, "Only Owner can use it.", FALSE) ;
    } else if (sStr == g_sLocked && iNum != CMD_WEARER) {
        g_iLocked = FALSE ;
        llMessageLinked(LINK_THIS, LM_SETTING_SAVE, g_sHideLockToken+"="+(string)g_iLocked, "");
        DoMenu(kID,iNum);
    } else if (sStr == g_sUnloced && iNum != CMD_WEARER) {
        g_iLocked = TRUE ;
        llMessageLinked(LINK_THIS,LM_SETTING_SAVE,g_sHideLockToken+"="+(string)g_iLocked, "");
        if (iNum == CMD_OWNER) DoMenu(kID,iNum);
        else  llMessageLinked(LINK_THIS, iNum, "menu "+g_sParentMenu, kID);
    } else if (sStr == g_sShowCMD) {
        g_iHidden = FALSE;
        llMessageLinked(LINK_THIS,LM_SETTING_SAVE,g_sStealthToken+"="+(string)g_iHidden,"");
        ShowHideAll();
    } else if (sStr == g_sHideCMD) {
        g_iHidden = TRUE;
        llMessageLinked(LINK_THIS,LM_SETTING_SAVE,g_sStealthToken+"="+(string)g_iHidden,"");
        ShowHideAll();
    } else if (sStr == "resend_appearance") SendSettings();
}

default {
    state_entry() {
        g_kWearer = llGetOwner();
        BuildHideElementList();
    }

    on_rez(integer param) {
        if (g_kWearer!=llGetOwner()) llResetScript();
    }

    link_message(integer sender, integer iNum, string sStr, key kID) {
        if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) UserCommand(iNum, sStr, kID);
        else if (iNum == LM_SETTING_RESPONSE) {
            list params = llParseString2List(sStr, ["="], []);
            string token = llList2String(params, 0);
            if (token == g_sHideToken) {
                g_lHideSettings = llParseString2List(llList2String(params, 1), ["~"], []);
                SendSettings();
            }
        } else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu) {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sHideMenu, "");
        } else if (iNum == DIALOG_RESPONSE) {
            integer index = llListFindList(g_lMenuIDs, [kID]);
            if (~index) {
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, index-1, index-2+g_iMenuStride);

                list params = llParseString2List(sStr, ["|"], []);
                key kAV = (key)llList2String(params, 0);
                string msg = llList2String(params, 1);
                //integer page = (integer)llList2String(params, 2);
                integer auth = (integer)llList2String(params, 3);

                if (msg == UPMENU) {
                    llMessageLinked(LINK_THIS, auth, "menu "+g_sParentMenu, kAV);
                    return;
                } else if (msg == g_sLocked) {
                    g_iLocked = FALSE ;
                    llMessageLinked(LINK_THIS,LM_SETTING_SAVE,g_sHideLockToken+"="+(string)g_iLocked,"");
                } else if (msg == g_sUnloced) {
                    g_iLocked = TRUE ;
                    llMessageLinked(LINK_THIS,LM_SETTING_SAVE,g_sHideLockToken+"="+(string)g_iLocked,"");
                } else if (llListFindList(g_lButtons,[msg]) != -1 ) {
                    ShowHide(msg);
                }
                DoMenu(kAV,auth);
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer index = llListFindList(g_lMenuIDs, [kID]);
            if (~index) g_lMenuIDs = llDeleteSubList(g_lMenuIDs, index-1, index-2+g_iMenuStride);
        }

    }
}