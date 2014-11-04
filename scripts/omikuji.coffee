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

omikuji_db_ver = 1 # must be updated when you change db structure
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

    purge_old_data = (omikuji_memo) ->
        for key, value of omikuji_memo
            # delete old style cache data from db
            delete omikuji_memo[key] if /^\d{4}-\d{2}-\d{2}:.*/.test(key)
        return omikuji_memo

    load_from_brain = ->
        omikuji_memo = robot.brain.get('omikuji') or {}
        ver = if '_ver_' of omikuji_memo then omikuji_memo['_ver_'] else -1
        omikuji_memo = purge_old_data(omikuji_memo) if ver < omikuji_db_ver
        omikuji_memo['_ver_'] = omikuji_db_ver
        if '_list_' of omikuji_memo
            omikuji_tbl = omikuji_memo['_list_']
        return omikuji_memo

    robot.hear /今日の運勢/, (msg) ->
        omikuji_memo = load_from_brain()
        ds = get_ds()
        user = msg.message.user.name
        omikuji_ts = omikuji_memo['_timestamp_'] or {}
        omikuji_msg = omikuji_memo['_result_'] or {}
        ld = if user of omikuji_ts then new Date(omikuji_ts[user]) else null 
        now = new Date(ds)
        if ld? and ld.getTime() >= now.getTime()
            msg.reply " さん、おみくじは一日一回まででお願いします。"
            msg.reply " さんの今日(" + ds + ")の運勢は\n" + omikuji_msg[user] + "\nでした。"
        else
            result  = msg.random omikuji_tbl
            msg.reply " さんの運勢 " + result.word
            omikuji_msg[user] = result.word
            omikuji_ts[user]  = ds
            omikuji_memo['_timestamp_'] = omikuji_ts
            omikuji_memo['_result_'] = omikuji_msg
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
