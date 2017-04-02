//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

string g_sParentMenu = " Appearance";
string g_sSubMenu = "Adjust";

//MESSAGE MAP
//integer CMD_NOAUTH = 0;
integer CMD_OWNER = 500;
//integer CMD_TRUST = 501;
//integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
//integer CMD_EVERYONE = 504;

integer LM_SETTING_REQUEST = 2001;
integer LM_SETTING_RESPONSE = 2002;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

integer LM_CUFF_CMD = -551001;
integer LM_CUFF_SEND = -555000;

string UPMENU = "▲";


string s_ModToken = "rlac"; // valid token for this module

list l_Cuffs = ["R biceps","R wrist","L biceps","L wrist","R thigh","R ankle","L thigh","L ankle","Chest","Pants","Belt"];
list l_CuffsTokens = ["ruac","rlac","luac","llac","rulc","rllc","lulc","lllc","chest","ocpants","ocbelt"];

// buttons
string b_pLeft = "left ←" ;
string b_pUp = "up ↑" ;
string b_pFwd = "forward ↳" ;
string b_pRight ="right →" ;
string b_pDown ="down ↓" ;
string b_pBack ="backward ↲" ;

string b_TiltLeft = "tilt left ↙" ;
string b_TiltRight = "tilt right ↘" ;

string b_TiltForw = "tilt forw ↻" ;
string b_TiltBack = "tilt back ↺" ;

string b_RotLeft = "rot left ↶" ;
string b_RotRight = "rot right ↷" ;

string s_ressizerwarn = "Attention!\nWhile resizing, don't change attachments and don't sit/unsit on object!";

list l_adjusBtn = ["Position", "Rotation","Size"];
//list l_posBtn = [b_pLeft,b_pUp,b_pFwd,b_pRight,b_pDown,b_pBack] ;
list l_posBtn = ["left ←","up ↑","forward ↳","right →","down ↓","backward ↲"] ;
list l_pos = [<0,1,0>,<0,0,1>,<1,0,0>,<0,-1,0>,<0,0,-1>,<-1,0,0>];
//list l_rotBtn = [b_TiltLeft,b_TiltForw,b_RotLeft,b_TiltRight,b_TiltBack,b_RotRight];
list l_rotBtn = ["tilt left ↙","tilt forw ↻","rot left ↶","tilt right ↘","tilt back ↺","rot right ↷"];
list l_rot =[<-1,0,0>,<0,1,0>,<0,0,1>,<1,0,0>,<0,-1,0>,<0,0,-1>];

list l_sizeBtn = ["+1%","-1%","+5%","-5%","+10%","-10%"];
list l_size_dif = [1.01, 0.99, 1.05, 0.95, 1.10, 0.90];

float g_fSmallNudge = 0.0005;
float g_fMediumNudge = 0.005;
float g_fLargeNudge = 0.05;
float g_fNudge = 0.0005;

float g_fSmallRotNudge = 1;
float g_fMediumRotNudge = 5;
float g_fLargeRotNudge = 20;
float g_fRotNudge = 1;

string CuffName ;
string CuffToken ;

key g_kWearer;

float check_time = 5 ;
string check = "check_attach" ;
string checked = "attached" ;

list g_lCuffs = [] ;
list g_lAttachedCuffs = [] ;
list l_CuffsBtn = [];

list g_lMenuIDs;  //three strided list of avkey, dialogid, and menuname
integer g_iMenuStride = 3;

float MAX_PRIM_SIZE=2.0; //maximum allowable prim size
float MIN_PRIM_SIZE=0.001; //minimum allowable prim size
float MAX_LINK_DIST=100.0; //maximum allowable link distance (hmn what is this value on opensim?)

vector GetScaleFactors()
{
    integer p = llGetNumberOfPrims();
    integer i;
    list pos;
    list size;
    while (i < p) {
        list t = llGetLinkPrimitiveParams(i+1,[PRIM_SIZE,PRIM_POS_LOCAL]);
        if (i > 0) {
            vector o=llList2Vector(t,1);
            pos+=[llFabs(o.x),llFabs(o.y),llFabs(o.z)];
        }
        vector s=llList2Vector(t,0);size+=[s.x,s.y,s.z];++i;
    }
    float maxr = MAX_PRIM_SIZE/llListStatistics(LIST_STAT_MAX, size);
    if (llGetListLength(pos)) {
        maxr = osMin(MAX_LINK_DIST/llListStatistics(LIST_STAT_MAX,pos), maxr);
    }
    return <MIN_PRIM_SIZE/llListStatistics(LIST_STAT_MIN,size),maxr,0>;
}

integer ScaleByFactor(float f)
{
    vector v=GetScaleFactors();
    if(f<v.x || f>v.y) return FALSE;
    else {
        integer p=llGetNumberOfPrims();
        integer i;list n;
        while(i<p) {
            list t=llGetLinkPrimitiveParams(i+1,[PRIM_SIZE,PRIM_POS_LOCAL]);
            n+=[PRIM_LINK_TARGET,i+1,PRIM_SIZE,llList2Vector(t,0)*f];
            if(i>0){n+=[PRIM_POS_LOCAL,llList2Vector(t,1)*f];}++i;
        }
        llSetPrimitiveParams(n);
        return TRUE;
    }
}

debug(string str) {
    llOwnerSay(llGetScriptName() + ": " + str);
}

SendCmd(string sSendTo, string sCmd, key kId) {
    llMessageLinked(LINK_THIS, LM_CUFF_SEND, sSendTo +"|"+sCmd, kId);
}

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

DoCuffs() {
    l_CuffsBtn = ["R wrist"];
    integer n = llGetListLength(g_lAttachedCuffs);
    integer i ;
    for (i=0; i<n; i++) {
        string token = llList2String(g_lAttachedCuffs,i) ;
        integer index = llListFindList(l_CuffsTokens,[token]) ;
        if(~index) l_CuffsBtn += llList2String(l_Cuffs,index) ;
    }
    l_CuffsBtn = llListSort(l_CuffsBtn,1,TRUE);
}

CuffsMenu(key kAV, integer iAuth) {
    DoCuffs();
    string prompt = "\nAdjustment menu.\n\nPick a Cuff to adjust\n";
    Dialog(kAV, prompt, l_CuffsBtn, [UPMENU], 0, iAuth, "cuffs");
}

AdjustMenu(key kAV, integer iAuth) {
    string prompt = "Change Adjust for " + CuffName+"\n";
    Dialog(kAV, prompt, l_adjusBtn, [UPMENU], 0, iAuth, "adjust");
}

PosMenu(key kAV, integer iAuth) {
    string prompt = "Change Position for " + CuffName + "\n";
    list lMyButtons = l_posBtn ;

    if (g_fNudge!=g_fSmallNudge) lMyButtons+=["▸"];
    else prompt += "▸";
    if (g_fNudge!=g_fMediumNudge) lMyButtons+=["▸▸"];
    else prompt += "▸▸";
    if (g_fNudge!=g_fLargeNudge) lMyButtons+=["▸▸▸"];
    else prompt += "▸▸▸";

    Dialog(kAV, prompt, lMyButtons, [UPMENU], 0, iAuth, "pos");
}

RotMenu(key kAV, integer iAuth) {
    string prompt = "Change Rotation for " + CuffName + "\n";
    list lMyButtons = l_rotBtn ;

    if (g_fRotNudge!=g_fSmallRotNudge) lMyButtons+=["▸"];
    else prompt += "▸";
    if (g_fRotNudge!=g_fMediumRotNudge) lMyButtons+=["▸▸"];
    else prompt += "▸▸";
    if (g_fRotNudge!=g_fLargeRotNudge) lMyButtons+=["▸▸▸"];
    else prompt += "▸▸▸";

    Dialog(kAV, prompt, lMyButtons, [UPMENU], 0, iAuth, "rot");
}

SizeMenu(key kAV, integer iAuth) {
    string prompt = "Change Size for " + CuffName+"\n\n"+s_ressizerwarn;
    Dialog(kAV, prompt, l_sizeBtn, [UPMENU], 0, iAuth, "size");
}

SelectCuff(string sMsg) {
    CuffName = sMsg;
    integer i = llListFindList(l_Cuffs,[CuffName]);
    CuffToken = llList2String(l_CuffsTokens,i);
}

SetPos(string sMsg, key kID) {
    if (sMsg == "▸") g_fNudge = g_fSmallNudge;
    else if (sMsg == "▸▸") g_fNudge = g_fMediumNudge;
    else if (sMsg == "▸▸▸") g_fNudge = g_fLargeNudge;
    else {
        integer i = llListFindList(l_posBtn,[sMsg]);
        vector vDelta = llList2Vector(l_pos,i)*g_fNudge;

        if (llGetAttached() && CuffToken == s_ModToken) AdjustPos(vDelta);
        else SendCmd(CuffToken,"Position="+(string)vDelta, kID);
    }
}

SetRot(string sMsg, key kID) {
    if (sMsg == "▸") g_fRotNudge = g_fSmallRotNudge;
    else if (sMsg == "▸▸") g_fRotNudge = g_fMediumRotNudge;
    else if (sMsg == "▸▸▸") g_fRotNudge = g_fLargeRotNudge;
    else {
        integer i = llListFindList(l_rotBtn,[sMsg]);
        vector vDelta = llList2Vector(l_rot,i)*g_fRotNudge;
        if (llGetAttached() && CuffToken == s_ModToken) AdjustRot(vDelta);
        else SendCmd(CuffToken,"Rotation="+(string)vDelta, kID);
    }
}

SetSize(string sMsg, key kID) {
    integer i = llListFindList(l_sizeBtn,[sMsg]);
    float fSizeFactor = llList2Float(l_size_dif,i);
    if (llGetAttached() && CuffToken == s_ModToken) AdjustSize(fSizeFactor, kID);
    else SendCmd(CuffToken,"Size="+(string)fSizeFactor, kID);
}


float min = 0.01 ; //min prim size
float max = 2.0 ;  //max prim size

integer ATTACH ;

vector Strig2Vector(string sStr) {
    return (vector)llDumpList2String(llParseString2List(sStr, [" "], []), "");
}

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
    } else if(ATTACH == 6 || ATTACH == 18 || ATTACH == 19) { // right arm
        out.x = pos.x ;
        out.y = pos.z ;
        out.z = -pos.y ;
    } else out = pos ;
    return out ;
}

vector ConvertRot(vector rot)
{
    vector out ;
    if(ATTACH == 1) {
        out.x = rot.y ;
        out.y = rot.z ;
        out.z = rot.x ;
    } else if(ATTACH == 5 || ATTACH == 20 || ATTACH == 21) { // left arm
        out.x = rot.x ;
        out.y = -rot.z ;
        out.z = rot.y ;
    } else if(ATTACH == 6 || ATTACH == 18 || ATTACH == 19) { // right arm
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

AdjustSize(float fSizeFactor, key kID) {
    if (ScaleByFactor(fSizeFactor)==FALSE) {
        Notify(kID, "Cannot be scaled as you requested; prims would surpass minimum or maximum size.", FALSE);
    }
}


integer t_scale = FALSE;

default {

    on_rez(integer param) {
        llResetScript();
    }

    state_entry() {
        g_kWearer = llGetOwner();
        ATTACH = llGetAttached();
        SendCmd("*", check, "");
        llSetTimerEvent(check_time);
    }

    link_message(integer sender, integer iNum, string sStr, key kID) {
        //owner, secowner, group, and wearer may currently change colors
        if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) {
            if (sStr == g_sSubMenu || sStr == "menu "+g_sSubMenu) {
                if (kID == g_kWearer || iNum == CMD_OWNER) CuffsMenu(kID, iNum);
                else {
                    Notify(kID,"You are not allowed to adjust cuffs.", FALSE);
                    llMessageLinked(LINK_THIS, iNum, "menu "+g_sParentMenu, kID);
                }
            }
            //list parsed = llParseString2List(sStr, ["="], []);
            if (~llSubStringIndex(sStr,checked)) {
                list parsed = llParseString2List(sStr, ["="], []);
                string cuff = llList2String(parsed, 1);
                if (llListFindList(g_lCuffs, [cuff]) == -1) g_lCuffs += [cuff] ;
            }
        } else if (iNum == LM_CUFF_CMD) {
            list parsed = llParseString2List(sStr, ["="], []);
            if (llList2String(parsed, 0) == checked) {
                string cuff = llList2String(parsed, 1);
                if (llListFindList(g_lCuffs, [cuff]) == -1) g_lCuffs += [cuff] ;
            }
        } else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu) {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        } else if (iNum == DIALOG_RESPONSE) {
            integer index = llListFindList(g_lMenuIDs, [kID]);
            if (~index) {

                list params = llParseString2List(sStr, ["|"], []);
                key kAV = (key)llList2String(params, 0);
                string sMsg = llList2String(params, 1);
                //integer iPage = (integer)llList2String(params, 2);
                integer iAuth = (integer)llList2String(params, 3);

                string sMenuType = llList2String(g_lMenuIDs, index+1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, index-1, index-2+g_iMenuStride);

                if (sMenuType == "cuffs") {
                    if (sMsg == UPMENU) llMessageLinked(LINK_THIS, iAuth, "menu "+g_sParentMenu, kAV);
                    else {
                        SelectCuff(sMsg);
                        AdjustMenu(kAV, iAuth);
                    }
                } else if (sMenuType == "adjust") {
                    if (sMsg == UPMENU) CuffsMenu(kAV, iAuth);
                    else if (sMsg == "Position") PosMenu(kAV, iAuth);
                    else if (sMsg == "Rotation") RotMenu(kAV, iAuth);
                    else if (sMsg == "Size") SizeMenu(kAV, iAuth);
                } else if (sMenuType == "pos") {
                    if (sMsg == UPMENU) AdjustMenu(kAV, iAuth);
                    else {
                        SetPos(sMsg, kAV);
                        PosMenu(kAV, iAuth);
                    }
                } else if (sMenuType == "rot") {
                    if (sMsg == UPMENU) AdjustMenu(kAV, iAuth);
                    else {
                        SetRot(sMsg, kAV);
                        RotMenu(kAV, iAuth);
                    }
                } else if (sMenuType == "size") {
                    if (sMsg == UPMENU) AdjustMenu(kAV, iAuth);
                    else {
                        SetSize(sMsg, kAV);
                        SizeMenu(kAV, iAuth);
                    }
                }
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer index = llListFindList(g_lMenuIDs, [kID]);
            if (~index) g_lMenuIDs = llDeleteSubList(g_lMenuIDs, index-1, index-2+g_iMenuStride);
        }
    }

    timer() {
        if (t_scale) {
            t_scale = FALSE;
            llSetTimerEvent(check_time);
        } else {
            if (llGetListLength(g_lAttachedCuffs) != llGetListLength(g_lCuffs)) g_lAttachedCuffs = g_lCuffs ;
            g_lCuffs = [] ;
            SendCmd("*", check,"");
        }
    }
}