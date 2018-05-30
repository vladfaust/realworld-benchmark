require "benchmark"
require "http/server"
require "http/client"
require "option_parser"
require "json"
require "time_format"

`wrk -v`

host = ""
port = 0

USERS_COUNT           = 100
ARTICLES_PER_USER     = 100
COMMENTS_PER_USER     = (0..5)
FOLLOWINGS_PER_USER   = (0..5)
FAVORITES_PER_ARTICLE = (0..3)

parser = OptionParser.parse! do |parser|
  parser.banner = "Usage: realworld-benchmark [arguments]"

  parser.on("-h HOST", "--host=HOST", "Conduit API host") do |h|
    host = h
  end

  parser.on("-p PORT", "--port=PORT", "Conduit API port") do |p|
    port = p.to_i
  end

  parser.on("--help", "Show this help") do
    puts parser
    exit
  end
end

if host.empty? || port <= 0
  puts parser
  exit
end

def rps(span)
  (1_000_000_000.0 / span.nanoseconds).round(2)
end

server = HTTP::Server.new(5748) do |env|
  env.response.print "Hello Real World!"
end

channel = Channel(Time::Span).new
times = 100

spawn do
  client = HTTP::Client.new("localhost", 5748)
  puts "\nTesting Crystal HTTP::Client latency..."

  elapsed = Time.measure do
    times.times do
      client.get "/"
    end
  end

  server.close
  channel.send(elapsed)
end

server.listen

client_latency = channel.receive / times
puts "Crystal HTTP::Client latency: " + TimeFormat.auto(client_latency)

client = HTTP::Client.new(host, port)

users_jwts = {} of Int32 => String
puts "\nRegistering #{USERS_COUNT} users..."
counter = 1

elapsed = Time.measure do
  USERS_COUNT.times do |i|
    counter += 1
    response = client.post("/users", headers: HTTP::Headers{"Content-Type" => "application/json"}, body: {
      "user" => {
        "email"    => "user#{i}@example.com",
        "password" => "qwerty",
        "username" => "user#{i}",
      },
    }.to_json)
    body = JSON.parse(response.body)
    users_jwts[i + 1] = body["user"]["token"].as_s
  end
end

puts "Overall time elapsed: #{TimeFormat.auto(elapsed)}"
puts "Per user: #{TimeFormat.auto(elapsed / counter)}"
puts "Per user minus latency: #{TimeFormat.auto(elapsed / counter - client_latency)}"
puts "RPS: #{rps(elapsed / counter - client_latency)}"

puts "\nUser#1 JWT token: #{users_jwts[1]}"

puts "\nCreating #{ARTICLES_PER_USER * USERS_COUNT} articles..."
tags = ["foo", "bar", "baz", "quuuuuuux", "yoyo"]
counter = 0

elapsed = Time.measure do
  USERS_COUNT.times do |user_id|
    ARTICLES_PER_USER.times do |article_id|
      counter += 1
      client.post("/articles", headers: HTTP::Headers{"Content-Type" => "application/json", "Authorization" => "Token #{users_jwts[user_id + 1]}"}, body: {
        "article" => {
          "title"       => "Article #{user_id + 1}-#{article_id + 1}",
          "description" => "Article #{user_id + 1}-#{article_id + 1} description",
          "body"        => "Article #{user_id + 1}-#{article_id + 1} body",
          "tagList"     => tags.sample(rand(tags.size)),
        },
      }.to_json)
    end
  end
end

puts "Overall time elapsed: #{TimeFormat.auto(elapsed)}"
puts "Per article: #{TimeFormat.auto(elapsed / counter)}"
puts "Per article minus latency: #{TimeFormat.auto(elapsed / counter - client_latency)}"
puts "RPS: #{rps(elapsed / counter - client_latency)}"

puts "\nCreating #{COMMENTS_PER_USER} comments per user"
counter = 0
elapsed = Time.measure do
  USERS_COUNT.times do |user_id|
    count = rand(COMMENTS_PER_USER)
    counter += count
    count.times do
      slug = "article-#{rand(2..USERS_COUNT)}-#{rand(2..ARTICLES_PER_USER)}"
      client.post("/articles/" + slug + "/comments", headers: HTTP::Headers{"Content-Type" => "application/json", "Authorization" => "Token #{users_jwts[user_id + 1]}"}, body: {
        "comment" => {
          "body" => "Thank you so much!",
        },
      }.to_json)
    end
  end
end

# Create 5 comments for article-1-1
5.times do
  client.post("/articles/article-1-1/comments", headers: HTTP::Headers{"Content-Type" => "application/json", "Authorization" => "Token #{users_jwts[rand(USERS_COUNT + 1)]}"}, body: {
    "comment" => {
      "body" => "Thank you so much!",
    },
  }.to_json)
end

puts "Created #{counter} comments"
puts "Overall time elapsed: #{TimeFormat.auto(elapsed)}"
puts "Per comment: #{TimeFormat.auto(elapsed / counter)}"
puts "Per comment minus latency: #{TimeFormat.auto(elapsed / counter - client_latency)}"
puts "RPS: #{rps(elapsed / counter - client_latency)}"

puts "\nCreating #{FAVORITES_PER_ARTICLE} favorites per article"
counter = 0
elapsed = Time.measure do
  USERS_COUNT.times do |user_id|
    ARTICLES_PER_USER.times do |article_id|
      count = rand(FAVORITES_PER_ARTICLE)
      counter += count
      count.times do
        slug = "article-#{user_id + 1}-#{article_id + 1}"
        client.post("/articles/" + slug + "/favorite", headers: HTTP::Headers{"Content-Type" => "application/json", "Authorization" => "Token #{users_jwts[rand(1..USERS_COUNT)]}"})
      end
    end
  end
end

puts "Created #{counter} favorites"
puts "Overall time elapsed: #{TimeFormat.auto(elapsed)}"
puts "Per favorite: #{TimeFormat.auto(elapsed / counter)}"
puts "Per favorite minus latency: #{TimeFormat.auto(elapsed / counter - client_latency)}"
puts "RPS: #{rps(elapsed / counter - client_latency)}"

puts "\nCreating #{FOLLOWINGS_PER_USER} followings per users"
counter = 0
elapsed = Time.measure do
  USERS_COUNT.times do |user_id|
    count = rand(FOLLOWINGS_PER_USER)
    counter += count
    count.times do
      client.post("/profiles/user#{rand(1..USERS_COUNT)}/follow", headers: HTTP::Headers{"Content-Type" => "application/json", "Authorization" => "Token #{users_jwts[user_id + 1]}"})
    end
  end
end

puts "Created #{counter} followings"
puts "Overall time elapsed: #{TimeFormat.auto(elapsed)}"
puts "Per following: #{TimeFormat.auto(elapsed / counter)}"
puts "Per following minus latency: #{TimeFormat.auto(elapsed / counter - client_latency)}"
puts "RPS: #{rps(elapsed / counter - client_latency)}"

token = users_jwts[1]

json_header = "-H \"Content-Type: application/json\""
auth_header = "-H \"Authorization: Token #{token}\""
url_base = "http://#{host}:#{port}"

puts "\nNow running benchmarks with wrk..."

puts "\nRunning Current User..."
puts `wrk -t10 -c100 -d30s #{json_header} #{auth_header} #{url_base}/user`
sleep 5

puts "\nRunning Single Article..."
puts `wrk -t10 -c100 -d30s #{json_header} #{url_base}/articles/article-1-1`
sleep 5

puts "\nRunning Articles by Author..."
puts `wrk -t10 -c100 -d30s #{json_header} #{url_base}/articles?author=user1`
sleep 5

puts "\nRunning Articles by Tag..."
puts `wrk -t10 -c100 -d30s #{json_header} #{url_base}/articles?tag=foo`
sleep 5

puts "\nRunning All Comments for Article..."
puts `wrk -t10 -c100 -d30s #{json_header} #{url_base}/articles/article-1-1/comments`
sleep 5

puts "\nRunning Profile..."
puts `wrk -t10 -c100 -d30s #{json_header} #{auth_header} #{url_base}/profiles/user1`
sleep 5

puts "\nRunning All Tags..."
puts `wrk -t10 -c100 -d30s #{json_header} #{url_base}/tags`
sleep 5
