#
# Description:
#       Omikuji handler for ingress-shonan team
#
# Notes:
#       This is a simple omikuji handler for ingress-shonan team
#

omikuji = [
    'つ[大吉]'
    'つ[中吉]'
    'つ[吉]'
    'つ[小吉]'
    'つ[半吉]'
    'つ[末吉]'
    'つ[凶]'
    'つ[大凶]'
]

module.exports = (robot) ->
    omikuji_memo = robot.brain.get('omikuji') or {}
    now = new Date()
    ds = "#{now.getFullYear()}/#{now.getMonth()+1}/#{now.getDate()}"
    robot.hear /今日の運勢/, (msg) ->
        user = msg.message.user.name
        key = "#{ds}:#{user}"
        if key of omikuji_memo
            msg.send user + "さん、おみくじは一日一回まででお願いします。"
            msg.send user + "さんの今日(" + ds + ")の運勢は" + omikuji_memo[key] + "でした。"
        else
            result  = msg.random omikuji
            msg.send user + "さんの運勢 " + result
            omikuji_memo[key] = result
        
