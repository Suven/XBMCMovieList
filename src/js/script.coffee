fs = require 'fs'
http = require 'http'
rimraf = require 'rimraf'
path = require "path"
Stream = require 'stream'
ncp = require('ncp').ncp
gui = require 'nw.gui'

numberOfImageDlTries = 3

xbmc = (
	host: "example.net"
	port: 80
	username: "xbmc"
	password: "xbmc"
)

userHome = ->
	process.env.HOME || process.env.HOMEPATH || process.env.USERPROFILE

themeFolder = "./themes/"
outFolder = path.join(userHome(), "out")

createDirs = ->
	fs.mkdirSync outFolder
	fs.mkdirSync path.join(outFolder, "thumbs")

getTheme = (path) ->
	# Dude.. if it ain't even a folder it ain't a fancy theme...
	if (!fs.lstatSync(path).isDirectory())
		return undefined

	themeContent = fs.readdirSync path

	# It needs to have a screenshot
	if themeContent.indexOf("screenshot.png") is -1
		console.log "WARNING: #{path} is missing a screenshot.png"
		return undefined

	# And it needs to have a (valid) info-file
	if themeContent.indexOf("package.json") is -1
		console.log "WARNING: #{path} is missing a package.json"
		return undefined

	# Get the theme infos
	themeInfos = getThemeInfos "#{path}/package.json"

	# If something is missing, ignore da shitty theme
	if !themeInfos.name? or !themeInfos.desc? or !themeInfos.features?
		console.log "WARNING: #{path} is missing some theme infos"
		return undefined

	themeInfos

getThemeInfos = (themeInfoFile) -> 
	JSON.parse fs.readFileSync(themeInfoFile, {encoding: "utf8"})

themeFiles = (err, files) ->
	# There might be other files in the themefolder
	c = 0
	for file in files
		c++
		theme = getTheme(themeFolder + file)

		if theme?
			$('#themes').append("""
				<div class="theme column small-6">
					<h1>#{theme.name}</h1>
					<img data-theme="#{file}" src="./themes/#{file}/screenshot.png" class="preview" />
					<p class="desc">#{theme.desc}</p>
				</div>"""
			)

	if c % 2 is 1
		$('#themes').append("""
			<div class="theme column small-6">
				<h1></h1>
				<p class="desc"></p>
			</div>"""
		)

isIp = (str) ->
	/^localhost(:[0-9]{1,4}){0,1}$/.test(str) or /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(:[0-9]{1,4}){0,1}$/.test(str)

checkForXBMC = (ip, username, password) ->
	match = ip.match(/^(.*?)(:([0-9]{1,4})){0,1}$/)
	host = match[1]
	host = "127.0.0.1" if host is "localhost"
	port = if !match[3]? then 80 else match[3]

	console.log "Checking host #{host} on port #{port}..."

	req = http.request(
		hostname: host
		path: "/jsonrpc"
		auth: "#{username}:#{password}"
		port: port
		method: "POST"
		headers:
			 "Content-Type": "application/json"
		(response) ->
			if response.statusCode is 200
				console.log " ...found at #{req._headers.host}"
				xbmc.host = host
				xbmc.port = port
				xbmc.username = username
				xbmc.password = password
				req.abort()
				fetchDataFromXBMC()
	)

	req.on(
		'error'
		(e) ->
			console.log e
			console.log " ...not found (or invalid user) at #{req._headers.host}"
	)

	req.setTimeout(
		500
		->
			console.log " ...not found at #{req._headers.host}"
			req.abort()
	)

	req.end()

getImagePath = (mov) ->
	"/image/#{mov.thumbnail.substr(8, mov.thumbnail.length - 9)}"

downloadImages = (data) ->
	$('#fetchingData').hide(
		'drop'
		->
			$('#downloadingImages').show 'drop'
	)

	downloadImage data

finished = ->
	$('#copyTheme').hide(
		'drop'
		->
			$('#finished').show 'drop'	
	)

copyTheme = (theme) ->
	$('#chooseTheme').hide(
		'drop'
		->
			$('#copyTheme').show 'drop'

			ncp.limit = 16

			ncp(
				"./themes/#{theme}"
				outFolder
				(err) ->
			 		if (err)
			   			return console.error err
			 		finished()
			)
	)

chooseTheme = ->
	$('#downloadingImages').hide(
		'drop'
		->
			$('#chooseTheme').show 'drop'
	)

downloadImage = (data, n = 0, attempt = 1) ->

	if n >= data.length
		chooseTheme()
		return 0

	if attempt >= numberOfImageDlTries and attempt > 1
		console.log "Tried #{n} to often. Skipping this item"
		updateMeter(data)
		downloadImage(data, ++n)
		return 0

	mov = data[n]
	imageUrl = getImagePath mov

	request = http.get(
		hostname: xbmc.host
		path: imageUrl
		auth: "#{xbmc.username}:#{xbmc.password}"
		port: xbmc.port
		(response) ->
			if response.statusCode is 200
				imageFile = fs.createWriteStream "#{outFolder}/thumbs/#{mov.movieid}.jpg"
				response.pipe imageFile
				updateMeter(data)
				downloadImage(data, ++n)
			else
				console.log "Error downloading a thumb (try #{attempt} [#{n}]): image not found"
				response.on(
					'data'
					->
						#
				)
				downloadImage(data, n, ++attempt)
	).on(
		'error'
		(e) ->
			console.log("Error downloading a thumb (try #{attempt} [#{n}]):", e)
			downloadImage(data, n, ++attempt)
	)

	request.setTimeout(
		5000,
		->
			console.log "Error downloading a thumb (try #{attempt} [#{n}]): timeout"
			downloadImage(data, n, ++attempt)
	)

completedImages = 0
updateMeter = (data) ->
	completedImages++
	perc = Math.round(completedImages / data.length * 100)
	$('#downloadingImages .meter').css('width', "#{perc}%")

processXBMCData = (data, ip) ->
	# Save the JSON
	dataFile = fs.createWriteStream("#{outFolder}/data.js")
	outStr = "var data = #{JSON.stringify(data)};"

	stream = new Stream()
	stream.pipe = (dest) ->
		dest.write(outStr)

	stream.pipe dataFile

	# Next step: Get the images
	downloadImages data

fetchDataFromXBMC = ->

	$('#location').hide(
		'drop'
		->
			$('#fetchingData').show 'drop'

			req = http.request(
				hostname: xbmc.host
				path: "/jsonrpc"
				auth: "#{xbmc.username}:#{xbmc.password}"
				port: xbmc.port
				method: "POST"
				headers:
					 "Content-Type": "application/json"
				(response) ->
					data = ""
					response.setEncoding 'utf8'
					response.on(
						'data'
						(chunk) ->
							data += chunk
					)
					response.on(
						'end'
						->
							data = JSON.parse(data)
							processXBMCData data.result.movies
					)
			)

			req.write """
					{
						"jsonrpc": "2.0",
						"method": "VideoLibrary.GetMovies",
						"params": {
							"properties" : [
								"director",
								"genre",
								"plot",
								"plotoutline",
								"tagline",
								"title",
								"trailer",
					        	"cast",
					        	"country", 
					        	"dateadded",
					        	"lastplayed",
					        	"originaltitle",
					        	"rating",
					        	"runtime",
					        	"tag",
					        	"thumbnail",
					        	"top250",
					        	"writer", 
					        	"year",
					        	"streamdetails"
							],
							"sort": {
								"order": "descending",
								"method": "dateadded"
							}
						},
						"id": "libMovies"
					}
			"""
				
			req.end()
	)

compareVersions = (a, b) ->
	regex = /^([0-9]+?)\.([0-9]+?)\.([0-9]+?)$/
	a = a.match(regex)
	b = b.match(regex)
	if (a[1] > b[1])
		return 1
	if (a[2] > b[2])
		return 1
	if (a[3] > b[3])
		return 1

	return 0

checkVersion = ->
	req = http.request(
		host: "movielist.wbbcoder.de"
		path: "/version.txt"
		(response) ->

			version = ""
			response.setEncoding 'utf8'
			response.on(
				'data'
				(chunk) ->
					version += chunk
			)
			response.on(
				'end'
				->
					if compareVersions(version, gui.App.manifest.version) is 1
						$('footer .update').html("<a href='#'>Update to #{version}</a>")
			)
	)

	req.end()

# Lets fire that wood!
$ ->
	$('footer .version').html gui.App.manifest.version

	# Show the Node-Window
	gui.Window.get().show()

	$('#welcome a.button').click ->
		$('#welcome').hide(
			'drop'
			->
				$('#location').show 'drop'
		)

	$('#openList').click ->
		link = fs.realpathSync outFolder
		gui.Shell.openExternal "file://#{link}/index.html"

	$('footer').on(
		'click'
		'a'
		(e) ->
			gui.Shell.openExternal "http://movielist.wbbcoder.de"
	)

	checkForIpTimer = null
	$('#xbmcUrl, #xbmcUser, #xbmcPassword').on(
		'keyup',
		->
			ip = $("#xbmcUrl").val()
			if isIp ip

				# Any Timeout set? Reset it
				clearTimeout checkForIpTimer if checkForIpTimer?

				# Wait an additional sec for changes
				checkForIpTimer = setTimeout(
					->
						checkForXBMC(ip, $('#xbmcUser').val(), $('#xbmcPassword').val())	
					500
				)
				
	)

	$('#themes').on(
		'click',
		'.theme img'
		->
			copyTheme $(@).data('theme')
	)

	# Setup dirs
	if fs.existsSync outFolder
		rimraf(outFolder, (e) ->
			createDirs()
		)  
	else 
		createDirs()

	# Check version
	checkVersion()

	# Check for available themes
	fs.readdir(themeFolder, themeFiles)
