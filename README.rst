Description
===========

MongroDump exists first and foremost to exploit blind MongoDB injections.

While many programs exist to find NoSQL injections MongroDump is focused on
exploiting them and actually getting the data out.

Usage
=====

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
