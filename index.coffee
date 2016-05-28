
fs = require 'fs-extra'
grs = require 'grs'
path = require 'path'
async = require 'async'
Promise = require 'bluebird'
mv = require 'mv'
mvAsync = Promise.promisify mv
rm = require 'rimraf'
rmAsync = Promise.promisify rm
util = require 'gulp-util'
asar = require 'asar'
chalk = require 'chalk'
Decompress = require 'decompress-zip'
PluginError = util.PluginError
through = require 'through2'
childProcess = require 'child_process'
ProgressBar = require 'progress'
File = require 'vinyl'
plist = require 'plist'
rcedit = require 'rcedit'


PLUGIN_NAME = 'gulp-electron'

module.exports = electron = (options) ->
  # Options should be like
  #  cache
  #  src
  #  packageJson
  #  release
  #  platforms: ['darwin', 'win32', 'linux']
  #  apm
  #  rebuild
  #  asar
  #  packaging
  #  symbols
  #  version
  #  repo
  PLUGIN_NAME = 'gulp-electron'
  options = (options or {})

  if not options.release or not options.version or
      not options.src or not options.cache
    throw new PluginError PLUGIN_NAME, 'Miss version or release path.'
  if path.resolve(options.src) is path.resolve(".")
    throw new PluginError PLUGIN_NAME, 'src path can not root path.'

  packageJson = options.packageJson
  if typeof options.packageJson is 'string'
    packageJson = require(packageJson)
  options.platforms ?= ['darwin']
  options.apm ?= getApmPath()
  options.symbols ?= false
  options.rebuild ?= false
  options.asar ?= false
  options.asarUnpack ?= false
  options.asarUnpackDir ?= false
  options.packaging ?= true
  options.ext ?= 'zip'

  options.platforms = [options.platforms] if typeof options.platforms is 'string'

  bufferContents = (file, enc, cb) ->
    src = file
    cb()

  endStream = (callback) ->
    push = @push
    platforms = ['darwin',
    'win32',
    'linux',
    'darwin-x64',
    'linux-ia32',
    'linux-x64',
    'win32-ia32',
    'win32-x64',
    'linux-arm']

    Promise.map options.platforms, (platform) ->
      platform = 'darwin' if platform is 'osx'
      platform = 'win32' if platform is 'win'

      if platforms.indexOf(platform) < 0
        throw new PluginError PLUGIN_NAME, "Not support platform #{platform}"

      options.ext ?= "zip"
      # ex: electron-v0.24.0-darwin-x64.zip
      pkgZip = pkg = "#{packageJson.name}-#{packageJson.version}-#{platform}"
      pkgZip += '-symbols' if options.symbols
      pkgZip += ".#{options.ext}"

      cacheZip = cache = "electron-#{options.version}-#{platform}"
      cacheZip += '-symbols' if options.symbols
      cacheZip += ".#{options.ext}"
      getUserHome = ->
        process.env.HOME or process.env.USERPROFILE
      if not path.isAbsolute(options.cache)
        if options.cache.match(/^\~/)
          options.cache = path.join getUserHome(), options.cache.replace(/^\~\//, "")
        else
          options.cache = path.resolve options.cache
      # ex: ./cache/v0.24.0/electron-v0.24.0-darwin-x64.zip
      cachePath = path.resolve options.cache, options.version
      cacheFile = path.resolve cachePath, cacheZip
      # ex: ./cache/v0.24.0/electron-v0.24.0-darwin-x64
      cacheedPath = path.resolve cachePath, cache
      # ex: ./release/v0.24.0/
      if not path.isAbsolute(options.release)
        if options.release.match(/^\~/)
          options.release = path.join getUserHome(), options.release.replace(/^\~\//, "")
        else
          options.release = path.resolve options.release
      pkgZipDir = path.resolve options.release, options.version
      pkgZipPath = path.resolve pkgZipDir
      pkgZipFilePath = path.resolve pkgZipDir, pkgZip
      # ex: ./release/v0.24.0/darwin-x64/
      platformDir = path.join pkgZipDir, platform
      platformPath = path.resolve platformDir

      targetApp = ""
      defaultAppName = "Electron"
      suffix = ""
      _src = path.join 'resources', 'app'
      if platform.indexOf('darwin') >= 0
        suffix = ".app"
        electronFile = "Electron" + suffix
        targetZip = packageJson.name + suffix
        _src = path.join packageJson.name + suffix, 'Contents', 'Resources', 'app'
      else if platform.indexOf('win') >= 0
        suffix = ".exe"
        electronFile = "electron" + suffix
        targetZip = "."
      else
        electronFile = "electron"
        targetZip = "."
      # ex: ./release/v0.24.0/darwin-x64/Electron
      electronFileDir = path.join platformDir, electronFile
      electronFilePath = path.resolve electronFileDir
      binName = packageJson.name + suffix
      targetAppDir = path.join platformDir , binName
      targetAppPath = path.join targetAppDir
      _src = path.join 'resources', 'app'
      if platform.indexOf('darwin') >= 0
        _src = path.join binName, 'Contents', 'Resources', 'app'
      # ex: ./release/v0.24.0/darwin-x64/Electron/Contents/resources/app
      targetDir = path.join packageJson.name, _src
      targetDirPath = path.resolve platformDir, _src
      targetAsarPath = path.resolve platformDir, _src + ".asar"

      contentsPlistDir = path.join targetAppPath, 'Contents', 'Info.plist'
      identity = ""
      if options.platformResources?.darwin?.identity? and isFile options.platformResources.darwin.identity
        identity = fs.readFileSync(options.platformResources.darwin.identity, 'utf8').trim()
        ###
      signingCmd =
        # http://sevenzip.sourceforge.jp/chm/cmdline/commands/extract.htm
        darwin: [
            cmd: 'codesign'
            args: ['--deep', '--force', '--verbose', '--sign', identity, path.join(targetAppDir ,'Contents', 'Frameworks', 'Electron\\ Framework.framework')]
          ,
            cmd: 'codesign'
            args: ['--deep', '--force', '--verbose', '--sign', identity, path.join(targetAppDir ,'Contents', 'Frameworks', 'Electron\\ Helper EH.app')]
          ,
            cmd: 'codesign'
            args: ['--deep', '--force', '--verbose', '--sign', identity, path.join(targetAppDir ,'Contents', 'Frameworks', 'Electron\\ Helper NP.app')]
          ,
            cmd: 'codesign'
            args: ['--deep', '--force', '--verbose', '--sign', identity, path.join(targetAppDir ,'Contents', 'Frameworks', 'Electron\\ Helper.app')]
          ,
            cmd: 'codesign'
            args: ['--deep', '--force', '--verbose', '--sign', identity, path.join(targetAppDir ,'Contents', 'Frameworks', 'ReactiveCocoa.framework')]
          ,
            cmd: 'codesign'
            args: ['--deep', '--force', '--verbose', '--sign', identity, path.join(targetAppDir ,'Contents', 'Frameworks', 'Squirrel.framework')]
          ,
            cmd: 'codesign'
            args: ['--deep', '--force', '--verbose', '--sign', identity, path.join(targetAppDir,'Contents', 'Frameworks', 'Mantle.framework')]
          ,
            cmd: 'codesign'
            args: ['--deep', '--force', '--verbose', '--sign', identity, targetAppDir]
        ]
        ###
      unpackagingCmd =
        # http://sevenzip.sourceforge.jp/chm/cmdline/commands/extract.htm
        win32:
          cmd: '7z'
          args: ['x', cacheFile, '-o' + cacheedPath]
        darwin:
          cmd: 'unzip'
          args: ['-q', '-o', cacheFile, '-d', cacheedPath]
        linux:
          cmd: 'unzip'
          args: ['-o', cacheFile, '-d', cacheedPath]
      packagingCmd =
        # http://www.appveyor.com/docs/packaging-artifacts#packaging-multiple-files-in-different-locations-into-a-single-archive
        win32:
          cmd: '7z',
          args: ['a', path.join('..', pkgZip), targetZip],
          opts: {cwd: platformPath}
        darwin:
          cmd: 'ditto'
          args: [ '-c', '-k', '--sequesterRsrc', '--keepParent' , targetZip, path.join('..', pkgZip)]
          opts: {cwd: platformPath}
        linux:
          cmd: 'zip'
          args: ['-9', '-y', '-r', path.join('..', pkgZip) , targetZip]
          opts: {cwd: platformPath}

      new Promise (resolve,reject) ->
        Promise.resolve().then ->
          # If not downloaded then download the special package.
          download cacheFile, cachePath, options.version, cacheZip, options.token
        .then ->
          # If not unziped then unzip the zip file.
          # Check if there already have an version file.
          unzip cacheFile, cacheedPath, unpackagingCmd[process.platform]
        .then ->
          distributeBase platformPath, cacheedPath, electronFilePath, targetAppPath
        .then ->
          if not options.rebuild
            return Promise.resolve()
          util.log PLUGIN_NAME, "Rebuilding modules"
          rebuild cmd: options.apm, args: ['rebuild']
        .then ->
          util.log PLUGIN_NAME, "distributeApp #{targetAppDir}"
          if not path.isAbsolute(options.src)
            if options.src.match(/^\~/)
              options.src = path.join getUserHome(), options.src.replace(/^\~\//, "")
            else
              options.src = path.resolve options.src

          distributeApp options.src, targetDirPath
        .then ->
          if platform.indexOf('darwin') is -1 or not options.platformResources?.darwin?
            return Promise.resolve()
          util.log PLUGIN_NAME, "distributePlist #{targetAppPath}"
          distributePlist options.platformResources.darwin, packageJson.name, targetAppPath
        .then ->
          if platform.indexOf('darwin') is -1 or not options.platformResources?.darwin?
            return Promise.resolve()
          util.log PLUGIN_NAME, "distributeMacIcon #{targetAppDir}"
          distributeMacIcon options.platformResources.darwin.icon, targetAppPath
        .then ->
          if platform.indexOf('win32') is -1 or not options.platformResources?.win?
            return Promise.resolve()
          util.log PLUGIN_NAME, "distributeWinIcon #{targetAppDir}"
          distributeWinIcon options.platformResources.win, targetAppPath
        .then ->
          if not options.asar
            return Promise.resolve()
          util.log PLUGIN_NAME, "packaging app.asar"
          asarPackaging targetDirPath, targetAsarPath,
           {unpack: options.asarUnpack, unpackDir: options.asarUnpackDir}
        .then ->
          if not options.packaging
            return Promise.resolve()
          # FIXME: skip signing
          return Promise.resolve()
          ###
          if platform is "darwin-x64" and process.platform is "darwin"
            if identity is ""
              util.log PLUGIN_NAME, "not found identity file. skip signing"
              return Promise.resolve()
            signDarwin signingCmd.darwin
          ###
        .then ->
          if not options.packaging
            return Promise.resolve()
          packaging pkgZipFilePath, packagingCmd[process.platform]
        .then ->
          resolve()
    .finally ->
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

download = (cacheFile, cachePath, version, cacheZip, token) ->
  if isFile cacheFile
    util.log PLUGIN_NAME, "download skip: already exists"
    return Promise.resolve()
  new Promise (resolve, reject) ->
    util.log PLUGIN_NAME, "download electron #{cacheZip} cache filie."
    fs.mkdirsSync cachePath
    # Download electron package throw stream.
    bar = null
    grs
      repo: 'atom/electron'
      tag: version
      name: cacheZip
      token: token
    .on 'error', (error) ->
      throw new PluginError PLUGIN_NAME, error
    .on 'size', (size) ->
      bar = new ProgressBar "#{cacheFile} [:bar] :percent :etas",
        complete: '>'
        incomplete: ' '
        width: 20
        total: size
    .pipe through (chunk, enc, cb) ->
      bar.tick chunk.length
      @push(chunk)
      cb()
    .pipe(fs.createWriteStream(cacheFile))
    .on 'close', resolve
    .on 'error', reject

unzip = (src, target, unpackagingCmd) ->
  if isExists target
    return Promise.resolve()
  return new Promise (resolve, reject) ->
    ###
    decompress = new Decompress src
    decompress.on 'error', reject
    decompress.on 'extract', ->
      util.log PLUGIN_NAME, "decompress done #{src}, #{target}"
      resolve()
    decompress.extract
      path: target
      follow: true
    ###
    spawn unpackagingCmd, ->
      resolve()

distributeBase = (platformPath, cacheedPath, electronFilePath, targetAppPath) ->
  if isExists(platformPath) and isExists(targetAppPath)
    util.log PLUGIN_NAME, "distributeBase skip: already exists"
    return Promise.resolve()
  new Promise (resolve) ->
    fs.mkdirsSync platformPath
    fs.copySync cacheedPath, platformPath
    mvAsync electronFilePath, targetAppPath, {mkdirp: true}
      .then resolve

distributeApp = (src, targetDirPath) ->
  if isExists targetDirPath
    util.log PLUGIN_NAME, "distributeApp skip: already exists"
    return Promise.resolve()
  new Promise (resolve) ->
    rmAsync targetDirPath
      .finally ->
        fs.mkdirsSync targetDirPath
        fs.copySync src, targetDirPath
        resolve()

distributePlist = (darwin, name, targetAppPath) ->
  new Promise (resolve) ->
    contentsPlist = plist.parse fs.readFileSync path.join(targetAppPath, 'Contents', 'Info.plist'), 'utf8'

    if darwin.CFBundleDisplayName?
      contentsPlist.CFBundleDisplayName = darwin.CFBundleDisplayName
    if darwin.CFBundleIdentifier?
      contentsPlist.CFBundleIdentifier = darwin.CFBundleIdentifier

    if darwin.CFBundleName?
      contentsPlist.CFBundleName = darwin.CFBundleName
    if darwin.CFBundleVersion?
      contentsPlist.CFBundleVersion = darwin.CFBundleVersion
    if darwin.CFBundleExecutable?
      contentsPlist.CFBundleExecutable = darwin.CFBundleExecutable
    if darwin.CFBundleURLTypes?
      contentsPlist.CFBundleURLTypes = darwin.CFBundleURLTypes
    fs.writeFileSync path.join(targetAppPath, 'Contents', 'Info.plist'), plist.build contentsPlist
    if darwin.CFBundleExecutable?
      _binarySrc = path.join targetAppPath, 'Contents', 'MacOS', 'Electron'
      _binaryDest = path.join targetAppPath, 'Contents', 'MacOS', darwin.CFBundleExecutable
      mvAsync _binarySrc, _binaryDest, {mkdirp: true}
      .then resolve
    else
      resolve()

distributeMacIcon = (src, targetAppPath) ->
  new Promise (resolve) ->
    iconDir = path.join targetAppPath, 'Contents', 'Resources', 'electron.icns'
    fs.createReadStream(src).pipe fs.createWriteStream iconDir
    resolve()

distributeWinIcon = (src, targetAppPath) ->
  new Promise (resolve) ->
    rcedit targetAppPath, src, resolve
    resolve()

rebuild = (cmd) ->
  new Promise (resolve) ->
    spawn cmd, resolve

asarPackaging = (src, target, opts) ->
  escSrc = src.replace(/(\\\s)/, "\\ ")
  escTarget = target.replace(/(\\\s)/, "\\ ")
  new Promise (resolve) ->
    util.log PLUGIN_NAME, "packaging app.asar #{escSrc}, #{escTarget}"
    asar.createPackageWithOptions escSrc, escTarget, opts, ->
      fs.remove escSrc, (err) ->
        util.log PLUGIN_NAME, 'removing dir ' + escSrc
        resolve()
        return

signDarwin = (signingCmd) ->
  promiseList = []
  signingCmd.forEach (cmd) ->
    p = Promise.defer()
    promiseList.push p
    spawn cmd, ->
      p.resolve()
  Promise.when promiseList

packaging = (pkgZipFilePath, packagingCmd) ->
  if not isFile pkgZipFilePath
    return new Promise (resolve) ->
      cmd = packagingCmd
      spawn cmd, ->
        resolve()
  return new Promise (resolve) ->
    rmAsync pkgZipFilePath
      .finally ->
        cmd = packagingCmd
        spawn cmd, ->
          resolve()

spawn = (options, cb) ->
  stdout = []
  stderr = []
  error = null
  options.args.forEach (arg) ->
    arg = arg.replace ' ', '\\ '
  util.log "> #{options.cmd} #{options.args.join ' '}"
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
    cb error, results
