
// texture & color & shiny

string g_sParentMenu = " Appearance";
string g_sSubMenu = " Paint";

//MESSAGE MAP
//integer CMD_NOAUTH = 0;
integer CMD_OWNER = 500;
//integer CMD_TRUST = 501;
//integer CMD_GROUP = 502;
integer CMD_WEARER = 503;

integer SETTING_SAVE = 2000;
//integer SETTING_REQUEST = 2001;
integer SETTING_RESPONSE = 2002;
//integer SETTING_DELETE = 2003;
//integer SETTING_EMPTY = 2004;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

integer LM_CUFF_SEND = -555000;

//string UPMENU = "BACK";
string UPMENU = "▲";

string CTYPE = "Cuffs";

string g_sAppLockToken = "AppLock";

integer g_iAppLock = FALSE ;

key g_kWearer;

integer g_iLinks ;

list g_lElements;
list g_lElementFlags;

string g_sCurrentElement ;

list g_lMenuIDs;//3-strided list of kAv, dialogid, menuname
integer g_iMenuStride = 3;

/*
Debug(string sStr) {
    llOwnerSay(llGetScriptName() + ": " + sStr);
}
*/

string ElementType(integer link, string type) {
    //prim desc will be elementtype~type
    list params = llParseString2List(llList2String(llGetLinkPrimitiveParams(link,[PRIM_DESC]),0), ["~"], []);
    if (llListFindList(params, [type]) == -1) return "" ;
    else return llList2String(params, 0);
}

integer CheckElement(string element, integer flag) {
    integer index = llListFindList(g_lElements, [element]);
    if (~index) return llList2Integer(g_lElementFlags,index) & flag ;
    else return 0 ;
}

// ****************************************************
// ****************** Textues *************************
list g_lTextures;
list g_lTextureSetting;

BuildTextureList() {
    g_lTextures = [];
    integer num_textures = llGetInventoryNumber(INVENTORY_TEXTURE);
    integer n;
    for (n=0;n<num_textures;n++) {
        g_lTextures += [llGetInventoryName(INVENTORY_TEXTURE,n)];
    }
    g_lTextures = llListSort(g_lTextures,1,TRUE);
}

LoadTextureSettings() {
    string cmd;
    integer i;
    integer n = llGetListLength(g_lTextureSetting);
    for (i=0; i<n; i+=2) {
        string el = llList2String(g_lTextureSetting, i);
        string tex = llList2String(g_lTextureSetting, i+1);
        if (SetPrimsTexture(el, tex)) {
            if (cmd) cmd += "~" ;
            cmd += "Texture="+el+"="+tex;
        }
    }
    if (cmd) llMessageLinked(LINK_THIS, LM_CUFF_SEND, "*|"+cmd, "");
}

TextureMenu(key kID, integer iPage, integer iAuth) {
    string sPrompt = "\nChoose the texture to apply.";
    Dialog(kID, sPrompt, g_lTextures, [UPMENU], iPage, iAuth, "TextureMenu");
}

SetElementTexture(string sElement, string sTex) {
    if(sElement == "All") {
        integer i;
        integer c = llGetListLength(g_lElements);
        for (i = 0; i < c; i++) {
            SetTexture(llList2String(g_lElements, i), sTex);
        }
    } else SetTexture(sElement, sTex);
    llMessageLinked(LINK_THIS, SETTING_SAVE, "texture=" + llDumpList2String(g_lTextureSetting, "~"), "");
}

SetTexture(string element, string stex) {
    key tex ;
    if (osIsUUID(stex)) tex = stex;
    else tex = llGetInventoryKey(stex);

    if (SetPrimsTexture(element, tex) == FALSE) return;
    llMessageLinked(LINK_THIS, LM_CUFF_SEND, "*|Texture="+element+"="+(string)tex, "");

    //change the g_lTextureSetting list entry for the current element
    integer index;
    index = llListFindList(g_lTextureSetting, [element]);
    if (index == -1) g_lTextureSetting += [element, tex];
    else g_lTextureSetting = llListReplaceList(g_lTextureSetting, [tex], index + 1, index + 1);
}

integer SetPrimsTexture(string sElement, key tex) {
    if (CheckElement(sElement, 1) == 0) return FALSE;
    if (tex == NULL_KEY) return FALSE;
    else {
        integer link;
        for (link = 2; link <= g_iLinks; link++) {
            if (ElementType(link,"texture") == sElement) {
                // update prim texture for each face with save texture repeats, offsets and rotations
                integer faces = llGetLinkNumberOfSides(link);
                integer face ;
                for (face = 0; face < faces; face++) {
                    list lParams = llGetLinkPrimitiveParams(link,[PRIM_TEXTURE,face]);
                    lParams = llDeleteSubList(lParams,0,0); // get texture params
                    llSetLinkPrimitiveParamsFast(link,[PRIM_TEXTURE,face,tex]+lParams);
                }
            }
        }
    }
    return TRUE;
}

// *******************************************
// ************* Color ***********************

list g_lCategories = ["Shades", "Bright", "Soft"];

list g_lAllColors = [
"Light Shade|<0.82745, 0.82745, 0.82745>
Gray Shade|<0.70588, 0.70588, 0.70588>
Dark Shade|<0.20784, 0.20784, 0.20784>
Brown Shade|<0.65490, 0.58431, 0.53333>
Red Shade|<0.66275, 0.52549, 0.52549>
Blue Shade|<0.64706, 0.66275, 0.71765>
Green Shade|<0.62353, 0.69412, 0.61569>
Pink Shade|<0.74510, 0.62745, 0.69020>
Gold Shade|<0.69020, 0.61569, 0.43529>
Black|<0.00000, 0.00000, 0.00000>
White|<1.00000, 1.00000, 1.00000>",
"Magenta|<1.00000, 0.00000, 0.50196>
Pink|<1.00000, 0.14902, 0.50980>
Hot Pink|<1.00000, 0.05490, 0.72157>
Firefighter|<0.88627, 0.08627, 0.00392>
Sun|<1.00000, 1.00000, 0.18039>
Flame|<0.92941, 0.43529, 0.00000>
Matrix|<0.07843, 1.00000, 0.07843>
Electricity|<0.00000, 0.46667, 0.92941>
Violet Wand|<0.63922, 0.00000, 0.78824>
Black|<0.00000, 0.00000, 0.00000>
White|<1.00000, 1.00000, 1.00000>",
"Baby Blue|<0.75686, 0.75686, 1.00000>
Baby Pink|<1.00000, 0.52157, 0.76078>
Rose|<0.93333, 0.64314, 0.72941>
Beige|<0.86667, 0.78039, 0.71765>
Earth|<0.39608, 0.27451, 0.18824>
Ocean|<0.25882, 0.33725, 0.52549>
Yolk|<0.98824, 0.73333, 0.29412>
Wasabi|<0.47059, 1.00000, 0.65098>
Lavender|<0.89020, 0.65882, 0.99608>
Black|<0.00000, 0.00000, 0.00000>
White|<1.00000, 1.00000, 1.00000>"
];

string g_sCurrentCategory = "";

list g_lColors;
list g_lColorSettings;

LoadColorSettings() {
    string cmd;
    integer i;
    integer n = llGetListLength(g_lColorSettings);
    if (n == 0) return;
    for (i=0; i<n; i+=2) {
        string el = llList2String(g_lColorSettings, i);
        string col = llList2String(g_lColorSettings, i+1);
        if (SetPrimsColor(el, (vector)col)) {
            if (cmd) cmd += "~" ;
            cmd += "Color="+el+"="+col;
        }
    }
    if (cmd) llMessageLinked(LINK_THIS, LM_CUFF_SEND, "*|"+cmd, "");
}

ColorCategoryMenu(key kAv, integer iPage, integer iAuth) {
    g_sCurrentCategory = "";
    string prompt = "Pick a Color.";
    Dialog(kAv, prompt, g_lCategories, [UPMENU], iPage, iAuth, "CategoryMenu");
}

ColorMenu(key kAv, integer iPage, integer iAuth) {
    integer iIndex = llListFindList(g_lCategories,[g_sCurrentCategory]);
    g_lColors = llParseString2List(llList2String(g_lAllColors, iIndex), ["\n", "|"], []);
    g_lColors = llListSort(g_lColors, 2, TRUE);
    string sPrompt = "\nChoose a color.";
    list g_lButtons = llList2ListStrided(g_lColors,0,-1,2);
    Dialog(kAv, sPrompt, g_lButtons, [UPMENU], iPage, iAuth, "ColorMenu");
}

SetElementColor(string sElement, vector vColor) {
    if(sElement == "All") {
        integer i;
        integer c = llGetListLength(g_lElements);
        for (i = 0; i < c; i++) {
            SetColor(llList2String(g_lElements, i), vColor);
        }
    } else SetColor(sElement, vColor);
    llMessageLinked(LINK_THIS, SETTING_SAVE, "color=" + llDumpList2String(g_lColorSettings, "~"), "");
}

SetColor(string sElement, vector vColor) {
    if (SetPrimsColor(sElement, vColor) == FALSE) return;
    string sColor = Vec2String(vColor); //create shorter string from the color vectors before saving
    llMessageLinked(LINK_THIS, LM_CUFF_SEND, "*|Color="+sElement+"="+sColor, "");

    //change the g_lColorSettings list entry for the current element
    integer index = llListFindList(g_lColorSettings, [sElement]);
    if (index == -1) g_lColorSettings += [sElement, sColor];
    else g_lColorSettings = llListReplaceList(g_lColorSettings, [sColor], index + 1, index + 1);
}

integer SetPrimsColor(string sElement, vector vColor) {
    if (CheckElement(sElement, 2) == 0) return FALSE;
    integer link;
    for (link = 2; link <= g_iLinks; link++) {
        if (ElementType(link,"color") == sElement) llSetLinkColor(link, vColor, ALL_SIDES);
    }
    return TRUE;
}

string Vec2String(vector vec) {
    list parts = [vec.x, vec.y, vec.z];
    integer n;
    for (n = 0; n < 3; n++) {
        string str = llList2String(parts, n);
        //remove any trailing 0's or .'s from str
        while ((~(integer)llSubStringIndex(str, ".")) && (llGetSubString(str,-1,-1) == "0" || llGetSubString(str,-1,-1) == ".")) {
            str = llDeleteSubString(str, -1, -1);
        }
        parts = llListReplaceList(parts, [str], n, n);
    }
    return "<" + llDumpList2String(parts, ",") + ">";
}

// *******************************************
// *******************************************


// *******************************************
// ************* Shininess *******************

list g_lShiny = ["none","low","medium","high"];
list g_lShinySettings ;

LoadShinySettings() {
    string cmd;
    integer n;
    integer i;
    n = llGetListLength(g_lShinySettings);
    for (i=0; i<n; i+=2) {
        string el = llList2String(g_lShinySettings, i);
        string sh = llList2String(g_lShinySettings, i+1);
        if (SetPrimsShiny(el,(integer)sh)) {
            if (cmd) cmd += "~" ;
            cmd += "Shine="+el+"="+sh;
        }
    }
    if (cmd) llMessageLinked(LINK_THIS, LM_CUFF_SEND, "*|"+cmd, "");
}

ShinyMenu(key kAv, integer iPage, integer iAuth) {
    string sPrompt = "Pick a Shiny.";
    Dialog(kAv, sPrompt, g_lShiny, [UPMENU], iPage, iAuth, "ShinyMenu");
}

SetElementShiny(string sElement, integer iShiny) {
    if (sElement == "All") {
        integer i;
        integer c = llGetListLength(g_lElements);
        for (i = 0; i < c; i++) {
            SetShiny(llList2String(g_lElements, i), iShiny);
        }
    } else SetShiny(sElement, iShiny);
    llMessageLinked(LINK_THIS, SETTING_SAVE, "shine=" + llDumpList2String(g_lShinySettings,"~"), "");
}

SetShiny(string sElement, integer iShiny) {
    if (SetPrimsShiny(sElement, iShiny) == FALSE) return;
    llMessageLinked(LINK_THIS, LM_CUFF_SEND, "*|Shine="+sElement+"="+(string)iShiny, "");

    //change the g_lShinySettings list entry for the current element
    integer index = llListFindList(g_lShinySettings, [sElement]);
    if (index == -1) g_lShinySettings += [sElement, iShiny];
    else g_lShinySettings = llListReplaceList(g_lShinySettings, [iShiny], index + 1, index + 1);
}

integer SetPrimsShiny(string sElement, integer shiny) {
    if (CheckElement(sElement, 4) == 0) return FALSE;
    integer link;
    for (link = 2; link <= g_iLinks; link++) {
        if (ElementType(link,"shine") == sElement)
            llSetLinkPrimitiveParamsFast(link,[PRIM_BUMP_SHINY,ALL_SIDES,shiny,0]);
    }
    return TRUE;
}


// *******************************************
// *******************************************

// **************************

Dialog(key kRCPT, string sPrompt, list lChoices, list lUtility, integer iPage, integer iAuth, string sMenuType) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|"
    + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtility, "`") + "|" + (string)iAuth, kMenuID);

    integer iMenuIndex = llListFindList(g_lMenuIDs, [kRCPT]);
    list lAddMe = [kRCPT, kMenuID, sMenuType];
    if (iMenuIndex == -1) g_lMenuIDs += lAddMe;
    else g_lMenuIDs = llListReplaceList(g_lMenuIDs, lAddMe, iMenuIndex, iMenuIndex + g_iMenuStride - 1);
}

Notify(key kAv, string sMsg, integer iAlsoNotifyWearer) {
    if (kAv == g_kWearer) llOwnerSay(sMsg);
    else {
        if (llGetAgentSize(kAv)!=ZERO_VECTOR) llRegionSayTo(kAv,0,sMsg);
        else llInstantMessage(kAv, sMsg);
        if (iAlsoNotifyWearer) llOwnerSay(sMsg);
    }
}

ElementMenu(key kAv, integer iPage, integer iAuth) {
    string sPrompt = "\nChange the looks, "+CTYPE+".\nSelect an element from the list";
    list lButtons = llListSort(g_lElements, 1, TRUE);
    Dialog(kAv, sPrompt, ["All"]+lButtons, [UPMENU], iPage, iAuth, "ElementMenu");
}

CustomMenu(key kAv, integer iPage, integer iAuth) {
    string sPrompt="\nSelect an option for element '"+g_sCurrentElement+"':";

    integer index = llListFindList(g_lElements, [g_sCurrentElement]);
    integer iFlags = llList2Integer(g_lElementFlags, index);

    list lButtons;

    if (iFlags & 1) lButtons += ["Texture"];
    if (iFlags & 2) lButtons += ["Color"];
    if (iFlags & 4) lButtons += ["Shine"];

    Dialog(kAv, sPrompt, lButtons, [UPMENU], iPage, iAuth, "CustomMenu");
}

BuildElementsList() {

    g_iLinks = llGetNumberOfPrims();
    g_lElements = [];
    g_lElementFlags = [];

    integer link = g_iLinks;
    do {
        string description = llStringTrim(llList2String(llGetLinkPrimitiveParams(link,[PRIM_DESC]),0),STRING_TRIM);
        list lParts = llParseStringKeepNulls(description,["~"],[]);
        string element = llList2String(lParts,0);
        integer iFlags = 0; //bitmask. 1=texture, 2=color, 4=shiny, 8=glow

        if (~llListFindList(lParts,["texture"])) iFlags = iFlags | 1;
        if (~llListFindList(lParts,["color"])) iFlags = iFlags | 2;
        if (~llListFindList(lParts,["shine"])) iFlags = iFlags | 4;
        integer index = llListFindList(g_lElements, [element]);
        if (iFlags > 0) {
            if (!~index) {
                g_lElements += element;
                g_lElementFlags += iFlags;
            } else {
                integer iOldFlags=llList2Integer(g_lElementFlags,index);
                iFlags = iFlags & iOldFlags;
                g_lElementFlags = llListReplaceList(g_lElementFlags,[iFlags],index, index);
            }
        }
    } while (link-- > 2) ;
}


UserCommand(integer iAuth, string sStr, key kAv) {
    if (iAuth < CMD_OWNER || iAuth > CMD_WEARER) return;

    list lParams = llParseString2List(sStr, [" "], []);
    string sCommand = llToLower(llList2String(lParams, 0));
    //string sValue = llToLower(llList2String(lParams, 1));
    if (sCommand == "lockappearance" && iAuth == CMD_OWNER) g_iAppLock = (llList2String(lParams, 1)!="0");

    if (g_iAppLock && iAuth != CMD_OWNER) {
        if (sStr=="menu "+g_sSubMenu)
            Notify(kAv, "The appearance of the " + CTYPE + " is locked. You cannot change appearance now!", FALSE);
    } else if (sStr == "menu " + g_sSubMenu) {
            //someone asked for our menu
            //give this plugin's menu to id
        if (kAv!=g_kWearer && iAuth!=CMD_OWNER) {
            Notify(kAv,"You are not allowed to change the "+CTYPE+"'s appearance.", FALSE);
            llMessageLinked(LINK_SET, iAuth, "menu " + g_sParentMenu, kAv);
        } else ElementMenu(kAv, 0, iAuth);
    }

    if (sCommand == "settexture") {
        string sElement = llList2String(lParams, 1);
        string sTex = llList2String(lParams, 2);
        if (sElement == "") ElementMenu(kAv, 0, iAuth);
        else if (sElement != "" && sTex == "") {
            g_sCurrentElement = sElement;
            TextureMenu(kAv, 0, iAuth);
        } else {
            SetElementTexture(sElement, sTex);
        }
    } else if (sCommand == "setcolor") {
        //Debug(sStr);
        string sElement = llList2String(lParams, 1);
        if (sElement == "") ElementMenu(kAv, 0, iAuth);
        else if (sElement != "" ) {
            vector color = (vector)llGetSubString(sStr,llSubStringIndex(sStr,"<"),llSubStringIndex(sStr,">"));
            SetElementColor(sElement, color);
        } else {
            g_sCurrentElement = sElement;
            ColorCategoryMenu(kAv, 0, iAuth);
        }
    } else if (sCommand == "setshine") {
        string sElement = llList2String(lParams, 1);
        string sShiny = llList2String(lParams, 2);
        if (sElement == "") ElementMenu(kAv, 0, iAuth);
        else if (sElement != "" && sShiny != "") {
            SetElementShiny(sElement, (integer)sShiny);
        } else {
            g_sCurrentElement = sElement;
            ShinyMenu(kAv, 0, iAuth);
        }
    } else if (sStr == "resend_appearance" ) {
        LoadTextureSettings();
        LoadColorSettings();
        LoadShinySettings();
    }
}


default {
    state_entry() {
        g_kWearer = llGetOwner();
        BuildElementsList();
        BuildTextureList();
        //Debug("FreeMem: " + (string)llGetFreeMemory());
    }

    on_rez(integer iParam) {
        //llResetScript();
        BuildElementsList();
        BuildTextureList();
    }

    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) UserCommand(iNum, sStr, kID);
        else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu) {
            llMessageLinked(LINK_THIS , MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        } else if (iNum == SETTING_RESPONSE) {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (sToken == "texture") g_lTextureSetting = llParseString2List(sValue, ["~"], []);
            else if (sToken == "color") g_lColorSettings = llParseString2List(sValue, ["~"], []);
            else if (sToken == "shine") g_lShinySettings = llParseString2List(sValue, ["~"], []);
            else if (sToken == g_sAppLockToken) g_iAppLock = (integer)sValue;
            else if (sStr == "settings=sent") {
                LoadTextureSettings();
                LoadColorSettings();
                LoadShinySettings();
            }
        } else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (~iMenuIndex) {
                //got a menu response meant for us.  pull out values
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iPage = (integer)llList2String(lMenuParams, 2);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                string sMenuType = llList2String(g_lMenuIDs, iMenuIndex + 1);
                //remove stride from g_lMenuIDs
                //we have to subtract from the index because the dialog id comes in the middle of the stride
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);

                if (sMenuType == "ElementMenu") {
                    if (sMessage == UPMENU) llMessageLinked(LINK_SET, iAuth, "menu " + g_sParentMenu, kAv);
                    else if ((~llListFindList(g_lElements, [sMessage])) || sMessage == "All") {
                        g_sCurrentElement = sMessage;
                        CustomMenu(kAv, iPage, iAuth);
                    } else {
                        g_sCurrentElement = "";
                        ElementMenu(kAv, iPage, iAuth);
                    }
                } else if (sMenuType == "CustomMenu") {
                    if (sMessage == UPMENU) ElementMenu(kAv, iPage, iAuth);
                    else if (sMessage == "Texture") TextureMenu(kAv, iPage, iAuth);
                    else if (sMessage == "Color") ColorCategoryMenu(kAv, iPage, iAuth);
                    else if (sMessage == "Shine") ShinyMenu(kAv, iPage, iAuth);
                } else if (sMenuType == "TextureMenu") {
                    if (sMessage == UPMENU) CustomMenu(kAv, iPage, iAuth);
                    else {
                        SetElementTexture(g_sCurrentElement, sMessage);
                        TextureMenu(kAv, iPage, iAuth);
                    }
                } else if (sMenuType == "CategoryMenu") {
                    if (sMessage == UPMENU) CustomMenu(kAv, iPage, iAuth);
                    else {
                        g_sCurrentCategory = sMessage;
                        ColorMenu(kAv, iPage, iAuth);
                    }
                } else if (sMenuType == "ColorMenu") {
                    if (sMessage == UPMENU) ColorCategoryMenu(kAv, iPage, iAuth);
                    else if (~llListFindList(g_lColors, [sMessage])) {
                        integer iIndex = llListFindList(g_lColors, [sMessage]);
                        vector vColor = (vector)llList2String(g_lColors, iIndex + 1);
                        SetElementColor(g_sCurrentElement, vColor);
                        ColorMenu(kAv, iPage, iAuth);
                    }
                } else if (sMenuType == "ShinyMenu") {
                    if (sMessage == UPMENU) CustomMenu(kAv, iPage, iAuth);
                    else if (~llListFindList(g_lShiny, [sMessage])) {
                        integer iShiny = llListFindList(g_lShiny, [sMessage]);
                        SetElementShiny(g_sCurrentElement, iShiny);
                        ShinyMenu(kAv, iPage, iAuth);
                    }
                }
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (~iMenuIndex) {
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
            }
        }
    }

    changed(integer iChange) {
        if (iChange & CHANGED_OWNER) llResetScript();
        if (iChange & CHANGED_LINK) BuildElementsList();
        if (iChange & CHANGED_INVENTORY) BuildTextureList();
    }

}