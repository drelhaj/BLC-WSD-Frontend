BLC WSD Frontend (for dummies):

Download RailsInstaller kit <http://railsinstaller.org/en>
RailsInstaller is the quickest way to go from zero to developing Ruby on Rails applications. Whether you're on Windows or Mac.

This will setup everything automatically all in one package.

Install USAS tools:
First checkOut the usastools from UCREL SVN repository on forge
<https://forge.comp.lancs.ac.uk/svn-repos/ucrel/usas/usastools/>

Using gem:

gem install usastools-0.2.2.gem

To run the server (in Ruby):
syntax:
ruby ./bin/server.rb LEXICONS THEME_DIR
example:
ruby bin/server.rb /lexicons/en.c7 themes/ucrel

