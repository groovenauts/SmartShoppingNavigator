import os
from flask import  Flask, request, render_template, Response

app = Flask(__name__)

@app.route("/")
def index():
    title = "IoST Demo"
    if os.access("/tmp/dashboard_url", os.R_OK):
        with open("/tmp/dashboard_url", "r") as f:
            url = f.readline().rstrip()
    else:
        url = "https://www.magellanic-clouds.com/"
    return render_template("index.html",
            url=url, title=title)

@app.route("/url")
def url():
    if os.access("/tmp/dashboard_url", os.R_OK):
        with open("/tmp/dashboard_url", "r") as f:
            url = f.readline().rstrip()
    else:
        url = "https://www.magellanic-clouds.com/"
    r = Response(response=url, status=200)
    r.headers["Content-Type"] = "text/plain"
    return r

if __name__ == "__main__":
    app.debug = True
    app.run(host="localhost")
