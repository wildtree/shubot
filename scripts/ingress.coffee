# Description:
#   Ingress related information supply
#
# Notes:

module.exports = (robot) ->
    robot.respond /(contact|通報先)/i, (msg) ->
        msg.send 'https://support.google.com/ingress/answer/2808360?contact=1&hl=en#hl=en&contact=1'

    spoofer = ['まだやってるの？', '通報してやれ！', '通報先はこちらになります。https://support.google.com/ingress/answer/2808360?contact=1&hl=en#hl=en&contact=1', 'チートはあかん' ]
    robot.hear /shokax/i, (msg) ->
        msg.send msg.random spoofer

    robot.respond /IRT/i, (msg) ->
        msg.send 'https://plus.google.com/communities/115949523823408648956'
