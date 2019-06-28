package main

import (
	"context"
	"encoding/json"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"cloud.google.com/go/datastore"
	"golang.org/x/oauth2/google"
)

const DefaultSeason = "spring"
const DefaultPeriod = "morning"
const DefaultDeviceId = "picamera02"

var projectID string

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
	Setting     Setting
	ImageBucket string
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
	ReadyToGo    bool
}

type cartImageTemplateParams struct {
	DeviceId    string
	ImageBucket string
}

func getImageBucket() string {
	s := os.Getenv("IMAGE_BUCKET")
	if s == "" {
		s = "gcp-iost-images"
	}
	return s
}

func getSetting(ctx context.Context) (*datastore.Key, *Setting, error) {
	client, e := datastore.NewClient(ctx, projectID)
	if e != nil {
		return nil, nil, e
	}
	key := datastore.NameKey("Setting", "master", nil)
	setting := new(Setting)
	e = client.Get(ctx, key, setting)
	if e != nil {
		if e.Error() == "datastore: no such entity" || strings.Index(e.Error(), "no such struct field") >= 0 {
			e = nil
		}
		return nil, nil, e
	}
	return key, setting, nil
}

func getDevice(ctx context.Context, deviceId string) (*datastore.Key, *Device, error) {
	client, e := datastore.NewClient(ctx, projectID)
	if e != nil {
		return nil, nil, e
	}
	key := datastore.NameKey("Device", deviceId, nil)
	device := new(Device)
	e = client.Get(ctx, key, device)
	if e != nil {
		if e.Error() == "datastore: no such entity" {
			e = nil
		}
		return nil, nil, e
	}
	return key, device, nil
}

func getItem(ctx context.Context, name string) (*datastore.Key, *Item, error) {
	client, e := datastore.NewClient(ctx, projectID)
	if e != nil {
		return nil, nil, e
	}
	key := datastore.NameKey("Item", name, nil)
	item := new(Item)
	e = client.Get(ctx, key, item)
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
	ctx := r.Context()
	indexTemplate := template.Must(template.ParseFiles("index.html"))
	params := indexTemplateParams{}
	_, setting, e := getSetting(ctx)
	if e != nil {
		log.Printf("Failed to get setting: %v", e)
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
	params.ImageBucket = getImageBucket()
	indexTemplate.Execute(w, params)
	return
}

func settingHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	client, e := datastore.NewClient(ctx, projectID)
	if e != nil {
		log.Printf("Connecting Datastore: %v", e)
		return
	}
	key, setting, e := getSetting(ctx)
	if e != nil {
		log.Printf("Getting settings: %v", e)
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprint(w, "Getting setting failed: ", e)
		return
	}
	if setting == nil {
		// Generate initial setting
		key = datastore.NameKey("Setting", "master", nil)
		setting = new(Setting)
		setting.Season = DefaultSeason
		setting.Period = DefaultPeriod
		setting.DeviceId = DefaultDeviceId
		if _, e := client.Put(ctx, key, setting); e != nil {
			log.Printf("Failed to put setting: %v", e)
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
	if _, err := client.Put(ctx, key, setting); err != nil {
		log.Printf("Failed to put setting : %v", err)
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprint(w, "Failed to put setting : ", err)
		return
	}
	http.Redirect(w, r, "/", http.StatusFound)
	return
}

func getDeviceHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
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
	ctx := r.Context()
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
		items = []string{"{\"title\":\"Healthy salad\", \"missingItems\":\"carrot,paprika,tomato\", \"key\":\"bowl-bright-close-up-248509\"}"}
	}
	log.Printf("Recommendation for device(%v) is %v", deviceId, items)

	recommends := make([]Recommend, len(items))
	for i := 0; i < len(items); i++ {
		if e := json.Unmarshal([]byte(items[i]), &recommends[i]); e != nil {
			log.Printf("Failed to parse JSON %v: %v", items[i], e)
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
	ctx := r.Context()
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
				Location: "A1",
			}
		}
	}

	params := slideTemplateParams{
		Item:         item,
		Title:        title,
		ShowDetail:   len(missing) > 0,
		MissingItems: missingDetails,
		ReadyToGo:    (len(missing) == 0) && (item != "supermarket"),
	}
	template := template.Must(template.ParseFiles("slide.html"))
	template.Execute(w, params)
	return
}

func cartImageHandler(w http.ResponseWriter, r *http.Request) {
	cartImageTemplate := template.Must(template.ParseFiles("cartImage.html"))
	params := cartImageTemplateParams{}
	params.DeviceId = r.FormValue("deviceId")
	params.ImageBucket = getImageBucket()
	cartImageTemplate.Execute(w, params)
	return
}

func main() {
	http.HandleFunc("/", indexHandler)
	http.HandleFunc("/setting", settingHandler)
	http.HandleFunc("/device", getDeviceHandler)
	http.HandleFunc("/display", displayByDeviceHandler)
	http.HandleFunc("/displayByDevice", displayByDeviceHandler)
	http.HandleFunc("/slide", slideHandler)
	http.HandleFunc("/cartImage", cartImageHandler)

	credentials, e := google.FindDefaultCredentials(context.Background())
	if e != nil {
		log.Fatal(e)
	}

	projectID = credentials.ProjectID

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
		log.Printf("Defaulting to port %s", port)
	}

	log.Printf("Listening on port %s", port)
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%s", port), nil))
}
