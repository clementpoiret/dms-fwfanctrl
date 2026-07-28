import QtQuick
import qs.Common

QtObject {
    function check(done) {
        Proc.runCommand("fwFanctrl.startupCheck", [
            "sh",
            "-c",
            "command -v fw-fanctrl >/dev/null 2>&1 && exec fw-fanctrl --help"
        ], (stdout, exitCode) => {
            if (exitCode === 0 && stdout.includes("--output-format") && stdout.includes("JSON")) {
                done(null);
                return;
            }

            done({
                "title": "fw-fanctrl with JSON output support is required",
                "details": "Install a recent version of fw-fanctrl and ensure the `fw-fanctrl` executable is available on DankMaterialShell's PATH.\n\nhttps://github.com/TamtamHero/fw-fanctrl"
            });
        }, 0);
    }
}
