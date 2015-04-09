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

    robot.respond /passcode\s+set\s+(\S+)\s*$/i, (msg) ->
        pd = load_from_brain()
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
        pd = load_from_brain()
        for p in passcode_tbl
            msg.send p.passcode