//OpenCuffs - settings

//integer CMD_NOAUTH = 0;
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
//integer MENUNAME_REMOVE = 3003;

string parentmenu = "Options";
string DUMPCACHE = "Dump Settings";
string RELOAD = "Load Defaults";

string defaultscard = "defaultsettings";
integer defaultsline = 0;

integer scriptcount; // number of script to resend if the coutn changes

key defaultslineid;
key card_key;
key g_kWearer ;

integer g_iReload = FALSE ;

list settings_pairs;// stores all settings
list settings_default; // Default settings placeholder.

Notify(key kID, string sMsg, integer iAlsoNotifyWearer) {
    if (kID == g_kWearer) llOwnerSay(sMsg);
    else {
        if (llGetAgentSize(kID)!=ZERO_VECTOR) llRegionSayTo(kID,0,sMsg);
        else llInstantMessage(kID, sMsg);
        if (iAlsoNotifyWearer) llOwnerSay(sMsg);
    }
}

integer SettingExists(list cache, string token) {
    integer idx = llListFindList(cache, [token]);
    if (idx == -1) return FALSE;
    else return TRUE;
}

list SetSetting(list cache, string token, string value) {
    integer idx = llListFindList(cache, [token]);
    if (idx == -1) cache += [token, value];
    else cache = llListReplaceList(cache, [value], idx + 1, idx + 1);
    return cache;
}

// like SetSetting, but only sets the value if there's not one already there.
list SetDefault(list cache, string token, string value) {
    integer idx = llListFindList(cache, [token]);
    if (idx == -1) {
        cache += [token, value];
        // also let the plugins know about it
        llMessageLinked(LINK_THIS, LM_SETTING_RESPONSE, token + "=" + value, "");
    }
    return cache;
}

string GetSetting(list cache, string token) {
    integer idx = llListFindList(cache, [token]);
    return llList2String(cache, idx + 1);
}

list DelSetting(list cache, string token) {
    integer idx = llListFindList(cache, [token]);
    if (idx != -1) cache = llDeleteSubList(cache, idx, idx + 1);
    return cache;
}

DumpCache() {
    string sOut = "Settings: \n";
    integer n;
    integer iStop = llGetListLength(settings_pairs);
    for (n = 0; n < iStop; n = n + 2) {
        //handle strlength > 1024
        string token = llList2String(settings_pairs, n);
        string sAdd;
        if (token) sAdd = token + "=" + llList2String(settings_pairs, n + 1) + "\n";
        if (llStringLength(sOut + sAdd) > 1024) {
            llOwnerSay("\n" + sOut);
            sOut = sAdd;
        } else sOut += sAdd;
    }
    llOwnerSay("\n" + sOut);
}

SendValues() {
    //loop through and send all the settings
    integer n;
    integer iStop = llGetListLength(settings_pairs);
    for (n = 0; n < iStop; n = n + 2) {
        string token = llList2String(settings_pairs, n);
        string value = llList2String(settings_pairs, n + 1);
        llMessageLinked(LINK_THIS, LM_SETTING_RESPONSE, token + "=" + value, "");
    }
    //tells scripts everything has be sentout
    llMessageLinked(LINK_THIS, LM_SETTING_RESPONSE, "settings=sent", "");
}

LoadCard() {
    defaultsline = 0;
    card_key = llGetInventoryKey(defaultscard);
    defaultslineid = llGetNotecardLine(defaultscard, defaultsline);
}

default {
    state_entry() {
        g_kWearer = llGetOwner();
        scriptcount = llGetInventoryNumber(INVENTORY_SCRIPT);
        LoadCard();
    }

    on_rez(integer iParam) {
        if (g_kWearer == llGetOwner()) {
            llSleep(0.5);
            SendValues();
        } else llResetScript();
    }

    dataserver(key id, string data) {
        if (id == defaultslineid) {
            if (data != EOF) {
                data = llStringTrim(data, STRING_TRIM_HEAD);
                if (llGetSubString(data, 0, 0) != "#") {
                    integer idx = llSubStringIndex(data, "=");
                    string token = llGetSubString(data, 0, idx - 1);
                    string value = llGetSubString(data, idx + 1, -1);
                    // Take multiple lines and puts them together,
                    //  workaround for llGetNotecardLine() limitation.
                    if (SettingExists(settings_default,token)) {
                        integer loc = llListFindList(settings_default, [token]) + 1;
                        value = llList2String(settings_default, loc) + "~" + value;
                    }
                    settings_default = SetSetting(settings_default, token, value);
                }
                defaultsline++;
                defaultslineid = llGetNotecardLine(defaultscard, defaultsline);
            } else {
                // Merge defaults with settings.
                string sToken;
                string sValue;
                integer count;
                for (count = 0; count < llGetListLength(settings_default); count += 2) {
                    sToken = llList2String(settings_default, count);
                    sValue = llList2String(settings_default, (count + 1));
                    settings_pairs = SetDefault(settings_pairs, sToken, sValue);
                }
                // wait a sec before sending settings, in case other scripts are
                // still resetting.
                llSleep(0.5);
                SendValues();
                Notify(id, "defaultsettings load.", TRUE);
                g_iReload = FALSE;
            }
        }
    }

    link_message(integer sender, integer iNum, string sStr, key kID) {
        if (iNum == LM_SETTING_SAVE) {
            //save the token, value
            list params = llParseString2List(sStr, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            settings_pairs = SetSetting(settings_pairs, token, value);
        } else if (iNum == LM_SETTING_REQUEST) {
            //check the cache for the token
            if (SettingExists(settings_pairs, sStr))
            llMessageLinked(LINK_THIS, LM_SETTING_RESPONSE, sStr+"="+GetSetting(settings_pairs,sStr), "");
            else llMessageLinked(LINK_THIS, LM_SETTING_EMPTY, sStr, "");
        } else if (iNum == LM_SETTING_DELETE) {
            settings_pairs = DelSetting(settings_pairs, sStr);
        } else if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) {
            if (iNum == CMD_OWNER || kID == g_kWearer) {
                if (sStr == "cachedump") DumpCache();
                else if (sStr == "menu " + DUMPCACHE) {
                    DumpCache();
                    llMessageLinked(LINK_THIS, iNum, "menu " + parentmenu, kID);
                } else if (sStr == "menu " + RELOAD) {
                    g_iReload = TRUE ;
                    Notify(kID, "Loading defaultsettings...", TRUE);
                    LoadCard();
                    //llMessageLinked(LINK_THIS, iNum, "menu " + parentmenu, kID);
                } else if (sStr == "reset" || sStr == "runaway") llResetScript();
            }
        } else if (iNum == MENUNAME_REQUEST && sStr == parentmenu) {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + DUMPCACHE, "");
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + RELOAD, "");
        }
    }

    changed(integer change) {
        if (change & CHANGED_OWNER) llResetScript();
        if (change & CHANGED_INVENTORY) {
            if (scriptcount != llGetInventoryNumber(INVENTORY_SCRIPT)) {
                SendValues();
                scriptcount = llGetInventoryNumber(INVENTORY_SCRIPT);
            }
            if (llGetInventoryKey(defaultscard) != card_key) LoadCard();
        }
    }
}