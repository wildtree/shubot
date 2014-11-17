# -*- utf-8 -*-
# Description:
#   parse weather forcast from Yahoo, notify in case it will be rain.
# Commands:
#   hubot geo add <query> [as <alias>] - add a point
#   hubot geo del <key> - delete a point
#   hubot geo show [<filter>] - show list of points
#   hubot geo channel add <channel> to <key> - add a channel to report about key
#   hubot geo channel del <channel> from <key> - delete a channel from the key
#   hubot geo alias <alias> as <key> - create `alias` as key
#   hubot weather me [<key>] - report weather information
#
cron = require('cron').CronJob

app_key = process.env.YOLP_API_KEY
db_ver = 1

rgstr  = [ '', '弱い雨', 'やや強い雨', '強い雨', '激しい雨', '非常に激しい雨', '猛烈な雨']

geo_coder_api = 'http://geo.search.olp.yahooapis.jp/OpenLocalPlatform/V1/geoCoder'
weather_api = 'http://weather.olp.yahooapis.jp/v1/place'
module.exports = (robot) ->
    # set up cron job
    cronjob = new cron '0 1,11,21,31,41,51 * * * *', () =>
        get_weather(robot, null)
    cronjob.start()
    
    cache = {}

    upgrade_db = (db) ->
        return db

    save_db = (db) ->
        robot.brain.set 'weather', db
        robot.brain.save

    load_db = ->
        db = robot.brain.get('weather') or {}
        db._ver_ = db_ver unless '_ver_' of db
        db = upgrade_db(db) if db._ver_ < db_ver
        save_db db
        return db

    alias2key = (a) ->
        db = load_db()
        loc = db._loc_
        alias = db._alias_

        return a unless alias?
        return a if a of loc
        return alias[a] if a of alias
        return a

    rain_grade = (r) ->
        if 1.0 <= r < 10.0
            return 1
        if 10.0 <= r < 20.0
            return 2
        if 20.0 <= r < 30.0
            return 3
        if 30.0 <= r < 50.0
            return 4
        if 50.0 <= r < 80.0
            return 5
        if r >= 80.0
            return 6
        return 0

    compare_grade = (r1, r2) ->
        g1 = rain_grade(r1)
        g2 = rain_grade(r2)
        return g1 isnt g2

    heart_beat = (robot) ->
        db = load_db()
        hb = db._hb_
        return unless hb?
        timestamp = new Date()
        for dest in hb
            robot.send { room: "@#{dest}" }, "#{timestamp} done."

    get_coordinate = (query, respond, a = null) ->
        db = load_db()
        loc = db._loc_ or {}
        return query if query of loc # skip 
        q = encodeURIComponent(query)
        api = geo_coder_api + "?appid=#{app_key}&query=#{q}&output=json"
        name = null
        user = respond.message.user.name
        robot.http(api).get() (err, res, body) ->
            if err
                 robot.send {room: "#sandbox"}, "YOLP APIにアクセスできません:- #{err}"
                 return null
            unless res.statusCode is 200
                 robot.send {room: '#sandbox'}, "YOLP APIがエラーを返しました。Status code: #{res.statusCode}"
                 return null
            data = JSON.parse(body)
            unless data.ResultInfo.Count > 0
                robot.send {room: '#sandbox'}, "`#{query}`は見つかりませんでした。"
                return null
            geo = data.Feature[0]
            name = geo.Name
            coordinate = geo.Geometry.Coordinates.split ','
            row = { lat: coordinate[1], lon: coordinate[0], channels: [], last_forecast: { Rainfall: 0, ChangeAt: 0, RainfallTo: 0, Timestamp: 0, changed: false }, owner: user, created: new Date() }
            renew = if name of loc then true else false
            loc[name] = row
            db._loc_ = loc
            if renew
                txt = "`#{name}` を (#{coordinate[0]}, #{coordinate[1]})に更新しました。"
            else
                a = query unless a?
                txt = "`#{query}` を (#{coordinate[0]}, #{coordinate[1]}) で、`#{name}`として登録しました。"
                unless name is a
                    alias = db._alias_ or {}
                    if a of alias
                        txt += "\n`#{a}`を#{alias[a]}のエイリアスから#{name}のエイリアスに変更しました。"
                    else
                        txt += "\n`#{a}` を#{name} のエイリアスとして登録しました。"
                    alias[a] = name
            respond.reply "#{txt}\n#{data.ResultInfo.Latency} 秒を要しました。"
            save_db db
            return name
 
    to_date = (d) ->
        ds   = d.toString()
        y    = ds.substr(0, 4)
        m    = ds.substr(4, 2)
        date = ds.substr(6, 2)
        h    = ds.substr(8, 2)
        min  = ds.substr(10, 2)

        return new Date("#{y}-#{m}-#{date} #{h}:#{min}")

    to_timestring = (d) ->
        return "#{('00'+d.getHours().toString()).substr(-2,2)}:#{('00'+d.getMinutes().toString()).substr(-2,2)}"

    parse_weather = (wl, loc, nocache) ->
        gnow = null
        norain = true
        for w in wl.Weather
            gnow = rain_grade(parseFloat w.Rainfall) if w.Type is 'observation'
            if w.Type is 'forecast'
                g = rain_grade(parseFloat w.Rainfall)
                d = to_date(w.Date)    
                norain = false if g > 0
                if g isnt gnow
                    prefix = "#{to_timestring(d)}ごろ、"
                    unless nocache
                        loc.last_forecast.changed = true if loc.last_forecast.RainfallTo isnt g or loc.last_forecast.ChangeAt isnt w.Date or loc.last_forecast.Rainfall isnt gnow
                        loc.last_forecast.Rainfall = gnow
                        loc.last_forecast.RainfallTo = g
                        loc.last_forecast.ChangeAt = w.Date
                    if gnow is 0
                        return "#{prefix}#{rgstr[g]}が降り出しそうです。"
                    else
                        if g is 0
                            return "現在の#{rgstr[gnow]}は、#{prefix}止みそうです。"
                        else
                            if g > gnow
                                return "#{prefix}雨脚が強まり、#{rgstr[g]}になりそうです。"
                            else
                                return "#{prefix}雨が弱まり、#{rgstr[g]}になりそうです。"
        unless nocache
            fd = to_date loc.last_forecast.ChangeAt
            nd = new Date()
            if gnow? and fd > nd
                if gnow is 0 and norain and loc.last_forecast.RainfallTo > 0
                    loc.last_forecast.RainfallTo = 0
                    loc.last_forecast.Rainfall = 0
                    loc.last_forecast.ChangeAt = 0
                    return "#{to_timestring(fd)}ごろの降雨予報は解除されました。"
                if loc.last_forecast.RainfallTo is 0
                    for w in wl.Weather
                        wd = to_date w.Date
                        if wd is fd and rain_grade(parseFloat w.Rainfall) > 0
                            loc.last_forecast.RainfallTo = 0
                            loc.last_forecast.Rainfall = gnow
                            loc.last_forecast.ChangeAt = 0
                            return "#{to_timestring(fd)}ごろ雨が止む予報は解除されました。"
        return null

    get_weather_sub = (api, robot, respond, list) ->
        db = load_db()
        loc = db._loc_
        robot.http(api).get() (err, res, body) ->
            return null if err or res.statusCode isnt 200
            data = JSON.parse(body)
            return null unless data.ResultInfo.Count > 0
            i = 0
            while i < data.ResultInfo.Count
                l = loc[list[i]]
                wl = data.Feature[i].Property.WeatherList
                nocache = respond?
                msg = parse_weather(wl, l, nocache)
                if respond?
                    msg = "一時間以内には天候の変化はないと思われます。" unless msg?
                    respond.reply "#{list[i]}地区:#{msg}"
                else
                    if msg? and l.last_forecast.changed
                        l.last_forecast.changed = false # flag clear
                        channels = l.channels
                        for room in channels
                            robot.send { room: "##{room}" }, "#{list[i]}地区:#{msg}"
                i++

    get_weather = (robot, respond, place = null) ->
        db = load_db()
        loc = db._loc_
        keys = Object.keys(loc)
        if place?
            unless place of loc
                # no such a key
                return null
            keys = [place]

        while keys.length > 0
            l1 = []
            n = 0
            for key in keys
                n++
                l1.push(key)
                break if l1.length is 10
            gs = null
            for k in l1
                s = "#{loc[k].lon},#{loc[k].lat}"
                gs = if gs? then "#{gs} #{s}" else s
            keys.splice(0, n)
            gs = encodeURIComponent(gs)
            api = weather_api + "?appid=#{app_key}&coordinates=#{gs}&output=json"
            get_weather_sub(api, robot, respond, l1)

        heart_beat(robot) unless respond?

    robot.respond /geo\s+me\s+(\S+)/i, (msg) ->
        get_coordinate(msg.match[1], msg)

    robot.respond /weather\s+me\s*(\S*)/i, (msg) ->
        db = load_db()
        loc = db._loc_
        a = msg.match[1]
        k = alias2key(a)
        if a? and k of loc
            get_weather(robot, msg, k)
        else
            if a? and a isnt ""
                msg.reply "`#{a}`は登録されていません。"
                return
            get_weather(robot, msg)

    robot.respond /geo\s+add\s+(\S+)(\s+as\s+)*(\S*)/i, (msg) ->
        a = if /^$/.test(msg.match[3]) then null else msg.match[3]
        get_coordinate(msg.match[1], msg, a)

    robot.respond /geo\s+del\s+(\S+)/i, (msg) ->
        db = load_db()
        loc = db._loc_
        name = msg.match[1]
        key = alias2key(name)
        unless key of loc
            msg.reply "`#{name}` は、登録されていません。"
            return
        user = loc[key]['owner']
        delete loc[key]
        alias = db._alias_
        if alias?
            for a, k of alias
                delete alias[a] if k is key
            db._alias_ = alias
        
        db._loc_ = loc
        save_db db
        msg.reply "`#{name}` は削除されました。"
        unless user is msg.message.user.name
            # send direct message to owner...
            robot.send { room: "@#{user}" }, "`#{name}`が@#{msg.message.user.name}からの要求により削除されました。"

    robot.respond /geo\s+show\s*(\S*)/i, (msg) ->
        db = load_db()
        loc = db._loc_
        alias = db._alias_
        txt = "登録地点情報:"

        a = msg.match[1]
        k = alias2key(a)
        
        n = 0
        m = 0
        for key, value of loc
            n++
            continue if /^\S+$/.test(a) and key isnt k
            m++
            txt += "\n`#{key}` (#{value.lon}, #{value.lat}) (#{value.created} by #{value.owner})"
            if alias?
                 aa = []
                 for a1, k1 of alias
                     aa.push "'#{a1}'" if k1 is key
                 txt += "\n    {#{aa.join(', ')}}" if aa.length > 0

            if value.channels.length > 0
                 txt += "\n    ["
                 i = 0
                 while i < value.channels.length
                     txt += ", " if i > 0
                     txt += "##{value.channels[i++]}"
                 txt += "]"
        txt += "\n--- #{m} out of #{n} reported.\n"
        msg.send txt

    robot.respond /geo\s+channel\s+add\s+#?(\S+)\s+to\s+(\S+)/i, (msg) ->
        db = load_db()
        loc = db._loc_
        channel = msg.match[1]
        alias = msg.match[2]
        key = alias2key(alias)
        unless key of loc
            msg.reply "`#{alias}`は登録されていません。"
            return
        channels = channel.split(/:/)
        txt = ""
        for c in channels
            loc[key].channels.push(c) unless c in loc[key].channels
            txt += "\n" unless txt is ""
            txt += "チャネル`##{c}`へ#{alias}の天候の変化を報告します。"
        msg.reply txt
        db._loc_ = loc
        save_db db

    robot.respond /geo\s+channel\s+del\s+#?(\S+)\s+from\s+(\S+)/i, (msg) ->
        db = load_db()
        loc = db._loc_
        channel = msg.match[1]
        alias = msg.match[2]
        key = alias2key(alias)
        unless key of loc
            msg.reply "`#{alias}`は登録されていません。"
            return
        channels = channel.split(/:/)
        txt = ""
        for c in channels
            unless c in loc[key].channels
                txt += "\n" unless txt is ""
                txt "`#{c}`は登録されていません。"
                continue
            i = 0
            while c in loc[key].channels
                if loc[key].channels[i] is c
                    loc[key].channels.splice(i, 1)
                    txt += "\n" unless txt is ""
                    txt += "チャネル`##{c}`への#{alias}の天候の報告を停止します。"
                else
                    i++
        msg.reply txt unless txt is ""
        db._loc_ = loc
        save_db db

    robot.respond /geo\s+alias\s+(\S+)\s+as\s+(\S+)/i, (msg) ->
        db = load_db()
        loc = db._loc_
        alias = db._alias_ or {}
        a = msg.match[1]
        k = alias2key msg.match[2]

        if k is "" and a of alias
            delete alias[a]
            msg.reply "`#{a}`は削除されました。"
        else
            unless k of loc
                msg.reply "`#{k}`は存在していません。"
            else
                alias[a] = k
                msg.reply "`#{a}`は#{k}のエイリアスとして登録されました。"

        db._alias_ = alias
        save_db db

    robot.respond /weather\s+hb\s+start\s+(\S+)/i, (msg) ->
        target = msg.match[1]
        db = load_db()
        hb = db._hb_ or []
        hb.push(target) unless target in hb
        msg.reply "#{target}へheartbeatの送信を開始します。"
        db._hb_ = hb
        save_db db

    robot.respond /weather\s+hb\s+stop\s+(\S+)/i, (msg) ->
        target = msg.match[1]
        db = load_db()
        hb = db._hb_
        return unless hb?
        if target in hb
            i = 0
            for p in hb
                if p is target
                    hb.splice(i++, 1)
                    msg.reply "#{target}へのheartbeatの送信を停止します。"
            db._hb_ = hb
            save_db db

    robot.respond /weather\s+hb\s+show/i, (msg) ->
        db = load_db()
        hb = db._hb_
        i = 0
        txt = ""
        if hb?
            for p in hb
                i++
                txt += "\n" unless txt is ""
                txt += "#{i}: `#{p}`"
        txt += "\n" unless txt is ""
        msg.reply "#{txt}#{i} person(s)"

