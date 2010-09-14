! Copyright (C) 2010 Jeremy Hughes.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors assocs combinators.short-circuit fry
http.client io.streams.byte-array kernel namespaces make
regexp sequences xml xml.data locals splitting strings
io.encodings.binary io io.files command-line http system
math.parser destructors math math.functions io.pathnames
continuations xml.traversal ;
IN: tvnz-grab

SYMBOL: ui
SINGLETON: text

HOOK: show-progress ui ( chunk full -- )
HOOK: show-begin-fetch ui ( url -- )
HOOK: show-end-fetch ui ( -- )
HOOK: show-page-fetch ui ( -- )
HOOK: show-playlist ui ( seq -- )
HOOK: show-fatal-error ui ( error -- )

SYMBOL: bytes
SYMBOL: count

: print-bar ( full chunk -- )
    count [
        [ swap / 50 * round ] dip [
            - CHAR: =
            <repetition> >string write
        ] [ drop ] 2bi
    ] change ;

M: text show-progress
    swap bytes [ + [ print-bar ] keep ] change flush ;

M: text show-begin-fetch
    "Fetching " write print "[" write flush ;

M: text show-end-fetch
    "]" print flush ;

M: text show-page-fetch
    "Fetching TVNZ page..." print flush ;

M: text show-playlist
    length "Found " write number>string write " parts." print
    flush ;

M: text show-fatal-error
    dup string? [ print ]
    [ drop "Oops! Something went wrong." print ] if 1 exit ;

: wrap-failed-request ( err -- * )
    [
        "HTTP request failed: " % [ message>> % ]
        [ " (" % code>> number>string % ")" % ] bi
    ] "" make throw ;

: get-playlist ( url -- data )
    http-get [ check-response drop ]
    [ R/ (?<=playlist: ').*(?=')/ first-match ] bi* [
        "http://tvnz.co.nz" prepend http-get [
            [ check-response drop ]
            [ wrap-failed-request ] recover
        ] dip
    ] [ "Could not find playlist at address." throw ] if* ;

: parse-playlist ( data -- urls )
    bytes>xml body>> "video" "700000" "systemBitrate"
    deep-tags-named-with-attr
    [ [ drop "src" ] [ attrs>> ] bi at ] map [ ] filter ;

: part-name ( url -- str )
    "/" split1-last-slice nip >string ;

: call-progress ( data -- )
    length response get check-response
    "content-length" header string>number show-progress ;

: process-chunk ( data stream -- )
    [ stream-write ] [ drop call-progress ] 2bi ;

: get-video-segment ( url -- )
    [ show-begin-fetch ] [ ]
    [ part-name binary <file-writer> ] tri
    [ '[ _ process-chunk ] with-http-get drop flush ]
    with-disposal show-end-fetch ;

: get-video-segments ( urls -- )
    [ get-video-segment ] each ;

: (grab-episode) ( url -- )
    show-page-fetch get-playlist parse-playlist dup
    show-playlist [
        0 bytes count [ set ] bi-curry@ bi get-video-segments
    ] with-scope ;

: grab-episode ( url -- )
    [ (grab-episode) ] [ nip show-fatal-error ] recover ;

: run-tvnz-grab ( -- )
    command-line get first text ui
    [ grab-episode ] with-variable ;

MAIN: run-tvnz-grab
