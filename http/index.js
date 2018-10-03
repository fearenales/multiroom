require('dotenv').config()

const request       = require('request');
const express       = require('express');
const app           = express();
const spawnSync     = require( 'child_process' ).spawnSync;
const SpotifyWebApi = require('spotify-web-api-node');

const normalizeRoom = (room) => {
  return room.replace(/\b\w/g, l => l.toUpperCase());
}

app.get('/bluetooth/:action/:room', function (req, res) {
  result = spawnSync('../multiroom', ['bluetooth', `--${req.params.action}`, normalizeRoom(req.params.room)]).stdout.toString();
  res.send(result);
});

app.get('/bluetooth/:action', function (req, res) {
  result = spawnSync('../multiroom', ['bluetooth', `--${req.params.action}`]).stdout.toString();
  res.send(result);
});

const spotifyApi = new SpotifyWebApi({
  clientId: process.env.SPOTIFY_CLIENT_ID,
  clientSecret: process.env.SPOTIFY_CLIENT_SECRET,
  redirectUri: 'https://example.com/callback'
});

if (process.env.SPOTIFY_ACCESS_TOKEN) {
  spotifyApi.setAccessToken(process.env.SPOTIFY_ACCESS_TOKEN);
}

if (process.env.SPOTIFY_REFRESH_TOKEN) {
  spotifyApi.setRefreshToken(process.env.SPOTIFY_REFRESH_TOKEN);
}

app.get('/spotify/devices', function (req, res) {
  spotifyApi.getMyDevices().then((response) => {
    res.send(response.body.devices);
  })
  .catch((err) => {
    res.send(err);
  });
});

const findSpotifyDevice = (deviceName) => {
  return spotifyApi.getMyDevices().then((response) => {
    return response.body.devices.find((device) => {
      device.name.toUpperCase() === deviceName.toUpperCase();
    });
  });
}

app.get('/spotify/transfer', function (req, res) {
  const deviceName = req.query.device;
  const device = findSpotifyDevice(deviceName);
  if (!device) {
    return res.status(404).send(`Device ${deviceName} not found`);
  }
  spotifyApi.transferMyPlayback({
    device_ids: [device.id],
    play: true,
  }).then(() => {
    res.send('ok');
  })
  .catch((err) => {
    res.send(err);
  });
});

const writeEnv = (key, value) => {
  require('fs').appendFile("./.env", `${key}=${value}\n`, function(err) {
    if(!err) { return; }
    console.err(err);
  }); 
}

app.get('/spotify/setup', function(req, res) {
  spotifyApi.authorizationCodeGrant(req.query.code).then((data) => {
    writeEnv('SPOTIFY_ACCESS_TOKEN', data.body['access_token']);
    writeEnv('SPOTIFY_REFRESH_TOKEN', data.body['refresh_token']);
    spotifyApi.setAccessToken(data.body['access_token']);
    spotifyApi.setRefreshToken(data.body['refresh_token']);
    res.send('ok');
  })
  .catch((err) => {
    res.send(err);
  });
});

app.get('/spotify/token', function(req, res) {
  const authorizeURL = spotifyApi.createAuthorizeURL(['user-read-playback-state'], '');
  res.send(authorizeURL);
});

app.listen(3000);
