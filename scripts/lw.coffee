# -*- utf-8 -*-
# Description:
#   parse weather forcast from Yahoo, notify in case it will be rain.
# Commands:
#   hubot lw me <area> - show weather report.
#   hubot lw update - update point data.
#   hubot lw show list - show point data.

to_json = require('xmljson').to_json
rss = 'http://weather.livedoor.com/forecast/rss/primary_area.xml'
api = 'http://weather.livedoor.com/forecast/webservice/json/v1?city='

module.exports = (robot) ->
    point = {}
    load_points = ->
        robot.http(rss).get() (err, res, body) ->
            if err
                return null
            if res.statusCode isnt 200
                return null
            to_json body, (error, json) =>
                ws = json.rss.channel['ldWeather:source']
                for id, pref of ws.pref
                    data = pref['$']
                    name = data.title
                    if Object.keys(pref.city).length is 1
                        cdata = pref.city['$']
                        key = cdata.title
                        point[key] = cdata.id
                        continue
                    for cid, city of pref.city
                        cdata = city['$']
                        key = cdata.title
                        point[key] = cdata.id

    load_points()
    robot.respond /lw\s+update/i, (msg) ->
        load_points()

    robot.respond /lw\s+me\s+(\S+)/i, (msg) ->
        key = msg.match[1]
        unless key of point
            msg.reply "`#{key}` は分からないワン！"
            return
        id = point[key]
        robot.http("#{api}#{id}").get() (err, res, body) ->
            if err
                msg.reply "エラーだワン! #{err}"
                return
            unless res.statusCode is 200
                msg.reply "サーバでエラーだワン！#{res.statusCode}"
                return
            json = JSON.parse(body)

            reply = """
`#{json.title}だワン`
  #{json.description.text}\n
"""
            for f in json.forecasts
                fstr = """
\n  #{f.dateLabel}(#{f.date})の天気: #{f.telop}\n
"""
                fstr += "    予想最高気温: #{f.temperature.max.celsius}°C\n" if f.temperature.max?
                fstr += "    予想最低気温: #{f.temperature.min.celsius}°C\n" if f.temperature.min?
                reply += fstr

            if json.pinpointLocations.length > 0
                reply += "\n  ピンポイント予報:\n"
                for p in json.pinpointLocations
                    reply += "    `#{p.name}` #{p.link}\n"

            msg.reply reply
            
    robot.respond /lw\s+show\s+list(\s+\S+)*/i, (msg) ->
        key = msg.match[1]
        reply = "観測地点:\n"
        n = Object.keys(point).length
        i = 0
        for p, id of point
            continue if key? and key isnt p
            i++
            reply += "  `#{p}`\n"
            
        reply += "---\n#{i} out of #{n}\n"
        msg.reply reply
