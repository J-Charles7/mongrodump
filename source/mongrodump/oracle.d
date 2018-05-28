module mongrodump.oracle;

import std.format;
import std.regex;

import mongrodump.logger;
import mongrodump.query;

enum OracleAnswer { Error, No, Yes }

/**
 * Oracle that answers questions by injecting them into an application
 * through a vulnerable entry point.
 *
 * Control of the injection point is done using a known query to which one
 * can add prefix and suffix.
 */
class Oracle {
    Query      query;
    Regex!char isTrue;
    Regex!char isFalse;
    string     prefix;
    string     suffix;

    /**
     * Builds an oracle from a query and two comparison values to distinguish
     * light from darkness from the abyss of the database's answers.
     */
    this(Query question, string isTrue, string isFalse) {
        this(question, regex(isTrue), regex(isFalse));
    }

    /// Ditto
    this(Query query, Regex!char isTrue, Regex!char isFalse) {
        this.query   = query;
        this.isTrue  = isTrue;
        this.isFalse = isFalse;
    }

    /**
     * Injects a question into a query and pulls the answer back.
     */
    OracleAnswer ask(string question) {
        auto payload  = format("%s%s%s", prefix, question, suffix);
        auto response = query.send(payload);

        if (response.matchFirst(isTrue)) {
            log(4, "[T] " ~ payload);
            return OracleAnswer.Yes;
        }

        else if (response.matchFirst(isFalse)) {
            log(4, "[F] " ~ payload);
            return OracleAnswer.No;
        }

        else {
            log(4, "[E] " ~ payload);
            return OracleAnswer.Error;
        }
    }
}
