module mongrodump.curlcmd;

import std.algorithm;
import std.array;
import std.exception;
import std.range;

import pegged.grammar;

/**
 * Reified curl request
 *
 * CurlRequest supposes that only one URL is used. It also ignores any option
 * that doesn't fit the context of MongroDump such as --silent.
 */
struct CurlRequest {
    string         url;
    string         data;
    string[string] headers;
    string         method = "GET";

    /**
     * Builds a CurlRequest from a curl command line string
     */
    this(string cmdLine) {
        this(cmdLineToArgv(cmdLine));
    }

    this(this) {
        headers = headers.dup;
    }

    /**
     * Builds a CurlRequest from a curl command line arguments.
     */
    this(string[] args) {
        import std.getopt;
        import std.typecons: tuple;

        enforce(args.length != 0, "Command line can't be empty");

        string[] headerList;

        args.getopt(std.getopt.config.bundling,
                    std.getopt.config.caseSensitive,
                    std.getopt.config.passThrough,
                    "X|request",   &method,
                    "H|header",    &headerList,
                    "data-binary", &data,
                    );

        headerList.map!(h => h.split(": "))
                  .filter!(p => p.length == 2)
                  .each!(p => headers[p[0]] = p[1]);

        url = args[1..$].filter!(arg => arg.canFind("://")).takeOne.join("");
        enforce(url != "", "URL can't be empty");
    }
}
unittest {
    string cmdLine = `
        curl -i -s -k \
             -X  'POST'  \
             -H 'Connection: keep-alive' \
             -H 'Cache-Control: max-age=0' \
             -H $'Upgrade-Insecure-Requests: 1' \
             -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64)' \
             -H 'Accept: text/html,application/xhtml+xml;q=0.9,*/*' \
             -H "X-Do-Not-Track: 1" \
             --header 'DNT: 1' \
             -H='Accept-Language: en-US,en' \
             --header='Referer: https://example.com/?q=referer' \
             -H 'Cookie: _ga=GA1.2.72537138.1511976784' \
             -H '' \
             --data-binary 'username=test&password=test' \
             'https://example.com/?q=query'
    `;

    CurlRequest expected;

    expected.url     = "https://example.com/?q=query";
    expected.method  = "POST";
    expected.headers = [
        "Connection": "keep-alive",
        "Cache-Control": "max-age=0",
        "Upgrade-Insecure-Requests": "1",
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64)",
        "Accept": "text/html,application/xhtml+xml;q=0.9,*/*",
        "X-Do-Not-Track": "1",
        "DNT": "1",
        "Accept-Language": "en-US,en",
        "Referer": "https://example.com/?q=referer",
        "Cookie": "_ga=GA1.2.72537138.1511976784",
    ];
    expected.data = "username=test&password=test";

    CurlRequest request = CurlRequest(cmdLine);

    assert(request.url     == expected.url);
    assert(request.method  == expected.method);
    assert(request.headers == expected.headers);
    assert(request.data    == expected.data);

    assertThrown!Exception(CurlRequest("no url present").url);
}

/**
 * This grammar describes the subset of bash corresponding to a quoted
 * command line.
 *
 * It supposes that only one command line is parsed at a time and so accepts
 * multi-line commands without trailing backslashes.
 *
 * FIXME: Empty arguments should be empty elements, not twtwo quotes.
 */
mixin(grammar(`
CmdLine:
    Line       <- (Argument :S*)*
    Argument   <~ (VoidArg / QuotedArg / RawArg)*
    VoidArg    <- quote quote / doublequote doublequote
    QuotedArg  <~ SimpleQuotedArg / DoubleQuotedArg
    RawArg     <~ (!(S / quote / doublequote)
                    (:backslash (S / quote / doublequote) / .))*

    SimpleQuotedArg <~ :"$"? :quote (!quote .)* :quote
    DoubleQuotedArg <~ :doublequote
                       (:backslash doublequote / !doublequote .)*
                       :doublequote

    S <~ (" " / "\t" / :backslash? "\n")
`));

unittest {
    auto parseTree = CmdLine(`/bin/sh --test0 -H 'test1' t'est2' \
                              $'te'"st"3 "te\"'st'"'4' '' ""`);

    immutable expected = ["/bin/sh", "--test0", "-H", "test1",
                          "test2", "test3", "te\"'st'4", "''", `""`];

    assert(parseTree.successful);
    assert(parseTree.children[0].matches == expected);
}

/**
 * cmdLineToArgv takes a bash command line and converts it into an array
 * similar to what argv would be if that program were executed.
 */
string[] cmdLineToArgv(string cmd) {
    return CmdLine(cmd).children[0]
                       .matches
                       .replace("''", "")  // Not quite perfect but I don't
                       .replace(`""`, ""); // know how to fix the PEG grammar
}
unittest {
    assert(cmdLineToArgv(`curl -H $'Header' -H "other"'header' "url"`)
            == ["curl", "-H", "Header", "-H", "otherheader", "url"]);

    assert(cmdLineToArgv(`multiple \
                          lines
                          and\ more`)
            == ["multiple", "lines", "and more"]);

    assert(cmdLineToArgv("--empty '' flag") == ["--empty", "", "flag"]);

    assert(cmdLineToArgv("").length == 0);
}

