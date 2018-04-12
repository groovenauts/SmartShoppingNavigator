import sys
import base64
import json
import urllib.request
import datetime
import picamera
import jwt

def capture():
    camera = picamera.PiCamera()
    camera.brightness = 60
    camera.hflip = False
    camera.vflip = False

    file = "/tmp/image.jpg"
    camera.capture(file)
    with open(file, "rb") as f:
        buf = f.read()
    buf = base64.urlsafe_b64encode(buf)
    return buf.decode("utf-8")

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

    print('Creating JWT using {} from private key file {}'.format(
            algorithm, private_key_file))

    return jwt.encode(token, private_key, algorithm=algorithm).decode("utf-8")

cmd, project_id, location, registry, device, private_key = sys.argv

b64_buf = capture()

jwt = create_jwt(project_id, private_key, "ES256")

headers = {
        "Authorization": "Bearer {}".format(jwt),
        "Content-Type" : "application/json",
        "Cache-Control": "no-cache"
        }
url = "https://cloudiotdevice.googleapis.com/v1/projects/{}/locations/{}/registries/{}/devices/{}:publishEvent".format(project_id, location, registry, device)
data = {
        "binaryData": b64_buf
        }
data = json.dumps(data).encode("utf-8")
req = urllib.request.Request(url, data=data, headers=headers, method="POST")
with urllib.request.urlopen(req) as res:
    print("HTTP Code={}".format(res.getcode()))
    if res.getcode() != 200:
        print(res.read().decode("utf-8"))
