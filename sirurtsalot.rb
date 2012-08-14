#!/usr/bin/env ruby
# (c) 2012 Ricky Elrod
# MIT Licensed.

require 'rubygems'
require 'yaml'
require 'file-tail'
require 'on_irc'

$: << File.dirname(__FILE__)
require 'urt_helpers'

$conf = YAML.load_file('config.yml')
$server = UrbanTerror.new($conf['game']['server'],
  $conf['game']['port'],
  $conf['game']['rcon'])

# Thread 1: IRC
irc = Thread.new do
  @bot = IRC.new do
    nick $conf['irc']['nick']
    ident $conf['irc']['nick']
    realname "Sir UrTs Alot"

    server :server do
      address $conf['irc']['server']
      port $conf['irc']['port']
    end
  end

  @bot[:server].on '001' do
    $conf['irc']['channels'].each do |channel|
      join channel
    end
  end

  @bot[:server].on :ping do
    pong params[0]
  end

  @bot[:server].on :privmsg do
    if $conf['irc']['relay']
      $server.rcon(
        "say ^7[IRC/#{params[0]}] ^6<#{sender.nick}> ^3#{params[1]}")
    end
  end

  @bot.connect
end


# Thread 2: Urban Terror
urt = Thread.new do
  File.open(File.expand_path($conf['game']['logfile'])) do |log|
    log.extend(File::Tail)
    log.interval = 0
    log.backward(0)
    log.tail do |line|
      begin
        # 61:25 say: 1 CodeBlock_1: hi
        # 61:25 sayteam: 1 CodeBlock_1: hi
        if line.include?('say:')
          split_line = line.split(' ', 4)
          nickname = split_line[2][0...-1]
          message = split_line[-1].strip
          team = team_for_player($server, nickname)

          $server.rcon("say ^4[spec] #{nickname}: ^3#{message}") if team == 'SPECTATOR'

          case message
          when '!time'
            sleep 0.5
            $server.rcon("say #{Time.now}")
          when '!irc status'
            $server.rcon("say IRC Relay: #{$conf['irc']['relay']}")
          when /^!irc (.+)/
            parsed = $1.split(' ', 2)
            if parsed.size != 2
              $server.rcon("say Syntax: !irc [channel with @ instead of #] [message]")
            else
              parsed[0] = parsed[0].gsub('@', '#')
              msg = case team
                    when 'RED'
                      "<\0035#{nickname}\003> #{parsed[1]}"
                    when 'BLUE'
                      "<\0032#{nickname}\003> #{parsed[1]}"
                    else
                      "<#{nickname}> #{parsed[1]}"
                      p team
                    end
              @bot[:server].msg(parsed[0], msg) if $conf['irc']['relay']
            end
          end
        end
      rescue Exception => e
        puts "[exception] #{e.class}: #{e.message}"
      end
    end
  end
end

irc.join
