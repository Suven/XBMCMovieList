# MovieList

Freaky little tool for automated creation of HTML-Versions of ones XBMC-Movie-Library.
Those generated files are ment to be shared among friends (for example via Dropbox).

## Download

The most recent version can be downloaded from [movielist.wbbcoder.de](http://movielist.wbbcoder.de)

## Building

This application was created with node-webkit. To build it from source, make sure
you have your npm-dependencies fetched via

    npm install

That has to be done in the projects root-folder as well as in the subdir `src`.

After that you can run
    
    grunt release

and will find your binary in `build`

## Creating additional themes

Currently themes are packaged with the tool itself, but this may change. If
you want to create your own theme, just have a look at `src/themes/beauty`.

Themes are autonomous *'applications'*. Feel free to do whatever you like, but please
stick to one index.html for now.

`screenshot.png` and `package.json` are mandatory files which have to be in your themes root-folder.

Just send me a Pull-Request with your theme as submodule as soon as you think your theme is
stable enough.