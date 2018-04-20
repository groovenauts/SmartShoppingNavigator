# IoST demo (Raspberry Pi)

## Setup Raspberry Pi for IoST demo

### Requirements

- Raspberry Pi 3 Model B
- SD Card (more than 8GB)
- Raspberry Pi Wide Angle Camera Module ([SEEED-114990838](https://www.seeedstudio.com/Raspberry-Pi-Wide-Angle-Camera-Module-p-2774.html))
- HyperPixel ([3.5" Hi-Res Display for Raspberry Pi](https://shop.pimoroni.com/products/hyperpixel))

### Setup Raspberry Pi

See [public documentation](https://www.raspberrypi.org/documentation/setup/) for details about setup Raspberry Pi in general.

IoST Demo applications are designed to work on Rasbian stretch with Desktop.

1. Download novel rasbian image file with desktop from https://www.raspberrypi.org/downloads/raspbian/
2. Install operating system image to SD card. See https://www.raspberrypi.org/documentation/installation/installing-images/
3. run `raspi-config` to setup network settings (if you want to use Wi-Fi), hostname, change password etc...
4. Update packages. `apt-get update && apt-get upgrade`.
5. Install some required packages. `apt-get install unclutter`.

### Setup Raspberry Pi devices

#### Camera

1. Enable camera module by `raspi-config` command. See [Camera configuration](https://www.raspberrypi.org/documentation/configuration/camera.md) for more details.
2. Connect camera module by FFC (Flexible Flat Cable).

#### HyperPixel

1. Insert HyperPixel into GPIO port.
2. Follow instructions in [HyperPixel driver](https://github.com/pimoroni/hyperpixel)

### Install IoST demo applications

#### Copy files to Raspberry Pi.

```
$ git clone https://github.com/groovenauts/iost-demo.git
$ cd iost-demo/raspberrypi/files
$ rsync -auz home/pi/ /home/pi/
$ sudo rsync -auz etc/ /etc/
```

#### Create device in Cloud IoT Core

The corresponding `device` resource should be created in [Cloud IoT Core](https://cloud.google.com/iot-core/).
Please read [Creating Registries and Devices](https://cloud.google.com/iot/docs/how-tos/devices) for details.

During creating device in Cloud IoT Core, you should [create device key paire](https://cloud.google.com/iot/docs/how-tos/credentials/keys) to authenticate the device.
IoST demo applications support only ES256 key.
Please generate ES256 key pair.

And copy private key file to Raspberry Pi as `/home/pi/ec_private.pem`.

#### Create config file

Edit `/home/pi/watchdog.conf` to specify the GCP project, Cloud IoT registry/device.

#### Enable services

```
$ sudo systemctl enable capture
$ sudo systemctl enable dashboard
