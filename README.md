# hubot-google-calendar

hubot scripts with Google Calendar API.

## Installation

```
$ npm install bageljp/hubot-google-calendar#master --save
```

Then add **hubot-google-images** to your `external-scripts.json`:

```json
[
  "hubot-google-calendar"
]
```

## Configuration

config file `config/cal.yml`:

```yml
calendars:
  <calendar key>:
    id: 'google calendar id'
    description: 'calendar description'
timezone: 'UTC'
```

Generate Google Calendar API oauth2.0 client id credential to `/.credentials/client_secret.json`:

> Ref. [Google API and Services](https://console.developers.google.com/apis/credentials)

## Appendix

> Ref. [Google Calendar API V3 - Events: list](https://developers.google.com/google-apps/calendar/v3/reference/events)  
> Ref. [Qiita: Slackと連携させたHubotに毎朝今日の予定をお知らせしてもらう](https://qiita.com/tk3fftk/items/6ae172abc57f72eabeb2)

## Author

kadoyama.keisuke@gmail.com
