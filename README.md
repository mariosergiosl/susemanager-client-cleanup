# susemanager-client-cleanup

This script removes a SUSE Manager client from the system. It should be used on systems that were cloned, are experiencing issues with SUSE Manager client registration, or have encountered problems during the configuration process.

## Features

* Stops SUSE Manager client services
* Backs up SUSE Manager client configuration files
* Removes SUSE Manager client packages
* Cleans up SUSE Manager client files
* Resets system identifiers

## Usage

USAGE: susemanager-client-cleanup.sh [OPTIONS]
OPTIONS:
-A           Perform all steps (default)
-nB          Don't run backup
-nC          Don't run cleanup
-oC          Only run cleanup (run backup if -nB is not set)
-nT          Run network test only
-nD          Don't download SSL certificate
-s <server>  Specify the SUSE Manager server
-h           Display this help
EXAMPLES:
susemanager-client-cleanup.sh -A            # Perform all steps
susemanager-client-cleanup.sh -oC -nB       # Only run cleanup, no backup
susemanager-client-cleanup.sh -nT -s my.server.com.br # Run network test with the specified server

## Disclaimer

This script is provided as-is and without warranty of any kind. Use at your own risk.

## Author

Mario Luz <mario.luz[at]suse.com>

## License

This script is licensed under the MIT License.

## References

* [How to deregister a SUSE Manager Client](https://www.suse.com/support/kb/doc/?id=000018170)
* [A registered client system disappeared from SUSE Manager](https://www.suse.com/support/kb/doc/?id=000018072)
* [zypper commands return "SSL certificate problem: unable to get local issuer certificate" on a SLES 12 SUSE Manager Client](https://www.suse.com/support/kb/doc/?id=000018620)
* [Bootstrap fails with ImportError: cannot import name idn_pune_to_unicode](https://www.suse.com/support/kb/doc/?id=000018753)
* [Attempt to bootstrap a client to a SUSE Manager 3 Server returns "Internal Server Error"](https://www.suse.com/support/kb/doc/?id=000018750)
