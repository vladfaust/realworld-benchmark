# RealWorld Benchmark

This is a benchmark for a [RealWorld](https://realworld.io) back-end API implementation.

## Recent results

I'm testing [Rails](https://github.com/gothinkster/rails-realworld-example-app), [Go](https://github.com/gothinkster/golang-gin-realworld-example-app) and [Crystal](https://github.com/vladfaust/crystalworld) implementations each on a separate START1-M [Scaleway](https://scaleway.com) instance, which has following specs:

```
€7.99/mo
4 X86 64bit Cores
4GB memory
Ubuntu Xenial
```

### Rails Configuration

Using Ruby 2.4.0:

```shell
git clone https://github.com/gothinkster/rails-realworld-example-app && cd rails-realworld-example-app
git fetch origin rails-5.1 && git checkout rails-5.1
bundle install
# Of course I had to install nokogiri, libsqlite3-dev and even NodeJS before running this monster. 
# Yes, I need NodeJS to run `rake db:migrate`... 2k18, guys
# Also in Gemfile there is `gem 'devise', git: 'https://github.com/gogovan/devise.git', branch: 'rails-5.1'`, which is 404
# Had to replace with `https://github.com/plataformatec/devise.git`
rake db:migrate
# Directly inheriting from ActiveRecord::Migration is not supported. Please specify the Rails release the migration was written for:
```

<details>
  <summary>Results</summary>
  
  ```
  Rails and Ruby are dead for me.
  ```
</details>

### Crystal configuration

A PostgreSQL instance was running in a single Docker container. 4 instances of the application were running in parallel due to Crystal's not supporting parallelism yet.

```shell
docker run --name postgres --restart unless-stopped -p 5432:5432 -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=crystalworld -d postgres:9.5
git clone https://github.com/vladfaust/crystalworld.git && cd crystalworld
env APP_ENV=production shards build --production --release --no-debug
./bin/cake db:migrate
```

Then 4 times in separate terminals (may be overcome by Docker with reverse proxy or Dokku/Heroku with `Procfile`):

```shell
export APP_ENV=production DATABASE_URL=postgres://postgres:postgres@localhost:5432/crystalworld JWT_SECRET_KEY=064f42f6fea056b8c9c10f14973629c9b541879514a854f287298ecbf28a5c82
./bin/server
```

Then in another terminal:

```shell
git clone https://github.com/vladfaust/realworld-benchmark.git && cd realworld-benchmark
shards install
crystal src/realworld-benchmark.cr --release --no-debug --progress -- --host=localhost -p 5000
```

<details>
  <summary>Results:</summary>

```
Testing Crystal HTTP::Client latency...
Crystal HTTP::Client latency: 140μs

Registering 100 users...
Overall time elapsed: 21.257s
Per user: 210.467ms
Per user minus latency: 210.326ms
RPS: 4.75

User#1 JWT token: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJjcnlzdGFsd29ybGQiLCJzdWIiOiJhdXRoIiwiZXhwIjoxNTMwMzYzODMxLCJ1c2VyIjp7ImlkIjoxfX0.EhXpYZINzEti7Y5i0Rj1ThqutLFX2MyeDyBTav7y6Uo

Creating 10000 articles...
Overall time elapsed: 1.46m
Per article: 8.742ms
Per article minus latency: 8.601ms
RPS: 116.27

Creating 0..5 comments per user
Created 233 comments
Overall time elapsed: 1.935s
Per comment: 8.303ms
Per comment minus latency: 8.163ms
RPS: 122.51

Creating 0..3 favorites per article
Created 14909 favorites
Overall time elapsed: 3.31m
Per favorite: 13.335ms
Per favorite minus latency: 13.194ms
RPS: 75.79

Creating 0..5 followings per users
Created 222 followings
Overall time elapsed: 1.752s
Per following: 7.892ms
Per following minus latency: 7.751ms
RPS: 129.01

Now running benchmarks with wrk...

Running Current User...
Running 30s test @ http://localhost:5000/user
  10 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   178.25ms  221.33ms   1.03s    79.46%
    Req/Sec   175.74    149.41     0.88k    70.44%
  49204 requests in 30.09s, 17.41MB read
Requests/sec:   1635.10
Transfer/sec:    592.41KB

Running Single Article...
Running 30s test @ http://localhost:5000/articles/article-1-1
  10 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   282.77ms  383.95ms   1.62s    80.29%
    Req/Sec   153.17     98.60   646.00     68.14%
  43213 requests in 30.09s, 14.63MB read
Requests/sec:   1436.15
Transfer/sec:    497.88KB

Running Articles by Author...
Running 30s test @ http://localhost:5000/articles?author=user1
  10 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   301.94ms  191.54ms   1.13s    62.96%
    Req/Sec    30.70     14.32    89.00     69.49%
  9128 requests in 30.08s, 214.28MB read
  Socket errors: connect 0, read 0, write 0, timeout 48
Requests/sec:    303.45
Transfer/sec:      7.12MB

Running Articles by Tag...
Running 30s test @ http://localhost:5000/articles?tag=foo
  10 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.26s   457.13ms   2.00s    63.29%
    Req/Sec     4.51      4.22    30.00     67.33%
  783 requests in 30.08s, 780.31MB read
  Socket errors: connect 0, read 0, write 0, timeout 546
Requests/sec:     26.03
Transfer/sec:     25.94MB

Running All Comments for Article...
Running 30s test @ http://localhost:5000/articles/article-1-1/comments
  10 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   306.27ms  400.36ms   1.78s    80.26%
    Req/Sec    99.09     47.07   270.00     64.53%
  28702 requests in 30.09s, 18.07MB read
Requests/sec:    953.96
Transfer/sec:    614.86KB

Running Profile...
Running 30s test @ http://localhost:5000/profiles/user1
  10 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   251.56ms  318.87ms   1.64s    80.51%
    Req/Sec   115.30     80.76   545.00     69.03%
  32411 requests in 30.08s, 5.56MB read
Requests/sec:   1077.34
Transfer/sec:    189.38KB

Running All Tags...
Running 30s test @ http://localhost:5000/tags
  10 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.04s   471.94ms   1.99s    65.33%
    Req/Sec    17.20     15.32    60.00     68.54%
  201 requests in 30.10s, 28.06KB read
  Socket errors: connect 0, read 1, write 0, timeout 2
  Non-2xx or 3xx responses: 101
Requests/sec:      6.68
Transfer/sec:      0.93KB
```
</details>

#### Summary

The best result for Current User is **0.61ms**, which is kinda good. DB is a weak spot for this implementation, Crystal itself takes **150-300μs** in most of the requests.

### Go

To be done...

## Installation

It's a [Crystal](https://crystal-lang.org) application, so you'll need to have Crystal installed on the machine. It also relies on [wrk](https://github.com/wg/wrk), which is mandatory.

## Usage

```shell
crystal src/realworld-benchmark.cr --release --no-debug --progress -- --host=localhost -p 5000
```

## Contributors

- [@vladfaust](https://github.com/vladfaust) Vlad Faust - creator, maintainer
