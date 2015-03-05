BLC WSD Frontend
================

This is the front-end for the BLC WSD task.

Requirements
------------

 * ruby ~> 2.0.0
 * The `usastools` gem (available from the UCREL SVN repo in `/usas/usastools`)
 * USAS lexicons in CLAWS c7 format (optional, needed only for pre-loading tags, to be found in the UCREL SVN at `/usas/lexicons`)

Structure
---------
The interface runs as a stateless server, which accepts various GET arguments and outputs to a directory of YAML files, each identifiable through a word and submission UUID.

The interface supports multiple languages (selectable using a GET parameter), and skins (set when launching the server).

The server can provide existing tags to the interface by reading a USAS lexicon file.  It may have one per language loaded at launch time by placing them in the LEXICONS folder (defined below) with the given country-code name.  The country codes allowed are restricted to the union of this list and the template names in the `template/references` directory.


Execution
---------

To run the server on port 8080:

    $ ruby ./bin/server.rb LEXICONS THEME_DIR

from the root of this repository, where:

 * `LEXICONS` is a directory containing lexicons (or symlinks thereto) named for their country codes, i.e. `en.c7` for English, 'nl.c7' for Dutch.  Default is `./lexicons`.
 * `THEME_DIR` is a directory served to the client for modification of the theme, containing css, images and js.  Default is `./themes/ucrel`

Visit [http://localhost:8080/go](http://localhost:8080/go) for a debug interface.

The GET parameters accepted for the main form (`/form`) run to:

 * `word` --- A URLsafe-Base64-encoded UTF-8 string containing the term to be annotated.  When submitting this note that client-side B64 implementations ofted don't handle UTF-8 correctly (also, to prevent code injection attacks, use something server side).
 * `lang` --- A country code that changes the lexicon and reference list used.  Valid ones are defined by the population of the `templates/references` and LEXICONS directories.
 * `timeout` --- Optional.  Set to the timeout in minutes to enable a countdown, the terminus of which locks out the UI.
 * `source` --- Optional.  If set to 'amt', will enable the AMT workers' interface to check for previous work.


Generating Input
----------------
The input terms are entered in URL safe Base64.  This is to allow UTF-8 characters to be sent without ambiguity for various clients' systems and browsers.  There is a handy tool to generate these, that reads one-line-per-term files from stdin and outputs a CSV to stdout containing the original term plus the encoded form:

    $ ./bin/b64words.rb < terms.txt > b64_terms.csv


Modifying the Taxonomy
----------------------
The taxonomy used for tagging is located in `./js-data'.  The canonical copy is the YAML file---the JSON versions are merely for use by JQuery and should not be edited.

To convert from the YAML version, use `./bin/yaml2json.rb`.  This takes a single argument, the YAML file to convert, and outputs to stdout:

    $ ./bin/yaml2json.rb ./js-data/usas.clean.yml > ./js-data/usas.json

