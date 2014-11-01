#
# Description:
#    Biorythm generator
#

module.exports = (robot) ->
    class Bio
        _days = 0
        constructor: (b) ->
            @birthday = b
            now = new Date()
            _days = parseInt((now.getTime() - @birthday.getTime()) / (24*60*60*1000), 10)

        daysPast: ->
            return _days

        getBirthday: ->
            return @birthday

        getBirthdayStr: ->
            y = @birthday.getFullYear().toString()
            m = ("0" + (@birthday.getMonth() + 1).toString()).substr(-2,2)
            d = ("0" + @birthday.getDate().toString()).substr(-2,2)
            return "#{y}-#{m}-#{d}"

        _getValue = (frac) ->
            return ("   " + Math.round(100 * Math.sin(2 * Math.PI * _days / frac)).toString()).substr(-4, 4)

        _isDanger = (frac) ->
            return Math.abs(_getValue(frac)) < 15

        _isUp = (frac) ->
            return Math.cos(2 * Math.PI * _days / frac) > 0

        _isGood = (frac) ->
            return _getValue(frac) > 85

        _isBad = (frac) ->
            return _getValue(frac) < -85

        p: ->
            return _getValue(23)
        s: ->
            return _getValue(28)
        i: ->
            return _getValue(33)

        pIsDanger: ->
            return _isDanger(23)
        sIsDanger: ->
            return _isDanger(28)
        iIsDanger: ->
            return _isDanger(33)

        pIsUp: ->
            return _isUp(23)
        sIsUp: ->
            return _isUp(28)
        iIsUp: ->
            return _isUp(33)

        judge: (rythm) ->
            r = { p: 23, s: 28, i: 33 }[rythm]
            s = "#{_getValue(r)}" + (if _isUp(r) then "↑" else "↓") + (if _isDanger(r) then " 要注意" else if _isGood(r) then " 絶好調" else if _isBad(r) then " 絶不調" else "")
            return s

    getBiorythm = (birth) ->
        bio = new Bio(birth)
        p = bio.judge('p')
        s = bio.judge('s')
        i = bio.judge('i')

        str = "さん(#{bio.getBirthdayStr()} 生まれ) のバイオリズム:\n 生後 #{bio.daysPast()} 日目\n 身体#{p}\n 感情#{s}\n 知性#{i}\n"
        return str
        
    robot.respond /bio (\d{4}[/\-]\d{2}[/\-]\d{2})/i, (msg) ->
        bd = robot.brain.get("bio") or {}
        birth = new Date(msg.match[1])
        msg.reply getBiorythm birth

        user = msg.message.user.name
        bd[user] = birth.getTime()
        robot.brain.set 'bio', bd
        robot.brain.save

    robot.respond /bio\s*$/i, (msg) ->
        bd = robot.brain.get("bio")
        prefix = robot.alias or robot.name
        unless bd?
            msg.send "Usage:\n#{prefix} bio <yyyy-mm-dd>"
            return
        user = msg.message.user.name
        unless user of bd
            msg.send "Usage:\n#{prefix} bio <yyyy-mm-dd>"

        birth = new Date
        birth.setTime(bd[user])
        msg.reply getBiorythm birth
