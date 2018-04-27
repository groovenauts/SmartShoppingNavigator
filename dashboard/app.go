package dashboard

import (
	"context"
	"encoding/json"
	"fmt"
	"html/template"
	"net/http"
	"net/url"

	"google.golang.org/appengine"
	"google.golang.org/appengine/datastore"
	"google.golang.org/appengine/log"
)

const DefaultSeason = "spring"
const DefaultPeriod = "morning"
const DefaultDeviceId = "picamera01"

type Setting struct {
	Season   string `json:"season" datastore:"season"`
	Period   string `json:"period" datastore:"period"`
	DeviceId string `json:"deviceId" datastore:"deviceId"`
}

type Device struct {
	DeviceId   string   `json:"deviceId" datastore:"deviceId"`
	Unixtime   int64    `json:"unixtime" datastore:"unixtime"`
	Objects    []string `json:"objects" datastore:"objects"`
	Recommends []string `json:"recommends" datastore:"recommends"`
}

type templateParams struct {
	Setting  Setting
	DeviceId string
}

func init() {
	http.HandleFunc("/", indexHandler)
	http.HandleFunc("/setting", settingHandler)
	http.HandleFunc("/display", displayHandler)
	http.HandleFunc("/displayByDevice", displayByDeviceHandler)
	http.HandleFunc("/slide", slideHandler)
}

func getSetting(ctx context.Context) (*datastore.Key, *Setting, error) {
	key := datastore.NewKey(ctx, "Setting", "master", 0, nil)
	setting := new(Setting)
	e := datastore.Get(ctx, key, setting)
	if e != nil {
		if e.Error() == "datastore: no such entity" {
			e = nil
		}
		return nil, nil, e
	}
	return key, setting, nil
}

func getDevice(ctx context.Context, deviceId string) (*datastore.Key, *Device, error) {
	key := datastore.NewKey(ctx, "Device", deviceId, 0, nil)
	device := new(Device)
	e := datastore.Get(ctx, key, device)
	if e != nil {
		if e.Error() == "datastore: no such entity" {
			e = nil
		}
		return nil, nil, e
	}
	return key, device, nil
}

func indexHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.Redirect(w, r, "/", http.StatusFound)
		return
	}
	ctx := appengine.NewContext(r)
	indexTemplate := template.Must(template.ParseFiles("index.html"))
	params := templateParams{}
	_, setting, e := getSetting(ctx)
	if e != nil {
		log.Errorf(ctx, "Failed to get setting: %v", e)
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprint(w, "Failed to get setting: ", e)
		return
	}
	if setting != nil {
		params.Setting = *setting
	} else {
		params.Setting.Season = DefaultSeason
		params.Setting.Period = DefaultPeriod
		params.Setting.DeviceId = DefaultDeviceId
	}
	indexTemplate.Execute(w, params)
	return
}

func settingHandler(w http.ResponseWriter, r *http.Request) {
	ctx := appengine.NewContext(r)
	key, setting, e := getSetting(ctx)
	if e != nil {
		log.Errorf(ctx, "Getting settings: %v", e)
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprint(w, "Getting setting failed: ", e)
		return
	}
	if setting == nil {
		// Generate initial setting
		key = datastore.NewKey(ctx, "Setting", "master", 0, nil)
		setting = new(Setting)
		setting.Season = DefaultSeason
		setting.Period = DefaultPeriod
		setting.DeviceId = DefaultDeviceId
		if _, e := datastore.Put(ctx, key, setting); e != nil {
			log.Errorf(ctx, "Failed to put setting: %v", e)
			w.WriteHeader(http.StatusInternalServerError)
			fmt.Fprint(w, "Failed to put setting: ", e)
			return
		}
	}
	if r.Method == "GET" {
		j, e := json.Marshal(setting)
		if e != nil {
			fmt.Fprint(w, "Fail to encode to JSON.")
			return
		}
		fmt.Fprint(w, string(j))
		return
	}
	setting = new(Setting)
	setting.Season = r.FormValue("season")
	if setting.Season == "" {
		setting.Season = DefaultSeason
	}
	setting.Period = r.FormValue("period")
	if setting.Period == "" {
		setting.Period = DefaultPeriod
	}
	if setting.DeviceId == "" {
		setting.DeviceId = DefaultDeviceId
	}
	if _, err := datastore.Put(ctx, key, setting); err != nil {
		log.Errorf(ctx, "Failed to put setting : %v", err)
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprint(w, "Failed to put setting : ", err)
		return
	}
	http.Redirect(w, r, "/", http.StatusFound)
	return
}

func displayHandler(w http.ResponseWriter, r *http.Request) {
	ctx := appengine.NewContext(r)
	params, e := url.ParseQuery(r.URL.RawQuery)
	stuffs := []string{}
	if e != nil {
		log.Errorf(ctx, "Parse query failed: %v", e)
	} else {
		stuffs = params["contents"]
	}

	template := template.Must(template.ParseFiles("display.html"))
	template.Execute(w, stuffs)
	return
}

func displayByDeviceHandler(w http.ResponseWriter, r *http.Request) {
	ctx := appengine.NewContext(r)
	deviceId := r.FormValue("deivceId")
	if deviceId == "" {
		deviceId = DefaultDeviceId
	}
	_, device, e := getDevice(ctx, deviceId)
	var stuffs []string
	if e == nil {
		stuffs = device.Recommends
	} else {
		stuffs = []string{}
	}
	log.Infof(ctx, "Recommendation for device(%v) is %v", deviceId, stuffs)
	template := template.Must(template.ParseFiles("display.html"))
	template.Execute(w, stuffs)
	return
}

func slideHandler(w http.ResponseWriter, r *http.Request) {
	stuff := r.FormValue("stuff")
	template := template.Must(template.ParseFiles("slide.html"))
	template.Execute(w, stuff)
	return
}
