#include once "misc.bi"

const FB_VERSION = "0.21"

enum
    TARGET_DOS = 0
    TARGET_LINUX
    TARGET_WIN32
end enum

type TRAMCTX
    as integer target
    as string target_name
    as string exeext

    as string sys_prev  '' Path to previous FreeBASIC release
    as string sys_gcc   '' Path to MinGW, DJGPP or /usr (to copy libs/binutils from)

    as string fbc
    as string gcc
    as string ar
    as string ranlib

    as string conf_rtlib
    as string conf_gfxlib2
    as string conf_compiler

    as string manifest

    as string title     '' Title for output archive/installer, e.g. FreeBASIC-0.21-win32

    as boolean standalone : 1
    as boolean pullbin    : 1
    as boolean genimplibs : 1
    as boolean rtlib      : 1
    as boolean gfxlib2    : 1
    as boolean compiler   : 1
    as boolean clean      : 1
    as boolean configure  : 1
    as boolean make       : 1
    as boolean remake     : 1
    as boolean genmanifest: 1
    as boolean archive    : 1
    as boolean installer  : 1
    as boolean source     : 1

    as boolean had_error  : 1
end type

dim shared as TRAMCTX tram

sub sh(byref cmd as string, byval max_good_exitcode as integer = 0)
    print "    $ ";cmd
    dim as integer exitcode = shell(cmd)
    if (exitcode > max_good_exitcode) then
        print "Error: exit code " + str(exitcode)
        tram.had_error = TRUE
    end if
end sub

sub mkdir_(byref folder as string)
    if (tram.had_error) then return
    print "    $ mkdir ";folder
    mkdir(folder)
end sub

sub cd(byref folder as string)
    if (tram.had_error) then return
    print "    $ cd ";folder
    if (chdir(folder)) then
        print "Error: failed to change to '";folder;"'."
        tram.had_error = TRUE
    end if
end sub

sub cp(byref source as string, byref dest as string)
    sh("cp --preserve " + source + " " + dest)
end sub

sub rm(byref file as string)
    sh("rm -f " + file)
end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

#macro STEP_BEGIN()
    do
#endmacro

#macro STEP_END()
        if (tram.had_error = FALSE) then
            exit do
        end if

        print "Please fix this, then press SPACE to retry or CTRL+C to abort. "
        print "Waiting...";
        while (inkey() <> "") : wend
        sleep
        while (inkey() <> "") : wend
        tram.had_error = FALSE
        print " retrying."
    loop
#endmacro

sub checkForTarget(byval argc as integer, byval argv as zstring ptr ptr)
    dim as string arg = ""
    for i as integer = 1 to (argc-1)
        arg = *argv[i]
        select case (arg)
        case "dos"
            tram.target = TARGET_DOS
        case "linux"
            tram.target = TARGET_LINUX
        case "win32"
            tram.target = TARGET_WIN32
        end select
    next
end sub

sub parseArgs(byval argc as integer, byval argv as zstring ptr ptr)
    dim as string arg = ""
    dim as string variable = ""
    dim as string value = ""

    for i as integer = 1 to (argc-1)
        arg = *argv[i]

        select case (arg)
        case "dos", "linux", "win32"

        case "standalone"
            tram.standalone = TRUE

        case "clean"
            tram.clean = TRUE

        case "pullbin"
            tram.pullbin = TRUE

        case "genimplibs"
            tram.genimplibs = TRUE

        case "rtlib"
            tram.rtlib = TRUE

        case "gfxlib2"
            tram.gfxlib2 = TRUE

        case "compiler"
            tram.compiler = TRUE

        case "configure"
            tram.configure = TRUE

        case "make"
            tram.make = TRUE

        case "remake"
            tram.remake = TRUE

        case "build"
            tram.rtlib = TRUE
            tram.gfxlib2 = TRUE
            tram.compiler = TRUE
            tram.configure = TRUE
            tram.make = TRUE
            tram.remake = TRUE

        case "manifest"
            tram.genmanifest = TRUE

        case "archive"
            tram.archive = TRUE

        case "installer"
            tram.installer = TRUE

        case "source"
            tram.source = TRUE

        case else
            print "Error: unknown command-line option: '";arg;"'"
            tram.had_error = TRUE

        end select
    next
end sub

sub replacePathVars(byref path as string)
    path = strReplace(path, "<gcc>", tram.sys_gcc)
    path = strReplace(path, "<prev>", tram.sys_prev)
end sub

sub pullBinaries()
    dim as string binariesfile = "src/contrib/tram2/binaries-" + tram.target_name + ".ini"

    if (tram.clean) then
        print "Deleting";
    else
        print "Copying in";
    end if
    print " binaries/libraries listed in '";binariesfile;"'."

    dim as integer f = freefile()
    if (open(binariesfile, for input, as #f)) then
        print "Error: Cannot access '" + binariesfile + "'."
        tram.had_error = TRUE
        return
    end if

    dim as string ln = ""
    dim as string source = ""
    dim as string dest = ""

    while (eof(f) = FALSE)
        line input #f, ln
        ln = trim(ln)

        if (len(ln) > 0) then
            select case (ln[0])
            case asc(";")
                '' Ignore comment

            case asc("[")
                '' [source -> destination] ?
                if (right(ln, 1) = "]") then
                    ln = trim(mid(ln, 2, len(ln)-2))

                    strSplit(ln, " -> ", source, dest)

                    replacePathVars(source)
                    replacePathVars(dest)
                end if

            case else
                STEP_BEGIN()
                    if (tram.clean) then
                        '' Delete the file in our tree.
                        rm(dest + "/" + ln)
                    else
                        '' Copy the file into our tree.
                        cp(source + "/" + ln, dest)
                    end if
                STEP_END()

            end select
        end if
    wend

    close #f
end sub

sub generateImportLibraries()
#if 0
    if (tram.clean) then
        print "Removing import libraries."
        sh("rm -f lib/win32/*.dll.a")
    else
        print "Generating import libraries."
        cd("src/contrib/genimplibs")
        sh("make")
        sh("genimplibs -f -a")
        cd("../../..")
    end if
#else
    print "Ignoring genimplibs"
#endif
end sub

sub configure(byref tree as string, byref options as string)
    cd("src/" + tree + "/obj/" + tram.target_name)
    sh("sh ../../configure" + options)
    cd("../../../..")
end sub

sub configureRtlib()
    print "Configuring rtlib."
    configure("rtlib", " CC=" + tram.gcc + _
                       " AR=" + tram.ar + _
                       " RANLIB=" + tram.ranlib + _
                       tram.conf_rtlib)
end sub

sub configureGfxlib2()
    print "Configuring gfxlib2."
    configure("gfxlib2", " CC=" + tram.gcc + _
                         " AR=" + tram.ar + _
                         " RANLIB=" + tram.ranlib + _
                         tram.conf_gfxlib2)
end sub

sub configureCompiler()
    print "Configuring compiler."
    configure("compiler", " FBC=" + tram.fbc + _
                          " CC=" + tram.gcc + _
                          tram.conf_compiler + _
                          " --disable-objinfo")
end sub

sub cpToLib(byref file as string)
    cp(file, "../../../../lib/" + tram.target_name + "/" + file)
end sub

sub rmLib(byref file as string)
    rm("../../../../lib/" + tram.target_name + "/" + file)
end sub

sub makeRtlib()
    cd("src/rtlib/obj/" + tram.target_name)

    if (tram.clean) then
        print "Cleaning up rtlib."
        sh("make clean")
        rmLib("libfb.a")
        rmLib("fbrt0.o")
    else
        print "Compiling rtlib."
        sh("make")
        cpToLib("libfb.a")
        cpToLib("fbrt0.o")
    end if

    cd("../../../..")
end sub

sub makeRtlibMt()
    cd("src/rtlib/obj/" + tram.target_name)

    if (tram.clean) then
        print "Cleaning up multi-threaded rtlib."
        sh("make clean MULTITHREADED=1")
        rmLib("libfbmt.a")
    else
        print "Compiling multi-threaded rtlib."
        sh("make MULTITHREADED=1")
        cpToLib("libfbmt.a")
    end if

    cd("../../../..")
end sub

sub makeGfxlib2()
    cd("src/gfxlib2/obj/" + tram.target_name)

    if (tram.clean) then
        print "Cleaning up gfxlib2."
        sh("make clean")
        rmLib("libfbgfx.a")
    else
        print "Compiling gfxlib2."
        sh("make")
        cpToLib("libfbgfx.a")
    end if

    cd("../../../..")
end sub

sub makeCompiler()
    print "Compiling fbc."

    cd("src/compiler/obj/" + tram.target_name)

    dim as string fbc = "../../../../fbc" + tram.exeext
    if (tram.clean) then
        sh("make clean")
        rm(fbc)
    else
        sh("make")
        cp("fbc_new" + tram.exeext, fbc)
    end if

    cd("../../../..")
end sub

sub remakeCompiler()
    '' Rebuild fbc with the one that was built before, this fbc will be
    '' built with the tools in the root tree, and linked against the libs
    '' in the root tree.
    print "Re-compiling fbc."

    dim as string fbc = "../../../../fbc" + tram.exeext

    configure("compiler", " FBC=" + fbc + _
                          " CC=" + tram.gcc + _
                          tram.conf_compiler)

    cd("src/compiler/obj/" + tram.target_name)
    sh("make clean")
    sh("make")
    cp("fbc_new" + tram.exeext, fbc)
    cd("../../../..")
end sub

sub applyPattern _
    ( _
        byref manifest as string, _
        byref filelist as string, _
        byref pattern as string, _  
        byval exclude as boolean _
    )

    dim as string cmd = ""
    dim as string temp = "../manifest.tmp"  '' Temporary file used when excluding

    '' Run the files list through the pattern.
    '' Note: using double quotes to prevent quirks with the
    '' cmd.exe escape character '^'.
    cmd = "grep -E """ + pattern + """ "

    if (exclude) then
        '' Excluding: Apply the inversed pattern to
        '' the current manifest (removing from what was gathered
        '' already), and overwrite the current manifest.
        cmd += "-v " + manifest + " > " + temp
    else
        '' Including: Apply the pattern to the whole file list,
        '' append the result to the manifest (duplicates are
        '' removed later).
        cmd += filelist + " >> " + manifest
    end if

    '' grep will return exit code '1' if no matches were found,
    '' so handle this special case as not-an-error. 
    '' On linux a '256' exit code is coming from somewhere,
    '' when not matches were found, weird...
    sh(cmd, 256)

    if (exclude) then
        cp(temp, manifest)
    end if

    rm(temp)
end sub

sub generateManifest(byref manifest as string, byref patternfile as string)
    print "Generating manifest '" + manifest + "' using '";patternfile;"'."

    rm(manifest)

    '' Note: creating temp files outside the tree, otherwise they'd be listed too...
    dim as string filelist = "../filelist.tmp"

    '' Find files (files only, no directories), and remove leading ./, because
    '' find's output looks like:
    ''      ./file.a
    ''      ./dir/file.bas
    '' but we want:
    ''      file.a
    ''      dir/file.bas
    sh("find . -type f | sed 's/^\.\///' > " + filelist)

    '' Read in & apply the regexps
    dim as integer f = freefile()
    if (open(patternfile, for input, as #f)) then
        print "Can't access " + patternfile
        tram.had_error = TRUE
        return
    end if

    dim as string ln = ""
    dim as boolean skipping = FALSE

    while (eof(f) = FALSE)
        line input #f, ln
        ln = trim(ln)

        if (len(ln) > 0) then
            select case (ln[0])
            case asc("+"), asc("-")
                if (skipping = FALSE) then
                    '' '-' means "exclude it".
                    dim as boolean exclude = (ln[0] = asc("-"))

                    '' Cut off +/- at the front.
                    ln = trim(right(ln, len(ln) - 1))

                    '' Replace '<target>' by 'win32' etc.
                    ln = strReplace(ln, "<target>", tram.target_name)

                    applyPattern(manifest, filelist, ln, exclude)
                end if

            '' '[' [Target] ']'
            case asc("[")
                if (right(ln, 1) = "]") then
                    '' Cut off the []'s.
                    ln = trim(mid(ln, 2, len(ln)-2))

                    '' Finding empty []'s/the correct target stops skipping.
                    '' If a different target is found, this section is skipped
                    '' until the next [...].
                    skipping = ((len(ln) > 0) and (ln <> tram.target_name))
                end if

            end select
        end if
    wend

    close #f

    '' Sort: case-insensitive, removing duplicates.
    dim as string temp = "../manifest.tmp"
    sh("sort --ignore-case --unique " + manifest + " > " + temp)
    cp(temp, manifest)
    rm(temp)

    #ifdef __FB_WIN32__
        sh("dos2unix --dos2unix " + manifest)
    #endif

    rm(filelist)
end sub

sub createArchive(byref title as string, byref manifest as string)
    dim as string archive = "../" + title + ".tar.lzma"
    print "Archiving '";archive;"'."

    '' Create archive using LZMA compression
    dim as string ln = "tar -c --lzma"

    '' Prefix all filenames with the <title>/ directory, i.e. put all files
    '' in that directory in the archive.
    ln += " --transform=""s,^," + title + "/,"""

    '' Read input files from the manifest
    ln += " -T " + manifest

    '' Output filename
    ln += " -f " + archive

    sh(ln)
end sub

sub emitPath(byval o as integer, byref cmd as string, byref path as string)
    print #o, "    " + cmd + " ""$INSTDIR\" + path + """"
end sub

sub emitInstallerFiles(byval o as integer, byval install as boolean)
    dim as integer f = freefile()
    if (open(tram.manifest, for input, as #f)) then
        print "Error: Cannot access '" + tram.manifest + "'."
        tram.had_error = TRUE
        return
    end if

    dim as string filename = ""
    dim as string path = ""
    dim as string prevpath = ""

    while (eof(f) = FALSE)
        line input #f, filename

        if (len(filename)) then
            '' Use backslashes for NSIS...
            filename = strReplace(filename, "/", "\")

            path = pathStripFile(filename)
            if (path <> prevpath) then
                if (install) then
                    emitPath(o, "SetOutPath", path)
                else
                    while ((len(prevpath) > 0) and _
                           (prevpath <> left(path, len(prevpath))))
                        emitPath(o, "RMDir ", prevpath)
                        prevpath = pathStripComponent(prevpath)
                    wend
                end if
                prevpath = path
            end if

            if (install) then
                filename = "                   File """ + filename + """"
            else
                filename = "    Delete ""$INSTDIR\" + filename + """"
            end if

            print #o, filename
        end if
    wend

    close #f
end sub

sub createNsisScript(byref script as string, byref setupexe as string)
    dim as string template = "src/contrib/tram2/installer-template.nsi"

    print "Creating NSIS script '" + script + "' from '" + template + "'."

    dim as integer i = freefile()
    if (open(template, for input, as #i)) then
        print "Error: Cannot access '" + template + "'."
        tram.had_error = TRUE
        return
    end if

    dim as integer o = freefile()
    if (open(script, for output, as #o)) then
        print "Error: Cannot access '" + script + "'."
        tram.had_error = TRUE
        return
    end if

    dim as string ln = ""

    while (eof(i) = FALSE)
        line input #i, ln

        ln = strReplace(ln, ";;;SETUP_EXE_NAME;;;", setupexe)
        ln = strReplace(ln, ";;;VERSION;;;", FB_VERSION)

        select case (trim(ln))
        case ";;;INSTALL;;;"
            STEP_BEGIN()
                emitInstallerFiles(o, TRUE)
            STEP_END()

        case ";;;UNINSTALL;;;"
            STEP_BEGIN()
                emitInstallerFiles(o, FALSE)
            STEP_END()

        case else
            print #o, ln

        end select
    wend

    close #o
    close #i
end sub

sub createInstaller()
    dim as string setupexe = "../" + tram.title + ".exe"
    dim as string script = "src/contrib/tram2/installer.nsi"

    createNsisScript(script, setupexe)

    print "Creating installer '";setupexe;"'."
    sh("C:/NSIS/makensis.exe -NOCD -V2 " + script)

    rm(script)
end sub

sub createSourceArchive()
    dim as string title = tram.title + "-source"
    dim as string archive = "../" + title + ".tar.lzma"

    print "Creating source code archive '";archive;"'."

    '' Duplicate the working copy
    sh("svn export . " + title)

    '' Create .tar.lzma tarball
    sh("tar -c --lzma -f " + archive + " " + title)

    sh("rm -r -f " + title)
end sub

function getStandaloneTitle() as string
    if (tram.target = TARGET_LINUX) then
        if (tram.standalone) then
            return "-standalone"
        end if
    end if
    return ""
end function

''
'' main
''
    '' Initialize with defaults
    #ifdef __FB_WIN32__
        tram.target = TARGET_WIN32
    #else
        tram.target = TARGET_LINUX
    #endif

    checkForTarget(__FB_ARGC__, __FB_ARGV__)

    parseArgs(__FB_ARGC__, __FB_ARGV__)

    select case (tram.target)
    case TARGET_DOS
        tram.target_name = "dos"
        tram.exeext = ".exe"

        tram.sys_gcc  = "C:/DJGPP"
        tram.sys_prev = "C:/FreeBASIC-dos-0.20"

        tram.fbc    = "C:/FreeBASIC-dos/fbc.exe"
        tram.gcc    = tram.sys_gcc + "/bin/gcc.exe"
        tram.ar     = tram.sys_gcc + "/bin/ar.exe"
        tram.ranlib = tram.sys_gcc + "/bin/ranlib.exe"

        '' Note: using --host so fbc is called with -target dos, see README.
        tram.conf_rtlib    = " --target=i386-pc-msdosdjgpp --host=i386-pc-msdosdjgpp"
        tram.conf_gfxlib2  = " --target=i386-pc-msdosdjgpp --host=i386-pc-msdosdjgpp"
        tram.conf_compiler = " --target=i386-pc-msdosdjgpp --host=i386-pc-msdosdjgpp"
        tram.standalone = TRUE

    case TARGET_LINUX
        tram.target_name = "linux"
        tram.exeext = ""

        tram.sys_prev = "~/FreeBASIC-0.20" + getStandaloneTitle()
        tram.sys_gcc  = "/usr"

        tram.fbc    = "fbc"
        tram.gcc    = "gcc"
        tram.ar     = "ar"
        tram.ranlib = "ranlib"

    case TARGET_WIN32
        tram.target_name = "win32"
        tram.exeext = ".exe"

        tram.sys_prev = "C:/FreeBASIC-0.20"
        tram.sys_gcc  = "C:/MinGW"

        tram.fbc    = "fbc"
        tram.gcc    = "gcc"
        tram.ar     = "ar"
        tram.ranlib = "ranlib"

        tram.conf_compiler  = " --enable-crosscomp-dos --enable-crosscomp-cygwin"
        tram.standalone = TRUE

    end select

    '' No -g
    tram.conf_rtlib   += " CFLAGS=-O2"
    tram.conf_gfxlib2 += " CFLAGS=-O2"

    '' The default manifest is manifest/<target>.lst.
    tram.manifest = "manifest/" + tram.target_name + getStandaloneTitle() + ".lst"

    tram.title = "FreeBASIC-" + FB_VERSION + "-" + /'getDateStamp() + "-" +'/ _
                 tram.target_name + getStandaloneTitle()

    '' We always use standalone for dos/win32 targets, but for linux, there is
    '' the 'standalone' tram2 commandline option.
    if (tram.standalone) then
        tram.conf_compiler += " --enable-standalone"
    end if

    '' -------------------------------------------------------------------------

    print "TRAM 2, target ";tram.target_name

    '' Work from the root FreeBASIC directory.
    cd("../../..")

    if (tram.had_error) then
        print "Error, aborting."
        end 1
    end if

    if (tram.pullbin) then
        STEP_BEGIN()
            pullBinaries()
        STEP_END()
    end if

    if (tram.genimplibs) then
        STEP_BEGIN()
            generateImportLibraries()
        STEP_END()
    end if

    if (tram.configure) then
        if (tram.clean = FALSE) then
            if (tram.rtlib) then
                STEP_BEGIN()
                    configureRtlib()
                STEP_END()
            end if

            if (tram.gfxlib2) then
                STEP_BEGIN()
                    configureGfxlib2()
                STEP_END()
            end if

            if (tram.compiler) then
                STEP_BEGIN()
                    configureCompiler()
                STEP_END()
            end if
        end if
    end if

    if (tram.make) then
        if (tram.rtlib) then
            STEP_BEGIN()
                makeRtlib()
            STEP_END()
            if (tram.target <> TARGET_DOS) then
                STEP_BEGIN()
                    makeRtlibMt()
                STEP_END()
            end if
        end if

        if (tram.gfxlib2) then
            STEP_BEGIN()
                makeGfxlib2()
            STEP_END()
        end if

        if (tram.compiler) then
            STEP_BEGIN()
                makeCompiler()
            STEP_END()
        end if
    end if

    if (tram.clean = FALSE) then
        if (tram.remake and tram.compiler) then
            STEP_BEGIN()
                remakeCompiler()
            STEP_END()
        end if

        if (tram.genmanifest) then
            STEP_BEGIN()
                generateManifest(tram.manifest, "src/contrib/tram2/manifest-pattern.ini")
            STEP_END()
        end if

        if (tram.archive) then
            STEP_BEGIN()
                createArchive(tram.title, tram.manifest)
            STEP_END()
        end if

        if (tram.installer) then
            STEP_BEGIN()
                createInstaller()
            STEP_END()
        end if

        if (tram.source) then
            STEP_BEGIN()
                createSourceArchive()
            STEP_END()
        end if
    end if

    print "Done."
