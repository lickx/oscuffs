//=============================================================================
//== OC Cuff - chains
//=============================================================================

integer LG_CMD = -9119;
integer LM_CUFF_CMD = -551001;
integer LM_CUFF_POINT = -551003;

list g_lCommands = ["id","link","unlink","ping","free","texture","size","life","speed","gravity","color"];

// These textures were granted by Zi and Tengu (see credits at top) for use in OC_ V2.
// Although they are being distributed with V2, they are still owned by their respective creators.
key kDefaultChain = "796ef797-1726-4409-a70f-cd64304ada22";
key kDefaultRope = "36b304cc-6209-4f47-9e4a-a68901e98e6e";

// Default particle chain values, if they're not loaded from the configuration notecard
// these are what they will be. Don't change the defaults here, change them in the OC_ V2
// Config notecard instead.
//key   kTextureDefault = "40809979-b6be-2b42-e915-254ccd8d9a08";
key   kTextureDefault = "796ef797-1726-4409-a70f-cd64304ada22";

vector vSizeDefault = <0.07,0.07,1>;
float fLifeDefault = 1;
float fGravityDefault = 0.3;
float fMinSpeedDefault = 0.005; // Not really used, life generally determines speed.
float fMaxSpeedDefault = 0.005; // Not really used, life generally determines speed.
vector vColorDefault = <1,1,1>;

// Particle chain values the program will actually use. Don't fill them in,
// they'll only get written over later.
key   kTexture;
vector vSize;
float fLife;
float fGravity;
float fMinSpeed;
float fMaxSpeed;
vector vColor;

key g_kWearer;

integer g_iCmdChannel = -190889;
integer g_iCmdChannelOffset = 0xCC0CC;

list g_lOC_Points ; // list of Cuff points IDs
list g_lOC_Links ;  // list of Cuff points prims links
list g_lOC_Targets ;  // list of Cuff points chain targets


integer GetOwnerChannel(integer iOffset) {
    integer chan = (integer)("0x"+llGetSubString((string)g_kWearer,3,8)) + iOffset;
    if (chan > 0) chan = chan*(-1);
    if (chan > -10000) chan -= 30000;
    return chan;
}

FindCuffPoints() {
    g_lOC_Points = [];
    g_lOC_Links = [];
    g_lOC_Targets = [];

    integer link;
    integer linkcount = llGetNumberOfPrims();
    //root link is 1, so start at 2
    for (link = 2; link <= linkcount; link++) {
        
        list params = llParseString2List(llStringTrim(llGetLinkName(link), STRING_TRIM), ["~"], [""]);        
        //list params = llParseString2List(llList2String(llGetLinkPrimitiveParams(link, [PRIM_DESC]), 0), ["~"], []);        
        integer i;
        for (i=0; i < llGetListLength(params); i++) {
            string name = llList2String(params, i);

            if (llSubStringIndex(name, "OC:") == 0) {
                list points = llCSV2List(llGetSubString(name, llSubStringIndex(name,":")+1, -1 ));
                for (i=0 ; i<llGetListLength(points) ; i++) {
                    string PointName = llList2String(points,i);
                    g_lOC_Points += [PointName] ;
                    g_lOC_Links += [link];
                    g_lOC_Targets += [NULL_KEY];
                    llMessageLinked(LINK_THIS, LM_CUFF_POINT, PointName, "");
                }
            }
        }
    }
}

RestoreOC_Defaults() {
    kTexture = kTextureDefault;
    vSize = vSizeDefault;
    fLife = fLifeDefault;
    fGravity = fGravityDefault;
    fMinSpeed = fMinSpeedDefault;
    fMaxSpeed = fMaxSpeedDefault;
    vColor = vColorDefault;
}

RelinkCuffs() {
    integer count = llGetListLength(g_lOC_Links);
    integer i;

    for (i = 0; i < count; i++) {
        OC_Link(i, llList2Key(g_lOC_Targets, i));
    }
}

OC_Link(integer index, key kTarget) {
    // The simple secret of a particle chain revealed! :)
    integer link = llList2Integer(g_lOC_Links, index);
    llLinkParticleSystem(link, []);

    if (kTarget == NULL_KEY) return;

    integer iBitField = PSYS_PART_TARGET_POS_MASK|PSYS_PART_FOLLOW_VELOCITY_MASK|PSYS_PART_FOLLOW_SRC_MASK;
    if (fGravity == 0) iBitField = iBitField|PSYS_PART_TARGET_LINEAR_MASK;

    llLinkParticleSystem(link, [ PSYS_PART_MAX_AGE, fLife, PSYS_PART_FLAGS, iBitField, PSYS_PART_START_COLOR, vColor, PSYS_PART_END_COLOR, vColor, PSYS_PART_START_SCALE, vSize, PSYS_PART_END_SCALE, vSize, PSYS_SRC_PATTERN, 1, PSYS_SRC_BURST_RATE, 0, PSYS_SRC_ACCEL, <0,0,(fGravity*-1)>, PSYS_SRC_BURST_PART_COUNT, 10, PSYS_SRC_BURST_RADIUS, 0, PSYS_SRC_BURST_SPEED_MIN, fMinSpeed, PSYS_SRC_BURST_SPEED_MAX, fMaxSpeed, PSYS_SRC_INNERANGLE, 0, PSYS_SRC_OUTERANGLE, 0, PSYS_SRC_OMEGA, <0,0,0>, PSYS_SRC_MAX_AGE, 0, PSYS_PART_START_ALPHA, 1, PSYS_PART_END_ALPHA, 1, PSYS_SRC_TARGET_KEY, kTarget, PSYS_SRC_TEXTURE, kTexture ] );

    g_lOC_Targets = llListReplaceList(g_lOC_Targets,[kTarget], index, index);
}

OC_Unlink(integer index) {
    // Unlink the particle chain, restore the item's defaults, and move along.
    integer link = llList2Integer(g_lOC_Links, index);
    llLinkParticleSystem(link, []);
    RestoreOC_Defaults();
    g_lOC_Targets = llListReplaceList(g_lOC_Targets,[NULL_KEY], index, index);
}

OC_Texture(key texture) {
    kTexture = texture;
    if (kTexture == "chain") kTexture = kDefaultChain;
    if (kTexture == "rope") kTexture = kDefaultRope;
}

OC_Size(float X, float Y) {
    vSize =  <X, Y, 1> ;
}

OC_Life(float life) {
    fLife = life;
}

OC_Speed(float min, float max) {
    fMinSpeed = min;
    fMaxSpeed = max;
}

OC_Gravity(float gravity) {
    fGravity = gravity;
}

OC_Color(float R, float G, float B) {
    vColor = <R,G,B>;
}

OC_Obey(list lCommandLine) {

    integer iCommands = llGetListLength(lCommandLine);
    integer iParser = 1;

    do {
        integer cmd = llListFindList(g_lCommands, llList2List(lCommandLine, iParser, iParser) );
        key target;
        if (cmd == 1) target = llList2Key(lCommandLine, ++iParser);
        string sCuffPoint = llList2String(lCommandLine, 0);

        integer index = llListFindList(g_lOC_Points, [sCuffPoint]);
        if (~index) {
            // These commands can only be called via chat command blocks.
            if (cmd == 1) OC_Link(index, target);
            if (cmd == 2) OC_Unlink(index);
        } else if (sCuffPoint == "*") {
            integer count = llGetListLength(g_lOC_Points);
            for (index = 0; index < count; index++) {
                if (cmd == 1) OC_Link(index, target);
                if (cmd == 2) OC_Unlink(index);
            }
        }

        if (cmd == 5) OC_Texture(llList2Key(lCommandLine,++iParser));
        if (cmd == 6) OC_Size(llList2Float(lCommandLine,++iParser), llList2Float(lCommandLine,++iParser));
        if (cmd == 7) OC_Life(llList2Float(lCommandLine,++iParser));
        if (cmd == 8) OC_Speed(llList2Float(lCommandLine, ++iParser), llList2Float(lCommandLine, ++iParser));
        if (cmd == 9) OC_Gravity(llList2Float(lCommandLine, ++iParser));
        if (cmd == 10) OC_Color(llList2Float(lCommandLine, ++iParser), llList2Float(lCommandLine, ++iParser), llList2Float(lCommandLine, ++iParser));

        if (cmd > 4) RelinkCuffs();

        iParser++;
    } while(iParser < iCommands);

}

//==================================================
//  default
//==================================================

default {
    on_rez(integer iNum) {
        // Kill any lingering chains and do a complete script reset during a new rez.
        RelinkCuffs();
        if (g_kWearer != llGetOwner()) llResetScript();
    }

    state_entry() {
        g_kWearer = llGetOwner();
        FindCuffPoints();
        llLinkParticleSystem(LINK_SET, []);
        RestoreOC_Defaults();
        g_iCmdChannel = GetOwnerChannel(g_iCmdChannelOffset)+1;
        //llOwnerSay(llGetScriptName ()+" ready - Freee Memory : " + (string)llGetFreeMemory());
    }

    link_message(integer iSender, integer iNum, string sStr, key kID) {
        // Parse the command line.
        if (iNum == LG_CMD) {
            list lCommandLine = llParseString2List(llToLower(sStr), [" "], []);
            if (llListFindList(lCommandLine, ["lockguard",(string)g_kWearer]) != 0 ) return;

            lCommandLine = llDeleteSubList(lCommandLine, 0, 1);
            string cuffpoint = llList2String(lCommandLine, 0);

            if (~llListFindList(g_lOC_Points+["all"],[cuffpoint])) OC_Obey(lCommandLine);

        } else if (iNum == LM_CUFF_CMD) {
            // OpenCuffs ChainIt from here
            if (sStr == "reset") llResetScript();
            list lParsed = llParseString2List(sStr, ["="], []);
            string sCmd = llList2String(lParsed, 0);

            if (sCmd == "chain" &&  llGetListLength(lParsed) == 4) {
                string sFrom = llList2String(lParsed, 1);
                integer index = llListFindList(g_lOC_Points,[sFrom]);

                if (~index || sFrom == "*") {
                    string sTo = llList2String(lParsed, 2);
                    string sLink = llList2String(lParsed, 3);
                    key CuffPointKey = llGetLinkKey(llList2Integer(g_lOC_Links,index));
                    if (sLink == "unlink" || sLink == "link") {
                        llRegionSayTo(g_kWearer, g_iCmdChannel, "lockguard "+(string)g_kWearer+" "+sTo+" "+sLink+" "+(string)CuffPointKey);
                    } else if (llGetSubString(sLink,0,3)=="link" && (llStringLength(sLink)>5)) {
                        llRegionSayTo(g_kWearer, g_iCmdChannel, "lockguard "+(string)g_kWearer+" "+sTo+" "+llGetSubString(sLink,5,-1)+" link "+(string)CuffPointKey);
                    }
                }
                //"chain=llac=rlac=unlink"
            }
        }
    }

    changed (integer change) {
        if (change & CHANGED_LINK) llResetScript();
        if (change & CHANGED_OWNER) llResetScript();
    }
}