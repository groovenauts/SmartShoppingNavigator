# coding: utf-8

require "google/apis/pubsub_v1"
require "google/apis/storage_v1"

class Pubsub
  include Google::Apis::PubsubV1

  def initialize
    @api = Google::Apis::PubsubV1::PubsubService.new
    @api.authorization = Google::Auth.get_application_default(["https://www.googleapis.com/auth/cloud-platform"])
    @api.authorization.fetch_access_token!
  end

  def publish(project_id, topic, message, attributes={})
    topic_name = "projects/#{project_id}/topics/#{topic}"
    msg_obj = PublishRequest.new(
      messages: [
        Message.new(data: message, attributes: attributes)
      ]
    )
    @api.publish_topic(topic_name, msg_obj)
  end
end

class GCS
  def initialize
    @api = Google::Apis::StorageV1::StorageService.new
    @api.authorization = Google::Auth.get_application_default(["https://www.googleapis.com/auth/cloud-platform"])
    @api.authorization.fetch_access_token!
  end

  def get_object_content(gcs_url)
    uri = URI(gcs_url)
    bucket = uri.host
    name = uri.path.sub(/\A\/*/, "")
    buf = StringIO.new
    @api.get_object(bucket, name, download_dest: buf)
    buf.string
  end
end

if $0 == __FILE__
  project_id, topic, device, gcs_url = ARGV
  gcs = GCS.new
  image = gcs.get_object_content(gcs_url)
  pubsub = Pubsub.new
  pubsub.publish(project_id, topic, image, attributes={"deviceId" => device})
end
