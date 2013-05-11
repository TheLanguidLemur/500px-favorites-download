_ = require 'lodash'
http = require 'http'
util = require 'util'
async = require 'async'
images = require 'http-get'
path = require 'path'
fs = require 'fs'

[username, savePath] = ["z0rch", "D:\\Dropbox\\Photos\\500px favorites"]
[fetchedPages, totalPages, photos, total] = [0, null, [], 0]

start = ->
    unless fs.existsSync savePath
        return console.log "Destination path does not exists, please check configuration"

    process = (callback) -> async.waterfall [
        fetch
        parse
        findLinks
        download
    ], callback

    predicate = -> fetchedPages is totalPages

    async.doUntil process, predicate, -> util.debug "#{total} new images downloaded."


makeOptions = (page) ->
    options =
        host: "500px.com"
        path: "/#{username}/favorites?nolayout=true&page=#{page}"
        headers:
            Accept: "application/json"

fetch = (callback) ->
    [response, options] = ["", makeOptions fetchedPages + 1]

    req = http.get options, (res) ->
        res.on "data", (chunk) -> response += chunk.toString()
        res.on "end", -> callback null, response

    req.on "error", _.partialRight "Fetching error", callback


parse = (response, callback) ->
    try
        data = JSON.parse response
        photos = photos.concat data.items
        totalPages = data.total_pages

        fetchedPages++
        util.debug "Parsed page ##{fetchedPages} out of #{totalPages}"
        callback null, photos

    catch err
        handle err, "Parsing error", callback


findLinks = (photos, callback) ->
    callback null, _.map photos, (value, key, list) ->
        regex = /<img.*?src=['"](.*?)['"]/gm
        url = (regex.exec value.html)[1]
        id: value.id.toString(), url: url.replace /\d\.jpg$/, "5.jpg"


download = (links, callback) ->
    async.each links, (img, downloaded) ->
        fileName = path.join(savePath, img.id) + ".jpg"
        return downloaded null if fs.existsSync fileName

        images.get img.url, fileName, (err, result) ->
            if err? then return fetchNude img, downloaded
            total++
            downloaded null
    , callback

fetchNude = (img, callback) ->
    response = ""

    req = http.get "http://500px.com/photo/#{img.id}", (res) ->
        res.on "data", (chunk) -> response += chunk.toString()
        res.on "end", ->
            try
                regex = /['"](.*?\d\.jpg)['"]/gm
                img.url = (regex.exec response)[1].replace /\d\.jpg$/, "5.jpg"
                download [img], callback
            catch err
                handle err, "Fetch nude error", callback

    req.on "error", _.partialRight "Downloading nude error", callback

handle = (err, where, callback) ->
    console.log where
    console.log err
    callback err


start()
