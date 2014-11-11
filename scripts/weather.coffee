# -*- utf-8 -*-
# Description:
#   parse weather forcast from Yahoo, notify in case it will be rain.
# Commands:
#   hubot geo add <query> - add a point
#   hubot geo del <key> - delete a point
#   hubot geo show [<filter>] - show list of points
#   hubot geo channel add <channel> to <key> - add a channel to report about key
#   hubot geo channel del <channel> from <key> - delete a channel from the key
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
    cronjob = new cron '0 */11 * * * *', () =>
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
        db['_ver_'] = db_ver unless '_ver_' of db
        db = upgrade_db(db) if db['_ver_'] < db_ver
        save_db db
        return db

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

    get_coordinate = (query, respond) ->
        db = load_db()
        loc = db['_loc_'] or {}
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
            row = { lat: coordinate[1], lon: coordinate[0], channels: [], last_forecast: { Rainfall: 0, ChangeAt: 0, RainfallTo: 0, Timestamp: 0 }, owner: user, created: new Date() }
            renew = if name of loc then true else false
            loc[name] = row
            db['_loc_'] = loc
            save_db db
            if renew
                respond.reply "`#{name}` を (#{coordinate[0]}, #{coordinate[1]})に更新しました。"
            else
                respond.reply "`#{query}` を (#{coordinate[0]}, #{coordinate[1]}) で、`#{name}`として登録しました。"
            respond.reply "#{data.ResultInfo.Latency} 秒を要しました。"
            return name
 
    to_date = (d) ->
        ds   = d.toString()
        y    = ds.substr(0, 4)
        m    = ds.substr(4, 2)
        date = ds.substr(6, 2)
        h    = ds.substr(8, 2)
        min  = ds.substr(10, 2)
        return new Date("#{y}-#{m}-#{date} #{h}:#{min}")

    parse_weather = (wl) ->
        console.log wl
        gnow = null
        for w in wl.Weather
            gnow = rain_grade(parseFloat w.Rainfall) if w.Type is 'observation'
            if w.Type is 'forecast'
                g = rain_grade(parseFloat w.Rainfall)
                d = to_date(w.Date)    
                if g isnt gnow
                    prefix = "#{d.getHours()}:#{d.getMinutes()}ごろ、"
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
        return null

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
            robot.http(api).get() (err, res, body) ->
                return null if err or res.statusCode isnt 200
                data = JSON.parse(body)
                return null unless data.ResultInfo.Count > 0
                i = 0
                while i < data.ResultInfo.Count
                    l = loc[l1[i]]
                    wl = data.Feature[i].Property.WeatherList
                    cache[l] = wl
                    msg = parse_weather(wl)
                    if respond?
                        msg = "一時間以内には天候の変化はないと思われます。" unless msg?
                        respond.reply "#{l1[i]}地区:#{msg}"
                    else
                        if msg?
                            channels = l.channels
                            for room in channels
                                robot.send { room: "#{room}" }, "#{l1[i]}地区:#{msg}"
                    i++
                    
            

    get_weather_test = (place) ->
        db = load_db
        loc = db['_loc_']
        unless place of loc
            return false
        row = loc[place]
        api = weather_api + "?appid=#{app_key}&coordinates=#{row['lon']},#{row['lat']}&output=json"
        robot.http(api).get() (err, res, body) ->
            if err
                return false
            if res.statusCode isnt 200
                return false
            data = JSON.parse(body)
            unless data.ResultInfo.Count > 0
                return false
            wl = data.Feature[0].Property.WeatherList
            Rainfall = 0
            ChangeAt = 0
            RainfallTo = 0
            for w in wl
                if w.Type is 'observation'
                    Rainfall = parseFloat w.Rainfall
                if w.Type is 'forecast'
                    r = parseFloat w.Rainfall
                    if compare_grade(r1, r)
                        RainfallTo = r
                        ChangeAt = w.Date
            if ChangeAt > 0
                g1 = rain_grade(Rainfall)
                g2 = rain_grade(RainfallTo)
                if g1 is 0
                   robot.send {room: '#sandbox'}, "間もなく"+rgstr[g2]+"が降り出します。"
                   robot.send {room: "#sandbox"}, "at #{ChangeAt}/#{place}"

    robot.respond /geo\s+me\s+(\S+)/i, (msg) ->
        get_coordinate(msg.match[1], msg)

    robot.respond /weather\s+me\s*(\S*)/i, (msg) ->
        db = load_db()
        loc = db['_loc_']
        if msg.match[1]? and msg.match[1] of loc
            get_weather(robot, msg, msg.match[1])
        else
            if msg.match[1]? and msg.match[1] isnt ""
                msg.reply "`#{msg.match[1]}`は登録されていません。"
                return
            get_weather(robot, msg)

    robot.respond /geo\s+add\s+(\S+)/i, (msg) ->
        get_coordinate(msg.match[1], msg)

    robot.respond /geo\s+del\s+(\S+)/i, (msg) ->
        db = load_db()
        loc = db['_loc_']
        name = msg.match[1]
        unless name of loc
            msg.reply "`#{name}` は、登録されていません。"
            return
        user = loc[name]['owner']
        delete loc[name]
        db['_loc_'] = loc
        save_db db
        msg.reply "`#{name}` は削除されました。"
        unless user is msg.message.user.name
            # send direct message to owner...
            return

    robot.respond /geo\s+show\s*(\S*)/i, (msg) ->
        db = load_db()
        loc = db._loc_
        txt = "登録地点情報:"
        
        n = 0
        m = 0
        for key, value of loc
            n++
            continue if /^\S+$/.test(msg.match[1]) and key isnt msg.match[1]
            m++
            txt += "\n`#{key}` (#{value.lon}, #{value.lat}) (#{value.created} by #{value.owner})"
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
        unless msg.match[2] of loc
            msg.reply "`#{msg.match[2]}`は登録されていません。"
            return
        loc[msg.match[2]].channels.push(msg.match[1]) unless msg.match[1] in loc[msg.match[2]].channels
        msg.reply "チャネル`##{msg.match[1]}`へ天候の変化を報告します。"
        db._loc_ = loc
        save_db db

    robot.respond /geo\s+channel\s+del\s+#?(\S+)\s+from\s+(\S+)/i, (msg) ->
        db = load_db()
        loc = db._loc_
        unless msg.match[2] of loc
            msg.reply "`#{msg.match[2]}`は登録されていません。"
            return
        unless msg.match[1] in loc[msg.match[2]].channels
            msg.reply "`#{msg.match[1]}`は登録されていません。"
        i = 0
        while msg.match[1] in loc[msg.match[2]].channels
            if loc[msg.match[2]].channels[i] is msg.match[1]
                loc[msg.match[2]].channels.splice(i, 1)
            else
                i++
        msg.reply "チャネル`##{msg.match[1]}`へ天候の報告を停止します。"
        db._loc_ = loc
        save_db db
