//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

string g_sVersion = "4.2" ;

//MESSAGE MAP
integer CMD_NOAUTH = 0;
integer CMD_OWNER = 500;
integer CMD_TRUST = 501;
integer CMD_GROUP = 502;
integer CMD_WEARER = 503;

integer LM_SETTING_SAVE = 2000;
//integer LM_SETTING_REQUEST = 2001;
integer LM_SETTING_RESPONSE = 2002;
//integer LM_SETTING_DELETE = 2003;
//integer LM_SETTING_EMPTY = 2004;

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

// ************** MENU ****************

string UPMENU = "▲";
string EXIT = "EXIT";

string UPDATE = "Update";

string AUTOLOCK_ON = "▣ AutoLock";
string AUTOLOCK_OFF = "☐ AutoLock";

// *********** LOCK/UNLOCK *******************

string g_sLockSound = "7d99f682-9f9a-4a78-801d-d7e676e67f0e";
string g_sUnLockSound = "0b0ccdb0-546f-4e76-9329-08ceba5fe2c6";

list g_lClosedLockElements;
list g_lOpenLockElements;

integer g_iHide;
integer g_iLocked;
integer g_iAutoLock;
key g_kWearer;
list g_lOwners;

integer g_iWaitUpdate = FALSE;
integer g_iWaitRebuild = FALSE;

string g_sDetachTime ;

integer g_iUpdateChan = -87383215;
integer g_iUpdateListen;

list g_lMenuNames;
list g_lMenus;//exists in parallel to g_lMenuNames, each entry containing a pipe-delimited string with the items for the corresponding menu

list g_lMenuID;//2-strided list of avatars given menus, their dialog ids of the menu they were given
integer g_iMenuStride = 2;

integer g_iScriptCount;//when the g_iScriptCount changes, rebuild menus


Notify(key kID, string sMsg, integer iAlsoNotifyWearer) {
    if (kID == g_kWearer) llOwnerSay(sMsg);
    else {
        if (llGetAgentSize(kID)!=ZERO_VECTOR) llRegionSayTo(kID,0,sMsg);
        else llInstantMessage(kID, sMsg);
        if (iAlsoNotifyWearer) llOwnerSay(sMsg);
    }
}

NotifyOwners(string msg) {
    integer n;
    integer stop = llGetListLength(g_lOwners);
    for (n = 0; n < stop; n++) {
        Notify((key)llList2String(g_lOwners, n), msg, FALSE);
    }
}

integer KeyIsAv(key id) {
    return llGetAgentSize(id) != ZERO_VECTOR;
}

Dialog(key rcpt, string prompt, list choices, list utility, integer page, integer auth) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_THIS, DIALOG, (string)rcpt + "|" + prompt + "|" + (string)page + "|" + llDumpList2String(choices, "`") + "|" + llDumpList2String(utility, "`") + "|" + (string)auth, kMenuID);

    integer i = llListFindList(g_lMenuID, [rcpt]);
    if (~i) g_lMenuID = llListReplaceList(g_lMenuID, [rcpt, kMenuID], i, i+g_iMenuStride-1);
    else g_lMenuID += [rcpt, kMenuID];
}

Menu(string name, key id, integer auth) {
    string prompt = "\n" + name + " menu.\n";
    integer index = llListFindList(g_lMenuNames, [name]);
    if (index != -1) {
        list utility;
        list items = llParseString2List(llList2String(g_lMenus, index), ["|"], []);
        if (name == "Main") {
            if (g_iLocked) items = ["UNLOCK"] + items ;
            else items = ["LOCK"] + items ;
            //utility = [EXIT];
            prompt = "Cuffs version: "+g_sVersion+ "\n" + prompt;
        } else utility = [UPMENU];

        Dialog(id, prompt, items, utility, 0, auth);
    }
}

Autolock() {
    if (g_iAutoLock) {
        HandleMenuRemove("Options|" + AUTOLOCK_OFF);
        HandleMenuResponse("Options|" + AUTOLOCK_ON);
    } else {
        HandleMenuRemove("Options|" + AUTOLOCK_ON);
        HandleMenuResponse("Options|" + AUTOLOCK_OFF);
    }
}

UserCommand(integer iAuth, string str, key id) {
    if (iAuth < CMD_OWNER || iAuth > CMD_WEARER) return;

    list params = llParseString2List(str, [" "], []);
    string cmd = llList2String(params, 0);

    if (str == "menu" ) Menu("Main", id, iAuth);
    else if (cmd == "menu" ) Menu(llList2String(params, 1), id, iAuth);
    else if (cmd == "menuto") {
        key av = (key)llList2String(params, 1);
        if (KeyIsAv(av)) Menu("Main", av, iAuth);
    } else if (cmd == "fixmenus") {
        Notify(id, "Rebuilding menu.  This may take several seconds.",FALSE);
        MenuInit();
    } else if (str == "lock" && g_iLocked == 0) {
        if (iAuth >= CMD_OWNER && iAuth <= CMD_WEARER) {
            //primary owners and wearer can lock and unlock. no one else
            g_iLocked = iAuth;
            llMessageLinked(LINK_THIS, RLV_CMD, "detach=n", id);
            llMessageLinked(LINK_THIS, LM_SETTING_SAVE, "locked="+(string)g_iLocked, "");
            llPlaySound(g_sLockSound, 1.0);
            SetLockElementAlpha();
            // owner = id; //need to store the one who locked (who has to be also owner) here
            Notify(id, "Locked.", FALSE);
            if (id!=g_kWearer) llOwnerSay("Your cuffs has been locked.");
        } else Notify(id, "Sorry, you can't lock the cuffs.", FALSE);
    } else if (str == "unlock" && g_iLocked !=0) {
        if (iAuth <= g_iLocked) {
            //primary owners can lock and unlock. no one else
            g_iLocked = FALSE;
            llMessageLinked(LINK_THIS, RLV_CMD, "detach=y", id);
            llMessageLinked(LINK_THIS, LM_SETTING_SAVE, "locked=0", "");
            llPlaySound(g_sUnLockSound, 1.0);
            SetLockElementAlpha();
            Notify(id, "Unlocked.", FALSE);
            if (id!=g_kWearer) llOwnerSay("Your cuffs has been unlocked.");
        } else Notify(id, "Sorry, you can't unlock the cuffs.", FALSE);
    } else if (str == "update") {
        if (id == g_kWearer) {
            Notify(id, "Searching Cuffs Updater...", FALSE);
            g_iUpdateListen = llListen(g_iUpdateChan, "", "", "");
            llWhisper(g_iUpdateChan, "UPDATE|" + g_sVersion);
            g_iWaitUpdate = TRUE;
            llSetTimerEvent(5.0);
        } else Notify(id, "Sorry, only wearer can undate the cuffs.", FALSE);
    } else if (str == "autolock") {
        if (iAuth <= g_iAutoLock || g_iAutoLock==0) {
            if (g_iAutoLock == 0) g_iAutoLock = iAuth;
            else g_iAutoLock = 0;
            Autolock();
            llMessageLinked(LINK_THIS, LM_SETTING_SAVE, "autolock="+(string)g_iAutoLock, "");
        } else Notify(id, "Sorry, you can't switch Autolock.", FALSE);
    }
}

BuildLockElementList() {
    integer n;
    integer iLinkCount = llGetNumberOfPrims();
    // clear list just in case
    g_lOpenLockElements = [];
    g_lClosedLockElements = [];
    //root prim is 1, so start at 2
    for (n = 2; n <= iLinkCount; n++) {
        string name = llList2String(llParseString2List(llGetLinkName(n),["~"],[]),0);
        // check inf name is lock name
        if (name == "Lock" || name == "ClosedLock") g_lClosedLockElements += [n];
        else if (name == "OpenLock") g_lOpenLockElements += [n];
    }
}

SetLockElementAlpha() {
    if (g_iHide) return ; // ***** if collar is hide, don't do anything
    //loop through stored links, setting alpha if element type is lock

    integer lock;
    if (g_iLocked > 0) lock = 1;
    else lock = 0;

    integer i;
    integer iLinkElements = llGetListLength(g_lOpenLockElements);
    for (i = 0; i < iLinkElements; i++) {
        llSetLinkAlpha(llList2Integer(g_lOpenLockElements,i), !lock, ALL_SIDES);
    }
    iLinkElements = llGetListLength(g_lClosedLockElements);
    for (i = 0; i < iLinkElements; i++) {
        llSetLinkAlpha(llList2Integer(g_lClosedLockElements,i), lock, ALL_SIDES);
    }
}

MenuInit() {
    g_lMenuNames = ["Main", "Options"];
    g_lMenus = ["",""];
    integer n;
    integer stop = llGetListLength(g_lMenuNames);
    for (n = 0; n < stop; n++) {
        string name = llList2String(g_lMenuNames, n);
        if (name != "Main") {
            //make each submenu appear in Main
            HandleMenuResponse("Main|"+ name);
            //request children of each submenu
            llMessageLinked(LINK_THIS, MENUNAME_REQUEST, name, "");
        }
    }
    HandleMenuResponse("Options|Fix Menus");
    Autolock();
    llMessageLinked(LINK_THIS, MENUNAME_REQUEST, "Main", "");
}

HandleMenuResponse(string entry) {
    list params = llParseString2List(entry, ["|"], []);
    string name = llList2String(params, 0);
    integer index = llListFindList(g_lMenuNames, [name]);
    if (index != -1) {
        //debug("we handle " + name);
        string submenu = llList2String(params, 1);
        //only add submenu if not already present
        //debug("adding button " + submenu);
        list guts = llParseString2List(llList2String(g_lMenus, index), ["|"], []);
        //debug("existing buttons for " + name + " are " + llDumpList2String(guts, ","));
        if (llListFindList(guts, [submenu]) == -1) {
            guts += [submenu];
            guts = llListSort(guts, 1, TRUE);
            g_lMenus = llListReplaceList(g_lMenus, [llDumpList2String(guts, "|")], index, index);
        }
    }
}

HandleMenuRemove(string entry) {
    //str should be in form of parentmenu|childmenu
    list params = llParseString2List(entry, ["|"], []);
    string parent = llList2String(params, 0);
    string child = llList2String(params, 1);
    integer index = llListFindList(g_lMenuNames, [parent]);
    if (index != -1) {
        list guts = llParseString2List(llList2String(g_lMenus, index), ["|"], []);
        integer gutindex = llListFindList(guts, [child]);
        //only remove if it's there
        if (gutindex != -1) {
            guts = llDeleteSubList(guts, gutindex, gutindex);
            g_lMenus = llListReplaceList(g_lMenus, [llDumpList2String(guts, "|")], index, index);
        }
    }
}

default {
    on_rez(integer param) {
        if (llGetAttached()>0 && g_sDetachTime != "") NotifyOwners("secondlife:///app/agent/"+(string)g_kWearer+"/about has detached me while locked ("+g_sDetachTime+")!");
        llResetScript();
    }

    attach(key id) {
        if (g_iLocked > 0 && id == NULL_KEY) g_sDetachTime = llGetTimestamp();
    }

    state_entry() {
        g_kWearer = llGetOwner();
        BuildLockElementList();
        g_iScriptCount = llGetInventoryNumber(INVENTORY_SCRIPT);
        g_iHide = !(integer)llGetAlpha(ALL_SIDES);
        g_iWaitRebuild = TRUE;
        llSetTimerEvent(1.0);
    }

    touch_start(integer num) {
        //llMessageLinked(LINK_THIS, CMD_NOAUTH, "menu "+ "Main", llDetectedKey(0));
        llMessageLinked(LINK_THIS, CMD_NOAUTH, "menu", llDetectedKey(0));
    }

    link_message(integer sender, integer num, string str, key id) {
        if (num >= CMD_OWNER && num <= CMD_WEARER) UserCommand(num, str, id);
        else if (num == MENUNAME_RESPONSE) HandleMenuResponse(str);
        else if (num == MENUNAME_REMOVE) HandleMenuRemove(str);
        else if (num == LM_SETTING_RESPONSE) {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if (token == "locked") {
                g_iLocked = (integer)value;
                if (g_iLocked > 0) llMessageLinked(LINK_THIS, RLV_CMD, "detach=n", "");
                else llMessageLinked(LINK_THIS, RLV_CMD, "detach=y", "");
                //SetLockElementAlpha();
            } else if (token == "autolock") {
                g_iAutoLock = (integer)value;
                if (g_iAutoLock > 0 && g_iLocked == 0) {
                    g_iLocked = g_iAutoLock;
                    llMessageLinked(LINK_THIS, RLV_CMD, "detach=n", NULL_KEY);
                    llMessageLinked(LINK_THIS, LM_SETTING_SAVE, "locked="+(string)g_iLocked, "");
                    //llPlaySound(g_sLockSound, 1.0);
                }
                Autolock();
            } else if (token == "owner") g_lOwners = llParseString2List(value, [","], []);
            if (str == "settings=sent") SetLockElementAlpha();
        } else if (num == LM_SETTING_SAVE) {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if (token == "owner") g_lOwners = llParseString2List(value, [","], []);
        } else if (num == RLV_REFRESH || num == RLV_CLEAR || num == RLV_ON) {
            if (g_iLocked) llMessageLinked(LINK_THIS, RLV_CMD, "detach=n", "");
            else llMessageLinked(LINK_THIS, RLV_CMD, "detach=y", "");
        } else if (num == DIALOG_RESPONSE) {
            integer index = llListFindList(g_lMenuID, [id]);
            if (~index) {
                g_lMenuID = llDeleteSubList(g_lMenuID, index-1, index-2+g_iMenuStride);
                //got a menu response meant for us.  pull out values
                list params = llParseString2List(str, ["|"], []);
                key av = (key)llList2String(params, 0);
                string msg = llList2String(params, 1);
                //integer page = (integer)llList2String(params, 2);
                integer auth = (integer)llList2String(params, 3);

                if (msg == UPMENU) Menu("Main", av, auth);
                else if (msg == "LOCK") {
                    UserCommand(auth, "lock", av);
                    Menu("Main", av, auth);
                } else if (msg == "UNLOCK") {
                    UserCommand(auth, "unlock", av);
                    Menu("Main", av, auth);
                } else if (msg == "Fix Menus") UserCommand(auth, "fixmenus", av);
                else if (msg == UPDATE) UserCommand(auth, "update", av);
                else if (msg == AUTOLOCK_ON || msg == AUTOLOCK_OFF) {
                    UserCommand(auth, "autolock", av);
                    Menu("Options", av, auth);
                } else llMessageLinked(LINK_THIS, auth, "menu "+msg, av);
            }
        } else if (num == DIALOG_TIMEOUT) {
            integer index = llListFindList(g_lMenuID, [id]);
            if (~index) g_lMenuID = llDeleteSubList(g_lMenuID, index-1, index-2+g_iMenuStride);
        }
    }

    changed(integer change) {
        if (change & CHANGED_INVENTORY) {
            if (llGetInventoryNumber(INVENTORY_SCRIPT) != g_iScriptCount) {
                g_iWaitRebuild = TRUE;
                llSetTimerEvent(1.0);
            }
        }
        if (change & CHANGED_COLOR) {
            //check alpha
            integer iNewHide =! (integer)llGetAlpha(ALL_SIDES);
            if (g_iHide != iNewHide) {
                //check there's a difference to avoid infinite loop
                g_iHide = iNewHide;
                SetLockElementAlpha(); // update hide elements
            }
        }
    }

    listen(integer channel, string name, key id, string msg) {
        if (llGetOwnerKey(id) == g_kWearer) {
            if (llToLower(msg) == "get ready") {
                g_iWaitUpdate = FALSE;
                llSetTimerEvent(0);
                integer pin = (integer)llFrand(99999998.0) + 1; //set a random pin
                llSetRemoteScriptAccessPin(pin);
                llRegionSayTo(id, g_iUpdateChan, "ready|" + (string)pin );
                Notify(g_kWearer, "Cuffs Updater found...",FALSE);
                llListenRemove(g_iUpdateListen);
            }
        }
    }

    timer() {
        if (g_iWaitUpdate) {
            g_iWaitUpdate = FALSE;
            llListenRemove(g_iUpdateListen);
            llOwnerSay("Cuffs Updater not found!");
        }
        if (g_iWaitRebuild) {
            g_iWaitRebuild = FALSE;
            g_iScriptCount = llGetInventoryNumber(INVENTORY_SCRIPT);
            MenuInit();
        }
        if (!g_iWaitUpdate && !g_iWaitRebuild) llSetTimerEvent(0.0);
    }
}
