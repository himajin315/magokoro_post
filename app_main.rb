require 'sinatra'
require 'line/bot'
require 'pry'
require 'aws-sdk-s3'

def line_client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV['LINE_CHANNEL_SECRET']
    config.channel_token = ENV['LINE_CHANNEL_TOKEN']
  }
end

def s3_upload(file)
  client = Aws::S3::Client.new(
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
  )

  s3 = Aws::S3::Resource.new(
    client: client,
    region: ENV['AWS_REGION'],
    endpoint: ENV['AWS_ENDPOINT']
  )

  obj = s3.bucket(ENV['BUCKET_NAME']).object(Time.now.strftime("%Y%m%d-%H:%M:%S"))
  obj.put(body: file)
end

post '/callback' do
  body = request.body.read

  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless line_client.validate_signature(body, signature)
    error 400 do 'Bad Request' end
  end

  events = line_client.parse_events_from(body)
  events.each { |event|
    if event.type == Line::Bot::Event::MessageType::Image
      response = line_client.get_message_content(event.message['id'])
      s3_upload(response.body)
    end
  }

  "OK"
end
