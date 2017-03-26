//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

//save owner, secowners, and group key
//check credentials when messages come in on CMD_NOAUTH, send out message on appropriate channel
//reset self on owner change

string g_sParentMenu = "Main";
string g_sSubMenu = "Access";

//MESSAGE MAP
integer CMD_NOAUTH = 0;
integer CMD_OWNER = 500;
integer CMD_TRUSTED = 501;
integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
integer CMD_EVERYONE = 504;

integer CMD_SAFEWORD = 510; // new for safeword
integer CMD_BLOCKED = 520;

integer CMD_WEARERLOCKEDOUT = 521; // added so when the sub is locked out they can use postions

integer WEARERLOCKOUT = 620; //this can change

//integer LM_SETTING_SAVE = 2000;
//integer LM_SETTING_REQUEST = 2001;
integer LM_SETTING_RESPONSE = 2002;
//integer LM_SETTING_DELETE = 2003;
integer LM_SETTING_EMPTY = 2004;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;

//***** constants ******

// range for limit range
float g_fRange = 20.0;

// ********** variables ***********

list g_lOwners;//strided list in form key,name
list g_lTrusted;//strided list in the form key,name
list g_lBlockList;//list of blacklisted UUID
list g_lTempOwner;//list of temp owners UUID.  Temp owner is just like normal owner, but can't add new owners.

key g_kGroup ;
integer g_iGroupEnabled = FALSE;

integer g_iPublicAccess = FALSE; // 0: disabled, 1: openaccess
integer g_iLimitRange = TRUE; // 0: unlimited, 1: limited
integer g_iWearerLockout;

key g_kWearer;
key g_kObject ;


/*debug(string sStr) {
    llOwnerSay(llGetScriptName() + ": " + sStr);
}*/

string NameURI(key uuid) {
    return "secondlife:///app/agent/"+(string)uuid+"/about";
}

Notify(key kID, string sMsg, integer iAlsoNotifyWearer) {
    if (kID == g_kWearer) llOwnerSay(sMsg);
    else {
        if (llGetAgentSize(kID)!=ZERO_VECTOR) llRegionSayTo(kID,0,sMsg);
        else llInstantMessage(kID, sMsg);
        if (iAlsoNotifyWearer) llOwnerSay(sMsg);
    }
}

integer in_range(key kID) {
    if (g_iLimitRange) {
        vector avpos = llList2Vector(llGetObjectDetails(kID, [OBJECT_POS]), 0);
        if (llVecDist(llGetPos(), avpos) > g_fRange) return FALSE;
        else return TRUE;
    } else return TRUE;
}

integer UserAuth(key kID, integer attachment) {
    integer auth = CMD_EVERYONE;
    string sID = (string)kID;
    if (g_iWearerLockout && kID == g_kWearer && !attachment) auth = CMD_WEARERLOCKEDOUT;
    else if (~llListFindList(g_lOwners+g_lTempOwner, [sID]))auth = CMD_OWNER;
    else if (llGetListLength(g_lOwners+g_lTempOwner) == 0 && kID == g_kWearer) auth = CMD_OWNER;
    else if (~llListFindList(g_lBlockList, [sID])) auth = CMD_BLOCKED;
    else if (~llListFindList(g_lTrusted, [sID])) auth = CMD_TRUSTED;
    else if (kID == g_kWearer) auth = CMD_WEARER;
    else if (in_range(kID)) {
        if (g_iPublicAccess) auth = CMD_GROUP;
        else if (llSameGroup(kID) && g_iGroupEnabled && kID != g_kWearer) auth = CMD_GROUP;
    }
    return auth;
}

string GetList(list temp) {
    string out;
    integer n;
    integer length = llGetListLength(temp);
    if (length > 0) {
        for (n = 0; n < length; n++) {
            out += "\n" + NameURI(llList2String(temp, n));
        }
    } else out += " none.";
    return out;
}


ShowSettings(key kID) {
    if (llGetListLength(g_lOwners)) Notify(kID, "Owners:" + GetList(g_lOwners), FALSE);
    if (llGetListLength(g_lTrusted)) Notify(kID, "Trusted:" + GetList(g_lTrusted), FALSE);
    if (llGetListLength(g_lTempOwner)) Notify(kID, "Temp Owners:" + GetList(g_lTempOwner), FALSE);
    if (llGetListLength(g_lBlockList)) Notify(kID, "Blocked: " + GetList(g_lBlockList), FALSE);
    if (g_kGroup!=NULL_KEY && g_kGroup!="") Notify(kID, "Group: secondlife:///app/group/"+(string)g_kGroup+"/about", FALSE);
    if (g_iPublicAccess) Notify(kID, "Public Access: open", FALSE);
    else Notify(kID, "Public Access: closed", FALSE);
}

UserCommand(integer iAuth, string sStr, key kID) {
    if (iAuth < CMD_OWNER || iAuth > CMD_WEARER) return;

    if (sStr == "listowners"  || sStr == "menu "+g_sSubMenu) {
        if (iAuth == CMD_OWNER || kID == g_kWearer) ShowSettings(kID);
        else Notify(kID, "Sorry, you are not allowed to see the owner list.",FALSE);
        llMessageLinked(LINK_THIS, iAuth, "menu "+g_sParentMenu, kID);
    } else if (sStr == "runaway" || sStr == "reset") {
        if (iAuth == CMD_OWNER || kID == g_kWearer) {    //IM Owners
            Notify(g_kWearer, "Running away from all owners started, your owners wil now be notified!",FALSE);
            integer n;
            integer stop = llGetListLength(g_lOwners);
            for (n = 0; n < stop; n += 2) {
                key owner = (key)llList2String(g_lOwners, n);
                if (owner != g_kWearer) Notify(owner, NameURI(g_kWearer) + " has run away!",FALSE);
            }
            Notify(g_kWearer, "Runaway finished, the cuffs will now reset!",FALSE);
            // moved reset request from settings to here to allow noticifation of owners.
            llResetScript();
        }
    }
}


default {
    state_entry() {
        //until set otherwise, wearer is owner
        //debug((string)llGetFreeMemory());
        g_kWearer = llGetOwner();
        g_kObject = (key)llList2String(llGetObjectDetails(llGetKey(), [OBJECT_GROUP]), 0);
    }

    link_message(integer sender, integer iNum, string sStr, key kID) {
        if (iNum == CMD_NOAUTH) {
            integer auth = UserAuth(kID, FALSE);
            llMessageLinked(LINK_THIS, auth, sStr, kID);
        } else if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) UserCommand(iNum, sStr, kID);
        else if (iNum == CMD_SAFEWORD) {
            integer n;
            integer stop = llGetListLength(g_lOwners+g_lTempOwner);
            for (n = 0; n < stop; n++) {
                key owner = (key)llList2String(g_lOwners+g_lTempOwner, n);
                Notify(owner, "Your sub " + NameURI(g_kWearer) + " has used the safeword. Please check on " + NameURI(g_kWearer) +"'s well-being and if further care is required.",FALSE);
            }
        } else if (iNum == WEARERLOCKOUT) {
            if (sStr == "on") g_iWearerLockout = TRUE;
            else if (sStr == "off") g_iWearerLockout = FALSE;
        } else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu) {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        } else if (iNum == LM_SETTING_RESPONSE) {
            list params = llParseString2List(sStr, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if (token == "owner") g_lOwners = llParseString2List(value, [","], []);
            else if (token == "trust") g_lTrusted = llParseString2List(value, [","], [""]);
            else if (token == "tempowner") g_lTempOwner = llParseString2List(value, [","], [""]);
            else if (token == "block") g_lBlockList = llParseString2List(value, [","], [""]);
            else if (token == "group") {
                g_kGroup = (key)value;
                if (g_kGroup!=NULL_KEY && g_kGroup!="") {
                    if (g_kGroup == g_kObject) g_iGroupEnabled = TRUE;
                    else g_iGroupEnabled = FALSE;
                } else g_iGroupEnabled = FALSE;
            }
            else if (token == "public") g_iPublicAccess = (integer)value;
            else if (token == "limitrange") g_iLimitRange = (integer)value;
        } else if (iNum == LM_SETTING_EMPTY) {
            list params = llParseString2List(sStr, ["="], []);
            string token = llList2String(params, 0);
            if (token == "owner") g_lOwners = [];
            else if (token == "trust") g_lTrusted = [];
            else if (token == "tempowner") g_lTempOwner = [];
            else if (token == "block") g_lBlockList = [];
            else if (token == "group") {
                g_kGroup = "";
                g_iGroupEnabled = FALSE;
            } else if (token == "public") g_iPublicAccess = FALSE;
            else if (token == "limitrange") g_iLimitRange = TRUE;
        }
    }

    on_rez(integer param) {
        llResetScript();
    }
}
