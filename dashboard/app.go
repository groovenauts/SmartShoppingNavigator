package dashboard

import (
	"context"
	"encoding/json"
	"fmt"
	"html/template"
	"net/http"

	"google.golang.org/appengine"
	"google.golang.org/appengine/datastore"
	"google.golang.org/appengine/log"
)

type Setting struct {
	Season string `json:"season" datastore:"season"`
	Period string `json:"period" datastore:"period"`
}

type templateParams struct {
	Setting Setting
}

func init() {
	http.HandleFunc("/", indexHandler)
	http.HandleFunc("/setting", settingHandler)
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
		params.Setting.Season = "spring"
		params.Setting.Period = "morning"
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
		setting.Season = "spring"
		setting.Period = "morning"
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
	setting.Period = r.FormValue("period")
	if _, err := datastore.Put(ctx, key, setting); err != nil {
		log.Errorf(ctx, "Failed to put setting : %v", err)
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprint(w, "Failed to put setting : ", err)
		return
	}
	http.Redirect(w, r, "/", http.StatusFound)
	return
}
