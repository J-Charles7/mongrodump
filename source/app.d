module app;

import std.algorithm;
import std.array;
import std.conv;

import mongrodump.database;
import mongrodump.query;
import mongrodump.oracle;

immutable helpMsg =
"MongoDB Exploitation Tool

Usage: mongrodump [options] --request FILE --true REGEX --false REGEX

Arguments:
    -r, --request FILE      File containing a curl command
                            It should contain the flag at the injection point
    -t, --true  REGEX       Regex determining a valid request
    -f, --false REGEX       Regex determining an invalid request

Options:
    -h, --help              Print this help and exit
    -v, --version           Print version and exit

    -d, --dump WHAT         What to dump. If not used, dumps the collection
                            names, otherwise dumps the given collection.
    -F, --flag FLAG         Injection flag to use; default: #MONGRODUMP#
";

immutable vernum="0.0.1";


int main(string[] args) {
    import std.stdio;
    import std.getopt: GetOptException;

    string trueReg;
    string falseReg;
    string requestFile;
    string toDump;
    string flag = "#MONGRODUMP#";

    try {
        import std.getopt;
        bool versionWanted;

        auto arguments = getopt(args,
                                config.bundling,
                                config.caseSensitive,
                                config.required,
                                "r|request", &requestFile,
                                config.required,
                                "t|true",    &trueReg,
                                config.required,
                                "f|false",   &falseReg,
                                "d|dump",    &toDump,
                                "F|flag",    &flag,
                                "v|version", &versionWanted);

        if (arguments.helpWanted) {
            write(helpMsg);
            return 0;
        }
        if (versionWanted) {
            writeln(vernum);
            return 0;
        }
    } catch (GetOptException ex) {
        stderr.write(helpMsg);
        return 1;
    }

    string curlCommand = File(requestFile).byLine.join("\n").to!string;

    auto query  = new WebQuery(curlCommand, flag);
    auto oracle = new Oracle(query, trueReg, falseReg);
    auto db     = new Database(oracle);

    if (toDump.length == 0) {
        db.getCollections().each!writeln;
    }
    else {
        db.getCollectionData(toDump).writeln;
    }

    return 0;
}
