// LockMeister addon

//  added channel -8888 and handler for lockmeister
integer g_iLMchannel = -8888;
string  g_sLMpoint = "rlcuff"; // will be read on int from the Object Name 

//====================================================================================================
//  LockGuard V2 Script (Rev 1)
//      ..... by Lillani Lowell
//
//      Special thanks (in alphabetical order) go to:
//
//          Tengu Tamabushi (testing/debugging/code support & rope texture)
//          Zi Ree (testing/debugging/code support & chain texture)
//
//              The chain and rope textures which LockGuard V2 uses are owned by Tengu and Zi.
//
//      And thanks to all the people who are using LockGuard!
//
//==================================================
//
// LockGuard V2 is a simple, powerful, programmable, and highly versatile particle chain
// link library. LockGuard V2 is a plug and play, multiple purple chain/rope/hose generator
// which can be used for fences, streamers, decorations, spiderwebs, and b&d related items.
//
// LockGuard chains are called by matching an avatar key with a particle chain ID tag, and
// by using this method particle chains can be called individually, in groups, or even all
// at once.
//
// Now.....
//
// I'd like to say, the way this source is written may seem a little odd to some people,
// but there *is* a rhyme and reason to my apparant madness, even
// if it doesn't seem entirely obvious at first glance. :)
//
// And, of course, code improvements are always welcome!
//
// Feel free to use this code in any derivitive works, a source mention would be
// nice, but not necessary. :)
//
// LockGuard Features:
//      -- One way communication, no need to haggle.
//      -- Plug and play functionality.
//      -- Built-in particle chain generator, configurable "on the fly".
//      -- 100% backwards compatibility with all previous furniture and devices.
//      -- Simplistic, furniture side scripting, LockGuard is your wheel, you don't have to reinvent it.
//      -- Call chains based on customizable ID tags, call multiple chains which share one ID.
//      -- Determine whether or not an item exists through a ping.

// LockGuard V2 Features:
//      -- Open source!
//      -- Multi-command parsing, include all your LockGuard commands in a single chatblock.
//      -- Multiple ID tags per item, call a chain individually, call it by a group tag, or all at once!
//      -- Determine whether or not a chain is linked from the item.
//      -- Ability to change channels for private projects (requires g_iPrivateProject=TRUE).
//      -- Ability to disable listen entirely, for "fire and forget" chains (requires g_iPrivateProject=TRUE).

//==================================================
//  program variables
//==================================================

// Changing g_iPrivateProject to TRUE will allow LockGuard V2 devices to change the LG channel
// or even disable llListen entirely. g_iPrivateProject should *always* be false for items which
// use non-static or linking with public items.
integer g_iPrivateProject = FALSE;


// Typical channel and handler.
integer g_iChannel = -9119;
integer g_iHandle;

// Variables for sucking the data out of a notecard. See the default state.
string g_sNCname = "LockGuard V2 Config";
string g_sNCdata;
list   g_lNCdataList;
integer g_iNCline;
key     g_kNCQueryID;
integer g_iLoadingNotecard = FALSE;

// Command line storage + parser count.
list g_lCommandLine;
integer g_iParserCount;

// Chat lines are converted into lists because
// it is assumed the internal compiled FindList functions will work faster than
// breaking it down into substrings and then having a bunch of intepreted if and thens
// running amok on a virtual machine comparing them.
//
// Known Issue
//
// The only potential issue with the new V2 Script is that it now supports multiple LockGuard
// commands in a single command block. This was included in the overhaul of the parser which old
// LockGuard does not support. This will *not* affect LockGuard devices or furniture which are
// already on the market, as they are still compatible with the LockGuard protocol.
// Backwards compatibility has been thoroughly tested to make sure old LockGuard furniture/devices
// operate as they should with the new LockGuard V2 Script.
//
// The only time this issue will present a problem is when new V2 furniture or devices use the
// new multi-command format and try to communicate with the old LockGuard Item Script. The old
// LockGuard Item Script will only recognize the first command, and ignore the rest. This is
// easily solved by dropping in the LockGuard V2 Script and LockGuard V2 Config notecard in place
// of the old LockGuard Item Script and LockGuard Item Config notecard into your item, etc.
//
// Again, this *does not* affect the use of current /furniture/ or /devices/.
//
// I had debated on adding the new multi-command parser because of this potential issue, but at
// the last minute decided being able to configure AND link a chain in one single call
// which significantly reduces LockGuard channel use and increases overall performance
// outweighed the minor inconvenience of taking a moment to change out LockGuards scripts in items.
//
// Evolution is not without its little bumps in the road, but that which does not evolve gets left
// behind.
//

//==================================================
//  lockguard variables
//==================================================
//
// 0 - id
// 1 - link
// 2 - unlink
// 3 - ping
// 4 - free
// 5 - texture
// 6 - size
// 7 - life
// 8 - speed
// 9 - gravity
// 10 - color
// 11 - unlisten    << only works when g_iPrivateProject = TRUE
// 12 - channel     << only works when g_iPrivateProject = TRUE
//
// Do not modify or change the order of g_lLGcommands unless you KNOW what you're doing!
list g_lLGcommands = ["id", "link", "unlink", "ping", "free", "texture", "size", "life", "speed", "gravity", "color", "unlisten", "channel"];

// These textures were granted by Zi and Tengu (see credits at top) for use in LockGuard V2.
// Although they are being distributed with V2, they are still owned by their respective creators.
key kDefaultChain = "796ef797-1726-4409-a70f-cd64304ada22";
key kDefaultRope = "36b304cc-6209-4f47-9e4a-a68901e98e6e";
list lLockGuardID = [];
key  kTarget;

// Default particle chain values, if they're not loaded from the configuration notecard
// these are what they will be. Don't change the defaults here, change them in the LockGuard V2
// Config notecard instead.
key   kTextureDefault = "796ef797-1726-4409-a70f-cd64304ada22";
float fSizeXDefault = 0.07;
float fSizeYDefault = 0.07;
float fLifeDefault = 1;
float fGravityDefault = 0.3;
float fMinSpeedDefault = 0.005; // Not really used, life generally determines speed.
float fMaxSpeedDefault = 0.005; // Not really used, life generally determines speed.
float fRedDefault = 1;
float fGreenDefault = 1;
float fBlueDefault = 1;

// Particle chain values the program will actually use. Don't fill them in,
// they'll only get written over later.
key   kTexture;
float fSizeX;
float fSizeY;
float fLife;
float fGravity;
float fMinSpeed;
float fMaxSpeed;
float fRed;
float fGreen;
float fBlue;

integer g_iLinked = FALSE;

//==================================================
//  filter
//==================================================

integer LG_ItemCheck() {
    // LockGuard will do the checks to ensure the command line meets the following critera:
    //      1. It's meant for LockGuard.
    //      2. It's meant for the avatar who owns the item this script is in.
    //      3. It's meant for all items OR.....
    //      4. It's meant for a corresponding ID tag which has been given to this item.
    //
    // While ALL is still supported as a tag for backwards compatibility with some old devices, it should
    // *never* be used in new devices.
    if (llList2String(g_lCommandLine, 0) != "lockguard") return FALSE;
    if (llList2String(g_lCommandLine, 1) != (string)llGetOwner()) return FALSE;
    if (llList2String(g_lCommandLine, 2) == "all") return TRUE;
    if (llListFindList(lLockGuardID, llList2List(g_lCommandLine, 2, 2)) == -1) return FALSE;
    return TRUE;
}

//==================================================
//  particle chain
//==================================================

Restore_LG_Defaults() {
    // Restore the chain defaults, LockGuard does this when the script first starts (after
    // loading from the notecard), when attached to an avatar, or when an unlink command
    // is issued.
    kTexture = kTextureDefault;
    fSizeX = fSizeXDefault;
    fSizeY = fSizeYDefault;
    fLife = fLifeDefault;
    fGravity = fGravityDefault;
    fMinSpeed = fMinSpeedDefault;
    fMaxSpeed = fMaxSpeedDefault;
    fRed = fRedDefault;
    fGreen = fGreenDefault;
    fBlue = fBlueDefault;
}

LockGuardLink(integer iRelinking) {
    // The simple secret of a particle chain revealed! :)
    integer nBitField = PSYS_PART_TARGET_POS_MASK|PSYS_PART_FOLLOW_VELOCITY_MASK|PSYS_PART_FOLLOW_SRC_MASK;
    llParticleSystem([]);
    if (iRelinking == FALSE) kTarget = llList2Key(g_lCommandLine, ++g_iParserCount);
    if (fGravity == 0) nBitField = nBitField|PSYS_PART_TARGET_LINEAR_MASK;

    llParticleSystem([ PSYS_PART_MAX_AGE, fLife, PSYS_PART_FLAGS, nBitField, PSYS_PART_START_COLOR, <fRed, fGreen, fBlue>, PSYS_PART_END_COLOR, <fRed, fGreen, fBlue>, PSYS_PART_START_SCALE, <fSizeX, fSizeY, 1.00000>, PSYS_PART_END_SCALE, <fSizeX, fSizeY, 1.00000>, PSYS_SRC_PATTERN, 1, PSYS_SRC_BURST_RATE, 0.000000, PSYS_SRC_ACCEL, <0.00000, 0.00000, (fGravity*-1)>, PSYS_SRC_BURST_PART_COUNT, 10, PSYS_SRC_BURST_RADIUS, 0.000000, PSYS_SRC_BURST_SPEED_MIN, fMinSpeed, PSYS_SRC_BURST_SPEED_MAX, fMaxSpeed, PSYS_SRC_INNERANGLE, 0.000000, PSYS_SRC_OUTERANGLE, 0.000000, PSYS_SRC_OMEGA, <0.00000, 0.00000, 0.00000>, PSYS_SRC_MAX_AGE, 0.000000, PSYS_PART_START_ALPHA, 1.000000, PSYS_PART_END_ALPHA, 1.000000, PSYS_SRC_TARGET_KEY, kTarget, PSYS_SRC_TEXTURE, (string)kTexture ]);

    g_iLinked = TRUE;
}

LockGuardUnlink() {
    // Unlink the particle chain, restore the item's defaults, and move along.
    llParticleSystem([]);
    Restore_LG_Defaults();
    g_iLinked = FALSE;
    kTarget = NULL_KEY;
}

LockGuardTexture() {
    // Change the texture.
    if (g_iLoadingNotecard == FALSE) kTexture = llList2Key(g_lCommandLine, ++g_iParserCount);
    else kTextureDefault = llList2Key(g_lCommandLine, ++g_iParserCount);

    if (kTexture == "chain") kTexture = kDefaultChain;
    if (kTexture == "rope") kTexture = kDefaultRope;

    if (g_iLinked) LockGuardLink(TRUE);
}

LockGuardSize() {
    // Change the size.
    if (g_iLoadingNotecard == FALSE) {
        fSizeX = llList2Float(g_lCommandLine, ++g_iParserCount);
        fSizeY = llList2Float(g_lCommandLine, ++g_iParserCount);
    } else {
        fSizeXDefault = llList2Float(g_lCommandLine, ++g_iParserCount);
        fSizeYDefault = llList2Float(g_lCommandLine, ++g_iParserCount);
    }

    if (g_iLinked) LockGuardLink(TRUE);
}

LockGuardLife() {
    // Change the life.
    if (g_iLoadingNotecard == FALSE) fLife = llList2Float(g_lCommandLine, ++g_iParserCount);
    else fLifeDefault = llList2Float(g_lCommandLine, ++g_iParserCount);

    if (g_iLinked) LockGuardLink(TRUE);
}

LockGuardSpeed() {
    // Change the speed.
    if (g_iLoadingNotecard == FALSE) {
        fMinSpeed = llList2Float(g_lCommandLine, ++g_iParserCount);
        fMaxSpeed = llList2Float(g_lCommandLine, ++g_iParserCount);

    } else {
        fMinSpeedDefault = llList2Float(g_lCommandLine, ++g_iParserCount);
        fMaxSpeedDefault = llList2Float(g_lCommandLine, ++g_iParserCount);
    }

    if (g_iLinked) LockGuardLink(TRUE);
}

LockGuardGravity() {
    // Change the amount of gravity.
    if (g_iLoadingNotecard == FALSE) fGravity = llList2Float(g_lCommandLine, ++g_iParserCount);
    else fGravityDefault = llList2Float(g_lCommandLine, ++g_iParserCount);

    if (g_iLinked) LockGuardLink(TRUE);
}

LockGuardColor() {
    // Change the color/tint.
    if (g_iLoadingNotecard == FALSE) {
        fRed = llList2Float(g_lCommandLine, ++g_iParserCount);
        fGreen = llList2Float(g_lCommandLine, ++g_iParserCount);
        fBlue = llList2Float(g_lCommandLine, ++g_iParserCount);
    } else {
        fRedDefault = llList2Float(g_lCommandLine, ++g_iParserCount);
        fGreenDefault = llList2Float(g_lCommandLine, ++g_iParserCount);
        fBlueDefault = llList2Float(g_lCommandLine, ++g_iParserCount);
    }

    if (g_iLinked) LockGuardLink(TRUE);
}

//==================================================
//  channel
//==================================================

LockGuardUnlisten() {
    // Kill the listener. This command will not work unless g_iPrivateProject == TRUE.
    // llListenRemove(g_iHandle);
}

LockGuardChannelChange() {
    // Swap channels. This command will not work unless g_iPrivateProject == TRUE.
    // llListenRemove(g_iHandle);
    // g_iChannel = llList2Integer(g_lCommandLine, ++g_iParserCount);
    // g_iHandle = llListen(g_iChannel, "", NULL_KEY, "");
}

//==================================================
//  obedience
//==================================================

LockGuardSetID() {
    // Assign a new ID to the item, an item can have multiple IDs.
    g_iParserCount++;
    lLockGuardID += llList2List(g_lCommandLine, g_iParserCount, g_iParserCount);
}

LockGuardPing() {
    // Do we exist?
    llWhisper(g_iChannel, "lockguard " + (string)llGetOwner() + " " +  llList2String(lLockGuardID, 0) + " okay");
}

LockGuardFree() {
    // Are we free?
    if (g_iLinked) llWhisper(g_iChannel, "lockguard " + (string)llGetOwner() + " " +  llList2String(lLockGuardID, 0) + " no");
    else llWhisper(g_iChannel, "lockguard " + (string)llGetOwner() + " " +  llList2String(lLockGuardID, 0) + " yes");
}

LockGuardObey(integer iBase) {
    integer iCommands = llGetListLength(g_lCommandLine);
    integer iReturn;
    // Let's parse! The script will poll through the commandline and compare it to any known commands
    // provided in the command list defined under the variables with g_lLGcommands. If it finds a
    // match it'll call the command based on its number.
    //
    // In theory, searching commands this way using compiled/native functions should be faster than using
    // multiple functions to break the commandline down into substrings, storing the substrings, and then           // comparing them on a virtual machine. Maybe someone can confirm/deny this.
    //
    // When iBase == 3, it is being called from the listen block.
    // When iBase == 0, it is being called from the notecard reader.
    g_iParserCount = iBase;
    do {
        iReturn = llListFindList(g_lLGcommands, llList2List(g_lCommandLine, g_iParserCount, g_iParserCount));
        if (iBase == 3) {
            // These commands can only be called via chat command blocks.
            if (iReturn == 1) LockGuardLink(FALSE);
            else if (iReturn == 2) LockGuardUnlink();
            if (iReturn == 3) LockGuardPing();
            if (iReturn == 4) LockGuardFree();
        }
        // These commands can be called anywhere, either by setting defaults through the notecards
        // or through chatblocks.
        if (iReturn == 5) LockGuardTexture();
        if (iReturn == 6) LockGuardSize();
        if (iReturn == 7) LockGuardLife();
        if (iReturn == 8) LockGuardSpeed();
        if (iReturn == 9) LockGuardGravity();
        if (iReturn == 10) LockGuardColor();

        if (g_iPrivateProject == TRUE) {
            // LockGuard willonly allow channel changing and unlistening if g_iPrivateProject == TRUE
            if (iReturn == 11) LockGuardUnlisten();
            if (iReturn == 12) LockGuardChannelChange();
        }

        if (iBase == 0) {// These commands can only be called via the notecard reader.
             if (iReturn == 0) LockGuardSetID();
        }

        g_iParserCount++;

    } while(g_iParserCount < iCommands);

}

//==================================================
//  default
//==================================================

default {
    // The standard, "let's read the notecard" function.
    state_entry() {
        g_iNCline = 0;
        g_kNCQueryID = llGetNotecardLine(g_sNCname, g_iNCline);
        g_iLoadingNotecard = TRUE;
    }

    dataserver(key query_id, string data) {
        integer i;
        if (query_id == g_kNCQueryID) {
            if (data != EOF) {
                if (g_iNCline > 0) g_sNCdata += " ";
                else g_lNCdataList = [];
                g_lNCdataList += [ data ];
                g_iNCline++;
                g_kNCQueryID = llGetNotecardLine(g_sNCname, g_iNCline);
            } else {
                do {
                    g_lCommandLine = llParseString2List(llToLower(llList2String(g_lNCdataList, i)), [ " " ], []);
                    LockGuardObey(0);
                    i++;
                } while(i < llGetListLength(g_lNCdataList));

                g_lNCdataList = [];
                state lockguardGo;
            }
        }
    }

    changed(integer change) {
        // If anything in our inventory changes, reset.
        if (change == CHANGED_INVENTORY) llResetScript();
    }

}

//==================================================
//  lockguardGo
//==================================================

state lockguardGo {
    on_rez(integer num) {
        // Kill any lingering chains and do a complete script reset during a new rez.
        LockGuardUnlink();
        llResetScript();
    }

    state_entry() {
        // Load up the default chain values and listen up.
        g_iLoadingNotecard = FALSE;
        Restore_LG_Defaults();
        // Now some LockMeister
        // Getting the LM attachment name from the object name
        g_sLMpoint = llGetObjectName();
        //adding lockmeistersupport
        llListen(g_iLMchannel, "", "", "");
    }

    link_message(integer sender,integer num,string message,key id) {
        // Parse the command line.
        if (num==g_iChannel) {
            g_lCommandLine = llParseString2List(llToLower(message), [ " " ], []);
            if (!LG_ItemCheck()) return;
            LockGuardObey(3);
        }
    }

    changed(integer change) {
        // If anything in our inventory changes, reset.
        if (change == CHANGED_INVENTORY) llResetScript();
    }

    // Listener for LockMeister
    listen(integer channel, string name, key id, string message) {
        //check if it is lockmeister or lockgaurd channel before continuing
        if (!llGetAttached()) return;
        if (channel == g_iLMchannel) {
            if (message == (string)llGetOwner()+ g_sLMpoint) {
                //This part reply to Lockmeister v1 messages
                //message structure:   llGetOwner()+mooring_point (without the '+')
                llWhisper(g_iLMchannel,(string)llGetOwner() + g_sLMpoint + " ok");
                //message structure:   llGetOwner()+mooring_point+" ok" (without the '+')
            } else {
                //This part reply to Lockmeister v2 messages
                list params = llParseString2List(message, ["|"], []);
                if (llList2List(params,0,3) == [llGetOwner(), "LMV2", "RequestPoint", g_sLMpoint]) {
                    //this message is for us, it's claiming to be an LMV2 message,
                    //message structure:   llGetOwner()|LMV2|RequestPoint|anchor_name
                    //Now that we are certain that the message concerns us, we look for the prim key to insert in our reply.
                    llRegionSayTo(id, g_iLMchannel, llDumpList2String([llGetOwner(), "LMV2", "ReplyPoint", g_sLMpoint, llGetKey()], "|"));
                }
            }
        }
    }
}
