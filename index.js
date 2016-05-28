var Decompress, File, PLUGIN_NAME, PluginError, ProgressBar, Promise, asar, asarPackaging, async, chalk, childProcess, distributeApp, distributeBase, distributeMacIcon, distributePlist, distributeWinIcon, download, electron, fs, getApmPath, grs, isDir, isExists, isFile, mv, mvAsync, packaging, path, plist, rcedit, rebuild, rm, rmAsync, signDarwin, spawn, through, unzip, util;

fs = require('fs-extra');

grs = require('grs');

path = require('path');

async = require('async');

Promise = require('bluebird');

mv = require('mv');

mvAsync = Promise.promisify(mv);

rm = require('rimraf');

rmAsync = Promise.promisify(rm);

util = require('gulp-util');

asar = require('asar');

chalk = require('chalk');

Decompress = require('decompress-zip');

PluginError = util.PluginError;

through = require('through2');

childProcess = require('child_process');

ProgressBar = require('progress');

File = require('vinyl');

plist = require('plist');

rcedit = require('rcedit');

PLUGIN_NAME = 'gulp-electron';

module.exports = electron = function(options) {
  var bufferContents, endStream, packageJson;
  PLUGIN_NAME = 'gulp-electron';
  options = options || {};
  if (!options.release || !options.version || !options.src || !options.cache) {
    throw new PluginError(PLUGIN_NAME, 'Miss version or release path.');
  }
  if (path.resolve(options.src) === path.resolve(".")) {
    throw new PluginError(PLUGIN_NAME, 'src path can not root path.');
  }
  packageJson = options.packageJson;
  if (typeof options.packageJson === 'string') {
    packageJson = require(packageJson);
  }
  if (options.platforms == null) {
    options.platforms = ['darwin'];
  }
  if (options.apm == null) {
    options.apm = getApmPath();
  }
  if (options.symbols == null) {
    options.symbols = false;
  }
  if (options.rebuild == null) {
    options.rebuild = false;
  }
  if (options.asar == null) {
    options.asar = false;
  }
  if (options.asarUnpack == null) {
    options.asarUnpack = false;
  }
  if (options.asarUnpackDir == null) {
    options.asarUnpackDir = false;
  }
  if (options.packaging == null) {
    options.packaging = true;
  }
  if (options.ext == null) {
    options.ext = 'zip';
  }
  if (typeof options.platforms === 'string') {
    options.platforms = [options.platforms];
  }
  bufferContents = function(file, enc, cb) {
    var src;
    src = file;
    return cb();
  };
  endStream = function(callback) {
    var platforms, push;
    push = this.push;
    platforms = ['darwin', 'win32', 'linux', 'darwin-x64', 'linux-ia32', 'linux-x64', 'win32-ia32', 'win32-x64', 'linux-arm'];
    return Promise.map(options.platforms, function(platform) {
      var _src, binName, cache, cacheFile, cachePath, cacheZip, cacheedPath, contentsPlistDir, defaultAppName, electronFile, electronFileDir, electronFilePath, getUserHome, identity, packagingCmd, pkg, pkgZip, pkgZipDir, pkgZipFilePath, pkgZipPath, platformDir, platformPath, ref, ref1, suffix, targetApp, targetAppDir, targetAppPath, targetAsarPath, targetDir, targetDirPath, targetZip, unpackagingCmd;
      if (platform === 'osx') {
        platform = 'darwin';
      }
      if (platform === 'win') {
        platform = 'win32';
      }
      if (platforms.indexOf(platform) < 0) {
        throw new PluginError(PLUGIN_NAME, "Not support platform " + platform);
      }
      if (options.ext == null) {
        options.ext = "zip";
      }
      pkgZip = pkg = packageJson.name + "-" + packageJson.version + "-" + platform;
      if (options.symbols) {
        pkgZip += '-symbols';
      }
      pkgZip += "." + options.ext;
      cacheZip = cache = "electron-" + options.version + "-" + platform;
      if (options.symbols) {
        cacheZip += '-symbols';
      }
      cacheZip += "." + options.ext;
      getUserHome = function() {
        return process.env.HOME || process.env.USERPROFILE;
      };
      if (!path.isAbsolute(options.cache)) {
        if (options.cache.match(/^\~/)) {
          options.cache = path.join(getUserHome(), options.cache.replace(/^\~\//, ""));
        } else {
          options.cache = path.resolve(options.cache);
        }
      }
      cachePath = path.resolve(options.cache, options.version);
      cacheFile = path.resolve(cachePath, cacheZip);
      cacheedPath = path.resolve(cachePath, cache);
      if (!path.isAbsolute(options.release)) {
        if (options.release.match(/^\~/)) {
          options.release = path.join(getUserHome(), options.release.replace(/^\~\//, ""));
        } else {
          options.release = path.resolve(options.release);
        }
      }
      pkgZipDir = path.resolve(options.release, options.version);
      pkgZipPath = path.resolve(pkgZipDir);
      pkgZipFilePath = path.resolve(pkgZipDir, pkgZip);
      platformDir = path.join(pkgZipDir, platform);
      platformPath = path.resolve(platformDir);
      targetApp = "";
      defaultAppName = "Electron";
      suffix = "";
      _src = path.join('resources', 'app');
      if (platform.indexOf('darwin') >= 0) {
        suffix = ".app";
        electronFile = "Electron" + suffix;
        targetZip = packageJson.name + suffix;
        _src = path.join(packageJson.name + suffix, 'Contents', 'Resources', 'app');
      } else if (platform.indexOf('win') >= 0) {
        suffix = ".exe";
        electronFile = "electron" + suffix;
        targetZip = ".";
      } else {
        electronFile = "electron";
        targetZip = ".";
      }
      electronFileDir = path.join(platformDir, electronFile);
      electronFilePath = path.resolve(electronFileDir);
      binName = packageJson.name + suffix;
      targetAppDir = path.join(platformDir, binName);
      targetAppPath = path.join(targetAppDir);
      _src = path.join('resources', 'app');
      if (platform.indexOf('darwin') >= 0) {
        _src = path.join(binName, 'Contents', 'Resources', 'app');
      }
      targetDir = path.join(packageJson.name, _src);
      targetDirPath = path.resolve(platformDir, _src);
      targetAsarPath = path.resolve(platformDir, _src + ".asar");
      contentsPlistDir = path.join(targetAppPath, 'Contents', 'Info.plist');
      identity = "";
      if ((((ref = options.platformResources) != null ? (ref1 = ref.darwin) != null ? ref1.identity : void 0 : void 0) != null) && isFile(options.platformResources.darwin.identity)) {
        identity = fs.readFileSync(options.platformResources.darwin.identity, 'utf8').trim();

        /*
              signingCmd =
         * http://sevenzip.sourceforge.jp/chm/cmdline/commands/extract.htm
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
         */
      }
      unpackagingCmd = {
        win32: {
          cmd: '7z',
          args: ['x', cacheFile, '-o' + cacheedPath]
        },
        darwin: {
          cmd: 'unzip',
          args: ['-q', '-o', cacheFile, '-d', cacheedPath]
        },
        linux: {
          cmd: 'unzip',
          args: ['-o', cacheFile, '-d', cacheedPath]
        }
      };
      packagingCmd = {
        win32: {
          cmd: '7z',
          args: ['a', path.join('..', pkgZip), targetZip],
          opts: {
            cwd: platformPath
          }
        },
        darwin: {
          cmd: 'ditto',
          args: ['-c', '-k', '--sequesterRsrc', '--keepParent', targetZip, path.join('..', pkgZip)],
          opts: {
            cwd: platformPath
          }
        },
        linux: {
          cmd: 'zip',
          args: ['-9', '-y', '-r', path.join('..', pkgZip), targetZip],
          opts: {
            cwd: platformPath
          }
        }
      };
      return new Promise(function(resolve, reject) {
        return Promise.resolve().then(function() {
          return download(cacheFile, cachePath, options.version, cacheZip, options.token);
        }).then(function() {
          return unzip(cacheFile, cacheedPath, unpackagingCmd[process.platform]);
        }).then(function() {
          return distributeBase(platformPath, cacheedPath, electronFilePath, targetAppPath);
        }).then(function() {
          if (!options.rebuild) {
            return Promise.resolve();
          }
          util.log(PLUGIN_NAME, "Rebuilding modules");
          return rebuild({
            cmd: options.apm,
            args: ['rebuild']
          });
        }).then(function() {
          util.log(PLUGIN_NAME, "distributeApp " + targetAppDir);
          if (!path.isAbsolute(options.src)) {
            if (options.src.match(/^\~/)) {
              options.src = path.join(getUserHome(), options.src.replace(/^\~\//, ""));
            } else {
              options.src = path.resolve(options.src);
            }
          }
          return distributeApp(options.src, targetDirPath);
        }).then(function() {
          var ref2;
          if (platform.indexOf('darwin') === -1 || (((ref2 = options.platformResources) != null ? ref2.darwin : void 0) == null)) {
            return Promise.resolve();
          }
          util.log(PLUGIN_NAME, "distributePlist " + targetAppPath);
          return distributePlist(options.platformResources.darwin, packageJson.name, targetAppPath);
        }).then(function() {
          var ref2;
          if (platform.indexOf('darwin') === -1 || (((ref2 = options.platformResources) != null ? ref2.darwin : void 0) == null)) {
            return Promise.resolve();
          }
          util.log(PLUGIN_NAME, "distributeMacIcon " + targetAppDir);
          return distributeMacIcon(options.platformResources.darwin.icon, targetAppPath);
        }).then(function() {
          var ref2;
          if (platform.indexOf('win32') === -1 || (((ref2 = options.platformResources) != null ? ref2.win : void 0) == null)) {
            return Promise.resolve();
          }
          util.log(PLUGIN_NAME, "distributeWinIcon " + targetAppDir);
          return distributeWinIcon(options.platformResources.win, targetAppPath);
        }).then(function() {
          if (!options.asar) {
            return Promise.resolve();
          }
          util.log(PLUGIN_NAME, "packaging app.asar");
          return asarPackaging(targetDirPath, targetAsarPath, {
            unpack: options.asarUnpack,
            unpackDir: options.asarUnpackDir
          });
        }).then(function() {
          if (!options.packaging) {
            return Promise.resolve();
          }
          return Promise.resolve();

          /*
          if platform is "darwin-x64" and process.platform is "darwin"
            if identity is ""
              util.log PLUGIN_NAME, "not found identity file. skip signing"
              return Promise.resolve()
            signDarwin signingCmd.darwin
           */
        }).then(function() {
          if (!options.packaging) {
            return Promise.resolve();
          }
          return packaging(pkgZipFilePath, packagingCmd[process.platform]);
        }).then(function() {
          return resolve();
        });
      });
    })["finally"](function() {
      util.log(PLUGIN_NAME, "all distribute done.");
      return callback();
    });
  };
  return through.obj(bufferContents, endStream);
};

isDir = function() {
  var filepath;
  filepath = path.join.apply(path, arguments);
  return fs.existsSync(filepath) && !fs.statSync(filepath).isFile();
};

isFile = function() {
  var filepath;
  filepath = path.join.apply(path, arguments);
  return fs.existsSync(filepath) && fs.statSync(filepath).isFile();
};

isExists = function() {
  var filepath;
  filepath = path.join.apply(path, arguments);
  return fs.existsSync(filepath);
};

getApmPath = function() {
  var apmPath;
  apmPath = path.join('apm', 'node_modules', 'atom-package-manager', 'bin', 'apm');
  if (!isFile(apmPath)) {
    return apmPath = 'apm';
  }
};

download = function(cacheFile, cachePath, version, cacheZip, token) {
  if (isFile(cacheFile)) {
    util.log(PLUGIN_NAME, "download skip: already exists");
    return Promise.resolve();
  }
  return new Promise(function(resolve, reject) {
    var bar;
    util.log(PLUGIN_NAME, "download electron " + cacheZip + " cache filie.");
    fs.mkdirsSync(cachePath);
    bar = null;
    return grs({
      repo: 'atom/electron',
      tag: version,
      name: cacheZip,
      token: token
    }).on('error', function(error) {
      throw new PluginError(PLUGIN_NAME, error);
    }).on('size', function(size) {
      return bar = new ProgressBar(cacheFile + " [:bar] :percent :etas", {
        complete: '>',
        incomplete: ' ',
        width: 20,
        total: size
      });
    }).pipe(through(function(chunk, enc, cb) {
      bar.tick(chunk.length);
      this.push(chunk);
      return cb();
    })).pipe(fs.createWriteStream(cacheFile)).on('close', resolve).on('error', reject);
  });
};

unzip = function(src, target, unpackagingCmd) {
  if (isExists(target)) {
    return Promise.resolve();
  }
  return new Promise(function(resolve, reject) {

    /*
    decompress = new Decompress src
    decompress.on 'error', reject
    decompress.on 'extract', ->
      util.log PLUGIN_NAME, "decompress done #{src}, #{target}"
      resolve()
    decompress.extract
      path: target
      follow: true
     */
    return spawn(unpackagingCmd, function() {
      return resolve();
    });
  });
};

distributeBase = function(platformPath, cacheedPath, electronFilePath, targetAppPath) {
  if (isExists(platformPath) && isExists(targetAppPath)) {
    util.log(PLUGIN_NAME, "distributeBase skip: already exists");
    return Promise.resolve();
  }
  return new Promise(function(resolve) {
    fs.mkdirsSync(platformPath);
    fs.copySync(cacheedPath, platformPath);
    return mvAsync(electronFilePath, targetAppPath, {
      mkdirp: true
    }).then(resolve);
  });
};

distributeApp = function(src, targetDirPath) {
  if (isExists(targetDirPath)) {
    util.log(PLUGIN_NAME, "distributeApp skip: already exists");
    return Promise.resolve();
  }
  return new Promise(function(resolve) {
    return rmAsync(targetDirPath)["finally"](function() {
      fs.mkdirsSync(targetDirPath);
      fs.copySync(src, targetDirPath);
      return resolve();
    });
  });
};

distributePlist = function(darwin, name, targetAppPath) {
  return new Promise(function(resolve) {
    var _binaryDest, _binarySrc, contentsPlist;
    contentsPlist = plist.parse(fs.readFileSync(path.join(targetAppPath, 'Contents', 'Info.plist'), 'utf8'));
    if (darwin.CFBundleDisplayName != null) {
      contentsPlist.CFBundleDisplayName = darwin.CFBundleDisplayName;
    }
    if (darwin.CFBundleIdentifier != null) {
      contentsPlist.CFBundleIdentifier = darwin.CFBundleIdentifier;
    }
    if (darwin.CFBundleName != null) {
      contentsPlist.CFBundleName = darwin.CFBundleName;
    }
    if (darwin.CFBundleVersion != null) {
      contentsPlist.CFBundleVersion = darwin.CFBundleVersion;
    }
    if (darwin.CFBundleExecutable != null) {
      contentsPlist.CFBundleExecutable = darwin.CFBundleExecutable;
    }
    if (darwin.CFBundleURLTypes != null) {
      contentsPlist.CFBundleURLTypes = darwin.CFBundleURLTypes;
    }
    fs.writeFileSync(path.join(targetAppPath, 'Contents', 'Info.plist'), plist.build(contentsPlist));
    if (darwin.CFBundleExecutable != null) {
      _binarySrc = path.join(targetAppPath, 'Contents', 'MacOS', 'Electron');
      _binaryDest = path.join(targetAppPath, 'Contents', 'MacOS', darwin.CFBundleExecutable);
      return mvAsync(_binarySrc, _binaryDest, {
        mkdirp: true
      }).then(resolve);
    } else {
      return resolve();
    }
  });
};

distributeMacIcon = function(src, targetAppPath) {
  return new Promise(function(resolve) {
    var iconDir;
    iconDir = path.join(targetAppPath, 'Contents', 'Resources', 'electron.icns');
    fs.createReadStream(src).pipe(fs.createWriteStream(iconDir));
    return resolve();
  });
};

distributeWinIcon = function(src, targetAppPath) {
  return new Promise(function(resolve) {
    rcedit(targetAppPath, src, resolve);
    return resolve();
  });
};

rebuild = function(cmd) {
  return new Promise(function(resolve) {
    return spawn(cmd, resolve);
  });
};

asarPackaging = function(src, target, opts) {
  var escSrc, escTarget;
  escSrc = src.replace(/(\\\s)/, "\\ ");
  escTarget = target.replace(/(\\\s)/, "\\ ");
  return new Promise(function(resolve) {
    util.log(PLUGIN_NAME, "packaging app.asar " + escSrc + ", " + escTarget);
    return asar.createPackageWithOptions(escSrc, escTarget, opts, function() {
      fs.remove(escSrc, function(err) {
        util.log(PLUGIN_NAME, "removing dir " + escSrc);
        return resolve();
      });
    });
  });
};

signDarwin = function(signingCmd) {
  var promiseList;
  promiseList = [];
  signingCmd.forEach(function(cmd) {
    var p;
    p = Promise.defer();
    promiseList.push(p);
    return spawn(cmd, function() {
      return p.resolve();
    });
  });
  return Promise.when(promiseList);
};

packaging = function(pkgZipFilePath, packagingCmd) {
  if (!isFile(pkgZipFilePath)) {
    return new Promise(function(resolve) {
      var cmd;
      cmd = packagingCmd;
      return spawn(cmd, function() {
        return resolve();
      });
    });
  }
  return new Promise(function(resolve) {
    return rmAsync(pkgZipFilePath)["finally"](function() {
      var cmd;
      cmd = packagingCmd;
      return spawn(cmd, function() {
        return resolve();
      });
    });
  });
};

spawn = function(options, cb) {
  var error, proc, stderr, stdout;
  stdout = [];
  stderr = [];
  error = null;
  options.args.forEach(function(arg) {
    return arg = arg.replace(' ', '\\ ');
  });
  util.log("> " + options.cmd + " " + (options.args.join(' ')));
  proc = childProcess.spawn(options.cmd, options.args, options.opts);
  proc.stdout.on('data', function(data) {
    stdout.push(data.toString());
    if (process.NODE_ENV === 'test') {
      return util.log(data.toString());
    }
  });
  proc.stderr.on('data', function(data) {
    return stderr.push(data.toString());
  });
  return proc.on('exit', function(code, signal) {
    var results;
    if (code !== 0) {
      error = new Error(signal);
    }
    results = {
      stderr: stderr.join(''),
      stdout: stdout.join(''),
      code: code
    };
    if (code !== 0) {
      throw new PluginError(PLUGIN_NAME, results.stderr || 'unknow error , maybe you can try delete the zip packages.');
    }
    return cb(error, results);
  });
};
