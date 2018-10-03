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

const redirectBaseUri = process.env.EXTERNAL_TUNNEL_URL || 'https://example.com'

const spotifyApi = new SpotifyWebApi({
  clientId: process.env.SPOTIFY_CLIENT_ID,
  clientSecret: process.env.SPOTIFY_CLIENT_SECRET,
  redirectUri: `${redirectBaseUri}/spotify/auth/token`
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
      return device.name.toUpperCase() === deviceName.toUpperCase();
    });
  });
}

app.get('/spotify/transfer', function (req, res) {
  const deviceName = req.query.device;
  return findSpotifyDevice(deviceName).then((device) => {
    console.log(device);
    if (!device) {
      return res.status(404).send(`Device ${deviceName} not found`);
    }
    return spotifyApi.transferMyPlayback({
      deviceIds: [device.id],
      play: true,
    }).then(() => {
      res.send('ok');
    })
    .catch((err) => {
      res.send(err);
    });
  });
});

const writeEnv = (key, value) => {
  require('fs').appendFile("./.env", `${key}=${value}\n`, function(err) {
    if(!err) { return; }
    console.err(err);
  }); 
}

app.get('/spotify/auth/token', function(req, res) {
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

app.get('/spotify/auth', function(req, res) {
  const authorizeURL = spotifyApi.createAuthorizeURL(['user-read-playback-state', 'user-modify-playback-state'], '');
  res.redirect(authorizeURL);
});

app.listen(3000);
