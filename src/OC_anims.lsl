//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

// Changes for OpenCuffs

string g_sParentMenu = "Main";
string g_sSubMenu = " Bind";

//MESSAGE MAP
integer CMD_NOAUTH = 0;
integer CMD_OWNER = 500;
//integer CMD_TRUST = 501;
//integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
//integer CMD_EVERYONE = 504;

integer CMD_SAFEWORD = 510;

integer LM_SETTING_SAVE = 2000;
//integer LM_SETTING_REQUEST = 2001;
integer LM_SETTING_RESPONSE = 2002;
integer LM_SETTING_DELETE = 2003;
//integer LM_SETTING_EMPTY = 2004;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;

integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;
integer RLV_CLEAR = 6002;
integer RLV_OFF = 6100;
integer RLV_ON  = 6101;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

string UPMENU = "▲";

integer LM_CUFF_CMD  = -551001; // used as channel for linkemessages - sending commands
integer LM_CUFF_CHAINTEXTURE = -551003; // used as channel for linkedmessages - sending the choosen texture to the cuff
integer LM_CUFF_SEND = -555000;

string g_sArmMenu = "Arm Cuffs";
string g_sLegMenu = "Leg Cuffs";
// stay mode when legs are cuffed
string g_sStayModeFixed = "Stay: Fixed";
string g_sStayModeSlow = "Stay: Slow";
string g_sStayModeFree = "Stay: Free";
string g_sStayModeToken = "stay";
string g_sStopAll = "Stop all";
string g_sStopCommand = "Stop"; // command to stop an animation

// RLV restriction when chained
string g_sRLVModeEnabled = "▣ RLV Restricions";
string g_sRLVModeDisabled = "☐ RLV Restricions";
string g_sRLVModeToken = "rest";

key g_kWearer; // key of the owner/wearer
key g_kCuffKey;

list g_lMenuIDs;  //three strided list of avkey, dialogid, and menuname
integer g_iMenuStride = 3;

string g_sModToken = "rlac"; // valid token for this module
list g_lModTokens = ["rlac","orlac","irlac"]; // list of attachment points in this cuff, only need for the main cuff, so i dont want to read that from prims

string g_sLGChainTexture="";

// Cleo: For Communication with AOs
integer g_iArmAnimRunning = FALSE;  // to make sure AOs get only switched off or on when needed
integer g_iLegAnimRunning = FALSE;  // to make sure AOs get only switched off or on when needed

// variable for staying in place
integer g_iStay = FALSE;

integer g_iStayModeFixed = FALSE; // instead of false we use a very high value
integer g_iStayModeAuth = FALSE; // instead of false we use a very high value

// variable for staying in place
integer g_iRLVModeAuth = FALSE;
integer g_iRLVArms = FALSE;
integer g_iRLVLegs = FALSE;

// slowing down wearer
vector g_vBase_impulse = <0.05,0,0>;
integer g_iDuration = 10;
integer g_iStart_time;

integer g_iLastrank = 10000;

string g_sHoverToken = "hover";
float g_fHoverIncrement = 0.02;
list g_lHeights;
integer g_iRLVA_ON;

//===============================================================================
// AK - Cuff - functions & variables
//===============================================================================

string g_sArmActAnim = "";
list g_lArmLocks;
list g_lArmAnims;
list g_lArmChains;

string g_sLegActAnim = "";
list g_lLegLocks;
list g_lLegAnims;
list g_lLegChains;

string g_sCuffsFile = "Cuffs";
integer g_iLine;
key g_kQuery;

integer ARMS = FALSE ;
integer LEGS = FALSE ;

string  g_sActAAnim = ""; // arm anim
string  g_sActLAnim = ""; // leg anim

integer g_iOverride = 0;
float   g_fOverrideTime = 0.25;
integer g_iInOverride = FALSE;
integer g_iAOState = TRUE;
integer g_iRESTART;

MessageAOs(string sONOFF, string sWhat) { //send string as "ON"  / "OFF" saves 2 llToUpper
    integer g_iInterfaceChannel = (integer)("0x" + llGetSubString(g_kWearer,30,-1));
    llRegionSayTo(g_kWearer, g_iInterfaceChannel, "CollarCommand|499|ZHAO_"+sWhat+sONOFF);
    llRegionSayTo(g_kWearer, -782690, "ZHAO_"+sWhat+sONOFF);
    llRegionSayTo(g_kWearer, -8888,(string)g_kWearer+"boot"+llToLower(sONOFF)); //for Firestorm AO
}

DoAnim(string sInfo, string sAnim) {
    // works only if the animation is found in inventory
    if (llGetInventoryType(sAnim) == INVENTORY_ANIMATION || llToLower(sAnim) == "stop") {
        if (llGetPermissionsKey() != NULL_KEY) {
            if (sInfo == "a" || sInfo == "*") { // arm anim
                StartAnim(g_sActAAnim, sAnim);
                g_sActAAnim = "";
                if (llToLower(sAnim) != "stop") {
                    g_sActAAnim = sAnim;
                    g_iArmAnimRunning = TRUE;
                } else g_iArmAnimRunning = FALSE;
            }
            if (sInfo == "l" || sInfo == "*") { // leg anim
                StartAnim(g_sActLAnim, sAnim);
                g_sActLAnim = "";
                if (llToLower(sAnim) != "stop") {
                    g_sActLAnim = sAnim;
                    g_iLegAnimRunning = TRUE;
                } else g_iLegAnimRunning = FALSE;
            }

            // now check if AOState has to be changed
            if (g_iAOState) { // AO running atm
                // disable AO if an arm OR a leg anim runs
                if (g_iArmAnimRunning == TRUE || g_iLegAnimRunning == TRUE) MessageAOs("OFF","STAND");
                g_iAOState = FALSE;
            } else { // AO is in sleep
                // enable AO if no arm AND no leg anim runs
                if (g_iArmAnimRunning == FALSE && g_iLegAnimRunning == FALSE) MessageAOs("ON","STAND");
                g_iAOState = TRUE;
            }
        }
    }
}

StartAnim(string sActAnim, string sAnim) {
    if (llGetPermissions() & PERMISSION_TRIGGER_ANIMATION) {
        if (sActAnim != "") {
            llSetTimerEvent(0);
            g_iOverride = FALSE;
            llStopAnimation(sActAnim);
        }
        if (llToLower(sAnim) != "stop") {
            llStartAnimation(sAnim);
            g_iOverride = TRUE;
            llSetTimerEvent(g_fOverrideTime);
        }
    }
}

Override() {
    if (!g_iInOverride) {
        g_iInOverride = TRUE;
        if (llGetPermissions()& PERMISSION_TRIGGER_ANIMATION) {
            if (g_iOverride && g_sActAAnim != "") {
                llStopAnimation(g_sActAAnim);
                llStartAnimation(g_sActAAnim);
            }
            if (g_iOverride && g_sActLAnim != "") {
                llStopAnimation(g_sActLAnim);
                llStartAnimation(g_sActLAnim);
            }
        }
        g_iInOverride = FALSE;
    }
}

LoadCuffsLocks() {
    if (llGetInventoryType(g_sCuffsFile) == INVENTORY_NOTECARD) {
        g_iLine = 0;
        g_lArmLocks = g_lArmAnims = g_lArmChains = [];
        g_lLegLocks = g_lLegAnims = g_lLegChains = [];
        g_kQuery = llGetNotecardLine(g_sCuffsFile, g_iLine);
    } else llOwnerSay(g_sCuffsFile+" notecard not found!\nAnimations and chains not loaded!");
}

LoadLocksParse(string data) {
    if (data == EOF) {
        g_lArmLocks = ["*Stop*"] + g_lArmLocks;
        g_lArmAnims = [""] + g_lArmAnims;
        g_lArmChains = [""] + g_lArmChains;
        g_lLegLocks = ["*Stop*"] + g_lLegLocks;
        g_lLegAnims = [""] + g_lLegAnims;
        g_lLegChains = [""] + g_lLegChains;
    } else {
        data = llStringTrim(data, STRING_TRIM);
        if (data == "ARMS") {
            ARMS = TRUE;
            LEGS = FALSE;
        } else if (data == "LEGS") {
            ARMS = FALSE;
            LEGS = TRUE;
        } else if (llGetSubString(data,0,0)!="#") {
            list lock = llParseString2List( data, ["|"], []);
            if (llGetListLength(lock) == 3) {
                if (ARMS) {
                    g_lArmLocks += [llList2String(lock,0)];
                    g_lArmAnims += [llList2String(lock,1)];
                    g_lArmChains += [llList2String(lock,2)];
                }
                if (LEGS) {
                    g_lLegLocks += [llList2String(lock,0)];
                    g_lLegAnims += [llList2String(lock,1)];
                    g_lLegChains += [llList2String(lock,2)];
                }
            }
        }
        g_iLine++ ;
        g_kQuery = llGetNotecardLine(g_sCuffsFile, g_iLine);
    }
}


DoChains(key kID, string sChain, string sLink) {
    list lParsed = llParseString2List( sChain, [ "~" ], []);
    integer iCnt = llGetListLength(lParsed);
    integer i = 0;
    for (i = 0; i < iCnt; i++) Chains(kID, llList2String(lParsed, i), sLink);
    lParsed = [];
}

Chains(key kID, string sChain, string sLink) {
    list lParsed = llParseString2List(sChain, [ "=" ], []);
    string sTo = llList2String(lParsed,0);
    string sFrom = llList2String(lParsed,1);
    string sCmd;
    if (sLink=="link") {
        if (g_sLGChainTexture=="") sCmd="link";
        else sCmd="link "+g_sLGChainTexture;
    } else sCmd="unlink";

    if (~llListFindList(g_lModTokens,[sTo])) {
        llMessageLinked(LINK_SET, LM_CUFF_CMD, "chain=" + sChain + "=" + sCmd, g_kCuffKey);
    } else SendCmd(sTo, "chain=" + sChain + "=" + sCmd, g_kCuffKey);
}

CallArmAnim(string sMsg, key kID) {
    integer index = -1;
    string sAnim = "";
    string sChain = "";
    if (g_sArmActAnim != "") index = llListFindList(g_lArmLocks, [g_sArmActAnim]);
    if (~index) {
        sChain = llList2String(g_lArmChains, index);
        DoChains(kID, sChain, "unlink");
    }
    if (sMsg == "Stop") {
        g_sArmActAnim = "";
        DoAnim("a", "Stop");
    } else {
        index = llListFindList(g_lArmLocks, [sMsg]);
        if (~index) {
            g_sArmActAnim = sMsg;
            sAnim = llList2String(g_lArmAnims, index);
            sChain = llList2String(g_lArmChains, index);
            DoAnim("a", sAnim);
            DoChains(kID, sChain, "link");
        }
    }

    if (g_iStayModeAuth > 0 && g_iLegAnimRunning == TRUE) StayPut();
    else UnStay();
    RLVRestrictions(TRUE);
}

AdjustHeight(float height) {
    if (g_iRLVA_ON) llMessageLinked(LINK_THIS,RLV_CMD,"adjustheight:1;0;"+(string)height+"=force",g_kWearer);
}

CallLegAnim(string sMsg, key kID) {
    integer index = -1;
    string sAnim = "";
    string sChain = "";
    if (g_sLegActAnim != "") index = llListFindList(g_lLegLocks, [g_sLegActAnim]);
    if (~index) {
        sChain = llList2String(g_lLegChains, index);
        DoChains(kID, sChain, "unlink");
    }
    if (sMsg == "Stop") {
        g_sLegActAnim = "";
        DoAnim("l", "Stop");
        AdjustHeight(0.0);
    } else {
        index = llListFindList(g_lLegLocks, [sMsg]);
        if (~index) {
            g_sLegActAnim = sMsg;
            sAnim = llList2String(g_lLegAnims, index);
            sChain = llList2String(g_lLegChains, index);
            if (sAnim == "*none*") DoAnim("l", "Stop");
            else {
                DoAnim("l", sAnim);
                index = llListFindList(g_lHeights,[g_sLegActAnim]);
                if (~index) AdjustHeight(llList2Float(g_lHeights,index+1));
                else AdjustHeight(0.0);
            }
            DoChains(kID, sChain, "link");
        }
    }

    if (g_iStayModeAuth > 0 && g_iLegAnimRunning == TRUE) StayPut();
    else UnStay();
    RLVRestrictions(TRUE);
}

StayPut() {
    if (g_iStay) return;
    if (g_iLegAnimRunning) {
        g_iStay = TRUE;
        if (g_iStayModeFixed) llTakeControls(CONTROL_LEFT|CONTROL_RIGHT|CONTROL_UP|CONTROL_ROT_LEFT|CONTROL_ROT_RIGHT|CONTROL_LBUTTON|CONTROL_ML_LBUTTON,FALSE,FALSE);
        else llTakeControls(CONTROL_UP|CONTROL_FWD|CONTROL_BACK, TRUE, FALSE);
        llOwnerSay("You are bound, so your movement is restricted.");
    }
}

UnStay() {
    if (!g_iStay) return;
    g_iStay = FALSE;
    llReleaseControls();
    if (llGetAttached()) llRequestPermissions(g_kWearer,PERMISSION_TRIGGER_ANIMATION|PERMISSION_TAKE_CONTROLS);
    llOwnerSay("You are free to move again.");
}

RLVRestrictions(integer ShowMessages) {
    if (g_iRLVModeAuth!=FALSE) {
        if (g_iArmAnimRunning) {
            if (!g_iRLVArms) {
                g_iRLVArms=TRUE;
                llMessageLinked(LINK_THIS, RLV_CMD, "edit=n,rez=n,showinv=n,fartouch=n", "");
                if (ShowMessages) llOwnerSay("Your arms are bound, so you can do only limited things.");
            }
        } else {
            if (g_iRLVArms) {
                g_iRLVArms=FALSE;
                llMessageLinked(LINK_THIS, RLV_CMD, "edit=y,rez=y,showinv=y,fartouch=y", "");
                if (ShowMessages) llOwnerSay("Your arms are free to touch things again.");
            }
        }

        if (g_iLegAnimRunning) {
            if (!g_iRLVLegs) {
                g_iRLVLegs=TRUE;
                llMessageLinked(LINK_THIS, RLV_CMD, "sittp=n,tplm=n,tploc=n,tplure=n,fly=n", "");
                if (ShowMessages) llOwnerSay("Your legs are bound, so you can only limited move.");
            }
        } else {
            if (g_iRLVLegs) {
                g_iRLVLegs=FALSE;
                llMessageLinked(LINK_THIS, RLV_CMD, "sittp=y,tplm=y,tploc=y,tplure=y,fly=y", "");
                if (ShowMessages) llOwnerSay("Your legs are free to you can move normal again.");
            }
        }
    } else {
        if (g_iRLVArms) {
            g_iRLVArms=FALSE;
            llMessageLinked(LINK_THIS, RLV_CMD, "edit=y,rez=y,showinv=y,fartouch=y", "");
            if (ShowMessages) llOwnerSay("Your are free to touch things again.");
        }
        if (g_iRLVLegs) {
            g_iRLVLegs=FALSE;
            llMessageLinked(LINK_THIS, RLV_CMD, "sittp=y,tplm=y,tploc=y,tplure=y,fly=y", "");
            if (ShowMessages) llOwnerSay("Your legs are free to you can move normal again.");
        }
    }
}


SendCmd(string sSendTo, string sCmd, key kID) {
    llMessageLinked(LINK_THIS, LM_CUFF_SEND, sSendTo + "|" + sCmd, kID);
}

integer startswith(string haystack, string needle) {
    // http://wiki.secondlife.com/wiki/llSubStringIndex
    return llDeleteSubString(haystack, llStringLength(needle), -1) == needle;
}

string NameURI(key kID) {
    return "secondlife:///app/agent/"+(string)kID+"/about";
}

Notify(key kID, string sMsg, integer iAlsoNotifyWearer) {
    if (kID == g_kWearer) llOwnerSay(sMsg);
    else {
        if (llGetAgentSize(kID)!=ZERO_VECTOR) llRegionSayTo(kID,0,sMsg);
        else llInstantMessage(kID, sMsg);
        if (iAlsoNotifyWearer) llOwnerSay(sMsg);
    }
}

Dialog(key kID, string sPrompt, list lChoices, list lUtility, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_THIS, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtility, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}

DoMenu(key id, integer auth, string menutype, integer page) {
    string prompt;
    list buttons;
    list utility = [UPMENU];
    if (menutype == g_sSubMenu) {
        prompt = "Pick an option.";
        buttons = [g_sArmMenu, g_sLegMenu, g_sStopAll];
        //fill in your button list here
        if (g_iStayModeAuth>0) {
            if (g_iStayModeFixed) buttons += [g_sStayModeFixed];
            else buttons += [g_sStayModeSlow];
        } else buttons += [g_sStayModeFree];

        if (g_iRLVModeAuth>0) buttons += [g_sRLVModeEnabled];
        else buttons += [g_sRLVModeDisabled];
    }
    else if (menutype == g_sArmMenu) {
        prompt = "Pick arm cuffs bound:";
        buttons = g_lArmLocks;
    }
    else if (menutype == g_sLegMenu) {
        prompt = "Pick leg cuffs bound:";
        buttons = g_lLegLocks;
        if (g_iRLVA_ON) utility = ["↑", "↓", UPMENU];
    }
    Dialog(id, prompt, buttons, utility, page, auth, menutype);
}

UserCommand(integer iAuth, string sMsg, key kID) {
    if (iAuth < CMD_OWNER || iAuth > CMD_WEARER) return;

    if (sMsg == "menu "+g_sSubMenu) DoMenu(kID, iAuth, g_sSubMenu, 0);
    //else if (sMsg == "menu "+g_sArmMenu) DoMenu(kID, iAuth, g_sArmMenu);
    //else if (sMsg == "menu "+g_sLegMenu) DoMenu(kID, iAuth, g_sLegMenu);
    else if (startswith(sMsg,"staymode")) {
        if (g_iStayModeAuth != 0 && g_iStayModeAuth < iAuth) {
            Notify(kID,"You are not allowed to change the stay mode.",FALSE);
        } else if (sMsg == "staymode=off") { // disable the stay mode
            g_iStayModeAuth = FALSE;
            UnStay();
            llMessageLinked(LINK_THIS, LM_SETTING_DELETE, g_sStayModeToken, "");
            Notify(kID,NameURI(g_kWearer)+" will now be able to move, even when the legs are bound.",TRUE);
        } else if (sMsg == "staymode=slow") { // enable the slow mode
            g_iStayModeAuth = iAuth;
            g_iStayModeFixed = FALSE;
            StayPut();
            llMessageLinked(LINK_THIS, LM_SETTING_SAVE, g_sStayModeToken+"="+(string)iAuth+",S", "");
            Notify(kID,NameURI(g_kWearer)+" will now only able to move very slowly, when the legs are bound.", TRUE);
        } else if (sMsg == "staymode=on") { // enable the stay mode
            g_iStayModeAuth = iAuth;
            g_iStayModeFixed = TRUE;
            StayPut();
            llMessageLinked(LINK_THIS, LM_SETTING_SAVE, g_sStayModeToken+"="+(string)iAuth+",F", "");
            Notify(kID,NameURI(g_kWearer)+ " will now NOT be able to move, when the legs are bound.", TRUE);
        }
    } else if (sMsg == "rlvmode=off") { // disable the stay mode
        if (g_iRLVModeAuth >= iAuth) {
            g_iRLVModeAuth = FALSE;
            RLVRestrictions(TRUE);
            llMessageLinked(LINK_THIS, LM_SETTING_DELETE, g_sRLVModeToken,"");
            Notify(kID,NameURI(g_kWearer)+ " will now NOT be under RLV restrictions when bound.", TRUE);
        } else Notify(kID,"You are not allowed to change the restriction mode.",FALSE);
    } else if (sMsg == "rlvmode=on") { // enable the stay mode
        g_iRLVModeAuth = iAuth;
        RLVRestrictions(TRUE);
        llMessageLinked(LINK_THIS, LM_SETTING_SAVE, g_sRLVModeToken+"="+(string)iAuth, "");
        Notify(kID,NameURI(g_kWearer)+ " will now be under RLV restrictions when bound.", TRUE);
    } else if (startswith(sMsg,"a:")) {
        if (iAuth <= g_iLastrank) {
            if (llGetSubString(sMsg, 2,-1) == "Stop") g_iLastrank = 10000;
            else g_iLastrank = iAuth;
            CallArmAnim(llGetSubString(sMsg, 2,-1), kID);
        }
    } else if (startswith(sMsg,"l:")) {
        if (iAuth <= g_iLastrank) {
            if (llGetSubString(sMsg, 2,-1) == "Stop") g_iLastrank = 10000;
            else g_iLastrank = iAuth;
            CallLegAnim(llGetSubString(sMsg, 2,-1), kID);
        }
    } else if (sMsg == "*:Stop") {
        if (iAuth <= g_iLastrank) {
            g_iLastrank = 10000;
            CallArmAnim("Stop", kID);
            CallLegAnim("Stop", kID);
        }
    }
}

default {

    on_rez(integer param) {
        g_kCuffKey = llGetKey();
        if (g_kWearer != llGetOwner()) llResetScript();
        else if (g_sArmActAnim != "" || g_sLegActAnim != "") {
            g_iRESTART = TRUE;
            llSetTimerEvent(4.0);
        }
    }

    attach(key id) {
        if (id!=NULL_KEY) llRequestPermissions(id, PERMISSION_TRIGGER_ANIMATION|PERMISSION_TAKE_CONTROLS);
    }

    state_entry() {
        LoadCuffsLocks();
        g_kWearer = llGetOwner();
        if (llGetAttached()) llRequestPermissions(g_kWearer,PERMISSION_TRIGGER_ANIMATION|PERMISSION_TAKE_CONTROLS);
        llMessageLinked(LINK_THIS, LM_CUFF_CMD, "settoken=" + g_sModToken, g_kWearer);
    }

    link_message(integer iSenderNum, integer iNum, string sMsg, key kID) {
        if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) UserCommand(iNum, sMsg, kID);
        else if (iNum == MENUNAME_REQUEST && sMsg == g_sParentMenu) {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        }
        else if (iNum == LM_CUFF_CHAINTEXTURE) {
            g_sLGChainTexture = sMsg;
            if (g_sArmActAnim!="") CallArmAnim(g_sArmActAnim,g_kWearer);
        }
        else if (iNum == RLV_REFRESH) RLVRestrictions(FALSE);
        else if (iNum == RLV_OFF) g_iRLVA_ON = FALSE;
        else if (iNum == RLV_ON) g_iRLVA_ON = TRUE;
        else if (iNum == RLV_CLEAR) {
            g_iRLVArms = FALSE;
            g_iRLVLegs = FALSE;
            RLVRestrictions(FALSE);
        }
        else if (iNum == CMD_SAFEWORD) {
            llMessageLinked(LINK_THIS, CMD_NOAUTH, "*:Stop", kID);
        }
        else if (iNum == LM_SETTING_RESPONSE) {
            list params = llParseString2List(sMsg, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);

            if (token == g_sStayModeToken) {
                list l=llParseString2List(value,[","],[]);
                integer n = (integer)llList2String(l,0);
                string s = llList2String(l,1);
                if (n>0) {
                    g_iStayModeAuth=n;
                    if (s=="F") g_iStayModeFixed = TRUE;  //fixed
                    else g_iStayModeFixed = FALSE;
                    StayPut();
                } else {
                    g_iStayModeAuth = FALSE;
                    UnStay();
                }
            } else if (token == g_sRLVModeToken) {
                integer n = (integer)value;
                if (n > 0) g_iRLVModeAuth = n;
                else g_iRLVModeAuth = FALSE;
                RLVRestrictions(TRUE);
            } else if (token == g_sHoverToken) g_lHeights = llParseString2List(value,[","],[]);
        } else if (iNum == DIALOG_RESPONSE) {
            integer index = llListFindList(g_lMenuIDs, [kID]);
            if (~index) {
                list menuparams = llParseString2List(sMsg, ["|"], []);
                key kAV = (key)llList2String(menuparams, 0);
                string msg = llList2String(menuparams, 1);
                integer page = (integer)llList2String(menuparams, 2);
                integer auth = (integer)llList2String(menuparams, 3);

                string sMenuType = llList2String(g_lMenuIDs, index+1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, index-1, index-2+g_iMenuStride);

                if (sMenuType == g_sSubMenu) {
                    if (msg == UPMENU) {
                        llMessageLinked(LINK_THIS, auth, "menu "+g_sParentMenu, kAV);
                        return;
                    }
                    else if (msg == g_sStopAll) llMessageLinked(LINK_THIS, auth, "*:Stop", kAV);
                    else if (msg == g_sStayModeFixed) UserCommand(auth, "staymode=off", kAV);
                    else if (msg == g_sStayModeSlow) UserCommand(auth,  "staymode=on", kAV);
                    else if (msg == g_sStayModeFree) UserCommand(auth, "staymode=slow", kAV);
                    else if (msg == g_sRLVModeEnabled) UserCommand(auth, "rlvmode=off", kAV);
                    else if (msg == g_sRLVModeDisabled) UserCommand(auth, "rlvmode=on", kAV);
                    else if (msg == g_sArmMenu) sMenuType = g_sArmMenu;
                    else if (msg == g_sLegMenu) sMenuType = g_sLegMenu;
                    DoMenu(kAV, auth, sMenuType, page);
                }
                else if (sMenuType == g_sArmMenu) {
                    if (msg == UPMENU) sMenuType = g_sSubMenu;
                    else if (~llListFindList(g_lArmLocks, [msg])) {
                        if (msg == "*Stop*") UserCommand(auth, "a:Stop", kAV);
                        else UserCommand(auth, "a:"+msg, kAV);
                    }
                    DoMenu(kAV, auth, sMenuType, page);
                }
                else if (sMenuType == g_sLegMenu) {
                    if (msg == UPMENU) sMenuType = g_sSubMenu;
                    else if (~llListFindList(g_lLegLocks, [msg])) {
                        if (msg == "*Stop*") UserCommand(auth, "l:Stop", kAV);
                        else UserCommand(auth, "l:"+msg, kAV);
                    }
                    else if (msg == "↑" || msg == "↓") {
                        float fNewHover = g_fHoverIncrement;
                        if (msg == "↓") fNewHover = -fNewHover;
                        index = llListFindList(g_lHeights,[g_sLegActAnim]);
                        if (~index) {
                            fNewHover = fNewHover + llList2Float(g_lHeights,index+1);
                            if (fNewHover) g_lHeights = llListReplaceList(g_lHeights,[fNewHover],index+1,index+1);
                            else g_lHeights = llDeleteSubList(g_lHeights,index,index+1);
                        } else g_lHeights += [g_sLegActAnim,fNewHover];
                        AdjustHeight(fNewHover);
                        llMessageLinked(LINK_THIS,LM_SETTING_SAVE,g_sHoverToken+"="+llDumpList2String(g_lHeights,","),"");
                    }
                    DoMenu(kAV, auth, sMenuType, page);
                }
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer index = llListFindList(g_lMenuIDs, [kID]);
            if (~index) g_lMenuIDs = llDeleteSubList(g_lMenuIDs, index-1, index-2+g_iMenuStride);
        }
    }

    dataserver(key queryid, string data) {
        if (queryid == g_kQuery) LoadLocksParse(data);
    }

    changed(integer change) {
        if (change & CHANGED_OWNER) llResetScript();
        if (change & CHANGED_INVENTORY) LoadCuffsLocks();
    }

    control(key id, integer level, integer edge) {
        if (g_iStay && !g_iStayModeFixed) {
            if (edge & (CONTROL_FWD | CONTROL_BACK)) g_iStart_time = llGetUnixTime();
            float wear_off = (g_iDuration + g_iStart_time - llGetUnixTime() + 0.0)/g_iDuration;
            if (wear_off < 0) wear_off = 0;
            vector impulse = wear_off * g_vBase_impulse;
            if (level & CONTROL_FWD) llApplyImpulse(impulse, TRUE);
            else if (level & CONTROL_BACK) llApplyImpulse(-impulse, TRUE);
        }

        if (level & (CONTROL_ROT_LEFT|CONTROL_ROT_RIGHT|CONTROL_FWD|CONTROL_BACK)) Override();
    }

    run_time_permissions(integer perm) {
    }

    timer() {
        if (g_iRESTART) {
            g_iRESTART = FALSE;
            llSetTimerEvent(0);
            CallArmAnim(g_sArmActAnim, g_kCuffKey);
            CallLegAnim(g_sLegActAnim, g_kCuffKey);
            if (g_iStayModeAuth > 0 && g_iLegAnimRunning == TRUE) StayPut();
            else UnStay();
            RLVRestrictions(TRUE);
        } else if (llGetPermissions() & PERMISSION_TRIGGER_ANIMATION) {
            if (g_sActAAnim != "" ) {
                llStopAnimation(g_sActAAnim);
                llStartAnimation(g_sActAAnim);
            }
            if (g_sActLAnim != "" ) {
                llStopAnimation(g_sActLAnim);
                llStartAnimation(g_sActLAnim);
            }
        }
    }
}
