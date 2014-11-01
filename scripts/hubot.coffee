#
# Description:
#       Tell about 'hubot' itself
#
# Notes:
#       
#
module.exports = (robot) ->
    robot.respond /(repositry|github|レポジトリ)/i, (msg) ->
        msg.send 'https://github.com/wildtree/shubot.git'
