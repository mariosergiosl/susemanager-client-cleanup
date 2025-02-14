# susemanager-client-cleanup

This script removes a SUSE Manager client from the system. It should be used on systems that were cloned, are experiencing issues with SUSE Manager client registration, or have encountered problems during the configuration process.

## Features

* **Network tests**: Verify connectivity to the SUSE Manager server using ping, port checks, name resolution, and traceroute.
* **Service control**: Stops SUSE Manager client services and disables them from starting at boot.
* **System backup**: Creates a backup of relevant configuration files and directories before making any changes.
* **Package removal**: Removes all packages related to the SUSE Manager client.
* **File cleanup**: Removes configuration files, logs, and other data associated with the SUSE Manager client.
* **Identifier reset**: Resets system identifiers such as the hostname, machine ID, and network configuration to ensure uniqueness.
* **SSL certificate download**: Optionally downloads the SSL certificate from the SUSE Manager server to resolve certificate errors.

## Usage

USAGE: susemanager-client-cleanup.sh [OPTIONS]

**OPTIONS:**
  
  * **General Options:**
  * `-A`          Perform all steps (backup, cleanup, and reset identifiers). This is the default behavior.)
  * `-h`          Display this help
  
  **Backup Options:**
  * `-nB`          Don't perform a backup of the system configuration. By default, a backup is created.
  
  **Cleanup Options:**
  * `-nC`         Don't perform the cleanup (remove packages and files). By default, cleanup is performed.
  * `-oC`         Only perform the cleanup. This will remove packages and files related to SUSE Manager.
                  A backup will be created unless -nB is also specified.
  **Network Test Options:**
  * `-nT`         Perform network connectivity tests to the SUSE Manager server. This includes ping, 
                  port checks, name resolution, and traceroute tests.
  
  **SUSE Manager Server Options:**
  * `-s <server>` Specify the hostname or IP address of the SUSE Manager server. This is optional 
                  if the server information is already present in the system's configuration files.
  
  **SSL Certificate Options:**
  * `-nD`         Don't download the SSL certificate from the SUSE Manager server. By default, the script
                  attempts to download the certificate.

**EXAMPLES:**

* `susemanager-client-cleanup.sh -A`            # Perform all cleanup steps with backup.
* `susemanager-client-cleanup.sh -oC -nB`       # Only perform cleanup without backup.
* `susemanager-client-cleanup.sh -nT -s my.server.com.br` #  Perform network tests to the specified server.

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
