import path from 'path'
import fs from 'fs'

class SystemStartServiceBase {
  available() {
    return false;
  }

  doesLaunchOnSystemStart() {
    throw new Error("doesLaunchOnSystemStart is not available");
  }

  launchOnSystemStart() {
    throw new Error("launchOnSystemStart is not available")
  }

  dontLaunchOnSystemStart() {
    throw new Error("dontLaunchOnSystemStart is not available")
  }
}

class SystemStartServiceDarwin extends SystemStartServiceBase {
  available() { return true; }

  plistPath() {
    return path.join(process.env.HOME, "Library",
                     "LaunchAgents", "com.nylas.plist");
  }

  launchdPlist() {
    return {
      "Label": "com.nylas.n1",
      "Program": "open",
      "ProgramArguments": ["-a", "'Nylas N1'"],
      "RunAtLoad": true,
    }
  }

  doesLaunchOnSystemStart(callback) {
    return fs.access(this.plistPath(), fs.R_OK | fs.W_OK, callback)
  }

  launchOnSystemStart() {
    fs.writeFile(this.plistPath(), JSON.stringify(this.launchdPlist()))
  }

  dontLaunchOnSystemStart() {
    return fs.unlink(this.plistPath())
  }
}

class SystemStartServiceWin32 extends SystemStartServiceBase {
  available() { return true; }

  shortcutPath() {
    return path.join(process.env.APPDATA, "Microsoft", "Windows",
                     "Start Menu", "Programs", "Startup", "Nylas.lnk")
  }

  doesLaunchOnSystemStart(callback) {
    return fs.access(this.shortcutPath(), fs.R_OK | fs.W_OK, callback)
  }

  launchOnSystemStart() {
    const updatePath = path.join(process.env.LOCALAPPDATA, "nylas",
                                 "Update.exe");
    const ws = require('windows-shortcuts')
    ws.create(this.shortcutPath(), `${updatePath} --processStart nylas.exe`);
  }

  dontLaunchOnSystemStart() {
    return fs.unlink(this.shortcutPath())
  }
}

class SystemStartServiceLinux extends SystemStartServiceBase {

}


let SystemStartService;
if (process.platform === "darwin") {
  SystemStartService = SystemStartServiceDarwin;
} else if (process.platform === "linux") {
  SystemStartService = SystemStartServiceLinux;
} else if (process.platform === "win32") {
  SystemStartService = SystemStartServiceWin32;
} else {
  SystemStartService = SystemStartServiceBase;
}

export default SystemStartService
