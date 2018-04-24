# coding: utf-8

require "yaml"
require "kura"
require "rmagick"
require "google/apis/pubsub_v1"
require "google/apis/storage_v1"
require "google/apis/cloudiot_v1"
require "google/cloud/datastore"

class Pubsub
  def initialize
    # use default credential
    @api = Google::Apis::PubsubV1::PubsubService.new
    @api.authorization = Google::Auth.get_application_default(["https://www.googleapis.com/auth/cloud-platform"])
    @api.authorization.fetch_access_token!
    @api.client_options.open_timeout_sec = 10
    @api.client_options.read_timeout_sec = 600
  end

  def pull(subscription)
    ret = @api.pull_subscription(subscription, Google::Apis::PubsubV1::PullRequest.new(max_messages: 1, return_immediately: false))
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

  def copy_object(source_bucket, source_object, destination_bucket, destination_object, object_object = nil, destination_predefined_acl)
    @api.copy_object(source_bucket, source_object, destination_bucket, destination_object, object_object, destination_predefined_acl: destination_predefined_acl)
  end
end

class CloudIot
  def initialize
    # use default credential
    @api = Google::Apis::CloudiotV1::CloudIotService.new
    @api.authorization = Google::Auth.get_application_default(["https://www.googleapis.com/auth/cloud-platform"])
    @api.authorization.fetch_access_token!
  end

  def list_device_configs(project, location, registry, device)
    @api.list_project_location_registry_device_config_versions("projects/#{project}/locations/#{location}/registries/#{registry}/devices/#{device}").device_configs
  end

  def modify_device_config(project, location, registry, device, str)
    @api.modify_cloud_to_device_config("projects/#{project}/locations/#{location}/registries/#{registry}/devices/#{device}",
                                       Google::Apis::CloudiotV1::ModifyCloudToDeviceConfigRequest.new(binary_data: str))
  end
end

class Datastore
  def initialize
    @dataset = Google::Cloud::Datastore.new(project_id: project_id)
  end

  def get_setting(project_id)
    query = Google::Cloud::Datastore::Query.new
    query.kind("Setting")
    query.limit(1)
    setting = @dataset.run(query).first
    setting&.properties&.to_hash or { "season" => "Spring", "period" => "Morning" }
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

LABELS = {
  1 => "person",
  2 => "bicycle",
  3 => "car",
  4 => "motorcycle",
  5 => "airplane",
  6 => "bus",
  7 => "train",
  8 => "truck",
  9 => "boat",
  10 => "traffic light",
  11 => "fire hydrant",
  13 => "stop sign",
  14 => "parking meter",
  15 => "bench",
  16 => "bird",
  17 => "cat",
  18 => "dog",
  19 => "horse",
  20 => "sheep",
  21 => "cow",
  22 => "elephant",
  23 => "bear",
  24 => "zebra",
  25 => "giraffe",
  27 => "backpack",
  28 => "umbrella",
  31 => "handbag",
  32 => "tie",
  33 => "suitcase",
  34 => "frisbee",
  35 => "skis",
  36 => "snowboard",
  37 => "sports ball",
  38 => "kite",
  39 => "baseball bat",
  40 => "baseball glove",
  41 => "skateboard",
  42 => "surfboard",
  43 => "tennis racket",
  44 => "bottle",
  46 => "wine glass",
  47 => "cup",
  48 => "fork",
  49 => "knife",
  50 => "spoon",
  51 => "bowl",
  52 => "banana",
  53 => "apple",
  54 => "sandwich",
  55 => "orange",
  56 => "broccoli",
  57 => "carrot",
  58 => "hot dog",
  59 => "pizza",
  60 => "donut",
  61 => "cake",
  62 => "chair",
  63 => "couch",
  64 => "potted plant",
  65 => "bed",
  67 => "dining table",
  70 => "toilet",
  72 => "tv",
  73 => "laptop",
  74 => "mouse",
  75 => "remote",
  76 => "keyboard",
  77 => "cell phone",
  78 => "microwave",
  79 => "oven",
  80 => "toaster",
  81 => "sink",
  82 => "refrigerator",
  84 => "book",
  85 => "clock",
  86 => "vase",
  87 => "scissors",
  88 => "teddy bear",
  89 => "hair drier",
  90 => "toothbrush",
}

def label_to_name(label_id)
  LABELS[label_id.to_i]
end

def labels_to_url(detections)
  if detections.find{|label, score| label == "apple" }
    "https://storage.googleapis.com/gcp-iost-contents/apple-pie.jpg"
  elsif detections.find{|label, score| label == "banana" }
    "https://storage.googleapis.com/gcp-iost-contents/banana-cereal.jpg"
  else
    "https://storage.googleapis.com/gcp-iost-contents/pizza2.jpg"
  end
end

def draw_bbox_image(b64_image, predictions, threshold=0.3)
  original = Magick::Image.read_inline(b64_image)[0]
  width = original.columns
  height = original.rows
  nega = original.negate
  mask = Magick::Image.new(width, height) { self.background_color = "none" }
  gc = Magick::Draw.new
  gc.stroke_color("white")
  gc.fill_opacity(0)
  gc.stroke_width(1)
  gc.text_align(Magick::LeftAlign)
  gc.font = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
  gc.pointsize = 21
  rec = predictions
  rec["detection_scores"].each_with_index do |score, idx|
    break if score < threshold
    label = label_to_name(rec["detection_classes"][idx])
    xmin = (rec["detection_box_xmin"][idx] * width).to_i
    ymin = (rec["detection_box_ymin"][idx] * height).to_i
    xmax = (rec["detection_box_xmax"][idx] * width).to_i
    ymax = (rec["detection_box_ymax"][idx] * height).to_i
    gc.fill_opacity(0)
    gc.rectangle(xmin, ymin, xmax, ymax)
    gc.fill_opacity(1)
    gc.text(xmin+2, ymin+12, label)
  end
  gc.draw(mask)
  bbox = mask.composite(nega, 0, 0, Magick::SrcInCompositeOp)
  result = original.composite(bbox, 0, 0, Magick::OverCompositeOp)
  result.to_blob
end

def main(config)
  project = config["project"]
  input_subscription = config["input_subscription"]
  bucket = config["bucket"]
  ml_model = config["ml_model"]
  iot_registry = config["iot_registry"]
  threshold = (config["score_threshold"] || 0.2).to_f
  $stdout.puts "PubSub:#{input_subscription} -> ML Engine -> GCS(gs://#{bucket}/) & BigQuery"
  $stdout.puts "project = #{project}"
  $stdout.puts "subscription = #{input_subscription}"
  $stdout.puts "bucket = #{bucket}"
  $stdout.puts "ml_model = #{ml_model}"
  $stdout.puts "iot_registry = #{iot_registry}"
  pubsub = Pubsub.new
  gcs = GCS.new
  iot = CloudIot.new

  loop do
    msgs = pubsub.pull(input_subscription)
    $stdout.puts "#{msgs.size} messages pulled."
    next if msgs.empty?
    msgs.each do |m|
      device = m.message.attributes["deviceId"]
      # Store original image to GCS
      time = Time.parse(m.message.publish_time)
      obj_name = time.strftime("original/#{device}/%Y-%m-%d/%H/%M%S.jpg")
      gcs.insert_object(bucket, obj_name, StringIO.new(m.message.data))
      annotated_name = time.strftime("annotated/#{device}/%Y-%m-%d/%H/%M%S.jpg")
      # Load Device config
      last_config = iot.list_device_configs(project, "us-central1", iot_registry, device).first
      data = JSON.parse(last_config.binary_data)
      b64_image = Base64.strict_encode64(m.message.data)
      # Object Detection prediction
      pred = ML.predict(project, ml_model, [{"key" => "1", "image" => { "b64" => b64_image } }])
      objs = pred[0]["detection_classes"].zip(pred[0]["detection_scores"]).select{|label, score| score > threshold}.map{|label, score| [LABELS[label.to_i], score] }
      $stdout.puts(objs.inspect)
      url = labels_to_url(objs)
      if data["dashboard_url"] != url and Time.parse(last_config.cloud_update_time) + 10 < Time.now
        $stdout.puts("URL change : #{url}")
        data["dashboard_url"] = url
        iot.modify_device_config(project, "us-central1", iot_registry, device, data.to_json)
      end
      # create bounding box image
      bboxed_image = draw_bbox_image(b64_image, pred.first)
      gcs.insert_object(bucket, annotated_name, StringIO.new(bboxed_image), content_type: "image/jpeg")
      gcs.copy_object(bucket, annotated_name, bucket, "annotated/#{device}/annotated.jpg", Google::Apis::StorageV1::Object.new(cache_control: "no-store", content_type: "image_jpeg"), "publicRead")
    end
    pubsub.ack(input_subscription, msgs)
  end
end

if $0 == __FILE__
  config, = ARGV

  if config
    config = YAML.load(File.read(config))
    config["input_subscription"] = "projects/#{config["project"]}/subscriptions/#{config["input_subscription"]}"
  else
    config = {}
    config["project"] = ENV["PROJECT"]
    config["input_subscription"] = "projects/#{config["project"]}/subscriptions/#{ENV["INPUT_SUBSCRIPTION"]}"
    config["bucket"] = ENV["SAVE_BUCKET"]
    config["ml_model"] = ENV["ML_MODEL"]
    config["iot_registry"] = ENV["IOT_REGISTRY"]
    config["score_threshold"] = ENV["SCORE_THRESHOLD"]
  end
  $stdout.sync = true
  $stderr.sync = true
  main(config)
end
