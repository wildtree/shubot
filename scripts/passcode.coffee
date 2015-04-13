#
# Description:
#    Passcode reminder
#
# Commands:
#   hubot passcode me - give a passcode list.
#

permanent_list = [
    'wolfe7jq38cj3'
    'hubert6db54fa6'
    'artifact4tt67xg9'
    'timezero2kk78gx5'
    'green7dv85mp8'
    'conflict5av38pw2'
    'bletchley9ob65ca4'
    'green3ou25jt4'
    'evolve5uu33zd4'
    'jarvis5ye63mv9'
    'roland8cx62mk4'
    'johnson3ba26qb2'
    'Moyer5pp56fg2'
]
passcode_tbl = []
passcode_db_ver = 1

system_time = new Date()
for p in permanent_list
    passcode_tbl.push({passcode: p, owner: 'system', time: system_time })

module.exports = (robot) ->

    robot_name = robot.alias or robot.name

    purge_old_data = (db) ->
        return db

    load_from_brain = ->
        passcode_db = robot.brain.get('passcode') or {}
        ver = if '_ver_' of passcode_db then passcode_db['_ver_'] else -1
        passcode_db = purge_old_data(passcode_db) if ver < passcode_db_ver
        passcode_db['_ver_'] = passcode_db_ver
        if '_list_' of passcode_db
            passcode_tbl = passcode_db['_list_']
        return passcode_db

    robot.respond /passcode\s+add\s+(\S+)\s*$/i, (msg) ->
        passcode_db = load_from_brain()
        new_passcode = msg.match[1]
        found = null
        for p in passcode_tbl
            found = p if p.passcode is new_passcode
        unless found?
            passcode_tbl.push({passcode: new_passcode, owner: msg.message.user.name, time: new Date})
            passcode_db._list_ = passcode_tbl
            robot.brain.set 'passcode', passcode_db
            robot.brain.save
        else
            msg.send "\"#{found.passcode}\" は定義済みだワン。"

    robot.respond /passcode\s+me\s*$/i, (msg) ->
        passcode_db = load_from_brain()
        for p in passcode_tbl
            msg.send p.passcode

    robot.respond /passcode\s+del\s+(\S+)\s*$/i, (msg) ->
        passcode_db = load_from_brain()
        passcode_to_del = msg.match[1]
        i = 0
        nf = true
        for p in passcode_tbl
            if p.passcode is passcode_to_del
                if p.owner is 'system'
                    msg.reply "\"#{p.passcode}\"は削除出来ないワン。"
                    nf = false
                    continue
                passcode_tbl.splice(i, 1)
                msg.reply "\"#{p.passcode}\"を削除したワン。"
                passcode_db._list_ = passcode_tbl
                robot.brain.set 'passcode', passcode_db
                robot.brain.save
                return
            i++
        msg.reply "\"#{passcode_to_del}\"は見つからないワン。" if nf
      
