# bhoptimer-playtime
Tracks player play-time using shavit's bhoptimer database and natives

To use this plugin, you must modify the SQL database by adding a `playtime` column. To do this, execute this on the SQL server:
```sql
ALTER TABLE `users` ADD `playtime` INT NOT NULL DEFAULT '0' AFTER `points`;
```

# To-Do
* Add native to retrieve play-time
* Add failsafes
