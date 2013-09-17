Zirrabot - A darkmyst info bot
=====================================

Description
-----------

Darkmyst infobot written with ruby.

Installation
------------

### RubyGems

You can install the latest Cinch gem using RubyGems

    gem install cinch
    gem install sqlite3


Example
-------

### Pretty Output

Ever get fed up of watching those boring, frankly unreadable lines
flicker down your terminal screen whilst your bot is online? Help is
at hand! By default, Cinch will colorize all text it sends to a
terminal, meaning you get some pretty damn awesome readable coloured
text. Cinch also provides a way for your plugins to log custom
messages:

    on :message, /hello/ do |m|
      bot.logger.debug "Someone said hello"
    end

Authors
-------

Bot =
* [Shawn Looker]

Cinch = 
* [Lee Jarvis](http://injekt.net)
* [Dominik Honnef](http://fork-bomb.org)

