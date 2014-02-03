fs = require 'fs'
http = require 'http'
rimraf = require 'rimraf'
path = require "path"
Stream = require 'stream'
ncp = require('ncp').ncp
gui = require 'nw.gui'

numberOfImageDlTries = 3

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
	for file in files

		theme = getTheme(themeFolder + file)

		if theme?
			$('#themes').append("""
				<div class="theme">
					<h1>#{theme.name}</h1>
					<img data-theme="#{file}" src="./themes/#{file}/screenshot.png" class="preview" />
					<p class="desc">#{theme.desc}</p>
				</div>"""
			)

isIp = (str) ->
	/^localhost(:[0-9]{1,4}){0,1}$/.test(str) or /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(:[0-9]{1,4}){0,1}$/.test(str)

checkForXBMC = (ip) ->
	$.ajax
		url: "http://#{ip}/jsonrpc"
		type: 'POST'
		contentType: 'application/json'
		timeout: 500
		success: ->
			fetchDataFromXBMC ip

getImagePath = (mov, ip) ->
	"http://#{ip}/image/#{mov.thumbnail.substr(8, mov.thumbnail.length - 9)}"

downloadImages = (data, ip) ->
	$('#fetchingData').hide(
		'drop'
		->
			$('#downloadingImages').show 'drop'
	)

	downloadImage(data,ip)

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

downloadImage = (data, ip, n = 0, attempt = 1) ->

	if n >= data.length
		chooseTheme()
		return 0

	if attempt >= numberOfImageDlTries and attempt > 1
		console.log "Tried #{n} to often. Skipping this item"
		updateMeter(data)
		downloadImage(data, ip, ++n)
		return 0

	mov = data[n]
	imageUrl = getImagePath(mov,ip)

	request = http.get(
		imageUrl
		(response) ->
			if response.statusCode is 200
				imageFile = fs.createWriteStream "#{outFolder}/thumbs/#{mov.movieid}.jpg"
				response.pipe imageFile
				updateMeter(data)
				downloadImage(data, ip, ++n)
			else
				console.log "Error downloading a thumb (try #{attempt} [#{n}]): image not found"
				response.on(
					'data'
					->
						#
				)
				downloadImage(data, ip, n, ++attempt)
	).on(
		'error'
		(e) ->
			console.log("Error downloading a thumb (try #{attempt} [#{n}]):", e)
			downloadImage(data, ip, n, ++attempt)
	)

	request.setTimeout(
		5000,
		->
			console.log "Error downloading a thumb (try #{attempt} [#{n}]): timeout"
			downloadImage(data, ip, n, ++attempt)
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
	downloadImages(data, ip)

fetchDataFromXBMC = (ip) ->

	$('#location').hide(
		'drop'
		->
			$('#fetchingData').show 'drop'

			$.ajax
				url: "http://#{ip}/jsonrpc"
				type: 'POST'
				contentType: 'application/json'
				data: """
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
					        	"year"
							],
							"sort": {
								"order": "descending",
								"method": "dateadded"
							}
						},
						"id": "libMovies"
					}
				"""
				success: (data) ->
					processXBMCData(data.result.movies, ip)

	)

# Lets fire that wood!
$ ->

	$('#welcome a.button').click ->
		$('#welcome').hide(
			'drop'
			->
				$('#location').show 'drop'
		)

	$('#openList').click ->
		link = fs.realpathSync outFolder
		gui.Shell.openExternal "file://#{link}/index.html"

	checkForIpTimer = null
	$('#xbmcUrl').on(
		'keyup',
		->
			val = $(@).val()
			if isIp val

				# Any Timeout set? Reset it
				clearTimeout checkForIpTimer if checkForIpTimer?

				# Wait an additional sec for changes
				checkForIpTimer = setTimeout(
					->
						checkForXBMC val
					1000
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

	# Check for available themes
	fs.readdir(themeFolder, themeFiles);
