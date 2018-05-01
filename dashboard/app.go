package dashboard

import (
	"context"
	"encoding/json"
	"fmt"
	"html/template"
	"net/http"
	"strings"
	"time"

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

type Recommend struct {
	Title        string `json:"title"`
	Key          string `json:"key"`
	MissingItems string `json:"missingItems"`
}

type Item struct {
	Name     string `json:"name" datastore:"name"`
	Price    string `json:"price" datastore:"price"`
	Location string `json:"location" datastore:"location"`
}

type indexTemplateParams struct {
	Setting Setting
}

type displayTemplateParams struct {
	Recommends []Recommend
	Timestamp  string
	Loop       bool
}

type slideTemplateParams struct {
	Item         string
	Title        string
	ShowDetail   bool
	MissingItems []Item
}

func init() {
	http.HandleFunc("/", indexHandler)
	http.HandleFunc("/setting", settingHandler)
	http.HandleFunc("/device", getDeviceHandler)
	http.HandleFunc("/display", displayByDeviceHandler)
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

func getItem(ctx context.Context, name string) (*datastore.Key, *Item, error) {
	key := datastore.NewKey(ctx, "Item", name, 0, nil)
	item := new(Item)
	e := datastore.Get(ctx, key, item)
	if e != nil {
		if e.Error() == "datastore: no such entity" {
			e = nil
		}
		return nil, nil, e
	}
	return key, item, nil
}

func indexHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.Redirect(w, r, "/", http.StatusFound)
		return
	}
	ctx := appengine.NewContext(r)
	indexTemplate := template.Must(template.ParseFiles("index.html"))
	params := indexTemplateParams{}
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
	setting.DeviceId = r.FormValue("deviceId")
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

func getDeviceHandler(w http.ResponseWriter, r *http.Request) {
	ctx := appengine.NewContext(r)
	deviceId := r.FormValue("deviceId")
	if deviceId == "" {
		deviceId = DefaultDeviceId
	}
	_, device, e := getDevice(ctx, deviceId)
	if e != nil {
		fmt.Fprint(w, "{\"error\":\"failed to get device information.\"}")
		return
	}
	j, e := json.Marshal(device)
	if e != nil {
		fmt.Fprint(w, "Fail to encode to JSON.")
		return
	}
	fmt.Fprint(w, string(j))
	return
}

func displayByDeviceHandler(w http.ResponseWriter, r *http.Request) {
	ctx := appengine.NewContext(r)
	deviceId := r.FormValue("deviceId")
	if deviceId == "" {
		deviceId = DefaultDeviceId
	}
	_, device, e := getDevice(ctx, deviceId)
	var items []string
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	if e == nil && device != nil && device.Recommends != nil {
		items = device.Recommends
		timestamp = time.Unix(device.Unixtime, 0).Format("2006-01-02 15:04:05")
	} else {
		//items = []string{"supermarket"}
		items = []string{"{\"title\":\"Healthy salad\", \"missingItems\":\"carrot\", \"key\":\"bowl-bright-close-up-248509\"}"}
	}
	log.Infof(ctx, "Recommendation for device(%v) is %v", deviceId, items)

	recommends := make([]Recommend, len(items))
	for i := 0; i < len(items); i++ {
		if e := json.Unmarshal([]byte(items[i]), &recommends[i]); e != nil {
			log.Errorf(ctx, "Failed to parse JSON %v: %v", items[i], e)
		}
	}
	params := displayTemplateParams{
		Recommends: recommends,
		Timestamp:  timestamp,
		Loop:       len(items) > 1,
	}
	template := template.Must(template.ParseFiles("display.html"))
	template.Execute(w, params)
	return
}

func slideHandler(w http.ResponseWriter, r *http.Request) {
	ctx := appengine.NewContext(r)
	item := r.FormValue("item")
	title := r.FormValue("title")
	missing := r.FormValue("missingItems")
	missingItems := []string{}
	if len(missing) > 0 {
		missingItems = strings.Split(missing, ",")
	}
	missingDetails := make([]Item, len(missingItems))
	for i := 0; i < len(missingItems); i++ {
		_, detail, e := getItem(ctx, missingItems[i])
		if e == nil && detail != nil {
			missingDetails[i] = *detail
		} else {
			missingDetails[i] = Item{
				Name:     missingItems[i],
				Price:    "$1.5",
				Location: "section A1",
			}
		}
	}

	params := slideTemplateParams{
		Item:         item,
		Title:        title,
		ShowDetail:   len(missing) > 0,
		MissingItems: missingDetails,
	}
	template := template.Must(template.ParseFiles("slide.html"))
	template.Execute(w, params)
	return
}
