#!/bin/sh

AUDIO_RESYNC_INTERVAL=120
SPOTIFY_TOKEN_REFRESH_INTERVAL=1800


(
  while ./multiroom bluetooth --resync; do
    sleep ${AUDIO_RESYNC_INTERVAL}
  done
) &

(
  while http localhost:3000/spotify/refresh; do
    sleep ${SPOTIFY_TOKEN_REFRESH_INTERVAL}
  done
) > /dev/null 2>&1 &

cd http && node index.js
