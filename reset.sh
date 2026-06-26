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
  secret: '61IuM8ndjSKV-tbIy3kwk4euagajbzjf8w-m0wuu6Do',
  uid: '1urYGmQAvkxu23-I9gx4xpnrEy7U12b6ZlXAHxyg6Mo',
  verified: true
)
"
