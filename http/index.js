const request = require('request');
const express = require('express');
const app = express();
const spawnSync = require( 'child_process' ).spawnSync;
const SpotifyWebApi = require('spotify-web-api-node');

const credentials = {
  clientId: process.env.SPOTIFY_CLIENT_ID,
  clientSecret: process.env.SPOTIFY_CLIENT_SECRET,
  redirectUri: 'https://example.com/callback'
};

const spotifyApi = new SpotifyWebApi(credentials);

if (process.env.SPOTIFY_AUTH_CODE) {
  spotifyApi.authorizationCodeGrant(process.env.SPOTIFY_AUTH_CODE).then((data) => {
    console.log(data);
    spotifyApi.setAccessToken(data.body['access_token']);
    spotifyApi.setRefreshToken(data.body['refresh_token']);
  })
  .catch((err) => {
    console.log('Something went wrong!', err);
  });
}

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

app.get('/devices', function (req, res) {
  spotifyApi.getMyDevices().then((response) => {
    res.send(response.body.devices);
  })
  .catch((err) => {
    res.send(err);
  });
});


app.get('/token', function(req, res) {
  const scopes = ['user-read-playback-state'],
    redirectUri = 'https://example.com/callback',
    clientId = process.env.SPOTIFY_CLIENT_ID,
    state = '';

  // Setting credentials can be done in the wrapper's constructor, or using the API object's setters.
  var spotifyApi = new SpotifyWebApi({
    redirectUri: redirectUri,
    clientId: clientId
  });

  // Create the authorization URL
  var authorizeURL = spotifyApi.createAuthorizeURL(scopes, state);

  // https://accounts.spotify.com:443/authorize?client_id=5fe01282e44241328a84e7c5cc169165&response_type=code&redirect_uri=https://example.com/callback&scope=user-read-private%20user-read-email&state=some-state-of-my-choice
  res.send(authorizeURL);
});

app.listen(3000);
