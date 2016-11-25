gulp-electron for [gulp](https://github.com/wearefractal/gulp) [![NPM version](https://badge.fury.io/js/gulp-electron.png)](http://badge.fury.io/js/gulp-electron)
=======

[![Build Status](https://travis-ci.org/mainyaa/gulp-electron.svg?branch=master)](https://travis-ci.org/mainyaa/gulp-electron) [![AppVayor status](https://ci.appveyor.com/api/projects/status/32r7s2skrgm9ubva/branch/master?svg=true)](https://ci.appveyor.com/project/mainyaa/gulp-electron) [![Dependency Status](https://david-dm.org/mainyaa/gulp-electron.svg)](https://david-dm.org/mainyaa/gulp-electron) [![Coverage Status](https://coveralls.io/repos/mainyaa/gulp-electron/badge.svg)](https://coveralls.io/r/mainyaa/gulp-electron) [![Code Climate](https://codeclimate.com/github/mainyaa/gulp-electron/badges/gpa.svg)](https://codeclimate.com/github/mainyaa/gulp-electron)

> A gulp plugin that creates electron based distributable applications.

Install
-----

Install with [npm](https://npmjs.org/package/gulp-electron).

```sh
npm install --save-dev gulp-electron
```

Usage
-----


Add a gulp electron task like :

```js
var gulp = require('gulp');
var electron = require('gulp-electron');
var packageJson = require('./src/package.json');

gulp.task('electron', function() {

    gulp.src("")
    .pipe(electron({
        src: './src',
        packageJson: packageJson,
        release: './release',
        cache: './cache',
        version: 'v0.37.4',
        packaging: true,
        token: 'abc123...',
        platforms: ['win32-ia32', 'darwin-x64'],
        platformResources: {
            darwin: {
                CFBundleDisplayName: packageJson.name,
                CFBundleIdentifier: packageJson.name,
                CFBundleName: packageJson.name,
                CFBundleVersion: packageJson.version,
                icon: 'gulp-electron.icns'
            },
            win: {
                "version-string": packageJson.version,
                "file-version": packageJson.version,
                "product-version": packageJson.version,
                "icon": 'gulp-electron.ico'
            }
        }
    }))
    .pipe(gulp.dest(""));
});
```

Executing `gulp electron` will create an electron package for the specified platforms.

When you run code under `process.NODE_ENV = test` more debug information will be displayed.

### `Dependency`

If you using windows: install 7z(http://www.7-zip.org/).

### `options`

* `src` The root directory of the sources that shall be packaged, **required**.
* `packageJson` The package.json, **required**.
* `cache` The download path for the electron package, **required**.
* `release` is where the release applictions path, **required**.
* `version` the version of the electron release to be download from the GitHub page, **required**.
* `platforms` Support `['darwin','win32','linux','darwin-x64','linux-ia32','linux-x64','win32-ia32','win64-x64']`, default is `darwin-x64`. If verion is under `v0.13.0` must use `['darwin','win32','linux']`.
* `apm` Path to the `atom-package-manager` executable. If not specified the default behavior will be to use the globally installed `apm` executable.
* `rebuild` Default is `false`, when set to `true` then rebuild native-modules.
* `asar` Default is `false`, when set to `true` then asar pack your app directory. see more docs(https://github.com/atom/electron/blob/master/docs/tutorial/application-packaging.md).
* `asarUnpack` Default is `false`, this options use [minimatch](https://github.com/isaacs/minimatch) to filter out asar file.
* `asarUnpackDir` Default is `false`, this options filter out asar directory, ex: `vendor` filter out `vendor` dir.
* `symbols` Default is `false`, when set to `true` the symbols package from GitHub will be downloaded.
* `packaging` Default is `false`, when set to `true` the packaging zip file.
* `token` Default is `undefined` or env `GITHUB_TOKEN`, when set to a GitHub authentication token helps prevent rate-limits when downloading Electron releases.

* `platformResources`
  * `darwin` Mac resources. See [Core Foundation Keys](https://developer.apple.com/library/ios/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html) for details.
    * `CFBundleDisplayName` The actual name of the bundle
    * `CFBundleIdentifier` An identifier string that specifies the app type of the bundle. The string should be in reverse DNS format using only the Roman alphabet in upper and lower case (A–Z, a–z), the dot (“.”), and the hyphen (“-”).
    * `CFBundleName` The short display name of the bundle.
    * `CFBundleVersion` The build-version-number string for the bundle.
    * `CFBundleURLTypes` An array of dictionaries describing the URL schemes supported by the bundle.
    * `icon` Path to the icon file. `.icns` format
  * `win` Windows resources. On platforms other then Windows you will need to have [Wine](http://winehq.org) installed and in the system path.
    * `version-string` - An object containings properties to change of `.exe`
      version string.
    * `file-version` File's version to change to.
    * `product-version` Product's version to change to.
    * `icon` Path to the icon file. `.ico` format


License
-----

MIT
