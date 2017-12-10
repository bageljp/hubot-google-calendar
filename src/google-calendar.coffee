# Description
#  Get Google Calendar
#
# Dependencies:
#  "google-auth-library": "^0.12.0"
#  "googleapis": "^23.0.0"
#  "moment-timezone": "^0.5.14"
#
# Configuration:
#  HUBOT_SLACK_BOTNAME - hubotの表示名
#  /.credentials/client_secret.json - Google Calendar APIのcredentials
#  /config/cal.yml - Google Calendarの設定
#
# Commands:
#   hubot cal help - Google Calendar取得のヘルプを表示します。
#
# Notes:
#   None
#
# Author:
#  kadoyama.keisuke@gmail.com

fs = require('fs')
readline = require('readline')
yaml = require('js-yaml')
google = require('googleapis')
googleAuth = require('google-auth-library')
calendar = google.calendar('v3')
moment = require('moment-timezone')
moment.locale('ja')
SCOPES = [ 'https://www.googleapis.com/auth/calendar.readonly' ]
TOKEN_DIR = '.credentials/'
TOKEN_PATH = TOKEN_DIR + 'calendar-api-quickstart.json'

# Load configurations
config = {}
fs.readFile "config/cal.yml", 'utf8', (err, data) ->
  throw err if err
  config = yaml.safeLoad data

# check calendar id exists
checkCalendarId = (id, robot) ->
  if config.calendars.hasOwnProperty(id)
    return true
  else
    robot.send "指定したGoogle Calendarは存在しません。"
    return false

# List calendar ids
listCalendars = (robot) ->
  message = ""
  for k of config.calendars
    message = "#{message}#{k} - #{config.calendars[k].description}\n"
  robot.send """
    表示可能なGoogle Calendarのid
    ```
    #{message}```
    """

# Load client secrets from a local file.
getCredentials = (callback, options, robot) ->
  fs.readFile '.credentials/client_secret.json', processClientSecrets = (err, data) ->
    if err
      console.log('Error loading client secret file: ' + err)
      return
    # Authorize a client with the loaded credentials, then call the
    # Google Calendar API.
    authorize JSON.parse(data), callback, options, robot

# Create an OAuth2 client with the given credentials, and then execute the
# given callback function.
#
# @param {Object} credentials The authorization client credentials.
# @param {function} callback The callback to call with the authorized client.
authorize = (credentials, callback, options, robot) ->
  clientSecret = credentials.installed.client_secret
  clientId = credentials.installed.client_id
  redirectUrl = "urn:ietf:wg:oauth:2.0:oob"
  auth = new googleAuth
  oauth2Client = new (auth.OAuth2)(clientId, clientSecret, redirectUrl)
  # Check if we have previously stored a token.
  fs.readFile TOKEN_PATH, (err, token) ->
    if err
      getNewToken oauth2Client, callback, options, robot
    else
      oauth2Client.credentials = JSON.parse(token)
      callback oauth2Client, options, robot
    return
  return

# Get and store new token after prompting for user authorization, and then
# execute the given callback with the authorized OAuth2 client.
#
# @param {google.auth.OAuth2} oauth2Client The OAuth2 client to get token for.
# @param {getEventsCallback} callback The callback to call with the authorized
#     client.
getNewToken = (oauth2Client, callback, options, robot) ->
  authUrl = oauth2Client.generateAuthUrl({
    access_type: 'offline'
    scope: SCOPES
  })
  console.log 'Authorize this app by visiting this url: ', authUrl
  rl = readline.createInterface({
    input: process.stdin
    output: process.stdout
  })
  rl.question 'Enter the code from that page here: ', (code) ->
    rl.close()
    oauth2Client.getToken code, (err, token) ->
      if err
        console.log 'Error while trying to retrieve access token', err
        return
      oauth2Client.credentials = token
      storeToken token
      callback oauth2Client, options, robot
      return
    return
  return

# Store token to disk be used in later program executions.
#
# @param {Object} token The token to store to disk.
storeToken = (token) ->
  try
    fs.mkdirSync TOKEN_DIR
  catch err
    if err.code != 'EEXIST'
      throw err
  fs.writeFile TOKEN_PATH, JSON.stringify(token)
  console.log 'Token stored to ' + TOKEN_PATH
  return

# Gets the next 10 events on the user's primary calendar.
#
# @param {google.auth.OAuth2} auth An authorized OAuth2 client.
getEvents = (auth, options, robot) ->
  # console.log "options: " + JSON.stringify(options)
  timeMin = options.timeMin or moment().startOf('day')
  timeMax = options.timeMax or moment().endOf('day')
  calendarId = options.calendar.id
  timezone = config.timezone or "UTC"
  if timeMin.tz(timezone).format("YYYY-MM-DD") == timeMax.tz(timezone).format("YYYY-MM-DD")
    message = "#{timeMin.tz(timezone).format("YYYY-MM-DD")} のGoogle Calendar(#{calendarId})の予定です。\n```\n"
  else
    message = "#{timeMin.tz(timezone).format("YYYY-MM-DD")} - #{timeMax.tz(timezone).format("YYYY-MM-DD")} のGoogle Calendar(#{calendarId})の予定です。\n```\n"

  calendar.events.list {
    auth: auth
    calendarId: calendarId
    timeMin: timeMin.toDate().toISOString()
    timeMax: timeMax.toDate().toISOString()
    # maxResults: 10
    singleEvents: true
    orderBy: 'startTime'
  }, (err, response) ->
    if err
      console.log 'There was an error contacting the Calendar service: ' + err
      return
    events = response.items
    if events.length == 0
      #console.log 'No upcoming events found.'
      robot.send "#{message}予定なし\n```"
    else
      # console.log 'Upcoming 10 events:'
      i = 0
      while i < events.length
        event = events[i]
        # console.log "event: #{JSON.stringify(event)}"
        start = event.start.dateTime or event.start.date
        end = event.end.dateTime or event.end.date
        start_m = moment(start, "YYYY-MM-DD")
        end_m = moment(end, "YYYY-MM-DD")
        # setting time?
        if start.indexOf("T") >= 0
          # dateTime format YYYY-MM-DDTHH:MM:SS.sssZ
          start_msg = start.split("T")[0] + start_m.format("(ddd)") \
            + " " + start.split("T")[1].split("+")[0]
          if start_m.diff(end_m, "days") == 0
            end_msg = end.split("T")[1].split("+")[0]
          else
            end_msg = end.split("T")[0] + end_m.format("(ddd)") \
              + " " + end.split("T")[1].split("+")[0]
        else
          # date format YYYY-MM-DD
          start_msg = start + start_m.format("(ddd)")
          if start_m.diff(end_m, "days") == -1
            end_msg = "終日"
          else
            end_msg = end_m.subtract(1, "days").format("YYYY-MM-DD(ddd)") + " 終日"
        if i != 0 && i % 28 == 0
          # slack block message until 20 line
          robot.send "#{message}```"
          message = "```\n"
        message = "#{message}#{start_msg} - #{end_msg}: <#{event.htmlLink}|#{event.summary}>\n"
        i++
      #console.log "#{message}があります。"
      robot.send "#{message}```"
    return
  return

help = (robot) ->
  robot.send """
    Google Calendarの予定を表示します。
    ```
    #{process.env.HUBOT_SLACK_BOTNAME} cal list - 指定可能なGoogle Calendarの一覧
    #{process.env.HUBOT_SLACK_BOTNAME} cal get [calendarId] - Google Calendarから指定したカレンダーの今週の予定を取得
    #{process.env.HUBOT_SLACK_BOTNAME} cal get {calendarId} week - Google Calendarから指定したカレンダーの今週の予定を取得
    #{process.env.HUBOT_SLACK_BOTNAME} cal get {calendarId} month - Google Calendarから指定したカレンダーの今月の予定を取得
    #{process.env.HUBOT_SLACK_BOTNAME} cal get {calendarId} {yyyymmdd} - Google Calendarから指定したカレンダーの今日からyyyymmddまでの予定を取得
    #{process.env.HUBOT_SLACK_BOTNAME} cal get {calendarId} {yyyymmdd} {yyyymmdd} - Google Calendarから指定したカレンダーのyyyymmddからyyyymmddまでの予定を取得
    ```
    """

module.exports = (robot) ->
  robot.respond /cal help/i, (robot) ->
    help robot

  robot.respond /cal list/i, (robot) ->
    listCalendars robot

  robot.respond /cal get ([a-zA-Z0-9]+)$/i, (robot) ->
    if not checkCalendarId robot.match[1], robot
      return
    options = {}
    options.calendar = config.calendars[robot.match[1]]
    options.timeMin = moment().startOf('day')
    options.timeMax = moment().endOf('day')
    getCredentials getEvents, options, robot

  robot.respond /cal get (.*) (.*)/i, (robot) ->
    if not checkCalendarId robot.match[1], robot
      return
    options = {}
    options.calendar = config.calendars[robot.match[1]]
    switch robot.match[2]
      when 'week'
        options.timeMin = moment().startOf('week')
        options.timeMax = moment().endOf('week')
      when 'month'
        options.timeMin = moment().startOf('month')
        options.timeMax = moment().endOf('month')
      else
        options.timeMax = moment(robot.match[2], "YYYYMMDD")
    getCredentials getEvents, options, robot

  robot.respond /cal get (.*) (.*) (.*)/i, (robot) ->
    if not checkCalendarId robot.match[1], robot
      return
    options = {}
    options.calendar = config.calendars[robot.match[1]]
    options.timeMin = moment(robot.match[2], "YYYYMMDD")
    options.timeMax = moment(robot.match[3], "YYYYMMDD")
    getCredentials getEvents, options, robot
