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

omikuji_sysdef = omikuji.length

module.exports = (robot) ->
    omikuji_memo = robot.brain.get('omikuji') or {}
    robot.brain.setAutoSave true
    now = new Date()
    ds = "#{now.getFullYear()}/#{now.getMonth()+1}/#{now.getDate()}"
    if '_list_' of omikuji_memo
        omikuji = omikuji_memo['_list_']
    robot.hear /今日の運勢/, (msg) ->
        user = msg.message.user.name
        key = "#{ds}:#{user}"
        if key of omikuji_memo
            msg.reply " さん、おみくじは一日一回まででお願いします。"
            msg.reply " さんの今日(" + ds + ")の運勢は\n" + omikuji_memo[key] + "\nでした。"
        else
            result  = msg.random omikuji
            msg.reply " さんの運勢 " + result
            omikuji_memo[key] = result
            robot.brain.set 'omikuji', omikuji_memo
            robot.brain.save

    robot.respond /omikuji\s+add\s+(.*)$/i, (msg) ->
        e = msg.match[1]
        unless e in omikuji
            omikuji.push(e)
            omikuji_memo['_list_'] = omikuji
            robot.brain.set 'omikuji', omikuji_memo
            robot.brain.save

    robot.respond /omikuji\s+dump/i, (msg) ->
        s = "おみくじ候補:\n"
        i = 0
        for e in omikuji
            i += 1
            index = "   #{i}".substr(-3,3)
            s += "#{index}: \"#{e}\"\n"
        s += "---\n#{i} items"
        msg.send s

    robot.respond /omikuji\s+del\s+(\d+)/i, (msg) ->
        target = parseInt(msg.match[1], 10) - 1
        if target >= omikuji_sysdef and target < omikuji.length
            omikuji.splice(target, 1)
        else
            err = "#{target + 1} is not existing."
            err = "#{target + 1} is defined by system." if target < omikuji_sysdef
            msg.send err


#    robot.respond /test/i, (msg) ->
#        console.log robot.brain        
