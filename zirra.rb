#!/home/godzirra/.rvm/rubies/ruby-1.9.2-p136/bin/ruby
require 'cinch'
require 'sqlite3'
require 'pp'
require 'time'

class RegisterChannels 
    include Cinch::Plugin
    react_on :private

    match /register_channels/, use_prefix: false, method: :register_channels

    def register_channels(m)
        @bot.debug "In register_channels."
        return unless check_op(m)

        user_pass = ''
        channel_pass = ''
        
        users = ['camgia1', 'camgia2', 'camgia3', 'camgia4']
        channels = [ '#lost', '#masquerade', '#geist', '#anarch-sect', '#sabbat-sect', '#camarilla-sect', '#independent-sect', '#cam-rules', '#cam-ops pirates',
'#cam-anarch', '#requiem', '#daeva', '#gangrel', '#mekhet', '#nosferatu', '#ventrue', '#Carthian-Movement', '#circle-of-the-crone', '#invictus',
'#Lancea-Sanctum', '#Ordo-Dracul', '#legio-mortuum', '#awakening', '#acanthus', '#mastigos', '#moros', '#obrimos', '#thyrsus', '#adamantine-arrow',
'#free-council', '#guardians-of-the-veil', '#mysterium', '#silver-ladder', '#forsaken', '#cahalith', '#elodoth', '#irraka', '#ithaeur',
'#rahu', '#blood-talons', '#bone-shadows', '#hunters-in-darkness', '#iron-masters', '#storm-lords' ]

        users.each do |u|
            @bot.msg('nickserv',"identify #{u} #{user_pass}")
        end

        channels.each do |chan| 
            @bot.join(chan, channel_pass)
            thisChannel = Channel(chan)
#            thisChannel.send("Hello there!")
            sleep 1
            thisChannel.part(chan)
        end
        


    end

    def check_op(m)
      return true if m.user.nick == 'godzirra'
      @bot.channels.each do |chan|      
        if chan.opped? m.user
          return true
        end
      end
      return false
    end
end





class NickDatabase
    include Cinch::Plugin
    react_on :private
    
    match /confirm (.+)/, use_prefix: false, method: :confirm_nick
    #match /register (.+),\w*(.+)(,\w*(.+))*/, use_prefix: :false, method: :register_nick
    match /register (.+)/, use_prefix: :false, method: :register_nick

    def confirm_nick(m, nick)
        if check_op(m) 
            @bot.debug "In confirm_nick."
            query = config[:dbh].prepare "SELECT name, cam_number, hostmask FROM nick_database WHERE nick = ?"
            query.execute(nick)
    
            if row = query.fetch
                (name, cam_number, hostmask) = row
                m.reply "#{name} - #{cam_number} - #{hostmask} for #{nick}"
            end
        end
    end

    #def register_nick(m, nick, name, cam_number)
    def register_nick(m, query)
        if check_op(m) 
            (nick, name, cam_number) = query.split(/\s*,\s*/)
            user = User(nick)
            hostmask = user.host
            @bot.debug "In register_nick."
            @bot.debug "Nick: #{nick} Name: #{name}: Cam Number: #{cam_number} -- Host: #{hostmask}."
            query = config[:dbh].prepare "SELECT cam_number, name, hostmask FROM nick_database WHERE nick = ?"
            query.execute(nick)
        
            if row = query.fetch
                query = config[:dbh].prepare "UPDATE nick_database SET name = ?, hostmask = ?, cam_number = ? WHERE nick = ?"
                query.execute( name, hostmask, cam_number, nick )
            else 
                query = config[:dbh].prepare "INSERT INTO nick_database (nick, name, cam_number, hostmask) values(?, ?, ?, ?)"
                query.execute( nick, name, cam_number, hostmask )
            end
            m.reply "#{name} - #{cam_number} - #{hostmask} for #{nick}"
        end
    end

    def check_op(m)
      return true if m.user.nick == 'godzirra'
      @bot.channels.each do |chan|      
        if chan.opped? m.user
          return true
        end
      end
      return false
    end
end

class JoinMessage
  include Cinch::Plugin
  listen_to :join,  method: :join_message

  def join_message(m)
    query = config[:dbh].prepare "SELECT join_message, last_spewed FROM join_message WHERE nick = ? AND last_spewed < DATE_SUB(NOW(), INTERVAL 1 HOUR)"
    query.execute(m.user.nick)

    if (m.channel == '#cam-ooc')
        if row = query.fetch # do |start_time, total_minutes, opped_now|
            join_message = row[0]
            if (join_message)
                @bot.msg("#cam-ooc", "#{m.user.nick} - #{join_message}") 
                query = config[:dbh].prepare 'UPDATE join_message SET last_spewed = now() WHERE nick = ?'
                query.execute(m.user.nick)
            end
        end
    end
  end
end

class Karma 
  include Cinch::Plugin
  prefix 'karma '
  
  match /^\s*([\w|\||\{\}\[\]-]+)(\+{2})/, use_prefix: false, method: :update_karma
  match /^\s*([\w|\||\{\}\[\]-]+)(\-{2})/, use_prefix: false, method: :update_karma
  match /^karma ([\w|\||\{\}\[\]-]+)/, use_prefix: false, method: :parse_karma

  def increase_karma(nickname)
    row = get_karma(nickname)
    @bot.debug "Increasing karma for #{nickname}"
    if row
      @bot.debug "Found #{nickname}.  Increasing."
      query = config[:dbh].prepare "UPDATE karma SET karma = karma + 1 WHERE nickname = ?"
    else 
      @bot.debug "Didn't find #{nickname}. Inserting. +"
      query = config[:dbh].prepare "INSERT INTO karma (nickname, karma) VALUES(?, 1)"
    end
    query.execute(nickname)
  end

  def reduce_karma(nickname)
    @bot.debug "Reducing karma for #{nickname}"
    row = get_karma(nickname)
    
    if row
      @bot.debug "Found #{nickname}.  Decreasing."
      query = config[:dbh].prepare "UPDATE karma SET karma = karma - 1 WHERE nickname= ?"
    else 
      @bot.debug "Didn't find #{nickname}. Inserting. -"
      query = config[:dbh].prepare "INSERT INTO karma (nickname, karma) VALUES(?, -1)"
    end
    query.execute(nickname)
  end

  def get_karma(nickname)
    @bot.debug "Fetching karma for #{nickname}"
    query = config[:dbh].prepare "SELECT id, karma FROM karma WHERE nickname = ?"
    query.execute(nickname)
    row = query.fetch
    if row 
        return Hash[ :id => row[0], :karma => row[1] ]
    end

  end

  def used_recently(nickname)
    return false if nickname == 'godzirra'
    query = config[:dbh].prepare "SELECT recent_update, use_count FROM karma_timer WHERE nickname = ?"
    query.execute(nickname) 

    if row = query.fetch
      recent_update = row[0]
      count = row[1]
        
      @bot.debug "Count: #{count} and recent_update: #{recent_update}"

      t1 = Time.parse(recent_update.to_s)
      t2 = Time.new

      seconds = t2 - t1

      if seconds > 1800  ## Last update was more than 30 minutes ago.  Reset the timer and count.
        @bot.debug "Last query was more than 30 minutes ago."
        query = config[:dbh].prepare "UPDATE karma_timer SET use_count=1, recent_update=now() WHERE nickname = ?"
        query.execute(nickname)
        return false
      elsif count >= 2 ## Two updates in 30 minutes.  Ignore this request
        @bot.debug "Had more than 2 queries in 30 minutes.  Ignoring."
        @bot.msg(nickname, "You can only use karma so often.")
        return true
      else ## not 2 updates in under 30 minutes.  Increase the count and honor this request
        @bot.debug "Had less than 2 queries in 30 minutes."
        query = config[:dbh].prepare "UPDATE karma_timer SET use_count = use_count + 1 WHERE nickname = ?"
        query.execute(nickname)
        return false
      end
    else ## No row found.  Insert and honor this request
      @bot.debug "No entries in the karma_timer table."
      query = config[:dbh].prepare "INSERT INTO karma_timer (recent_update, use_count, nickname) VALUES(now(), 1, ?)"
      query.execute(nickname)
      return false
    end
  end

  def parse_karma(m, nickname)
    if used_recently(m.user.nick)
        @bot.debug "Ignoring.  USed too often in parse_karma"
        return nil
    end 
    if !m.channel.users.has_key?(User(nickname))
      return @bot.msg(m.user.nick, "Karma only counts if the person you're giving it to is here to see it.")
    end
    @bot.debug "Nickname parse: #{m.channel.users.has_key?(User(nickname))}"
    nickname.strip!
    if nickname == 'godzirra'
      return m.reply "Godzirra is beyond karma."
    elsif nickname.downcase == m.user.nick.downcase
      return m.reply "Giving yourself karma's a little cheesy, bub."
    end
    row = get_karma(nickname)
    m.reply "Karma for #{nickname} is #{row[:karma]}";
  end

  def update_karma(m, nickname, change)
    if used_recently(m.user.nick)
        @bot.debug "Ignoring.  USed too often in update "
        return nil
    end 
    if !m.channel.users.has_key?(User(nickname))
      return @bot.msg(m.user.nick, "Karma only counts if the person you're giving it to is here to see it.")
    end
    nickname.strip!
    if nickname == 'godzirra'
      return m.reply "Godzirra is beyond karma."
    elsif nickname.downcase == m.user.nick.downcase
      return m.reply "Giving yourself karma's a little cheesy, bub."
    end
    @bot.debug "Changing karma for #{nickname} and #{change}"
    if change == '--'
      reduce_karma(nickname)
      msg = "Poor #{nickname} lost karma."
    elsif change == '++'
      increase_karma(nickname)
      msg = "#{nickname} gained karma."
    end
    row = get_karma(nickname)
    m.reply "#{msg}  They now have #{row[:karma]} karma."
  end
end

class Info
  include Cinch::Plugin
 
  match /(.+)\?{2}/, use_prefix: false, method: :parse_message
  match /(.+)/, method: :parse_message
  match /forget (.+)/, method: :unstore_fact
  
  def parse_message (m, string) 
    string.gsub!(/\?*$/, '');
    @bot.debug "String is #{string}"
    string.strip!
    @bot.debug "Nick is #{m.user.nick}"
    if isOpped(m)
      if string =~ /^renickify/i
        m.reply renickify()
      elsif string =~ /^say (.+)/ and m.user.nick == 'godzirra'
        @bot.debug "Saying #{string} in #cam-ooc"
        @bot.msg("#cam-ooc", "#{$1}")
        return
      elsif string =~ /\s?(.+?)\s+\b(is|are|were|was)\b\s+(.+)\s*/i
        @bot.debug "String is #{string}"
        @bot.debug "-#{$1}--#{$2}--#{$3}-"
        return m.reply store_fact($1, $2, $3, m.user.nick)
      elsif string =~ /^alias (.+)=(.+)/i
        return m.reply store_alias($1, $2)
      elsif string =~ /^forget (.+)/i
        return m.reply unstore_fact($1)
      else
        @bot.debug "An op.  Retrieving string."
        return m.reply retrieve_string(m, string)
      end
    end
      @bot.debug "Not an op.  Retrieving string."
      m.reply retrieve_string(m, string)
  end

  ## Check to see if a user is an op in the channel the message was sent in, or an op in any of the other channels
  def isOpped(m) 
    return true if m.user.nick == 'godzirra'

    if m.channel
        @bot.debug "Channel #{m.channel} and opped #{m.channel.opped? m.user}"
        return m.channel.opped? m.user
    else
      @bot.channels.each do |chan|      
        if chan.opped? m.user
          return true
        end
      end
    end
    return false
  end

  ## Ghost old nick, identify new one.
  def renickify 
    @bot.msg("nickserv", "ghost #{bot.nick} pearljam")
    @bot.msg("nickserv", "identify pearljam")
    @bot.nick = 'infobot-clone'
    return "Renickifying!"
  end

  ## Create or update an alias
  def store_alias(myAlias, fact)
    @bot.debug "parsing and storing alias #{myAlias}"
    query = config[:dbh].prepare "SELECT id FROM aliases WHERE alias = ?"
    query.execute myAlias
    if row = query.fetch
      query = config[:dbh].prepare "UPDATE aliases SET original=? WHERE alias=?";
      query.execute(fact, myAlias)
    else
      query = config[:dbh].prepare "INSERT INTO aliases (original, alias) values(?, ?)";
      query.execute(fact, myAlias)
    end
    return "Aliasing #{myAlias} to #{fact}"
  end

  ## Create or update a fact
  def store_fact(object, joiner, fact, owner)
    @bot.debug "parsing and storing fact #{object} -- #{joiner} -- #{fact} -- #{owner}"
#    m.reply "parsing and storing #{string}"
    query = config[:dbh].prepare "SELECT id FROM facts WHERE object = ?"
    query.execute object
    if row = query.fetch 
      query = config[:dbh].prepare "UPDATE facts SET fact=?, joiner=? WHERE object=?";
      query.execute(fact, joiner, object)
    else 
      query = config[:dbh].prepare "INSERT INTO facts (object, joiner, fact, owner) values(?, ?, ?, ?)";
      query.execute(object, joiner, fact, owner)
    end
    return "Saved #{object}"
  end

  ## Delete a fact and alias
  def unstore_fact(object) 
    @bot.debug "Unstoring #{object}"
    query = config[:dbh].prepare "DELETE FROM facts WHERE object=?"
    query.execute object

    query = config[:dbh].prepare "DELETE FROM aliases WHERE original=?"
    query.execute object
    return "Forgetting #{object}"
  end
    
  ## retrieve a fact or alias
  def retrieve_string(m, string)
    @bot.debug "retrieving #{string}"
    factoid = fetch_fact(string)
    if factoid
        @bot.debug "Found a factoid."
        if factoid[2].gsub!(/^\<reply\>/i, '')
           return factoid[2]
        else 
           return "#{factoid[0]} #{factoid[1]} #{factoid[2]}"
        end
    elsif factoid = fetch_alias(string)
#       factoid = fetch_alias(string)
       return "#{factoid[0]} #{factoid[1]} #{factoid[2]} (alias of #{string})"
    else 
        return fetch_like_facts(string)
    end
  end

  ## Get similar facts
  def fetch_like_facts(string)
    @bot.debug "retrieving facts LIKE #{string}"
    #query = config[:dbh].prepare "select object from facts where object LIKE '%#{string}%' order by count desc"
    query = config[:dbh].prepare "select object from facts where object LIKE ? order by count desc"
    query.execute "%#{string}%"

    likeArray = Array.new
    i = 0
    while row = query.fetch and i < 5
        likeArray << row[0]
        i += 1
    end

    if likeArray.length > 0 
        return "No matches found for '#{string}'.  Did you mean one of these: #{likeArray.join(', ')}? (#{query.num_rows} similar matches found)"
    end
  end

  ## dbh retrieve an alias
  def fetch_alias(string) 
    query = config[:dbh].prepare "SELECT original FROM aliases WHERE alias = ?"
    query.execute string

    if row = query.fetch
      return fetch_fact(row[0])
    end
  end

  ## dbh retrieve a fact
  def fetch_fact(string)
    @bot.debug "fetch_fact(#{string})"
    query = config[:dbh].prepare "SELECT object, joiner, fact FROM facts WHERE object=?"
    query.execute string 
    increment_count(string)
    return query.fetch
  end

  def increment_count(object)
    query = config[:dbh].prepare "UPDATE facts SET count = count + 1 WHERE object = ?"
    query.execute object
  end
end

bot = Cinch::Bot.new do
  dbh = SQLite3::Database.new 'zirrabot.sqlite'

  configure do |c|
    c.nick = "infobot-clone"
    c.server = "irc.darkmyst.org"
    #c.port = 6667
    c.verbose = true
    c.timeouts.connect = 30
    #c.channels = ["#qwertybot", "#cam-ooc", "#athensohio-ooc", "#forsaken-ooc"]
    c.channels = ["#cam-ooc", "#athensohio-ooc", "#forsaken-ooc"]
    c.plugins.options[NickDatabase][:dbh] = dbh
    c.plugins.options[Info][:dbh] =  dbh
    c.plugins.options[Karma][:dbh] =  dbh
    c.plugins.options[JoinMessage][:dbh] =  dbh
#    c.plugins.options[OpTime][:dbh] =  dbh
#    c.plugins.plugins = [Info, Karma, OpTime]
    c.plugins.plugins = [NickDatabase, Info, Karma, RegisterChannels, JoinMessage]
    c.plugins.prefix = proc { |m|
      if m.nil? || !m.channel?
        nil
      else
        bot.nick + ": "
      end
    }
  end


end

bot.on(:disconnect) { @bot.start(false) }
bot.on(:connect) { @bot.msg("nickserv", "identify password") }
bot.start


