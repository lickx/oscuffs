//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

string g_sParentMenu = "Main";
string g_sSubMenu = "RLV";

//MESSAGE MAP
//integer CMD_NOAUTH = 0;
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
integer LM_SETTING_EMPTY = 2004;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this msg.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this msg.
integer RLV_VERSION = 6003; //RLV Plugins can recieve the used rl viewer version upon receiving this msg..

integer RLV_OFF = 6100; // send to inform plugins that RLV is disabled now, no msg or key needed
integer RLV_ON = 6101; // send to inform plugins that RLV is enabled now, no msg or key needed

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

string UPMENU = "▲";
string TURNON = "*Turn On*";
string TURNOFF = "*Turn Off*";
string CLEAR = "*Clear All*";

integer g_iRLVon = FALSE;//set to TRUE if DB says user has turned RLV features on
integer g_iRLVactive = FALSE;//set to TRUE if viewer is has responded to @version msg
//integer rlvnotify = FALSE;//if TRUE, ownersay on each RLV restriction
integer g_iListener;
integer g_iVersionChannel = 293847;
integer g_iCheckCount;//increment this each time we say @version.  check it each time timer goes off in default state. give up if it's >= 2
float g_fVersionTimeout = 30.0;

key g_kWearer;

string g_sRLVVersion ;

integer g_iVerbose;
integer g_iLastDetach; //unix time of the last detach: used for checking if the detached time was small enough for not triggering the ping mechanism

list g_lOwners;

list g_lMenuIDs;  //three strided list of avkey, dialogid, and menuname
integer g_iMenuStride = 2;

/*
Debug(string sStr) {
    llOwnerSay(llGetScriptName() + ": " + sStr);
}
*/

Notify(key kID, string sMsg, integer iAlsoNotifyWearer) {
    if (kID == g_kWearer) llOwnerSay(sMsg);
    else {
        if (llGetAgentSize(kID)!=ZERO_VECTOR) llRegionSayTo(kID,0,sMsg);
        else llInstantMessage(kID, sMsg);
        if (iAlsoNotifyWearer) llOwnerSay(sMsg);
    }
}

string NameURI(key uuid) {
    return "secondlife:///app/agent/"+(string)uuid+"/about";
}

Dialog(key kID, string sPrompt, list lChoices, list lUtility, integer iPage, integer iAuth) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_THIS, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtility, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID];
}

CheckVersion(integer iVerbose) {
    if (g_iRLVon) {
        g_iRLVactive = FALSE;
        g_iVerbose = iVerbose;
        if (iVerbose) llOwnerSay("Check RLV...");
        g_iVersionChannel = llAbs((integer)("0x"+(string)llGetKey()));
        g_iListener = llListen(g_iVersionChannel, "", g_kWearer, "");
        llSetTimerEvent(g_fVersionTimeout);
        g_iCheckCount++;
        llOwnerSay("@version=" + (string)g_iVersionChannel);
    }
}

DoMenu(key kID, integer iAuth) {
    list buttons;

    if (g_iRLVon) buttons += [TURNOFF, CLEAR] ;
    else buttons += [TURNON];
    string prompt = "Restrained Life Viewer Options \n\n";
    if (g_iRLVon) {
        if (g_iRLVactive) prompt += g_sRLVVersion + " detected.\nRLV functions active.";
        else prompt += "Could not detect RLV.\nRLV functions disabled.";
    }
    Dialog(kID, prompt, buttons, [UPMENU], 0, iAuth);
}

safeword (integer collartoo) {
    llOwnerSay("@clear");
    if (!collartoo) llMessageLinked(LINK_THIS, RLV_REFRESH, "", "");
}

UserCommand(integer iAuth, string sStr, key kID) {
    if (iAuth < CMD_OWNER || iAuth > CMD_WEARER) return;

    if (llToLower(sStr) == g_sSubMenu || sStr == "menu "+g_sSubMenu ) {
        DoMenu(kID, iAuth);
    } else if (llToLower(sStr) == "rlvon" && !g_iRLVon) {
        g_iRLVon = TRUE;
        llMessageLinked(LINK_THIS, LM_SETTING_SAVE, "rlvon=1", "");
        CheckVersion(FALSE);
    } else if (llToLower(sStr) == "rlvoff" && g_iRLVon) {
        if (iAuth == CMD_OWNER) {
            g_iRLVon = FALSE;
            llMessageLinked(LINK_THIS, LM_SETTING_SAVE, "rlvon=0", "");
            safeword(TRUE);
            llMessageLinked(LINK_THIS, RLV_OFF, "", "");
        } else Notify(kID, "Sorry, only owner may disable RLV functions", FALSE);
    }
    /*
    else if (llToLower(sStr) == "rlvnotify on") {
        rlvnotify = TRUE;
        llMessageLinked(LINK_THIS, LM_SETTING_SAVE, "rlvnotify=1", "");
    } else if (llToLower(sStr) == "rlvnotify off") {
        rlvnotify = FALSE;
        llMessageLinked(LINK_THIS, LM_SETTING_SAVE, "rlvnotify=0", "");
    }*/
    else if (llToLower(sStr) == "clear") {
        if (iAuth == CMD_OWNER) {
            llMessageLinked(LINK_THIS, RLV_CLEAR, "", "");
            safeword(TRUE);
        } else Notify(kID,"Sorry, only owner may clear RLV settings.",FALSE);
    }
}

default {
    on_rez(integer param) {
        if (llGetOwner() != g_kWearer) llResetScript();
        if (llGetUnixTime()-g_iLastDetach > 15) CheckVersion(FALSE);
        else if (g_iRLVon && g_iRLVactive) {
            llOwnerSay("@clear");
            llMessageLinked(LINK_THIS, RLV_REFRESH, "", "");
        }
    }

    attach(key kID) {
        if (kID == NULL_KEY) g_iLastDetach = llGetUnixTime(); //remember when the cuffs was detached last
    }

    state_entry() {
        g_kWearer = llGetOwner();
        llMessageLinked(LINK_THIS, LM_SETTING_REQUEST, "rlvon", "");
    }

    listen(integer channel, string name, key kID, string msg) {
        llListenRemove(g_iListener);
        llSetTimerEvent(0.0);
        g_iRLVactive = TRUE;
        g_iCheckCount = 0;
        llMessageLinked(LINK_THIS, RLV_ON, "", "");
        g_sRLVVersion =  llDeleteSubString(msg,0,21);
        if (g_iVerbose) llOwnerSay("RLV ready! " + g_sRLVVersion);
    }

    timer() {
        llSetTimerEvent(0.0);
        llListenRemove(g_iListener);
        if (g_iCheckCount == 1) CheckVersion(FALSE);
        else if (g_iCheckCount >= 2) {
            //we've given the viewer a full 60 seconds
            g_iRLVactive = FALSE;
            llMessageLinked(LINK_THIS, RLV_OFF, "", "");
            if (g_iVerbose) llOwnerSay("Could not detect RLV.\nRLV functions disabled.");
            if (llGetListLength(g_lOwners) > 0) {
                string msg = NameURI(g_kWearer)+" appears to have logged in without using the RLV.\nTheir RLV functions have been disabled.";
                if (llGetListLength(g_lOwners) == 1) {
                    // only 1 owner
                    llOwnerSay("Your owner has been notified.");
                    Notify(llList2Key(g_lOwners,0), msg, FALSE);
                } else {
                    llOwnerSay("Your owners have been notified.");
                    integer i;
                    for(i=0; i < llGetListLength(g_lOwners); i++) {
                        Notify(llList2Key(g_lOwners,i), msg, FALSE);
                    }
                }
            }
        }
    }

    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) UserCommand(iNum, sStr, kID);
        else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu) {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        } else if (iNum == LM_SETTING_SAVE) {
            list params = llParseString2List(sStr, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if (token == "owner" && llStringLength(value) > 0) {
                g_lOwners = llParseString2List(value, [","], []);
            }
        } else if (iNum == LM_SETTING_RESPONSE) {
            if (sStr == "rlvon=0") {
                g_iRLVon = FALSE;
                g_iRLVactive = FALSE;
                llMessageLinked(LINK_THIS, RLV_OFF, "", "");
            } else if (sStr == "rlvon=1") {
                g_iRLVon = TRUE;
                CheckVersion(FALSE);
            }
            else {
                list params = llParseString2List(sStr, ["="], []);
                string token = llList2String(params, 0);
                string value = llList2String(params, 1);
                if (token == "owner" && llStringLength(value) > 0) {
                    g_lOwners = llParseString2List(value, [","], []);
                }
            }
            //else if (sStr == "rlvnotify=1") rlvnotify = TRUE;
            //else if (sStr == "rlvnotify=0") rlvnotify = FALSE;
        } else if (iNum == LM_SETTING_EMPTY && sStr == "rlvon") {
            //CheckVersion(FALSE);
        }
        else if (iNum == DIALOG_RESPONSE) {
            integer index = llListFindList(g_lMenuIDs, [kID]);
            if (~index) {
                list params = llParseString2List(sStr, ["|"], []);
                key av = (key)llList2String(params, 0);
                string msg = llList2String(params, 1);
                //integer page = (integer)llList2String(params, 2);
                integer auth = (integer)llList2String(params, 3);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, index-1, index-2+g_iMenuStride);

                if (msg == TURNON) {
                    UserCommand(auth, "rlvon", av);
                    llMessageLinked(LINK_THIS, auth, "menu "+g_sParentMenu, av);
                } else if (msg == TURNOFF) {
                    UserCommand(auth, "rlvoff", av);
                    llMessageLinked(LINK_THIS, auth, "menu "+g_sParentMenu, av);
                } else if (msg == CLEAR) {
                    UserCommand(auth, "clear", av);
                    DoMenu(av, auth);
                } else if (msg == UPMENU) {
                    llMessageLinked(LINK_THIS, auth, "menu "+g_sParentMenu, av);
                }
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer index = llListFindList(g_lMenuIDs, [kID]);
            if (~index) g_lMenuIDs = llDeleteSubList(g_lMenuIDs, index-1, index-2+g_iMenuStride);
        }

        //these are things we only do if RLV is ready to go
        if (g_iRLVon && g_iRLVactive) {
            //if RLV is off, don't even respond to RLV submenu events
            if (iNum == RLV_CMD) {
                list commands=llParseString2List(sStr,[","],[]);
                integer i;
                integer l = llGetListLength(commands);
                for (i=0;i<l;i++) {
                    string cmd = llToLower(llList2String(commands,i));
                    llOwnerSay("@"+cmd);
                    //if (rlvnotify) Notify(g_kWearer, "Sent RLV Command: " + cmd, TRUE);
                }
            } else if (iNum == CMD_SAFEWORD) {
                // safeword used, clear rlv settings
                llMessageLinked(LINK_THIS, RLV_CLEAR, "", "");
                safeword(TRUE);
            }
        }
    }

    changed(integer change) {
        if (change & CHANGED_REGION) llMessageLinked(LINK_THIS, RLV_REFRESH, "", "");
        if (change & CHANGED_OWNER) llResetScript();
    }
}