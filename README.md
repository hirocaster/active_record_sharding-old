# ActiveRecordSharding

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'active_record_sharding'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install active_record_sharding

## Database Setup

This library is not support Rails standard database management/migration feature. because, not assumed the use of multidb.

Use recommend [ridgepole](https://github.com/winebarrel/ridgepole).

### for shading database

Sharding object is `User` class. `user` shards databases(3node).

sharding config `config/shards.yml`

```
development:                       # Rails.env
  user:                            # shard name
    - user_shard_1_development     # database connection name for sharding
    - user_shard_2_development     # ...
    - user_shard_3_development     # ... total 3node
```

database connection name config for `config/database.yml`

```
user_shard_1_development: &user_shard
  adapter: mysql2
  encoding: utf8
  pool: 5
  username: root
  password:
  host: node1.user_shard.host
  database: user_shard_1_development

user_shard_2_development:
  <<: *user_shard
  database: user_shard_2_development
  host: node2.user_shard.host

user_shard_3_development:
  <<: *user_shard
  database: user_shard_3_development
  host: node3.user_shard.host
```

create database

    $ rake sharding:db:create

generate initial schema for user shards

    $ rails g active_record_sharding:schema_shards user 3
          create  db/ridgepole/user_shard/shards/user_shard_1.yml
          create  db/ridgepole/user_shard/shards/user_shard_2.yml
          create  db/ridgepole/user_shard/shards/user_shard_3.yml
          create  db/ridgepole/user_shard/shards/Schemafile
          create  db/ridgepole/user_shard/shards/users.schema

dry run apply migration

    $ rake "sharding:db:migrate:dry_run[user]"

apply migration

    $ rake "sharding:db:migrate[user]"

### for sequence database

sequence database is id generator for records(ActiveRecord Objects) in shading databases.

shard name is `user`, and sharding class is `User` for `database.yml`

naming rule `#{shard_name}_#{class_name}_sequence_#{Rails.env}`

```
user_user_sequence_development:
  adapter: mysql2
  encoding: utf8
  pool: 5
  username: root
  password:
  host: seq.db.host
  database: user_user_sequence_development
```

create database for user shard, user class

    $ rake "sharding:sequence:create[user, user]"

generate initial schema for user shard, user class sequence

    $ rails g active_record_sharding:schema_sequencer user user
          create  db/ridgepole/user_shard/user_sequence/config.yml
          create  db/ridgepole/user_shard/user_sequence/Schemafile
          create  db/ridgepole/user_shard/user_sequence/user_user_sequence.schema

database migration dry run and apply

    $ bundle exec ridgepole -c db/ridgepole/user_shard/user_sequence/config.yml -f db/ridgepole/user_shard/user_sequence/Schemafile --apply --dry-run

    $ bundle exec ridgepole -c db/ridgepole/user_shard/user_sequence/config.yml -f db/ridgepole/user_shard/user_sequence/Schemafile --apply

need initial counter record for sequence database.

    $ mysql -u root -h seq.db.host user_user_sequence_development -e "INSERT INTO user_user_sequencer (id) VALUES(0)"

    mysql> select * from user_user_sequencer;
    +----+
    | id |
    +----+
    |  0 |
    +----+
    1 row in set (0.00 sec)

## Usage

`User` class model

```
class User < ActiveRecord::Base
  use_shard :user  # shard name(symbol)
end
```

## Contributing

1. Fork it ( http://github.com/hirocaster/active_record_sharding/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
