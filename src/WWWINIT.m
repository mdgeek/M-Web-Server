WWWINIT ; VEN/SMH - Initialize Web Server;1:43 PM  25 Dec 2013; 12/25/13 1:03pm
 ;;0.1;MASH WEB SERVER/WEB SERVICES
 ;
 ; Map %W
 I +$SYSTEM=0 DO CACHEMAP  ; Only Cache!
 ;
 ; Set-up TLS on Cache
 I +$SYSTEM=0 DO CACHETLS
 ;
 ; Download the files from Github
 D DOWNLOAD("https://raw.github.com/shabiel/M-Web-Server/0.1.0/dist/MWS.RSA")
 ;
 ; Silently install RSA (we changed the default directory already)
 I +$SYSTEM=0 DO RICACHE($ZU(168)_"MWS.RSA")
 I +$SYSTEM=47 DO RIGTM($ZD_"MWS.RSA")
 ;
 ; If fileman is installed, do an init for the %W(17.001 file
 I $D(^DD) D ^%WINIT
 QUIT
 ;
CACHEMAP ; Map %W* Globals and Routines away from %SYS in Cache
 ; Get current namespace
 N NMSP S NMSP=$NAMESPACE
 ;
 ; Map %W globals away from %SYS
 ZN "%SYS" ; Go to SYS
 N % S %=##class(Config.Configuration).GetGlobalMapping(NMSP,"%W*","",NMSP,NMSP)
 I '% S %=##class(Config.Configuration).AddGlobalMapping(NMSP,"%W*","",NMSP,NMSP)
 I '% W !,"Error="_$SYSTEM.Status.GetErrorText(%) QUIT
 ;
 ; Map %W routines away from %SYS
 N A S A("Database")=NMSP
 N % S %=##Class(Config.MapRoutines).Get(NMSP,"%W*",.A)
 S A("Database")=NMSP
 I '% S %=##Class(Config.MapRoutines).Create(NMSP,"%W*",.A)
 I '% W !,"Error="_$SYSTEM.Status.GetErrorText(%) QUIT
 ZN NMSP ; Go back
 QUIT
 ;
CACHETLS ; Create a client SSL/TLS config on Cache
 ;
 ; Create the configuration
 N NMSP S NMSP=$NAMESPACE
 ZN "%SYS"
 n config,status
 n % s %=##class(Security.SSLConfigs).Exists("client",.config,.status) ; check if config exists
 i '% d
 . n prop s prop("Name")="client"
 . s %=##class(Security.SSLConfigs).Create("client",.prop) ; create a default ssl config
 . i '% w $SYSTEM.Status.GetErrorText(%) s $ec=",u-cache-error,"
 . s %=##class(Security.SSLConfigs).Exists("client",.config,.status) ; get config
 e  s %=config.Activate()
 ;
 ; Test it by connecting to encrypted.google.com
 n rtn
 d config.TestConnection("173.194.33.4",443,.rtn)
 i rtn w "TLS/SSL client configured on Cache as config name 'client'",!
 e  w "Cannot configure TLS/SSL on Cache",! s $ec=",u-cache-error,"
 ZN NMSP
 QUIT
 ;
DOWNLOAD(URL) ; Download the files from Github
 D:+$SY=0 DOWNCACH(URL)
 D:+$SY=47 DOWNGTM(URL)
 QUIT
 ;
DOWNCACH(URL) ; Download for Cache
 ; Change directory to temp directory
 new OS set OS=$zversion(1)
 if OS=1 S $EC=",U-VMS-NOT-SUPPORTED,"
 if OS=2 D  ; windows
 . open "|CPIPE|WWW1":("chdir %temp%":"R"):1
 . use "|CPIPE|WWW1"
 . close "|CPIPE|WWW1"
 if OS=3 D  ; UNIX
 . N % S %=$ZU(168,"/tmp/")
 ;
 ; Download and save
 set httprequest=##class(%Net.HttpRequest).%New()
 if $e(URL,1,5)="https" do
 . set httprequest.Https=1
 . set httprequest.SSLConfiguration="client"
 new server set server=$p(URL,"://",2),server=$p(server,"/")
 new port set port=$p(server,":",2)
 new filepath set filepath=$p(URL,"://",2),filepath=$p(filepath,"/",2,99)
 new filename set filename=$p(filepath,"/",$l(filepath,"/"))
 set httprequest.Server=server
 if port set httprequest.Port=port
 set httprequest.Timeout=5
 new status set status=httprequest.Get(filepath)
 new response set response=httprequest.HttpResponse.Data
 new sysfile set sysfile=##class(%Stream.FileBinary).%New()
 set status=sysfile.FilenameSet(filename)
 set status=sysfile.CopyFromAndSave(response)
 set status=sysfile.%Close()
 QUIT
 ;
DOWNGTM(URL) ; Download for GT.M
 S $ZD="/tmp/"
 N CMD S CMD="curl -s -L -O "_URL
 O "pipe":(shell="/bin/sh":command=CMD)::"pipe"
 U "pipe" C "pipe"
 QUIT
 ;
RIGTM(ROPATH,FF) ; Silent Routine Input for GT.M
 ; ROPATH = full path to routine archive
 ; FF = Form Feed 1 = Yes 0 = No. Optional.
 ;
 ; Check inputs
 I $ZPARSE(ROPATH)="" S $EC=",U-NO-SUCH-FILE,"
 S FF=$G(FF,0)
 ;
 ; Convert line endings from that other Mumps
 O "pipe":(shell="/bin/sh":command="perl -pi -e 's/\r\n?/\n/g' "_ROPATH:parse)::"pipe"
 U "pipe" C "pipe"
 ;
 ; Set end of routine
 I FF S EOR=$C(13,12)
 E  S EOR=""
 ;
 ; Get output directory
 N D D PARSEZRO(.D,$ZROUTINES)
 N OUTDIR S OUTDIR=$$ZRO1ST(.D)
 ;
 ; Open use RO/RSA
 O ROPATH:(readonly:block=2048:record=2044:rewind):0 E  S $EC=",U-ERR-OPEN-FILE,"
 U ROPATH
 ;
 ; Discard first two lines
 N X,Y R X,Y
 ;
 F  D  Q:$ZEOF
 . ; Read routine info line
 . N RTNINFO R RTNINFO
 . Q:$ZEOF
 . ;
 . ; Routine Name is 1st piece
 . N RTNNAME S RTNNAME=$P(RTNINFO,"^")
 . ;
 . ; Check routine name
 . I RTNNAME="" QUIT
 . I RTNNAME'?1(1"%",1A).99AN S $EC=",U-INVALID-ROUTINE-NAME,"
 . ;
 . ; Path to save routine, and save
 . N SAVEPATH S SAVEPATH=OUTDIR_$TR(RTNNAME,"%","_")_".m"
 . O SAVEPATH:(newversion:noreadonly:blocksize=2048:recordsize=2044)
 . F  U ROPATH R Y Q:Y=EOR  Q:$ZEOF  U SAVEPATH W $S(Y="":" ",1:Y),!
 . C SAVEPATH
 ;
 C ROPATH
 ;
 QUIT  ; Done
 ;
PARSEZRO(DIRS,ZRO) ; Parse $zroutines properly into an array
 N PIECE
 N I
 F I=1:1:$L(ZRO," ") S PIECE(I)=$P(ZRO," ",I)
 N CNT S CNT=1
 F I=0:0 S I=$O(PIECE(I)) Q:'I  D
 . S DIRS(CNT)=$G(DIRS(CNT))_PIECE(I)
 . I DIRS(CNT)["("&(DIRS(CNT)[")") S CNT=CNT+1 QUIT
 . I DIRS(CNT)'["("&(DIRS(CNT)'[")") S CNT=CNT+1 QUIT
 . S DIRS(CNT)=DIRS(CNT)_" " ; prep for next piece
 QUIT
 ;
ZRO1ST(DIRS) ; $$ Get first routine directory
 ; TODO: Deal with .so.
 N OUT ; $$ return
 N %1 S %1=DIRS(1) ; 1st directory
 ; Parse with (...)
 I %1["(" DO
 . S OUT=$P(%1,"(",2)
 . I OUT[" " S OUT=$P(OUT," ")
 . E  S OUT=$P(OUT,")")
 ; no parens
 E  S OUT=%1
 ;
 ; Add trailing slash
 I $E(OUT,$L(OUT))'="/" S OUT=OUT_"/"
 QUIT OUT
 ;
RICACHE(ROPATH) ; Silent Routine Input for Cache
 D $SYSTEM.Process.SetZEOF(1) ; Cache stuff!!
 I $ZSEARCH(ROPATH)="" S $EC=",U-NO-SUCH-FILE,"
 N EOR S EOR=""
 ;
 ; Open using Stream Format (TERMs are CR/LF/FF)
 O ROPATH:("RS"):0 E  S $EC=",U-ERR-OPEN-FILE,"
 U ROPATH
 ;
 ; Discard first two lines
 N X,Y R X,Y
 ;
 F  D  Q:$ZEOF
 . ; Read routine info line
 . N RTNINFO R RTNINFO
 . Q:$ZEOF
 . ;
 . ; Routine Name is 1st piece
 . N RTNNAME S RTNNAME=$P(RTNINFO,"^")
 . ;
 . ; Check routine name
 . I RTNNAME="" QUIT
 . I RTNNAME'?1(1"%",1A).99AN S $EC=",U-INVALID-ROUTINE-NAME,"
 . ;
 . N RTNCODE,L S L=1
 . F  R Y:0 Q:Y=EOR  Q:$ZEOF  S RTNCODE(L)=Y,L=L+1
 . S RTNCODE(0)=L-1 ; required for Cache
 . D ROUTINE^%R(RTNNAME_".INT",.RTNCODE,.ERR,"CS",0)
 ;
 C ROPATH
 ;
 QUIT  ; Done
 ;
TEST D EN^XTMUNIT($T(+0),1) QUIT
GTMRITST ; @TEST - Test GT.M Routine Input
 ; Use VPE's RSA file to test.
 Q:+$SY'=47
 D DELRGTM("%ZV*"),DELRGTM("ZV*")
 D SILENT^%RSEL("%ZV*")
 D CHKEQ^XTMUNIT(%ZR,0)
 N URL S URL="http://hardhats.org/tools/vpe/VPE_12.zip"
 S $ZD="/tmp/"
 N CMD S CMD="curl -L -s -O "_URL
 O "p":(shell="/bin/sh":command=CMD:parse)::"pipe"
 U "p" C "p"
 S CMD="unzip -o /tmp/VPE_12.zip"
 O "p":(shell="/bin/sh":command=CMD:parse)::"pipe"
 U "p" C "p"
 N PATH S PATH="/tmp/VPE_12_Rtns.MGR"
 D RIGTM(PATH)
 D SILENT^%RSEL("%ZV*")
 D CHKTF^XTMUNIT(%ZR>0)
 QUIT
 ;
DELRGTM(NMSP) ; Delete routines for GT.M - yahoo
 D SILENT^%RSEL(NMSP)
 N R S R="" F  S R=$O(%ZR(R)) Q:R=""  D
 . N P S P=%ZR(R)_$TR(R,"%","_")_".m"
 . O P C P:(delete)
 QUIT
 ;
CACHERIT ; @TEST - Test Cache Routine Input
 Q:+$SY'=0
 D DELRCACH("%ZV*"),DELRCACH("ZV*")
 D CHKTF^XTMUNIT('$D(^$R("%ZVEMD")))
 N URL S URL="http://hardhats.org/tools/vpe/VPE_12.zip"
 D DOWNCACH(URL)
 S %=$ZF(-1,"unzip -o /tmp/VPE_12.zip")
 N PATH S PATH="/tmp/VPE_12_Rtns.MGR"
 D RICACHE(PATH)
 D CHKTF^XTMUNIT($D(^$R("%ZVEMD")))
 QUIT
 ;
DELRCACH(NMSP) ; Delete routines for Cache - yahoo again
 I $E(NMSP,$L(NMSP))'="*" D  QUIT
 . D DEL^%R(NMSP_".INT")
 S NMSP=$E(NMSP,1,$L(NMSP)-1)
 N R S R=NMSP
 D:$D(^$R(R))  F  S R=$O(^$R(R)) Q:R=""  Q:($P(R,NMSP,2)="")  D
 . X "ZR  ZS @R"
 QUIT
