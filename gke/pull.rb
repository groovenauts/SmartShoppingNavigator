# coding: utf-8

require "yaml"
require "kura"
require "google/apis/pubsub_v1"
require "google/apis/storage_v1"

class Pubsub
  def initialize
    # use default credential
    @api = Google::Apis::PubsubV1::PubsubService.new
    @api.authorization = Google::Auth.get_application_default(["https://www.googleapis.com/auth/cloud-platform"])
    @api.authorization.fetch_access_token!
  end

  def pull(subscription)
    options = Google::Apis::RequestOptions.default
    options.timeout_sec = 600
    ret = @api.pull_subscription(subscription, Google::Apis::PubsubV1::PullRequest.new(max_messages: 1, return_immediately: false), options: options)
    ret.received_messages || []
  rescue Google::Apis::TransmissionError
    $stderr.puts $!
    []
  end

  def ack(subscription, msgs)
    msgs = [msg] unless msgs.is_a?(Array)
    return if msgs.empty?
    ack_ids = msgs.map(&:ack_id)
    @api.acknowledge_subscription(subscription, Google::Apis::PubsubV1::AcknowledgeRequest.new(ack_ids: ack_ids))
  end
end

class GCS
  def initialize
    @api = Google::Apis::StorageV1::StorageService.new
    @api.authorization = Google::Auth.get_application_default(["https://www.googleapis.com/auth/cloud-platform"])
    @api.authorization.fetch_access_token!
  end

  def insert_object(bucket, name, io, content_type: "image/jpeg")
    obj = Google::Apis::StorageV1::Object.new(name: name)
    @api.insert_object(bucket, obj, upload_source: io, content_type: content_type)
  end
end

class Blocks
  def initialize(url, token)
    @url = URI(url)
    @token = token
  end

  def invoke(params)
    res = Net::HTTP.post_form(@url, params)
    if res.code != "200"
      $stderr.puts("BLOCKS flow invocation failed: #{res.code} #{res.body}")
    end
  end
end

module ML
  module_function
  def predict(project, model, instances)
    auth = Google::Auth.get_application_default(["https://www.googleapis.com/auth/cloud-platform"])
    auth.fetch_access_token!
    access_token =  auth.access_token
    uri = URI("https://ml.googleapis.com/v1/projects/#{project}/models/#{model}:predict")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.request_uri)
    req["content-type"] = "application/json"
    req["Authorization"] = "Bearer #{access_token}"
    req.body = JSON.generate({ "instances" => instances })
    res = http.request(req)
    begin
      jobj = JSON.parse(res.body)
    rescue
      $stderr.puts "ERR: #{$!}"
      return nil
    end
    if jobj["error"]
      $stderr.puts "ERR: #{project}/#{model} #{jobj["error"]}"
      return nil
    end
    jobj["predictions"]
  end
end

def main(project, input_subscription, bucket, blocks_url, blocks_token)
  $stdout.puts "PubSub:#{input_subscription} -> ML Engine -> GCS(gs://#{bucket}/) & BigQuery"
  $stdout.puts "project = #{project}"
  $stdout.puts "subscription = #{input_subscription}"
  $stdout.puts "bucket = #{bucket}"
  $stdout.puts "blocks_url = #{blocks_url}"
  $stdout.puts "blocks_token = #{blocks_token.gsub(/./, "*")}"
  pubsub = Pubsub.new
  gcs = GCS.new
  blocks = Blocks.new(blocks_url, blocks_token)

  loop do
    msgs = pubsub.pull(input_subscription)
    $stdout.puts "#{msgs.size} messages pulled."
    next if msgs.empty?
    msgs.each do |m|
      device = m.message.attributes["deviceId"]
      time = Time.parse(m.message.publish_time)
      obj_name = time.strftime("original/#{device}/%Y-%m-%d/%H/%M%S.jpg")
      gcs.insert_object(bucket, obj_name, StringIO.new(m.message.data))
      annotated_name = time.strftime("annotated/#{device}/%Y-%m-%d/%H/%M%S.jpg")
      blocks.invoke({
        api_token: blocks_token,
        published_time: time.iso8601(3),
        device: device,
        original_gcs: "gs://#{bucket}/#{obj_name}",
        annotated_gcs: "gs://#{bucket}/#{annotated_name}",
      })
    end
    pubsub.ack(input_subscription, msgs)
  end
end

if $0 == __FILE__
  config, = ARGV

  if config
    config = YAML.load(File.read(config))
    project = config["project"]
    input_subscription = "projects/#{project}/subscriptions/#{config["input_subscription"]}"
    bucket = config["bucket"]
    blocks_url = config["blocks_url"]
    blocks_token = config["blocks_token"]
  else
    project = ENV["PROJECT"]
    input_subscription = "projects/#{project}/subscriptions/#{ENV["INPUT_SUBSCRIPTION"]}"
    bucket = ENV["SAVE_BUCKET"]
    blocks_url = ENV["BLOCKS_URL"]
    blocks_token = ENV["BLOCKS_TOKEN"]
  end
  $stdout.sync = true
  $stderr.sync = true
  main(project, input_subscription, bucket, blocks_url, blocks_token)
end
