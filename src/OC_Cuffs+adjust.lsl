//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

string g_sVersion = "4.0" ;

integer g_iUpdateChan = -87383215;
integer g_iUpdateListen;
integer g_iWaitUpdate = FALSE;

// *********************************
// ************ Adjust *************

vector ConvertPos(vector pos) {
    vector out ;
    if (ATTACH == 1) { // Chest
        out.x = pos.y ;
        out.y = pos.z ;
        out.z = pos.x ;
    } else if (ATTACH == 5 || ATTACH == 20 || ATTACH == 21) { // left arm
        out.x = pos.x ;
        out.y = -pos.z ;
        out.z = pos.y ;
    } else if (ATTACH == 6 || ATTACH == 18 || ATTACH == 19) { // right arm
        out.x = pos.x ;
        out.y = pos.z ;
        out.z = -pos.y ;
    } else out = pos ;
    return out ;
}

vector ConvertRot(vector rot) {
    vector out ;
    if (ATTACH == 1) { // Chest
        out.x = rot.y ;
        out.y = rot.z ;
        out.z = rot.x ;
    } else if (ATTACH == 5 || ATTACH == 20 || ATTACH == 21) { // left arm
        out.x = rot.x ;
        out.y = -rot.z ;
        out.z = rot.y ;
    } else if (ATTACH == 6 || ATTACH == 18 || ATTACH == 19) { // right arm
        out.x = rot.x ;
        out.y = rot.z ;
        out.z = -rot.y ;
    } else out = rot ;
    return out ;
}
///////////////////////////////////////////////////////////////
ForceUpdate() {
    //workaround for https://jira.secondlife.com/browse/VWR-1168
    llSetText(".", <1,1,1>, 1.0);
    llSetText("", <1,1,1>, 1.0);
}

AdjustPos(vector vDelta) {
    llSetPos(llGetLocalPos() + ConvertPos(vDelta));
    ForceUpdate();
}

AdjustRot(vector vDelta) {
    llSetLocalRot(llGetLocalRot() * llEuler2Rot(ConvertRot(vDelta)*DEG_TO_RAD));
    ForceUpdate();
}

// *********************************


// *********************************
// ********** Appearance ***********

integer g_iHidden = FALSE;

list g_lHideSettings;
list g_lHideElements;
list g_lHidePrims;

string ElementType(integer linknum, string type) {
    list params = llParseString2List(llList2String(llGetLinkPrimitiveParams(linknum, [PRIM_DESC]), 0), ["~"], []);
    if (llListFindList(params,[type]) == -1) return "";
    else return llList2String(params, 0);
}

SetElementTexture(string element, key tex) {
    if (tex == NULL_KEY) return ;
    if (tex) {
        integer link;
        //root link is 1, so start at 2
        for (link = 2; link <= g_iLinks; link++) {
            if (ElementType(link,"texture") == element) {
                // llSetLinkPrimitiveParamsFast(link, [PRIM_TEXTURE,ALL_SIDES,sTex,<1.0,1.0,1.0>,<0.0,0.0,0.0>,0.0]);
                // update prim texture for each face with save texture repeats, offsets and rotations
                integer faces = llGetLinkNumberOfSides(link);
                integer face ;
                for (face = 0; face < faces; face++) {
                    list lParams = llDeleteSubList(llGetLinkPrimitiveParams(link,[PRIM_TEXTURE,face]),0,0);
                    llSetLinkPrimitiveParamsFast(link,[PRIM_TEXTURE,face,tex]+lParams);
                }
            }
        }
    }
}

SetElementColor(string element, vector color) {
    integer link;
    //root link is 1, so start at 2
    for (link = 2; link <= g_iLinks; link++) {
        if (ElementType(link,"color") == element) llSetLinkColor(link, color, ALL_SIDES);
    }
}

SetElementShine(string element, integer shiny) {
    integer link;
    //root link is 1, so start at 2
    for (link = 2; link <= g_iLinks; link++) {
        if (ElementType(link,"shine") == element) llSetLinkPrimitiveParamsFast(link,[PRIM_BUMP_SHINY,ALL_SIDES,shiny,0]);
    }
}

BuildHideElementList() {
    g_lHideElements = [];
    g_lHidePrims = [] ;
    integer link;
    //root link is 1, so start at 2
    for (link = 2; link <= g_iLinks; link++) {
        string element;
        list params = llParseString2List(llGetLinkName(link),["~"],[]);
        if (~llListFindList(params, ["hide"])) element = llList2String(params,0);
        else element = ElementType(link, "hide");

        if (element) {
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

UpdateHide() {
    if (g_iHidden) return ;
    integer i;
    for (i = 0; i < llGetListLength(g_lHideElements); i++) {
        string element = llList2String(g_lHideElements,i);
        integer hide = 0;
        integer n = llListFindList(g_lHideSettings,[element]);
        if (n != -1) hide = llList2Integer(g_lHideSettings, n+1);
        SetElementHide(element,hide);
    }
}

SetElementHide(string element, integer hide) {
    integer i = llListFindList(g_lHideElements, [element]);
    if (i == -1) return;
    list links = llCSV2List(llList2String(g_lHidePrims,i));

    for (i = 0; i < llGetListLength(links); i++) {
        integer link = llList2Integer(links,i);
        if (hide) llSetLinkAlpha(link, 0, ALL_SIDES);
        else llSetLinkAlpha(link, 1, ALL_SIDES);
    }
}

SetHide(string element, integer hide) {
    integer i = llListFindList(g_lHideSettings, [element]);
    if (i == -1) g_lHideSettings += [element, hide];
    else g_lHideSettings = llListReplaceList(g_lHideSettings, [hide], i + 1, i + 1);
    if (g_iHidden) return;    
    SetElementHide(element,hide);
}
// *********************************


// *********************************
// ************ LOCKING ************
// Messages to be received

float versiontimeout = 30.0;
integer versionchannel = 293847;
integer checkcount;//increment this each time we say @version.  check it each time timer goes off in default state. give up if it's >= 2

integer g_iLocked = FALSE; // is the cuff locked
integer g_iAutoLock = FALSE;
integer g_iRLVon = FALSE; // should RLV be on
integer g_iUseRLV = FALSE; //set to TRUE if viewer is has responded to @version message
integer listener;

list g_lClosedLockElements; //to store the locks prim to hide or show //EB
list g_lOpenLockElements; //to store the locks prim to hide or show //EB

key g_kFirstOwner;
key g_kWearer;

string g_sDetachTime ;
list g_lOwners; // owner of the sub t send information about detaching while locked

BuildLockElementList() {
    // clear list just in case
    g_lOpenLockElements = [];
    g_lClosedLockElements = [];

    integer link;
    //root prim is 1, so start at 2
    for (link = 2; link <= g_iLinks; link++) {
        string name = llList2String(llParseString2List(llGetLinkName(link),["~"],[]),0);
        // check inf name is lock name
        if (name=="Lock" || name=="ClosedLock") g_lClosedLockElements += [link];
        else if (name=="OpenLock") g_lOpenLockElements += [link];
    }
}

SetLockElementAlpha() {
    if (g_iHidden == 1) return ; // ***** if collar is hide, don't do anything
    //loop through stored links, setting alpha if element type is lock
    integer link;
    for (link = 0; link < llGetListLength(g_lOpenLockElements); link++) {
        llSetLinkAlpha(llList2Integer(g_lOpenLockElements,link), (float)(!g_iLocked), ALL_SIDES);
    }

    for (link = 0; link < llGetListLength(g_lClosedLockElements); link++) {
        llSetLinkAlpha(llList2Integer(g_lClosedLockElements,link), (float)g_iLocked, ALL_SIDES);
    }
}

SetLocking(integer lock) {
    g_iLocked = lock;
    if (g_iUseRLV) {
        if (g_iLocked && g_iRLVon) llOwnerSay("@detach=n");
        else llOwnerSay("@detach=y");
    }
    SetLockElementAlpha();
}


CheckRLV() {
    //versionchannel = llAbs((integer)("0x"+(string)llGetKey()));
    versionchannel = llAbs((integer)("0x"+(string)g_kWearer));
    listener = llListen(versionchannel, "", g_kWearer, "");
    llSetTimerEvent(versiontimeout);
    checkcount++;
    llOwnerSay("@version=" + (string)versionchannel);
}

NotifyOwners() {
    string msg = "secondlife:///app/agent/"+(string)g_kWearer+"/about has detached me while locked ("+g_sDetachTime+")!";
    integer i;
    for (i = 0; i < llGetListLength(g_lOwners); i++) {
        Notify(llList2Key(g_lOwners,i), msg);
    }
    g_sDetachTime="";
}

Notify(key kID, string sMsg) {
    if (kID == g_kWearer) llOwnerSay(sMsg);
    else {
        if (llGetAgentSize(kID)) llRegionSayTo(kID,0,sMsg);
        else llInstantMessage(kID, sMsg);
    }
}

// *********************************


// *********************************
// *********** Commands ************

CuffCmd(string sMsg, key kID) {
    list parsed = llParseString2List(sMsg,["="],[]);
    string cmd = llList2String(parsed,0);
    string value = llList2String(parsed,1);
    string value2 = llList2String(parsed,2);

    if (cmd == "Lock") SetLocking((integer)value);
    else if (cmd == "AutoLock") g_iAutoLock = (integer)value ;
    else if (cmd == "Owners") {
        // store the owners for detach warning
        g_lOwners = llParseString2List(value, [","], [""]);
        // now store the first owner for asap notify on detach
        g_kFirstOwner = NULL_KEY;
        integer m = llGetListLength(g_lOwners);
        integer i;
        for (i = 0; i < m; i += 2) {
            if (llList2Key(g_lOwners,i) != g_kWearer) {
                g_kFirstOwner = llList2Key(g_lOwners,i);
                i = m;
            }
        }
    } else if (cmd == "RLV") {
        // RLV got activated
        g_iRLVon = (integer)value ;
        SetLocking(g_iLocked); // Update Cuff lock status
    } else if (cmd == "Color") SetElementColor(value, (vector)value2);
    else if (cmd == "Texture") SetElementTexture(value, value2);
    else if (cmd == "Shine") SetElementShine(value, (integer)value2);
    else if (cmd == "HideCuffs") {
        g_iHidden = (integer)value;
        if (g_iHidden) llSetLinkAlpha(LINK_SET,0.0,ALL_SIDES);
        else llSetLinkAlpha(LINK_SET,1.0,ALL_SIDES);
        UpdateHide();
        SetLockElementAlpha();
    } else if (cmd == "HideElement") SetHide(value, (integer)value2);
    else if (cmd == "Position") AdjustPos((vector)value);
    else if (cmd == "Rotation") AdjustRot((vector)value);
    else if (cmd == "Size") {
        float fSizeFactor = (float)value;
        if (llScaleByFactor(fSizeFactor)==FALSE) {
            Notify(kID, "Cannot be scaled as you requested; prims would surpass minimum or maximum size.");
        };
    } else if (sMsg == "check_attach") SendCmd(g_sCmdToken, "attached=" + g_sCuffToken);
    else if (sMsg == "update") {
        if (kID == g_kWearer) {
            //Notify(kID, "Searching Cuffs Updater...");
            g_iUpdateListen = llListen(g_iUpdateChan, "", "", "");
            llWhisper(g_iUpdateChan, "UPDATE_CUFFS|" + g_sVersion);
            g_iWaitUpdate = TRUE;
            llSetTimerEvent(120.0);
        }
    }
}

//=============================================================================
//== OC Cuff - slave listen module
//== receives messages from exernal objects
//==
//== 2009-01-16 Jenny Sigall - 1. draft
//=============================================================================

integer LM_CUFF_CMD  = -551001;
//integer LM_CUFF_ANIM = -551002;
integer LM_CUFF_CUFFPOINTNAME = -551003;

list lstTokens = ["Not","chest","skull","lshoulder","rshoulder","lhand","rhand","lfoot","rfoot","spine","ocpants","mouth","chin","lear","rear","leye","reye","nose","ruac","rlac","luac","llac","rhip","rulc","rllc","lhip","lulc","lllc","ocbelt","rpec","lpec","HUD Center 2","HUD Top Right","HUD Top","HUD Top Left","HUD Center","HUD Bottom Left","HUD Bottom","HUD Bottom Right","neck","avatar center"]; // list of attachment point to resolcve the names for the cuffs system, addition cuff chain point will be transamitted via LMs
// attention, belt is twice in the list, once for stomach. , once for pelvis as there are version for both points

string g_sCmdToken = "rlac"; // only accept commands from this token adress
string g_sCuffToken ;
list   g_lCuffPoints = []; // valid token for this module

key g_kCuffKey  = NULL_KEY;       // key of the cuff

integer ATTACH ;

integer g_iLockGuardChannel = -9119;
integer g_iCmdChannelOffset = 0xCC0CC;  // offset to be used to make sure we do not interfere with other items using the same technique for
integer g_iSendChannel = -190890;    // command channel for send to main cuff
integer g_iCmdChannel = -190889;    // command channel to recieve command

integer iGetOwnerChannel(integer offset) {
    integer chan = (integer)("0x"+llGetSubString((string)llGetOwner(),3,8)) + offset;
    if (chan > 0) chan = chan*(-1);
    if (chan > -10000) chan -= 30000;
    return chan;
}

SendCmd(string sSendTo, string sCmd) {
    llRegionSayTo(g_kWearer, g_iSendChannel, g_sCuffToken + "|" + sSendTo + "|" + sCmd);
}

CheckCmd(key kID, string sMsg) {
    list parsed = llParseString2List(sMsg,["|"],[]);

    // first part should be sender token
    // second part the receiver token
    // third part = command
    if (llGetListLength(parsed) > 2) {
        string sender = llList2String(parsed,0) ;
        if (sender == g_sCmdToken) {
            // only accept command from the master cuff
            string receiver = llList2String(parsed,1);
            // we are the receiver?
            if (llListFindList(g_lCuffPoints,[receiver]) != -1 || receiver == "*") {
                string cmd = llList2String(parsed,2) ;
                key id = (key)llList2String(parsed,3) ;
                if (id) kID = id ;

                parsed = llParseString2List(cmd,["~"],[]);
                integer i;
                for (i = 0; i < llGetListLength(parsed); i++) {
                    ParseSingleCmd(kID, llList2String(parsed, i));
                }
            }
        }
    }
}

ParseSingleCmd(key kID, string sMsg) {
    list parsed = llParseString2List(sMsg,["="],[]);
    string Cmd = llList2String(parsed,0);
    if (Cmd == "chain" && llGetListLength(parsed) == 4 && kID != g_kCuffKey)
        llMessageLinked(LINK_SET,LM_CUFF_CMD,sMsg,g_kCuffKey);
    else CuffCmd(sMsg, kID);
}


init() {
    g_kWearer = llGetOwner();
    g_kCuffKey = llGetKey();
    // get name of the cuff from the attachment point, this is absolutly needed for the system to work,
    // other chain point wil be received via LMs
    ATTACH = llGetAttached();
    g_sCuffToken = llList2String(lstTokens,ATTACH);
    g_lCuffPoints = [g_sCuffToken];
    llMessageLinked(LINK_SET, LM_CUFF_CMD, "reset", "");
    // get unique channel numbers for the command and cuff channel, cuff channel wil be used for LG chains of cuffs as well
    g_iSendChannel = iGetOwnerChannel(g_iCmdChannelOffset);
    g_iCmdChannel = g_iSendChannel + 1;
    llListen(g_iCmdChannel, "", "", "");
    llListen(g_iLockGuardChannel,"","",""); // listen to LockGuard requests
    //Store_StartScaleLoop();
    // wait for init and start RLV check
    CheckRLV();
}

BuildElementsLists() {
    g_iLinks = llGetNumberOfPrims();
    BuildLockElementList();
    BuildHideElementList();
}

integer g_iLinks ; // global variable - total prims

default {
    on_rez(integer param) {
        if (g_iLinks != llGetNumberOfPrims()) llResetScript();
        if (g_kWearer != llGetOwner()) llResetScript();
    }

    attach(key id) {
        if (g_iLocked && id == NULL_KEY) g_sDetachTime = llGetTimestamp();
        if (id == g_kWearer) {
            init();
            if (g_sDetachTime != "") NotifyOwners();
        }
    }

    state_entry() {
        init();
        BuildElementsLists();
    }

    touch_start(integer nCnt) {
        SendCmd(g_sCmdToken, "cmenu|"+(string)llDetectedKey(0));
    }

    link_message(integer sender, integer iNum, string sMsg, key kID) {
        //if (iNum == LM_CUFF_CMD) CuffCmd(sMsg, kID);
        //else
        if (iNum == LM_CUFF_CUFFPOINTNAME) {
            if (llListFindList(g_lCuffPoints,[sMsg]) == -1) g_lCuffPoints += [sMsg];
        }
    }

    listen(integer iChannel, string sName, key kID, string sMsg) {
        sMsg = llStringTrim(sMsg, STRING_TRIM);
        if (iChannel == versionchannel) {
            llListenRemove(listener);
            llSetTimerEvent(0);
            if (llSubStringIndex(sMsg,"RestrainedLife viewer") == 0) g_iUseRLV = TRUE;
            SendCmd(g_sCmdToken, "SendLockInfo");
            if (g_iAutoLock) SetLocking(TRUE);
            else SetLocking(g_iLocked);
        }
        else if (iChannel == g_iCmdChannel && llGetOwnerKey(kID) == g_kWearer) {
            // commands sent on cmd channel
            if (llGetSubString(sMsg,0,8)=="lockguard") llMessageLinked(LINK_SET, g_iLockGuardChannel, sMsg, kID);
            else CheckCmd(kID, sMsg);
        } else if (iChannel == g_iLockGuardChannel) {
            // LG message received, forward it to the other prims
            llMessageLinked(LINK_SET, g_iLockGuardChannel, sMsg, kID);
        }
        else if (iChannel == g_iUpdateChan && llGetOwnerKey(kID) == g_kWearer) {          
            if (llToLower(sMsg) == "get ready") {
                g_iWaitUpdate = FALSE;
                llSetTimerEvent(0);
                integer pin = (integer)llFrand(99999998.0) + 1; //set a random pin
                llSetRemoteScriptAccessPin(pin);
                llRegionSayTo(kID, g_iUpdateChan, "ready|" + (string)pin );
                //Notify(g_kWearer, "Cuffs Updater found...");
                llListenRemove(g_iUpdateListen);
            }
        }  
    }

    changed(integer iChange) {
        if (iChange & CHANGED_LINK) BuildElementsLists();
        if (iChange & CHANGED_REGION) SetLocking(g_iLocked);
    }

    timer() {
        llSetTimerEvent(0);
        
        if (g_iWaitUpdate) {
            g_iWaitUpdate = FALSE;
            llListenRemove(g_iUpdateListen);
            llOwnerSay("Cuffs Updater not found!");
        }
        
        if (listener) {
            llListenRemove(listener);
            if (checkcount == 1) CheckRLV();
            else if (checkcount >= 2) g_iUseRLV = FALSE;
            SendCmd(g_sCmdToken, "SendLockInfo");
        }
    }
}