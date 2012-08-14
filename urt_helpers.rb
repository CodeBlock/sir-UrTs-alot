#!/usr/bin/env ruby
# (c) 2012 Ricky Elrod
# MIT Licensed.

require 'rubygems'
require 'urbanterror'

# Public: Get the color of the team the player is on.
#
# urt      - The UrbanTerror instance to RCON against.
# nickname - The nickname of the player for which we want the team.
#
# Returns a String which is one of: "RED", "BLUE", or "SPECTATOR"
def team_for_player(urt, nickname)
  sleep 1
  players = urt.rcon('players').split("\n")
  player = players.keep_if { |line|
    line =~ /^\d/ && line.split(' ')[1] == nickname
  }[0]
  if player
    player.split(' ')[2]
  else
    'UNKNOWN'
  end
end
