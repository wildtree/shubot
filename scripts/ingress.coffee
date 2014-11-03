# Description:
#   Ingress related information supply
#
# Notes:
# Commands:
#   hubot contact - give an URI for reporting to NIA
#   hubot IRT - give an URI of Ingress Resistance Tokyo

module.exports = (robot) ->
    robot.respond /(contact|通報先)/i, (msg) ->
        msg.send 'https://support.google.com/ingress/answer/2808360?contact=1&hl=en#hl=en&contact=1'

    spoofer = ['$1 まだやってるの？', '通報してやれ！', '通報先はこちらになります。https://support.google.com/ingress/answer/2808360?contact=1&hl=en#hl=en&contact=1', 'チートはあかん' ]
    robot.hear /(shokax)/i, (msg) ->
        output = msg.random spoofer
        output = output.replace(/\$1/, msg.match[1])
        msg.send output

    robot.respond /IRT/i, (msg) ->
        msg.send 'https://plus.google.com/communities/115949523823408648956'
