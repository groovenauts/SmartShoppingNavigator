import sys
import time
import base64
import json
import datetime
import jwt
import requests
import picamera

def create_jwt(project_id, private_key_file, algorithm):
    """Creates a JWT (https://jwt.io) to establish an MQTT connection.
        Args:
         project_id: The cloud project ID this device belongs to
         private_key_file: A path to a file containing either an RSA256 or
                 ES256 private key.
         algorithm: The encryption algorithm to use. Either 'RS256' or 'ES256'
        Returns:
            An MQTT generated from the given project_id and private key, which
            expires in 20 minutes. After 20 minutes, your client will be
            disconnected, and a new JWT will have to be generated.
        Raises:
            ValueError: If the private_key_file does not contain a known key.
        """

    token = {
            # The time that the token was issued at
            'iat': datetime.datetime.utcnow(),
            # The time the token expires.
            'exp': datetime.datetime.utcnow() + datetime.timedelta(minutes=60),
            # The audience field should always be set to the GCP project id.
            'aud': project_id
    }

    # Read the private key file.
    with open(private_key_file, 'r') as f:
        private_key = f.read()

    return jwt.encode(token, private_key, algorithm=algorithm).decode("utf-8")

def capture(camera):
    file = "/tmp/image.jpg"
    camera.capture(file)
    with open(file, "rb") as f:
        buf = f.read()
    buf = base64.urlsafe_b64encode(buf)
    return buf.decode("utf-8")

def upload_image(project_id, location, registry, device, jwt, b64_buf):
    headers = {
            "Authorization": "Bearer {}".format(jwt),
            "Content-Type" : "application/json",
            "Cache-Control": "no-cache"
            }
    url = "https://cloudiotdevice.googleapis.com/v1/projects/{}/locations/{}/registries/{}/devices/{}:publishEvent".format(project_id, location, registry, device)
    data = { "binaryData": b64_buf }
    data = json.dumps(data).encode("utf-8")
    res = requests.post(url, data=data, headers=headers)
    print("POST HTTP Code={}".format(res.status_code))
    if res.status_code != 200:
        print(res.json())

def capture_and_upload(camera, project_id, location, registry, device, private_key):
    buf = capture(camera)
    jwt = create_jwt(project_id, private_key, "ES256")
    upload_image(project_id, location, registry, device, jwt, buf)

def get_config(
        version, base_url, project_id, cloud_region, registry_id,
        device_id, private_key):
    jwt = create_jwt(project_id, private_key, "ES256")
    headers = {
            'authorization': 'Bearer {}'.format(jwt),
            'content-type': 'application/json',
            'cache-control': 'no-cache'
    }

    basepath = '{}/projects/{}/locations/{}/registries/{}/devices/{}/'
    template = basepath + 'config?local_version={}'
    config_url = template.format(
        base_url, project_id, cloud_region, registry_id, device_id, version)

    resp = requests.get(config_url, headers=headers)

    if (resp.status_code != 200):
        print('Error getting config: {}, retrying'.format(resp.status_code))
        raise AssertionError('Not OK response: {}'.format(resp.status_code))

    return resp

def main(argv):
    _, project_id, location, registry, device, private_key = argv

    camera = picamera.PiCamera()
    camera.brightness = 60
    camera.hflip = False
    camera.vflip = False

    version = "0"
    config_interval = 1
    capture_interval = 60
    last_captured_at = time.time()

    while True:
        res = get_config(
                version, "https://cloudiotdevice.googleapis.com/v1",
                project_id, location, registry, device, private_key)
        res = res.json()
        if version != res["version"]:
            version = res["version"]
            binary = res["binaryData"]
            buf = base64.urlsafe_b64decode(binary).decode("utf-8")
            print("Configuration update: {}".format(buf))
            config = json.loads(buf)
            config_interval = config.get("config_interval", 1)
            capture_interval = config.get("capture_interval", 60)
            camera.hflip = config.get("camera_hflip", False)
            camera.vflip = config.get("camera_vflip", False)
            camera.brightness = config.get("camera_brightness", 60)
            camera.sharpness = config.get("camera_sharpness", 0)
            camera.contrast = config.get("camera_contrast", 0)
            camera.iso = config.get("camera_iso", 0)
        if time.time() - last_captured_at > capture_interval:
            capture_and_upload(camera, project_id, location, registry, device, private_key)
            print("Still image captured.")
            last_captured_at = time.time()
        time.sleep(config_interval)

main(sys.argv)
