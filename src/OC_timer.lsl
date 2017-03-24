//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

string parentmenu = "Main";
string submenu = " Timer";

// messages for authenticating users
integer CMD_NOAUTH = 0;
integer CMD_OWNER = 500;
integer CMD_TRUST = 501;
integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
integer CMD_EVERYONE = 504;

// added so when the sub is locked out they can use postions
integer CMD_WEARERLOCKEDOUT = 521;
integer WEARERLOCKOUT = 620;

integer LM_SETTING_SAVE = 2000;
integer LM_SETTING_REQUEST = 2001;
integer LM_SETTING_RESPONSE = 2002;
integer LM_SETTING_DELETE = 2003;
integer LM_SETTING_EMPTY = 2004;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

// menu option to go one step back in menustructure
string UPMENU = "▲";
// buttons
string REALTIME = "REAL" ;
string ONLINE = "ONLINE" ;
string START = "START" ;
string STOP = "STOP" ;

string ON = "▣ " ;
string OFF = "☐ " ;
string UNLOCK = "unlock" ;
string UNCHAIN = "unchain" ;
string RLVCLR = "clear RLV" ;
integer MAX_TIME=0x7FFFFFFF;

list localbuttons = ["ONLINE", "REAL"]; // ONLINE, REALTIME
list timebuttons = ["clear","+00:01","+00:05","+00:30","+03:00","+24:00","-00:01","-00:05","-00:30","-03:00","-24:00"];
list timechanges = [0, 60, 300, 1800, 10800, 86400, -60, -300, -1800, -10800, -86400];

//these can change
integer REAL_TIME=1;
integer REAL_TIME_EXACT=5;
integer ON_TIME=3;
integer ON_TIME_EXACT=7;

integer timeslength;
integer currenttime;
integer ontime;
integer lasttime;
integer firstontime;
integer firstrealtime;
integer lastrez;
integer n;//for loops

// end time keeper

integer onrunning;
integer onsettime;
integer ontimeupat;

integer realrunning;
integer realsettime;
integer realtimeupat;

integer unlockcuffs;
integer cuffslocked;
integer clearRLVrestions;
integer unleash;
integer both;
integer whocanchangetime;
integer whocanchangeleash;
integer whocanchangeothersettings;

list g_lMenuIDs;  //three strided list of avkey, dialogid, and menuname
integer g_iMenuStride = 3;

key g_kWearer;

list times;

/*
debug(string sMsg) {
    llOwnerSay(llGetScriptName() + ": " + sMsg);
}
*/


Notify(key kID, string sMsg, integer iAlsoNotifyWearer) {
    if (kID == g_kWearer) llOwnerSay(sMsg);
    else {
        if (llGetAgentSize(kID)) llRegionSayTo(kID,0,sMsg);
        else llInstantMessage(kID, sMsg);
        if (iAlsoNotifyWearer) llOwnerSay(sMsg);
    }
}


integer nStartsWith(string sHaystack, string sNeedle) {
    return (llDeleteSubString(sHaystack, llStringLength(sNeedle), -1) == sNeedle);
}

Dialog(key kID, string sPrompt, list lChoices, list lUtility, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_THIS, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtility, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}

MainMenu(key kAV, integer iAutn) {
    //debug("timeremaning:"+(string)(ontimeupat-ontime));
    string prompt = "\nTimer menu.\n";
    list mybuttons = localbuttons ;

    //fill in your button list and additional prompt here
    prompt += "\nOnline timer - ";
    if (onrunning==1) prompt += int2time(ontimeupat-ontime)+" left";
    else prompt += int2time(onsettime) + " - not running";

    prompt += "\nRealtime timer - ";
    if (realrunning==1) prompt += int2time(realtimeupat-currenttime)+" left";
    else prompt += int2time(realsettime) + " - not running";

    if (realrunning || onrunning) mybuttons += [STOP];
    else if (realsettime || onsettime) mybuttons += [START];
    else mybuttons += [" "];

    prompt += "\n\nWhen the timer goes off:";

    if (unlockcuffs) {
        prompt += "\n•the cuffs will be unlocked";
        mybuttons += [ON+UNLOCK];
    } else {
        prompt += "\n•the cuffs will not be unlocked";
        mybuttons += [OFF+UNLOCK];
    }

    if (unleash) {
        prompt += "\n•the cuffs will be unchained";
        mybuttons += [ON+UNCHAIN];
    } else {
        prompt += "\n•the cuffs will not be unchained";
        mybuttons += [OFF+UNCHAIN];
    }

    //comented out for use in cuffs RLV restrictions does not make sense there.
    /*
    if (clearRLVrestions) {
        prompt += "\n•the RLV restions will be cleared";
        mybuttons += [ON+RLVCLR];
    } else {
        prompt += "\n•the RLV restions will not be cleared";
        mybuttons += [OFF+RLVCLR];
    }
    */

    //prompt += "\n\nPick an option.";

    Dialog(kAV, prompt, mybuttons, [UPMENU], 0, iAutn, "main");
}

DoOnMenu(key kAV, integer iAutn) {
    string prompt = "\nSet Online Timer.\n\n";

    if (onrunning==1) prompt += int2time(ontimeupat-ontime)+" left";
    else prompt += int2time(onsettime) + " - not running";
    Dialog(kAV, prompt, timebuttons, [UPMENU], 0, iAutn, "online");
}

DoRealMenu(key kAV, integer iAutn) {
    string prompt = "\nSet Realtime Timer.\n\n";
    //fill in your button list and additional prompt here
    if (realrunning==1) prompt += int2time(realtimeupat-currenttime)+" left";
    else prompt += int2time(realsettime) + " - not running";
    Dialog(kAV, prompt, timebuttons, [UPMENU], 0, iAutn, "real");
}


string int2time(integer time) {
    if (time<0) time=0;
    integer secs=time%60;
    time = (time-secs)/60;
    integer mins=time%60;
    time = (time-mins)/60;
    integer hours=time%24;
    integer days = (time-hours)/24;

    //this is the onley line that needs changing...
    return ( (string)days+" days "+
        llGetSubString("0"+(string)hours,-2,-1) + ":"+
        llGetSubString("0"+(string)mins,-2,-1) + ":"+
        llGetSubString("0"+(string)secs,-2,-1) );
    //return (string)days+":"+(string)hours+":"+(string)mins+":"+(string)secs;
}

TimerStart(integer num) {
    // do What has to be Done
    whocanchangetime = num;
    if (realsettime) {
        realtimeupat = currenttime + realsettime;
        llMessageLinked(LINK_THIS, WEARERLOCKOUT, "on", "");
        realrunning = 1;
    } else realrunning = 3;

    if (onsettime) {
        ontimeupat = ontime+onsettime;
        llMessageLinked(LINK_THIS, WEARERLOCKOUT, "on", "");
        onrunning = 1;
    } else onrunning = 3;
}

TimerWhentOff() {
    if (both && (onrunning || realrunning)) return;

    llMessageLinked(LINK_THIS, WEARERLOCKOUT, "off", "");
    onsettime = realsettime = 0;
    onrunning = realrunning = 0;
    ontimeupat = realtimeupat = 0;
    whocanchangetime = CMD_EVERYONE;
    if (unlockcuffs) llMessageLinked(LINK_THIS, CMD_OWNER, "unlock", g_kWearer);

    if (clearRLVrestions) {
        llMessageLinked(LINK_THIS, CMD_OWNER, "clear", g_kWearer);
        if (!unlockcuffs && cuffslocked) {
            llSleep(2);
            llMessageLinked(LINK_THIS, CMD_OWNER, "lock", g_kWearer);
        }
    }

    if (unleash) {
        //changed to Stop to release from animation in cuffs
        llMessageLinked(LINK_THIS, CMD_OWNER, "*:Stop", g_kWearer);
    }
    unlockcuffs = clearRLVrestions=unleash=0;
    Notify(g_kWearer, "The timer has expired", FALSE);
}


integer GetTimeChange(string sStr) {
    integer i = llListFindList(timebuttons,[sStr]);
    if (i != -1) return llList2Integer(timechanges,i);
    else return 0 ;
}


SetOnlineTimer(string sStr) {
    integer timechange = GetTimeChange(sStr);
    if (timechange == 0) {
        onsettime = ontimeupat = 0;
        if (onrunning == 1) {
            //unlock
            onrunning = 0;
            TimerWhentOff();
        }
    } else {
        onsettime += timechange;
        if (onsettime < 0) onsettime = 0;
        if (onrunning == 1) {
            ontimeupat += timechange;
            if (ontimeupat <= ontime) {
                //unlock
                onrunning = onsettime = ontimeupat = 0;
                TimerWhentOff();
            }
        } else if (onrunning == 3 && timechange > 0) {
            ontimeupat = ontime + onsettime;
            onrunning = 1;
        }
    }
}


SetRealTimer(string sStr) {
    integer timechange = GetTimeChange(sStr);
    if (timechange == 0) {
        realsettime = realtimeupat = 0;
        if (realrunning == 1) {
            //unlock
            realrunning=0;
            TimerWhentOff();
        }
    } else {
        realsettime += timechange;
        if (realsettime < 0) realsettime = 0;
        if (realrunning == 1) {
            realtimeupat += timechange;
            if (realtimeupat<=currenttime) {
                //unlock
                realrunning = realsettime = realtimeupat = 0;
                TimerWhentOff();
            }
        } else if (realrunning == 3 && timechange > 0) {
            realtimeupat = currenttime + realsettime;
            realrunning = 1;
        }
    }
}

UserCommand(integer iAuth, string sStr, key kAV) {
    if (iAuth < CMD_OWNER || iAuth > CMD_WEARER) return;

    if (llToLower(sStr) == "timer" || sStr == "menu "+ submenu) {
        MainMenu(kAV, iAuth);
    } else if (llGetSubString(sStr, 0, 5) == "timer ") {
        string msg = llGetSubString(sStr, 6, -1);

        if (msg == REALTIME) DoRealMenu(kAV, iAuth);
        else if (msg == ONLINE) DoOnMenu(kAV, iAuth);
        else if (msg == START) {
            TimerStart(iAuth);
            if (kAV != g_kWearer) MainMenu(kAV, iAuth);
        } else if (msg == STOP) {
            TimerWhentOff();  // do What has to be Done
            MainMenu(kAV, iAuth);
        } else if (msg == ON+UNLOCK) {
            if (iAuth == CMD_OWNER) unlockcuffs = 0;
            else Notify(kAV,"Only the owner can change if the cuffs unlock when the timer runs out.",FALSE);
        } else if (msg == OFF+UNLOCK) {
            if (iAuth == CMD_OWNER) unlockcuffs = 1;
            else Notify(kAV,"Only the owner can change if the cuffs unlock when the timer runs out.",FALSE);
        } else if (msg == ON+RLVCLR) {
            if (iAuth == CMD_WEARER) Notify(kAV,"You canot change if the RLV settings are cleared",FALSE);
            else clearRLVrestions=0;
        } else if (msg == OFF+RLVCLR) {
            if (iAuth == CMD_WEARER) Notify(kAV,"You canot change if the RLV settings are cleared",FALSE);
            else clearRLVrestions=1;
        } else if (msg == ON+UNCHAIN) {
            if (iAuth <= whocanchangeleash) unleash = 0;
            else Notify(kAV,"Only the someone who can leash the sub can change if the cuffs unleash when the timer runs out.",FALSE);
        } else if (msg == OFF+UNCHAIN) {
            if (iAuth <= whocanchangeleash) unleash = 1;
            else Notify(kAV,"Only the someone who can leash the sub can change if the cuffs unleash when the timer runs out.",FALSE);
        }
    }
}

default {
    state_entry() {
        lasttime = llGetUnixTime();
        llSetTimerEvent(1);
        g_kWearer = llGetOwner();

        firstontime = MAX_TIME;
        firstrealtime = MAX_TIME;

        //end of timekeeper

        //set settings
        unlockcuffs = 0;
        clearRLVrestions = 0;
        unleash = 0;
        both = 0;
        whocanchangetime = CMD_EVERYONE;
        whocanchangeleash = CMD_EVERYONE;
        whocanchangeothersettings = CMD_EVERYONE;
    }

    on_rez(integer start_param) {
        lasttime = lastrez = llGetUnixTime();

        if (realrunning == 1 || onrunning == 1) {
            llMessageLinked(LINK_THIS, WEARERLOCKOUT, "on", "");
        }
    }

    // listen for likend messages fromOC scripts
    link_message(integer sender, integer iNum, string sStr, key kID) {
        if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) UserCommand(iNum, sStr, kID);
        else if (iNum == CMD_WEARERLOCKEDOUT && sStr == "menu") {
            if (onrunning || realrunning)
                Notify(kID , "You are locked out of the cuffs until the timer expires", FALSE);
        } else if (iNum == LM_SETTING_DELETE) {
            // added prefix for cuffs
            if (sStr == "locked") cuffslocked = 0;
        } else if (iNum == LM_SETTING_SAVE) {
            // added prefix for cuffs
            if (sStr == "locked=1") cuffslocked = 1;
        } else if (iNum == LM_SETTING_RESPONSE) {
            list params = llParseString2List(sStr, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            // added prefix for cuffs
            if (token == "locked") cuffslocked = (integer)value;
        } else if (iNum == MENUNAME_REQUEST && sStr == parentmenu) {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, "");
        }
        else if (iNum == DIALOG_RESPONSE) {
            integer index = llListFindList(g_lMenuIDs, [kID]);
            if (~index) {
                list menuparams = llParseString2List(sStr, ["|"], []);
                key av = (key)llList2String(menuparams, 0);
                string msg = llList2String(menuparams, 1);
                //integer page = (integer)llList2String(menuparams, 2);
                integer iAutn = (integer)llList2String(menuparams, 3);

                string sMenuType = llList2String(g_lMenuIDs, index+1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, index-1, index-2+g_iMenuStride);

                if (sMenuType == "main") {
                    if (msg == UPMENU) {
                        llMessageLinked(LINK_THIS, iAutn, "menu "+parentmenu, av);
                    } else {
                        UserCommand(iAutn, "timer " + msg, av);
                        if (llListFindList(localbuttons, [msg]) == -1) MainMenu(av,iAutn);
                    }
                } else if (sMenuType == "online") {
                    if (msg == UPMENU) MainMenu(av,iAutn);
                    else {
                        if (iAutn <= whocanchangetime) SetOnlineTimer(msg) ;
                        DoOnMenu(av, iAutn);
                    }
                } else if (sMenuType == "real") {
                    if (msg == UPMENU) MainMenu(av,iAutn);
                    else {
                        if (iAutn <= whocanchangetime) SetRealTimer(msg) ;
                        DoRealMenu(av, iAutn);
                    }
                }
            }
        }
        else if (iNum == DIALOG_TIMEOUT) {
            integer index = llListFindList(g_lMenuIDs, [kID]);
            if (~index) g_lMenuIDs = llDeleteSubList(g_lMenuIDs, index-1, index-2+g_iMenuStride);
        }
    }

    timer() {
        currenttime=llGetUnixTime();
        if (currenttime<(lastrez+60)) return;

        if ((currenttime-lasttime)<60) ontime+=currenttime-lasttime;

        if (ontime>=firstontime) {
            //could store which is need but if both are trigered it will have to send both anyway I prefer not to check for that.

            firstontime=MAX_TIME;
            timeslength=llGetListLength(times);
            for(n = 0; n < timeslength; n = n + 2) {
                // send notice and find the next time.
                if (llList2Integer(times, n)==ON_TIME) {
                    while(llList2Integer(times, n+1)<=ontime&&llList2Integer(times, n)==ON_TIME&&times!=[]) {
                        times=llDeleteSubList(times, n, n+1);
                        timeslength=llGetListLength(times);
                    }

                    if (llList2Integer(times, n)==ON_TIME&&llList2Integer(times, n+1)<firstontime) {
                        firstontime=llList2Integer(times, n+1);
                    }
                }
            }
        }

        if (currenttime>=firstrealtime) {
            //could store which is need but if both are trigered it will have to send both anyway I prefer not to check for that.

            firstrealtime=MAX_TIME;
            timeslength=llGetListLength(times);
            for(n = 0; n < timeslength; n = n + 2) {
                // send notice and find the next time.
                if (llList2Integer(times, n)==REAL_TIME) {
                    while(llList2Integer(times, n+1)<=currenttime&&llList2Integer(times, n)==REAL_TIME) {
                        times=llDeleteSubList(times, n, n+1);
                        timeslength=llGetListLength(times);
                    }

                    if (llList2Integer(times, n)==REAL_TIME&&llList2Integer(times, n+1)<firstrealtime) {
                        firstrealtime=llList2Integer(times, n+1);
                    }
                }
            }
        }

        if (onrunning == 1 && ontimeupat<=ontime) TimerWhentOff();
        if (realrunning == 1 && realtimeupat<=currenttime) TimerWhentOff();
        lasttime=currenttime;
    }
}