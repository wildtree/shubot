#
# Description:
#       Tell about 'hubot' itself
#
# Notes:
#
# Commands:
#   hubot repositry - give an URI for the repository of this hubot.
#   hubot github - same as 'repository' command.
#       
#
module.exports = (robot) ->
    robot.respond /(repository|github|レポジトリ)/i, (msg) ->
        msg.send 'https://github.com/wildtree/shubot.git'
