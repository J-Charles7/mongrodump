module mongrodump.logger;

alias Level = ubyte;

class Logger
{
    private this() {}

    private static    bool   instantiated;
    private __gshared Logger instance;

    import std.stdio;

    Level verbosity;
    File  outputFile;

    static Logger get()
    {
        if (!instantiated)
        {
            synchronized(Logger.classinfo)
            {
                if (!instance)
                {
                    instance = new Logger();
                }

                instantiated = true;
            }
        }

        return instance;
    }

    void log(Level level, string message) {
        if (level <= verbosity)
            outputFile.writeln(message);
    }
}

void log(Level level, string message) {
    Logger.get().log(level, message);
}
