require('dotenv').config()

const request       = require('request');
const express       = require('express');
const app           = express();
const spawnSync     = require( 'child_process' ).spawnSync;
const SpotifyWebApi = require('spotify-web-api-node');

const HTTP_PORT=3000;

const normalizeRoom = (room) => {
  return room.trim().replace('the ', '').replace(/\b\w/g, l => l.toUpperCase());
}

app.get('/rooms/connect', function (req, res) {
  const room = normalizeRoom(req.query.room);
  console.log(spawnSync('../multiroom', ['bluetooth', '-vvv', '--connect', room]).stdout.toString());
  console.log(spawnSync('../multiroom', ['spotify', '--start', '-vvv', '--user=felipe', room]).stdout.toString());
  res.send('ok');
});

app.get('/rooms/disconnect', function (req, res) {
  const room = normalizeRoom(req.query.room);
  console.log(spawnSync('../multiroom', ['spotify', '--stop', '-vvv', '--user=felipe', room]).stdout.toString());
  console.log(spawnSync('../multiroom', ['bluetooth', '-vvv', '--disconnect', room]).stdout.toString());
  res.send('ok');
});

app.get('/rooms/:action', function (req, res) {
  result = spawnSync('../multiroom', ['bluetooth', `--${req.params.action}`]).stdout.toString();
  res.send(result);
});

const redirectBaseUri = process.env.EXTERNAL_TUNNEL_URL || 'https://example.com'

const spotifyApi = new SpotifyWebApi({
  clientId: process.env.SPOTIFY_CLIENT_ID,
  clientSecret: process.env.SPOTIFY_CLIENT_SECRET,
  redirectUri: `${redirectBaseUri}/spotify/auth/token`
});

console.log('Starting Multiroom HTTP Server...');

if (process.env.SPOTIFY_ACCESS_TOKEN) {
  spotifyApi.setAccessToken(process.env.SPOTIFY_ACCESS_TOKEN);
}

if (process.env.SPOTIFY_REFRESH_TOKEN) {
  spotifyApi.setRefreshToken(process.env.SPOTIFY_REFRESH_TOKEN);
  spotifyApi.refreshAccessToken().then((data) => {
    spotifyApi.setAccessToken(data.body['access_token']);
  })
  .catch((res) => {
    console.log(res);
  });
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
  console.log(req.query.room);
  const roomName = normalizeRoom(req.query.room);
  return findSpotifyDevice(roomName).then((device) => {
    console.log(device);
    if (!device) {
      return res.status(404).send(`Room ${roomName} not found`);
    }
    return spotifyApi.transferMyPlayback({
      deviceIds: [device.id],
      play: true,
    }).then(() => {
      res.send('ok');
    })
    .catch((err) => {
      console.err(err);
      res.send(err);
    });
  })
  .catch((err) => {
    res.send(err);
  });
});

app.get('/spotify/volume', function (req, res) {
  console.log(req.query.room);
  console.log(req.query.volume);
  const roomName = normalizeRoom(req.query.room);
  const volume = parseInt(req.query.volume);
  return findSpotifyDevice(roomName).then((device) => {
    console.log(device);
    if (!device) {
      return res.status(404).send(`Room ${roomName} not found`);
    }
    return spotifyApi.setVolume(volume, { device_id: device.id }).then(() => {
      res.send('ok');
    })
    .catch((err) => {
      console.err(err);
      res.send(err);
    });
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

app.get('/spotify/auth/refresh', function(req, res){
  spotifyApi.refreshAccessToken().then((data) => {
    spotifyApi.setAccessToken(data.body['access_token']);
    res.send('ok');
  })
  .catch((err) => {
    res.send(err);
  })
});

app.get('/spotify/auth/token', function(req, res) {
  spotifyApi.authorizationCodeGrant(req.query.code).then((data) => {
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

app.listen(HTTP_PORT);

console.log('Listening on port ' + HTTP_PORT);
