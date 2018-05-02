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

  def get_object_content(gcs_url)
    uri = URI(gcs_url)
    bucket = uri.host
    name = uri.path.sub(/\A\/*/, "")
    buf = StringIO.new
    @api.get_object(bucket, name, download_dest: buf)
    buf.string
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
  def initialize(project_id)
    @dataset = Google::Cloud::Datastore.new(project_id: project_id)
  end

  def get_setting
    query = Google::Cloud::Datastore::Query.new
    query.kind("Setting")
    query.limit(1)
    setting = @dataset.run(query).first
    setting&.properties&.to_hash or { "season" => "Spring", "period" => "Morning" }
  end

  def get_cart(device)
    entities = @dataset.lookup(Google::Cloud::Datastore::Key.new("Cart", device))
    e = entities.first
    return [[]] if e.nil?
    JSON.parse(e.properties["history"] || "[[]]")
  end

  def put_cart(device, history)
    entity = Google::Cloud::Datastore::Entity.new
    entity.key = Google::Cloud::Datastore::Key.new("Cart", device)
    entity["history"] = JSON.generate(history)
    @dataset.save(entity)
  end

  def get_device(device)
    entities = @dataset.lookup(Google::Cloud::Datastore::Key.new("Device", device))
    e = entities.first
    return [{}] if e.nil?
    e.properties.to_hash
  end

  def put_device(device, objs, recommends)
    entity = Google::Cloud::Datastore::Entity.new
    entity.key = Google::Cloud::Datastore::Key.new("Device", device)
    entity["deviceId"] = device
    entity["unixtime"] = Time.now.to_i
    entity["objects"] = objs
    entity["recommends"] = recommends.map{|i| JSON.generate(i) }
    @dataset.save(entity)
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
    http.read_timeout = 600
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
  rescue Net::ReadTimeout
    $stdout.puts "ML Engine online prediction connection timoout. retry"
    retry
  end
end

LABELS = {
  1 => "onion",
  2 => "tomato",
  3 => "potato",
  4 => "paprika",
  5 => "eggplant",
  6 => "beef",
  7 => "pork",
  8 => "chicken",
  9 => "banana",
  10 => "corn",
}

def label_to_name(label_id)
  LABELS[label_id.to_i]
end

def name_to_label(name)
  LABELS.find{|i, n| n == name }[0]
end

WelcomeDisplay = { "key" => "supermarket", "title" => "Smart Shopping Cart", "missingItems" => "" }

def items_to_recipes(all_recipes, objs, key_item)
  original_objs = objs.dup
  recipes = []
  if key_item
    recipes = all_recipes.select{|_, _, _, items, _, _|
      (items & (objs | [key_item])).size == (objs | [key_item]).size
    }
  end
  if recipes.empty?
    recipes = all_recipes.select{|_, _, _, items, _, _|
      (items & objs).size == objs.size
    }
  end
  if recipes.empty?
    recipes = all_recipes.select{|_, _, _, items, _, _|
      (items & objs).size == items.size
    }
  end
  if recipes.empty?
    [WelcomeDisplay]
  else
    recipes.map{|name, all_items, label, items, season, period|
      {
        "title" => name,
        "missingItems" => (all_items.split(",") - original_objs).join(","),
        "key" => label,
      }
    }
  end
end

def recipes_to_url(base_url, device, recipes)
  base_url + "?" + URI.encode_www_form([["deviceId", device]] + recipes.map{|u| ["contents", u["key"]] })
end

def draw_bbox_image(b64_image, predictions, time, threshold=0.5)
  original = Magick::Image.read_inline(b64_image)[0]
  width = original.columns
  height = original.rows
  nega = original.negate
  mask = Magick::Image.new(width, height) { self.background_color = "none" }
  gc = Magick::Draw.new
  gc.stroke_color("white")
  gc.fill_color("white")
  gc.fill_opacity(0)
  gc.stroke_width(1)
  gc.text_align(Magick::LeftAlign)
  gc.font = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
  gc.pointsize = 21
  rec = predictions
  rec["detection_scores"].each_with_index do |score, idx|
    break if score < threshold
    label = label_to_name(rec["detection_classes"][idx]) || "none"
    # MEMO: Remove paprika from detected objects
    #       Because current model tend to detect false positive for paprika under the lighting eveironment of warm colors.
    next if label == "none" or label == "paprika"
    xmin = (rec["detection_box_xmin"][idx] * width).to_i
    ymin = (rec["detection_box_ymin"][idx] * height).to_i
    xmax = (rec["detection_box_xmax"][idx] * width).to_i
    ymax = (rec["detection_box_ymax"][idx] * height).to_i
    gc.fill_opacity(0)
    gc.rectangle(xmin, ymin, xmax, ymax)
    gc.fill_opacity(1)
    gc.text(xmin+2, ymin+12, label)
  end
  gc.annotate(mask, 0, 0, 5, 5, time.strftime("%Y-%m-%d %H:%M:%S")) do
    self.fill = "white"
    self.pointsize = 16
    self.gravity = Magick::SouthEastGravity
  end
  gc.draw(mask)
  bbox = mask.composite(nega, 0, 0, Magick::SrcInCompositeOp)
  bbox = mask
  result = original.composite(bbox, 0, 0, Magick::OverCompositeOp)
  result.to_blob
end

def encode_cart_history_to_vector(history)
  until history.size >= 4
    history.unshift([])
  end
  history = history[-4, 4]
  history.map{|items| LABELS.map{|_, name| items.include?(name) ? 1 : 0 } }
end

def predict_next(project, model, history, setting)
  pred = ML.predict(project, model, [{"key" => "1", "cart_history" => encode_cart_history_to_vector(history), "season" => setting["season"], "period" => setting["period"] }])
  scores = pred[0]["score"]
  if setting["recommend"]
    idx = name_to_label(setting["recommend"]["label"])
    scores[idx] += setting["recommend"]["amount"] || 0.2
  end
  idx = scores.index(scores.max)
  if idx == 0
    "end"
  else
    LABELS[idx]
  end
end

def main(config)
  project = config["project"]
  input_subscription = config["input_subscription"]
  bucket = config["bucket"]
  ml_model = config["ml_model"]
  iot_registry = config["iot_registry"]
  threshold = (config["score_threshold"] || 0.2).to_f
  recipes_yaml = config["recipes_yaml"]
  $stdout.puts "PubSub:#{input_subscription} -> ML Engine -> GCS(gs://#{bucket}/) & BigQuery"
  $stdout.puts "project = #{project}"
  $stdout.puts "subscription = #{input_subscription}"
  $stdout.puts "bucket = #{bucket}"
  $stdout.puts "ml_model = #{ml_model}"
  $stdout.puts "iot_registry = #{iot_registry}"
  $stdout.puts "recipes_yaml = #{recipes_yaml}"
  pubsub = Pubsub.new
  gcs = GCS.new
  iot = CloudIot.new
  datastore = Datastore.new(project)
  all_recipes_yaml = gcs.get_object_content(recipes_yaml)
  all_recipes = YAML.load(all_recipes_yaml)

  loop do
    msgs = pubsub.pull(input_subscription)
    $stdout.puts "#{msgs.size} messages pulled."
    next if msgs.empty?
    msgs.each do |m|
      device = m.message.attributes["deviceId"]
      $stdout.puts "Device: #{device}"
      # Store original image to GCS
      time = Time.parse(m.message.publish_time)
      obj_name = time.strftime("original/#{device}/%Y-%m-%d/%H/%Y%m%d_%H%M%S.jpg")
      gcs.insert_object(bucket, obj_name, StringIO.new(m.message.data))
      gcs.copy_object(bucket, obj_name, bucket, "original/#{device}/original.jpg", Google::Apis::StorageV1::Object.new(cache_control: "no-store", content_type: "image_jpeg"), "publicRead")
      # Load Device config
      last_config = iot.list_device_configs(project, "us-central1", iot_registry, device).first
      data = JSON.parse(last_config.binary_data)
      b64_image = Base64.strict_encode64(m.message.data)
      # Object Detection prediction
      $stdout.puts("start object detection")
      pred = ML.predict(project, ml_model, [{"key" => "1", "image" => { "b64" => b64_image } }])
      $stdout.puts("finished object detection")
      objs = pred[0]["detection_classes"].zip(pred[0]["detection_scores"]).select{|label, score| score > threshold}.map{|label, score| [LABELS[label.to_i], score] }
      $stdout.puts("detected items: #{objs.inspect}")
      objs = objs.map{|o| o[0] }.compact.uniq.sort

      # MEMO: Remove paprika from detected objects
      #       Because current model tend to detect false positive for paprika under the lighting eveironment of warm colors.
      objs -= ["paprika"]

      # create bounding box image
      th = Thread.start(device, b64_image, pred.first, time) do |dev, img, p, t|
        annotated = t.strftime("annotated/#{device}/%Y-%m-%d/%H/%Y%m%d_%H%M%S.jpg")
        bboxed_image = draw_bbox_image(img, p, t, config["score_threshold"])
        gcs.insert_object(bucket, annotated, StringIO.new(bboxed_image), content_type: "image/jpeg")
        gcs.copy_object(bucket, annotated, bucket, "annotated/#{dev}/annotated.jpg", Google::Apis::StorageV1::Object.new(cache_control: "no-store", content_type: "image_jpeg"), "publicRead")
      end

      history = datastore.get_cart(device)
      if history.last != objs
        $stdout.puts("cart contents changed. #{history.inspect} -> #{objs}")
        if objs.empty?
          # reset cart
          $stdout.puts("reset cart")
          datastore.put_cart(device, [[]])
          recipes = [WelcomeDisplay]
          datastore.put_device(device, objs, recipes)
          url = recipes_to_url(config["display_base_url"], device, recipes)
        else
          # new item
          history << objs
          $stdout.puts("store new cart status")
          datastore.put_cart(device, history)
          $stdout.puts("start predict next item")
          setting = datastore.get_setting
          next_item = predict_next(project, config["bucket_prediction_model"], history, setting)
          $stdout.puts("finish predict next item")
          $stdout.puts("predicted next item = #{next_item}")
          if next_item != "end"
            key_item = next_item
          end
          recipes = items_to_recipes(all_recipes, objs, key_item)
          datastore.put_device(device, objs, recipes)
          url = recipes_to_url(config["display_base_url"], device, recipes)
        end
        if data["dashboard_url"] != url
          $stdout.puts("URL change to #{url}")
          data["dashboard_url"] = url
          iot.modify_device_config(project, "us-central1", iot_registry, device, data.to_json)
        end
      else
        $stdout.puts "Cart status not changed"
      end

      th.join
    end
    pubsub.ack(input_subscription, msgs)
  end
end

if $0 == __FILE__
  config, = ARGV

  if config
    config = YAML.load(File.read(config))
    config["input_subscription"] = "projects/#{config["project"]}/subscriptions/#{config["input_subscription"]}"
    config["display_base_url"] ||= "https://gcp-iost.appspot.com/display"
    config["recipes_yaml"] ||= "gs://gcp-iost-contents/recipes.yaml"
  else
    config = {}
    config["project"] = ENV["PROJECT"]
    config["input_subscription"] = "projects/#{config["project"]}/subscriptions/#{ENV["INPUT_SUBSCRIPTION"]}"
    config["bucket"] = ENV["SAVE_BUCKET"]
    config["ml_model"] = ENV["ML_MODEL"]
    config["bucket_prediction_model"] = ENV["BUCKET_PREDICTION_MODEL"]
    config["iot_registry"] = ENV["IOT_REGISTRY"]
    config["score_threshold"] = Float(ENV["SCORE_THRESHOLD"] || 0.5)
    config["display_base_url"] = ENV["DISPLAY_BASE_URL"] || "https://gcp-iost.appspot.com/display"
    config["recipes_yaml"] = ENV["RECIPES_YAML"] || "gs://gcp-iost-contents/recipes.yaml"
  end
  $stdout.sync = true
  $stderr.sync = true
  main(config)
end
