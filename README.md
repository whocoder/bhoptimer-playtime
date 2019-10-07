# bhoptimer-playtime
Tracks player play-time using shavit's bhoptimer database and natives.

[![travis-ci](https://api.travis-ci.com/whocodes/bhoptimer-playtime.svg?branch=master)](https://travis-ci.com/whocodes/bhoptimer-playtime)

![example](https://i.imgur.com/XBksJvw.png)

To use this plugin, you must modify the SQL database by adding a `playtime` column. To do this, execute this on the SQL server:
```sql
ALTER TABLE `users` ADD `playtime` INT NOT NULL DEFAULT '0' AFTER `points`;
```

# Notes
This does not account for a server crash. Playtime is updated when a user disconnects; if the disconnect event is not fired, the playtime will not be updated for the session.
