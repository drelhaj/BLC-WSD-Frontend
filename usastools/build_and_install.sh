#!/bin/bash

# This simple script is a timesaver or reminder for those who
# don't work with ruby gems much
#
# You must have ruby and rubygems installed.

rm usastools-*.gem

gem build usastools.gemspec

gem install usastools-*.gem


