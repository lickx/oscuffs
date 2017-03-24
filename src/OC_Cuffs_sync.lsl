//MESSAGE MAP

integer LINK_CUFFS = 9 ;
integer LINK_UPDATE = -10;
integer REBOOT = -1000;

integer LM_CUFF_SET = -551010;

integer SETTING_SAVE = 2000;
integer SETTING_DELETE = 2003;

// ********** constants *************
list groups = ["auth","color","texture","shininess"];
///***************************

default {
    on_rez(integer param) {
        llResetScript();
    }

    state_entry() {
        llSetMemoryLimit( llGetUsedMemory() + 4096);
    }

    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum == SETTING_SAVE || iNum == SETTING_DELETE) {
            list lParams = llParseString2List(sStr, ["_"], []);            
            if (~llListFindList(groups,[llList2String(lParams, 0)])) llMessageLinked(LINK_CUFFS, LM_CUFF_SET, sStr, "");
        }        
        else if (iNum == LM_CUFF_SET && sStr == "LINK_CUFFS") LINK_CUFFS = iSender;
        else if (iNum == LINK_UPDATE && sStr == "LINK_CUFFS") LINK_CUFFS = iSender;
    }
}
