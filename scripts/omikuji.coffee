#
# Description:
#	Omikuji handler for ingress-shonan team
#
# Notes:
#	This is a simple omikuji handler for ingress-shonan team
#

omikuji = ['つ[大吉]','つ[中吉]','つ[吉]','つ[小吉]','つ[半吉]','つ[末吉]','つ[凶]','つ[大凶]','おみくじ']
module.exports = (robot) ->
    robot.hear /今日の運勢/, (msg) ->
        msg.send msg.random omikuji
