#!/bin/bash

docker compose restart db

docker compose exec web rails db:reset

docker compose exec web rails runner "
OauthApplication.create!(
  id: 2,
  confidential: true,
  name: 'sd',
  owner_id: 1,
  owner_type: 'User',
  redirect_to_hca_login: false,
  redirect_uri: 'http://localhost:3001/auth/hackatime/callback',
  scopes: 'profile read',
  secret: '168L3q9SgZogm5jySI106nnbZI8FBFJ1hT6_FvqRG4w',
  uid: '1urYGmQAvkxu23-I9gx4xpnrEy7U12b6ZlXAHxyg6Mo',
  verified: true
)
"
