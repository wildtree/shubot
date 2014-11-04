#
# Description:
#       Omikuji handler for ingress-shonan team
#
# Notes:
#       This is a simple omikuji handler for ingress-shonan team
#
# Commands:
#   hubot omikuji add <words> - add a words as omikuji reply
#   hubot omikuji del <num> - delete a words from omikuji list
#   hubot omikuji dump - show omikuji list
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

omikuji_tbl = []
system_time = new Date("1970-01-01 00:00:00")
for e in omikuji
    omikuji_tbl.push({word: e, owner: 'system', time: system_time })

module.exports = (robot) ->
    get_ds = ->
        now = new Date()
        y = ('0000' + now.getFullYear().toString()).substr(-4, 4)
        m = ('00' + (now.getMonth() + 1).toString()).substr(-2, 2)
        d = ('00' + now.getDate().toString()).substr(-2, 2)
        return "#{y}-#{m}-#{d}"

    load_from_brain = ->
        omikuji_memo = robot.brain.get('omikuji') or {}
        if '_list_' of omikuji_memo
            omikuji_tbl = omikuji_memo['_list_']
        return omikuji_memo

    robot.hear /今日の運勢/, (msg) ->
        omikuji_memo = load_from_brain()
        ds = get_ds()
        user = msg.message.user.name
        key = "#{ds}:#{user}"
        if key of omikuji_memo
            msg.reply " さん、おみくじは一日一回まででお願いします。"
            msg.reply " さんの今日(" + ds + ")の運勢は\n" + omikuji_memo[key] + "\nでした。"
        else
            result  = msg.random omikuji_tbl
            msg.reply " さんの運勢 " + result.word
            omikuji_memo[key] = result.word
            robot.brain.set 'omikuji', omikuji_memo
            robot.brain.save

    robot.respond /omikuji\s+add\s+(.*)$/i, (msg) ->
        omikuji_memo = load_from_brain()
        e = msg.match[1]
        found = null
        for h in omikuji_tbl
            found = h if h.word is e
        unless found?
            omikuji_tbl.push({word: e, owner: msg.message.user.name, time: new Date})
            omikuji_memo['_list_'] = omikuji_tbl
            robot.brain.set 'omikuji', omikuji_memo
            robot.brain.save
        else
            msg.send "\"#{found.word}\" は定義済みです。"

    robot.respond /omikuji\s+dump/i, (msg) ->
        omikuji_memo = load_from_brain()
        s = "おみくじ候補:\n"
        i = 0
        for h in omikuji_tbl
            i += 1
            index = "   #{i}".substr(-3,3)
            s += "#{index}: \"#{h.word}\" (#{h.time} by #{h.owner})\n"
        s += "---\n#{i} items"
        msg.send s

    robot.respond /omikuji\s+del\s+(\d+)/i, (msg) ->
        omikuji_memo = load_from_brain()
        target = parseInt(msg.match[1], 10) - 1
        if target >= omikuji_sysdef and target < omikuji_tbl.length
            omikuji_tbl.splice(target, 1)
        else
            err = "#{target + 1} is not existing."
            err = "#{target + 1} is defined by system." if target < omikuji_sysdef
            msg.send err


#    robot.respond /test/i, (msg) ->
#        console.log robot.brain        
