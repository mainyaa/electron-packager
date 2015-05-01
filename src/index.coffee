
fs = require 'fs'
grs = require 'grs'
path = require 'path'
async = require 'async'
wrench = require 'wrench'
mv = require 'mv'
rm = require 'rimraf'
util = require 'gulp-util'
PluginError = util.PluginError
through = require 'through2'
childProcess = require 'child_process'
ProgressBar = require 'progress'
File = require 'vinyl'


PLUGIN_NAME = 'gulp-electron'

module.exports = electron = (options) ->
  # Options should be like
  #  cache
  #  src
  #  release
  #  platforms: ['darwin', 'win32', 'linux']
  #  apm
  #  rebuild
  #  symbols
  #  version
  #  repo
  options = (options or {})

  if not options.release or not options.version or
   not options.src or not options.cache
    throw new PluginError 'Miss version or release path.'

  packageJson = options.packageJson
  if typeof options.packageJson is 'string'
    packageJson = require(packageJson)
  options.platforms ?= ['darwin']
  options.apm ?= getApmPath()
  options.symbols ?= false
  options.rebuild ?= false
  options.ext ?= 'zip'

  options.platforms = [options.platforms] if typeof options.platforms is 'string'

  bufferContents = (file, enc, callback) ->
    callback()

  endStream = (callback) ->
    push = @push
    platforms = ['darwin',
    'win32',
    'linux',
    'darwin-x64',
    'linux-ia32',
    'linux-x64',
    'win32-ia32',
    'win32-x64']

    async.eachSeries options.platforms,
      (platform, cb) ->
        platform = 'darwin' if platform is 'osx'
        platform = 'win32' if platform is 'win'

        if platforms.indexOf(platform) < 0
          throw new PluginError "Not support platform #{platform}"

        options.ext ?= "zip"
        # ex: electron-v0.24.0-darwin-x64.zip
        cacheZip = cache = "electron-#{options.version}-#{platform}"
        cacheZip += '-symbols' if options.symbols
        cacheZip += ".#{options.ext}"
        pkgZip = pkg = "#{packageJson.name}-#{packageJson.version}-#{platform}"
        pkgZip += '-symbols' if options.symbols
        pkgZip += ".#{options.ext}"

        # ex: ./cache/v0.24.0/electron-v0.24.0-darwin-x64.zip
        cachePath = path.resolve options.cache, options.version
        cacheFile = path.resolve cachePath, cacheZip
        cacheedPath = path.resolve cachePath, cache
        pkgZipDir = path.join options.release, options.version
        pkgZipPath = path.resolve pkgZipDir
        platformDir = path.join pkgZipDir, platform
        platformPath = path.resolve platformDir
        # ex: ./release/v0.24.0/darwin-x64/
        platformZipDir = path.join pkgZipDir, packageJson.name
        platformZipPath = path.resolve platformZipDir

        src = ""
        targetApp = ""
        defaultAppName = "Electron"
        suffix = ""
        if platform.indexOf('darwin') >= 0
          suffix = ".app"
          electronFile = "Electron" + suffix
        else if platform.indexOf('win') >= 0
          suffix = ".exe"
          electronFile = "electron" + suffix
        else
          electronFile = "electron"
        # ex: ./release/v0.24.0/darwin-x64/Electron
        binName = packageJson.name + suffix
        targetAppPath = path.join platformPath , binName
        _src = 'resources/app'
        if platform.indexOf('darwin') >= 0
          _src = binName + '/Contents/Resources/app/'
        # ex: ./release/v0.24.0/darwin-x64/Electron/Contents/resources/app
        targetDir = path.join packageJson.name, _src
        targetDirPath = path.resolve platformZipDir, _src
        targetPath = path.resolve platformPath

        async.series [
          # If not downloaded then download the special package.
          (next) ->
            if not isFile cacheFile
              util.log PLUGIN_NAME, "download #{platform} #{options.version} cache filie."
              wrench.mkdirSyncRecursive cachePath
              # Download electron package throw stream.
              bar = null
              grs
                repo: 'atom/electron'
                tag: options.version
                name: cacheZip
              .on 'error', (error) ->
                 throw new PluginError error
              .on 'size', (size) ->
                bar = new ProgressBar "#{pkg} [:bar] :percent :etas",
                  complete: '>'
                  incomplete: ' '
                  width: 20
                  total: size
              .pipe through (chunk, enc, cb) ->
                bar.tick chunk.length
                @push(chunk)
                cb()
              .pipe(fs.createWriteStream(cacheFile))
              .on 'close', ->
                next()
              .on 'error', next
            else next()
          # If not unziped then unzip the zip file.
          # Check if there already have an version file.
          (next) ->
            if not isDir cacheedPath
              wrench.mkdirSyncRecursive cacheedPath
              util.log PLUGIN_NAME, "unzip #{platform} #{options.version} electron."
              spawn {cmd: 'unzip', args: ['-o', cacheFile, '-d', cacheedPath]}, next
            else next()

          # If rebuild
          # then rebuild the native module.
          (next) ->
            if options.rebuild
              util.log PLUGIN_NAME, "Rebuilding modules"
              spawn {cmd: options.apm, args: ['rebuild']}, next
            else next()

          # Distribute.
          (next) ->
            wrench.mkdirSyncRecursive platformPath
            wrench.copyDirSyncRecursive cacheedPath, platformPath,
              forceDelete: true
              excludeHiddenUnix: false
              inflateSymlinks: false
            next()
          (next) ->
            if not isExists targetAppPath
              mv electronFile, targetAppPath, ->
                next()
            else next()

          # Distribute app.
          (next) ->
            if not isExists targetDirPath
              rm targetDirPath, next
            else next()
          (next) ->
            util.log PLUGIN_NAME, "#{options.src} -> #{targetDir} distributing"
            wrench.mkdirSyncRecursive targetDirPath

            # Major bug here
            # if src: '.', then you end up with a full disk and an undeletable folder
            # You should use the gulp src list instead
            # e.g.
            # gulp.src(['*.js', '*.json'])
            #     .pipe(electron({ ... }))
            #     .pipe(gulp.dest('release'))
            #wrench.copyDirSyncRecursive options.src, targetDirPath,
            #  forceDelete: true
            #  excludeHiddenUnix: false
            #  inflateSymlinks: false
            next()

          # packaging app.
          (next) ->
            _target = packageJson.name
            if not options.rebuild and isExists path.join pkgZipPath, pkgZip
              _target = targetDir
            util.log PLUGIN_NAME, "#{path.join pkgZipDir, _target} packaging"
            mv platformPath, platformZipPath, ->
              spawn {
                cmd: 'zip'
                args: ['-9', '--symlinks', '-r', pkgZip , _target]
                opts: {cwd: pkgZipPath}
              }, ->
                mv platformZipPath, platformPath, next

        ], (error, results) ->
          _zip = path.join pkgZipDir, pkgZip
          util.log PLUGIN_NAME, "#{_zip} distribute done."
          cb()

      (error, results) ->
        util.log PLUGIN_NAME, "all distribute done."
        callback()

  return through.obj(bufferContents, endStream)

isDir = ->
  filepath = path.join.apply path, arguments
  fs.existsSync(filepath) and not fs.statSync(filepath).isFile()

isFile = ->
  filepath = path.join.apply path, arguments
  fs.existsSync(filepath) and fs.statSync(filepath).isFile()

isExists = ->
  filepath = path.join.apply path, arguments
  fs.existsSync(filepath)

getApmPath = ->
  apmPath = path.join 'apm', 'node_modules', 'atom-package-manager', 'bin', 'apm'
  apmPath = 'apm' unless isFile apmPath

spawn = (options, callback) ->
  stdout = []
  stderr = []
  error = null
  proc = childProcess.spawn options.cmd, options.args, options.opts
  proc.stdout.on 'data', (data) ->
    stdout.push data.toString()
    if process.NODE_ENV is 'test'
      util.log data.toString()
  proc.stderr.on 'data', (data) ->
    stderr.push data.toString()
  proc.on 'exit', (code, signal) ->
    error = new Error(signal) if code isnt 0
    results = stderr: stderr.join(''), stdout: stdout.join(''), code: code
    if code isnt 0
      throw new PluginError PLUGIN_NAME, results.stderr or
       'unknow error , maybe you can try delete the zip packages.'
    callback error, results
