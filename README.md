Redisk
======

Redisk is based off of antirez's weekend idea of a redis ugly brother - BigDis (check out antirez' repos).
Redisk uses Redis's protocol, and saves the data via a sha1 hash to disk. 

## Usage

`budle exec bin/redisk`

The default options are 

- port 6380
- localhost
- 2 level hashing
- /tmp DB prefix

You can change these arguments via a config file, or passing options in the CLI.
Check out lib/redisk/config.rb for what options are valid. 
Passing a CLI option will override a config file that is passed as well. 

## Example

- open up one terminal and run the (eventmachine) server:


`shair@comp ~/projects/redisk: $ bundle exec bin/redisk `

`Starting Redisk on port 6380`

- Then use the redisk server to store files on disk: 


`shair@comp ~/projects/redisk: $ echo "set foo bar" | redis-cli -p 6380 `

`OK`

`shair@comp ~/projects/redisk: $ cat /tmp/0b/ee/0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33 `

`bar`

`shair@comp ~/projects/redisk: $ echo "get foo" | redis-cli -p 6380 `

`bar`

`shair@comp ~/projects/redisk: $ echo "exists foo" | redis-cli -p 6380 `

`(integer) 1`

`shair@comp ~/projects/redisk: $ echo "del foo" | redis-cli -p 6380 `

`(integer) 1`

`shair@comp ~/projects/redisk: $ echo "del foo" | redis-cli -p 6380 `

`(integer) 0`

`shair@comp ~/projects/redisk: $ cat /tmp/0b/ee/0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33 `

`cat: /tmp/0b/ee/0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33: No such file or directory`

`shair@comp ~/projects/redisk: $ echo "exists foo" | redis-cli -p 6380 `

`(integer) 0`

`shair@comp ~/projects/redisk: $ echo "flushdb" | redis-cli -p 6380 `

`OK`

## Serving files via HTTP

Nginx is known for it's blazing speed for serving static files:

See: http://wiki.nginx.org/NginxHttpRedis 

It can be used with simple HTTP req's like GET /key etc.

The content type can be determined with another key.contenttype and be used as the Content Type header.

## Nothing here

Any questions?

Enjoy!
