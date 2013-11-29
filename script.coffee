_       = require 'lodash'
http    = require 'http'
util    = require 'util'
async   = require 'async'
images  = require 'http-get'
cheerio = require 'cheerio'
path    = require 'path'
fs      = require 'fs'

[username, savePath] = ["z0rch", "D:\\Dropbox\\Photos\\500px favorites"]
[fetchedPages, totalPages, photos, total] = [0, null, [], 0]

start = ->
    unless fs.existsSync savePath
        return util.debug "Destination path does not exists, please check configuration"

    process = (callback) -> async.waterfall [
        fetch
        parse
        findLinks
        findNudeLinks
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


isValid = (url) ->
    regex = /^(https?:\/\/)?[\w\d-+_=&?#~;%*\/\.]+$/i
    regex.test url


parseUrl = (html) ->
    $ = cheerio.load html
    img = $(".the_photo")
    img = $("img") unless img.length
    url = img.attr("src")

    return false if url.indexOf("/nude/") > -1
    throw "Url is invalid" unless isValid url

    regex = /(\d+)\.jpg$/
    resolution = parseInt regex.exec(url)[1]
    url = url.replace regex, "5.jpg" if resolution < 5
    url


fetch = (callback) ->
    [response, options] = ["", makeOptions fetchedPages + 1]

    req = http.get options, (res) ->
        res.on "data", (chunk) -> response += chunk.toString()
        res.on "end", -> callback null, response

    req.on "error", _.partialRight handle, "Fetching", callback


parse = (response, callback) ->
    try
        data = JSON.parse response
        photos = photos.concat data.items
        totalPages = data.total_pages

        fetchedPages++
        util.debug "Parsed page ##{fetchedPages} out of #{totalPages}"
        callback null, photos

    catch err
        handle err, "Parsing", callback


findLinks = (photos, callback) ->
    try
        callback null, _.map photos, (value) ->
            id: value.id.toString(), url: parseUrl value.html
    catch err
        handle err, "Finding links", callback


findNudeLinks = (links, callback) ->
    nude = _.filter links, (img) -> not img.url

    async.each nude, (img, found) ->
        response = ""

        req = http.get "http://500px.com/photo/#{img.id}", (res) ->
            res.on "data", (chunk) -> response += chunk.toString()
            res.on "end", ->
                try
                    img.url = parseUrl response
                    throw "Cannot parse url for nude image" unless img.url
                    found null
                catch err
                    handle err, "Finding nude link", found

        req.on "error", _.partialRight handle, "Downloading page with nude link", found
    , -> callback null, links


download = (links, callback) ->
    async.each links, (img, downloaded) ->
        fileName = path.join(savePath, img.id) + ".jpg"
        return downloaded null if fs.existsSync fileName

        images.get img.url, fileName, (err, result) ->
            total++
            downloaded err
    , callback


handle = (err, where, callback) ->
    util.debug """EXCEPTION:
                  During: #{where}
                  Details: #{util.inspect err}"""
    callback err


start()
