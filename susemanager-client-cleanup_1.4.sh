#!/bin/bash
# =======================================================================================
#
#  FILE: susemanager-client-cleanup_1.4.bash
#
#  USAGE: susemanager-client-cleanup_1.4.bash
#
#  DESCRIPTION: Removes a SUSE Manager client from the system.
#               This script should be used on systems that were cloned,
#               are experiencing issues with SUSE Manager client registration,
#               or have encountered problems during the configuration process.
#
#  REQUIREMENTS:
#
#  BUGS:
#
#  NOTES:
#
#  DISCLAIMER: This script is provided as-is and without warranty of any kind.
#              Use at your own risk.
#
#  REFERENCES:
#   - How to deregister a SUSE Manager Client
#     TID 7013242 - https://www.suse.com/support/kb/doc/?id=000018170
#   - A registered client system disappeared from SUSE Manager
#     TID 7012170 - https://www.suse.com/support/kb/doc/?id=000018072
#   - How to deregister a SUSE Manager Client
#     TID 7013242 - https://www.suse.com/support/kb/doc/?id=000018170
#   - zypper commands return "SSL certificate problem: unable to get local issuer certificate" on a SLES 12 SUSE Manager Client
#     TID 7017147 - https://www.suse.com/support/kb/doc/?id=000018620
#   - Bootstrap fails with ImportError: cannot import name idn_pune_to_unicode
#     TID 7018018 - https://www.suse.com/support/kb/doc/?id=000018753
#   - Attempt to bootstrap a client to a SUSE Manager 3 Server returns "Internal Server Error"
#     TID 7017994 - https://www.suse.com/support/kb/doc/?id=000018750
#
#
#  AUTHOR:  Mario Luz <mario.luz[at]suse.com>
#  COMPANY:  SUSE
#
#  VERSION: 1.4
#  CREATED: 2024-02-12
#  REVISION:
#
# =======================================================================================

##########################################################################################
## VARIABLES
##########################################################################################
# --- CONSTANTES ---
SUSE_MANAGER_SERVER=""
TIMESTAMP_FORMAT="+%Y%m%d_%H%M%S"
LOG_FILE_PREFIX="susemanager_cleanup_"
BACKUP_DIR_PREFIX="susemanager_backup_"

# --- VARIABLES ---
timestamp=$(date "$TIMESTAMP_FORMAT")
log_file="${LOG_FILE_PREFIX}${timestamp}.log"
backup_dir="${BACKUP_DIR_PREFIX}${timestamp}"

##########################################################################################
## CHECKS
##########################################################################################
# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "$(date +%Y-%m-%d_%H:%M:%S) ERRO: This script needs root privileges!"
    exit 1
fi

##########################################################################################
## HELP
##########################################################################################
print_help() {
  echo "
  USAGE: $(basename "$0") [OPTIONS]

  OPTIONS:
    -A           Perform all steps (default)
    -nB          Don't run backup
    -nC          Don't run cleanup
    -oC          Only run cleanup (run backup if -nB is not set)
    -nT          Run network test only
    -s <server>  Specify the SUSE Manager server
    -h           Display this help

  EXAMPLES:
    $(basename "$0") -A            # Perform all steps
    $(basename "$0") -oC -nB       # Only run cleanup, no backup
    $(basename "$0") -nT -s my.server.com.br # Run network test with the specified server
  "
}

# Check if help was requested
if [[ "$1" == "-h" ]]; then
  print_help
  exit 0
fi

# Check if no options were provided
if [[ $# -eq 0 ]]; then
  echo "No options provided."
  print_help
  exit 0
fi

# Set default options
use_option_A="false"
use_option_nB="false"
use_option_nC="true"
use_option_nD="true"
use_option_oC="false"
use_option_nT="false"
use_option_s="false"

# Process command line options
while getopts "ABCn:o:s:hD" option; do
  case $option in
    A) use_option_A="true";;
    n)
      case ${OPTARG} in
        B) use_option_nB="true";;
        C) use_option_nC="true";;
        T) use_option_nT="true";;
        D) use_option_nD="true";;
      esac
  ;;
    o)
      case ${OPTARG} in
        C) use_option_oC="true";;
      esac
  ;;
    s) use_option_s="true"
       SUSE_MANAGER_SERVER="$OPTARG";;
    h) print_help; exit 0;;
    *) echo "Invalid option: -$OPTARG"; print_help; exit 1;;
  esac
done

##########################################################################################
## PREPARATION
##########################################################################################
# Create backup directory
if [[ "$use_option_nT" == "false" && "$use_option_nB" == "false" ]]; then
  mkdir -p "$backup_dir"
fi

# Create log file
exec >> "$log_file" 2>&1

# Redirect standard output and error to the log file
exec 2>&1

##########################################################################################
## FUNCTIONS
##########################################################################################
#===
# FUNCTION: check_command
# DESCRIPTION: Check if a command exists on the system.
# PARAMETER 1: Command name
#===
check_command() {
  local cmd="$1"
  if ! command -v "$cmd" &> /dev/null; then
    return 1
  fi
  return 0
}

#===
# FUNCTION: exec_command
# DESCRIPTION: Execute a command and log the output and return code to the log file.
# PARAMETER 1: Command to execute.
#===
exec_command() {
  local cmd="$1"
  echo "$(date +%Y-%m-%d_%H:%M:%S) Executing: $cmd"
  output=$($cmd 2>&1)
  return_code=$?
  echo "$output"
  if [[ $return_code -ne 0 ]]; then
      echo "$(date +%Y-%m-%d_%H:%M:%S) Error during execution (code $return_code)."
  fi
  return $return_code
}

#===
# FUNCTION: ping_test
# DESCRIPTION: Execute a ping test on a given target.
# PARAMETER 1: Ping target.
#===
ping_test() {
  local target="$1"
  echo "$(date +%Y-%m-%d_%H:%M:%S) Ping Test ($target)"
  exec_command "ping -c 4 $target"
}

#===
# FUNCTION: nc_test
# DESCRIPTION: Execute a connection test on multiple ports using nc.
# PARAMETER 1: Test target.
# Execute a connection test on multiple ports using nc.
# Parameter 1: Test target.
# Ports used by SUSE Manager:
# 22 (TCP): SSH (secure remote access)
# 80 (TCP): HTTP (bootstrap repositories and automated installations)
# 443 (TCP): HTTPS (web interface, communication with clients and proxy)
# 4505 (TCP): Salt (client requests to the Salt master)
# 4506 (TCP): Salt (results from clients to the Salt master)
# 5222 (TCP): osad (sending osad actions to clients)
# 5269 (TCP): jabberd (actions to and from proxy)
# 25151 (TCP): Cobbler (operating system provisioning)
#===
nc_test() {
  local target="$1"
  echo "$(date +%Y-%m-%d_%H:%M:%S) --- Port Test with nc ($target) ---"
  for porta in 22 80 443 4505 4506 5222 5269 25151; do
    exec_command "nc -zv $target $porta"
  done
}

#===
# FUNCTION: nslookup_test
# DESCRIPTION: Execute a name resolution test using nslookup, dig or host.
# PARAMETER 1: Hostname to be resolved.
#===
nslookup_test() {
  local target="$1"
  echo "$(date +%Y-%m-%d_%H:%M:%S) --- Name Resolution Test ($target) ---"
  if check_command nslookup; then
    echo "$(date +%Y-%m-%d_%H:%M:%S) Using nslookup..."
    exec_command "nslookup $target"
  elif check_command dig; then
    echo "$(date +%Y-%m-%d_%H:%M:%S) Using dig..."
    exec_command "dig $target"
  elif check_command host; then
    echo "$(date +%Y-%m-%d_%H:%M:%S) Using host..."
    exec_command "host $target"
  else
    echo "$(date +%Y-%m-%d_%H:%M:%S) Warning: nslookup, dig, host unavailable."
  fi
}

#===
# FUNCTION: traceroute_test
# DESCRIPTION: Executes a traceroute test on a given target.
# PARAMETER 1: Traceroute target.
#===
traceroute_test() {
  local target="$1"
  echo "$(date +%Y-%m-%d_%H:%M:%S) --- Traceroute Test ($target) ---"
  if check_command traceroute; then
      exec_command "traceroute $target"
  fi
}

#===
# FUNCTION: get_ip_from_sumaservername
# DESCRIPTION: Gets the IP address of a given hostname.
# PARAMETER 1: Hostname.
#===
get_ip_from_sumaservername() {
  local sumaservername="$1"
  #local SUSE_MANAGER_SERVER="$1"
  local ip=""

  # Ping resolution attempt
  if check_command ping; then
    ip=$(ping -c 1 "$sumaservername" | awk -F'[()]' '/PING/{print $2}')
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return 0
    fi
  fi

  # DNS resolution attempts
  if check_command nslookup; then
    ip=$(nslookup "$sumaservername" | awk '/^Address: / { print $2; exit }')
  elif check_command dig; then
    ip=$(dig +short "$sumaservername" | tail -n 1)
  elif check_command host; then
    ip=$(host "$sumaservername" | awk '{print $4; exit}')
  fi

  # Check if an IP address was found
  if [[ -z "$ip" ]]; then
    echo "$(date +%Y-%m-%d_%H:%M:%S) Error: Could not resolve IP address for $sumaservername"
    return 1
  fi

  echo "$ip"
}

##########################################################################################
## INITIAL INFORMATION
##########################################################################################
echo "#######################################################################################"
echo "$(date +%Y-%m-%d_%H:%M:%S) --- Initial Information ---"
echo "#######################################################################################"
echo "timestamp= " $timestamp
echo "log_file= " $log_file
echo "backup_dir= " $backup_dir
if [[ -f /etc/os-release ]]; then
    SLES_VERSION=$(cat /etc/os-release | grep VERSION_ID | cut -d'"' -f2 | cut -d'.' -f1)
    echo "/etc/os-release"
elif [[ -f /etc/SuSE-release ]]; then
    SLES_VERSION=$(cat /etc/SuSE-release | head -n 1 | awk '{print $3}')
    echo "/etc/SuSE-release"
else
    SLES_VERSION="unknown"
fi

echo "SLES_VERSION= " $SLES_VERSION

##########################################################################################
## CAPTURING SUSE MANAGER INFORMATION
##########################################################################################
# Check if -s was informed
if [[ -n "$SUSE_MANAGER_SERVER" ]]; then  # Verifica se -s foi informado
  echo "Ignoring SUSE Manager server information from configuration files."
  echo "User provided the address for connection tests: $SUSE_MANAGER_SERVER"
else
  echo "#######################################################################################"
  echo "$(date +%Y-%m-%d_%H:%M:%S) --- Capturing SUSE Manager Information ---"
  echo "#######################################################################################"
  echo "$(date +%Y-%m-%d_%H:%M:%S) Searching for configuration files..."

  # Searching in file /etc/rhsm/rhsm.conf (SLES 12 e 15)
  echo "$(date +%Y-%m-%d_%H:%M:%S) Searching in file /etc/rhsm/rhsm.conf..."
  if [[ -f /etc/rhsm/rhsm.conf ]]; then
    SUSE_MANAGER_SERVER=$(grep ^hostname /etc/rhsm/rhsm.conf | cut -d= -f2 | tr -d '[:space:]')
    #SUSE_MANAGER_SERVER=$(grep ^hostname /etc/rhsm/rhsm.conf | awk -F= '{print $2}')
    echo "$(date +%Y-%m-%d_%H:%M:%S) /etc/rhsm/rhsm.conf: $SUSE_MANAGER_SERVER"
  fi

  # Searching in file /etc/sysconfig/rhn/up2date (SLES 11)
  echo "$(date +%Y-%m-%d_%H:%M:%S) Searching in file /etc/sysconfig/rhn/up2date..."
  if [[ -z "$SUSE_MANAGER_SERVER" ]] && [[ -f /etc/sysconfig/rhn/up2date ]]; then
    SUSE_MANAGER_SERVER=$(grep ^serverURL /etc/sysconfig/rhn/up2date | cut -d/ -f3 | tr -d '[:space:]')
    echo "$(date +%Y-%m-%d_%H:%M:%S) /etc/sysconfig/rhn/up2date: $SUSE_MANAGER_SERVER"
  fi

  # Searching in file susemanager.conf
  echo "$(date +%Y-%m-%d_%H:%M:%S) Searching in file susemanager.conf..."
  if [[ -z "$SUSE_MANAGER_SERVER" ]]; then
    SUSE_MANAGER_CONF=$(find /etc/ -type f -name "susemanager.conf" 2>/dev/null | head -n 1)
    echo "$(date +%Y-%m-%d_%H:%M:%S) susemanager.conf: $SUSE_MANAGER_CONF"
    if [[ -n "$SUSE_MANAGER_CONF" ]]; then
      SUSE_MANAGER_SERVER=$(grep ^master "$SUSE_MANAGER_CONF" | cut -d: -f2 | tr -d '[:space:]')
      echo "$(date +%Y-%m-%d_%H:%M:%S) $SUSE_MANAGER_CONF: $SUSE_MANAGER_SERVER"
    fi
  fi

  # Use the environment variable as a last resort
  echo "$(date +%Y-%m-%d_%H:%M:%S) Searching in environment variable SUSE_MANAGER_SERVER..."
  if [[ -z "$SUSE_MANAGER_SERVER" ]] && [[ -n "$SUSE_MANAGER_SERVER_ENV" ]]; then
    echo "$(date +%Y-%m-%d_%H:%M:%S) SUSE Manager not found in configuration files. Using variable SUSE_MANAGER_SERVER_ENV"
    SUSE_MANAGER_SERVER="$SUSE_MANAGER_SERVER_ENV"
    echo "$(date +%Y-%m-%d_%H:%M:%S) Using environment variable SUSE_MANAGER_SERVER: $SUSE_MANAGER_SERVER"
  fi

  if [[ -n "$SUSE_MANAGER_SERVER" ]]; then
    echo "$(date +%Y-%m-%d_%H:%M:%S) SUSE Manager: $SUSE_MANAGER_SERVER"
  else
    echo "$(date +%Y-%m-%d_%H:%M:%S) SUSE Manager: Data not available."
  fi
fi

# Get the IP address of the SUSE Manager server
if [[ -n "$SUSE_MANAGER_SERVER" ]]; then
  SUSE_MANAGER_IP=$(get_ip_from_sumaservername "$SUSE_MANAGER_SERVER")
else
  SUSE_MANAGER_IP="Data not available"
fi

if [[ -n "$SUSE_MANAGER_IP" ]]; then
  echo "$(date +%Y-%m-%d_%H:%M:%S) SUSE Manager IP: $SUSE_MANAGER_IP"
else
  echo "$(date +%Y-%m-%d_%H:%M:%S) SUSE Manager IP: Data not available."
fi

##########################################################################################
## SUSE MANAGER CONNECTIVITY TESTS
##########################################################################################
# Check if option -A was used without -s or --server, or if option -nT was used
if [[ ("$use_option_A" == "true" && "$use_option_s" == "false") || "$use_option_nT" == "true" ]]; then
  echo "#######################################################################################"
  echo "$(date +%Y-%m-%d_%H:%M:%S) --- SUSE Manager Connectivity Tests ---"
  echo "#######################################################################################"

  # If SUSE_MANAGER_SERVER is still empty, prompt the user
  if [[ -z "$SUSE_MANAGER_SERVER" && "$use_option_s" == "false" ]]; then
    echo "$(date +%Y-%m-%d_%H:%M:%S) No SUSE Manager server information found in configuration files." | tee -a "$log_file" /dev/tty
    echo "$(date +%Y-%m-%d_%H:%M:%S) Please use the -s option to specify the server and run the tests." | tee -a "$log_file" /dev/tty
    exit 1  # Sai do script com erro
  fi

  # If the user has provided the server, perform the tests
  if [[ -n "$SUSE_MANAGER_SERVER" ]]; then
    echo "$(date +%Y-%m-%d_%H:%M:%S) Using $SUSE_MANAGER_SERVER for connectivity tests."

    # Check and install the nc command, if necessary
    echo "$(date +%Y-%m-%d_%H:%M:%S) Checking for nc command..."
    if check_command nc; then
      zypper -n in netcat-openbsd 2>&1
    fi

    # Perform connectivity tests by hostname
    echo "$(date +%Y-%m-%d_%H:%M:%S) --- Connectivity Tests by name ---"
    target="$SUSE_MANAGER_SERVER"
    ping_test "$target"
    nc_test "$target"
    nslookup_test "$target"
    traceroute_test "$target"

    # Get the IP address of the SUSE Manager and perform tests by IP
    echo "$(date +%Y-%m-%d_%H:%M:%S) --- Connectivity Tests by IP ---"
    SUSE_MANAGER_IP=$(get_ip_from_sumaservername "$SUSE_MANAGER_SERVER")
    if [[ -n "$SUSE_MANAGER_IP" ]]; then
      target="$SUSE_MANAGER_IP"
      ping_test "$target"
      nc_test "$target"
      traceroute_test "$target"
    else
      echo "$(date +%Y-%m-%d_%H:%M:%S) Could not resolve IP address for $SUSE_MANAGER_SERVER"
    fi
  else
    echo "$(date +%Y-%m-%d_%H:%M:%S) Skipping connectivity tests."
  fi
fi

##########################################################################################
## STOP SERVICES
##########################################################################################
# Check if -oC or -A were used
if [[ "$use_option_oC" == "true" || "$use_option_A" == "true" ]]; then
  echo "#######################################################################################"
  echo "$(date +%Y-%m-%d_%H:%M:%S) --- Stop Services ---"
  echo "#######################################################################################"

  # Commands to stop the services
  services=(
    "killall -9 rhn_check"
    "service susemanager-client stop"
    "chkconfig susemanager-client off"
    "service rhnsd stop"
    "chkconfig rhnsd off"
    "rcsalt-minion stop 2>/dev/null"
    "chkconfig salt-minion off 2>/dev/null"
    "systemctl stop susemanager-client"
    "systemctl disable susemanager-client"
    "systemctl stop rhnsd"
    "systemctl disable rhnsd"
    "systemctl stop salt-minion"
    "systemctl disable salt-minion"
    "systemctl stop osad"
    "systemctl disable osad"
  )

  # Execute commands using exec_command
  for service_command in "${services[@]}"; do
    exec_command "$service_command"
  done
fi

##########################################################################################
## SYSTEM BACKUP
##########################################################################################
# Check if -nB was not used or if -oC or -A were used
if [[ "$use_option_nB" == "false" && "$use_option_oT" == "false" ]]; then
  echo "#######################################################################################"
  echo "$(date +%Y-%m-%d_%H:%M:%S) --- System Backup ---"
  echo "#######################################################################################"

  # list of installed packages
  rpm -qa | grep -E 'spacewalk|rhn-client-tools|rhnlib|salt' > "$backup_dir/lista_pacotes.txt"

  # Backup with tar.gz
  echo "$(date +%Y-%m-%d_%H:%M:%S) Backing up with tar.gz..."
  BACKUP_PATHS=(
      "/etc/zypp/repos.d"
      "/etc/venv-salt-minion"
      "/etc/sysconfig/rhn"
      "/etc/salt"
      "/var/lib/rhn"
      "/var/cache/salt"
      "/etc/hostid"
      "/var/lib/YaST2/install.inf"
      "/var/lib/zypp/AnonymousUniqueId"
      "/etc/sysconfig/rhn/osad-auth.conf"
      "/etc/sysconfig/rhn/systemid"
      "/etc/zypp/credentials.d/NCCcredentials"
      "/etc/zmd/deviceid"
      "/etc/sysconfig/susemanager"
      "/var/lib/susemanager"
      "/etc/susemanager"
  )

  for path in "${BACKUP_PATHS[@]}"; do
      if [[ -e "$path" ]]; then
          backup_tar="${backup_dir}$(echo "$path" | tr '/' '_').tar.gz"
          echo "$(date +%Y-%m-%d_%H:%M:%S) Creating backup of $path to $backup_tar"
          tar -czvf "$backup_dir"/"$backup_tar" "$path" 2>&1
      else
          echo "$(date +%Y-%m-%d_%H:%M:%S) Warning: $path not found. Backup ignored"
      fi
  done
fi

##########################################################################################
## REMOVE PACKAGES
##########################################################################################
# Check if -nC was not used or if -oC or -A were used
if [[ "$use_option_nC" == "false" || "$use_option_oC" == "true" || "$use_option_A" == "true" ]]; then
  echo "#######################################################################################"
  echo "$(date +%Y-%m-%d_%H:%M:%S) --- Remove Packages ---"
  echo "#######################################################################################"

  # List of packages to remove
  packages=(
    "susemanager-client"
    "venv-salt-minion"
    "salt-minion"
    "rhn-client-tools"
    "rhnlib"
    "spacewalk-client-tools"
    "spacewalk-client-setup"
    "'zypp-plugin-spacewalk'"
    "'spacewalk*'"
    "'rhn*'"
    "spacewalk-client*"
    "rhn-client-tools*"
    "rhnlib*"
    "salt*"
  )

  # Remove packages using exec_command
  for package in "${packages[@]}"; do
    exec_command "zypper --non-interactive rm $package"
  done
 
  # Remove repositories
  zypper lr
  exec_command "zypper clean --all"
  for repo_alias in $(zypper lr --uri | awk '/sles|suma|susemanager/ {print $3}'); do
    exec_command "zypper rr $repo_alias"
  done

  # Checking for the second time - On some systems the command zypper rr does not remove all repositories
  for repo_alias in $(zypper lr --uri | awk '/sles|suma|susemanager/ {print $3}'); do
    exec_command "zypper rr $repo_alias"
  done

  # Removing susemanager-client, using yum...
  echo "$(date +%Y-%m-%d_%H:%M:%S) Removing susemanager-client, using yum..."
  yum remove -y susemanager-client
fi

##########################################################################################
## REMOVING FILES
##########################################################################################
# Check if -nC was not used or if -oC or -A were used
if [[ "$use_option_nC" == "false" || "$use_option_oC" == "true" || "$use_option_A" == "true" ]]; then
  echo "#######################################################################################"
  echo "$(date +%Y-%m-%d_%H:%M:%S) --- Cleaning the System ---"
  echo "#######################################################################################"

  # --- File cleanup ---
  echo "$(date +%Y-%m-%d_%H:%M:%S) Removing configuration files..."

  # List of files and directories to remove
  files_to_remove=(
    "/etc/sysconfig/susemanager*"
    "/var/lib/susemanager*"
    "/etc/susemanager*"
    "/etc/rhn/*"
    "/var/spool/rhn/*"
    "/var/lib/yum/rhn/*"
    "/var/log/susemanager*"
    "/var/lib/zypp/rhn/*"
    "/etc/sysconfig/rhn/{osad-auth.conf,systemid}"
    "/etc/zypp/credentials.d/NCCcredentials"
    "/etc/zmd/deviceid"
    "/etc/sysconfig/rhn"
    "/etc/salt"
    "/var/lib/rhn"
    "/var/cache/salt"
    "/etc/venv-salt-minion"
    "/var/log/salt*"
  )

  # Remove files and directories using exec_command
  for file in "${files_to_remove[@]}"; do
    exec_command "rm -rf $file"
  done
fi

##########################################################################################
## RESET IDENTIFIERS
##########################################################################################
# Check if -nC was not used or if -oC or -A were used
if [[ "$use_option_nC" == "false" || "$use_option_oC" == "true" || "$use_option_A" == "true" ]]; then
  echo "#######################################################################################"
  echo "$(date +%Y-%m-%d_%H:%M:%S) --- Reset Identifiers ---"
  echo "#######################################################################################"
  echo "$(date +%Y-%m-%d_%H:%M:%S) --- Reconfiguring unique identifiers ---"

  # Clear virtual hardware ID and YaST installation ID
  # List of files to remove
  files_to_remove=(
    "/etc/hostid"
    "/var/lib/dbus/machine-id"
    "/etc/machine-id"
    "/var/lib/YaST2/install.inf"
    "/var/lib/zypp/AnonymousUniqueId"
    "/etc/sysconfig/hwcfg*"
  )

  # Remove files using exec_command
  for file in "${files_to_remove[@]}"; do
    exec_command "rm -f $file"
  done

  # Run commands to generate new IDs
  exec_command "/usr/sbin/s390-tools/mk_hostid"
  exec_command "dbus-uuidgen --ensure"
  exec_command "systemd-machine-id-setup"
  exec_command "c_rehash"

  echo "$(date +%Y-%m-%d_%H:%M:%S) uuidgen generating new machine-id"
  uuidgen > /etc/machine-id
  echo "$(date +%Y-%m-%d_%H:%M:%S) machine-id: $(cat /etc/machine-id)" 

  echo "$(date +%Y-%m-%d_%H:%M:%S) dbus-uuidgen generating new machine-id"
  dbus-uuidgen > /var/lib/dbus/machine-id
  echo "$(date +%Y-%m-%d_%H:%M:%S) dbus-machine-id: $(cat /var/lib/dbus/machine-id)"
fi

##########################################################################################
## DOWNLOAD SSL CERTIFICATE FROM SUSE MANAGER
##########################################################################################
# Check if -nD and -nT were not used
if [[ "$use_option_nD" == "false"  && "$use_option_nT" == "false" ]]; then # Check if -nD was not used
  echo "#######################################################################################"
  echo "$(date +%Y-%m-%d_%H:%M:%S) --- Download SSL SSL Certificate from SUSE Manager ---"
  echo "#######################################################################################"
  if [[ -n "$SUSE_MANAGER_SERVER" ]]; then
    # Check if ports 80 and 443 are open
    if nc -zv "$SUSE_MANAGER_SERVER" 80 &> /dev/null && nc -zv "$SUSE_MANAGER_SERVER" 443 &> /dev/null; then
      if [[ -n "$SUSE_MANAGER_SERVER" ]]; then
        echo "$(date +%Y-%m-%d_%H:%M:%S) Trying to download the SSL certificate from SUSE Manager from: $SUSE_MANAGER_SERVER"

        # Use HTTPS instead of HTTP (more secure)
        # Download the certificate to a more specific temporary file
        CERT_FILE="/tmp/susemanager-cert.pem"

        wget -q --show-progress "https://$SUSE_MANAGER_SERVER/pub/RHN-ORG-TRUSTED-SSL-CERT" -O "$CERT_FILE" 2>&1

        if [[ $? -eq 0 ]]; then
          echo "$(date +%Y-%m-%d_%H:%M:%S) SSL certificate successfully downloaded to: $CERT_FILE"

          # Extract only the certificate (remove other information)
          # Here, we are using a more robust method to extract the certificate, "GO HORSE", which should work even if the file has extra information.
          awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' "$CERT_FILE" > "$CERT_FILE.extracted"
          # Simpler but less robust alternative:
          # openssl s_client -showcerts -connect <servidor_suma>:443 </dev/null 2>/dev/null | openssl x509 -outform PEM > /tmp/certificado_suma.pem

          if [[ -f "$CERT_FILE.extracted" && -s "$CERT_FILE.extracted" ]]; then # check if the file was created and is not empty
              echo "$(date +%Y-%m-%d_%H:%M:%S) SSL certificate successfully extracted to: $CERT_FILE.extracted"
              # Install the certificate (adapt the path as needed)
              # This example installs to the system certificate directory (recommended)
              sudo cp "$CERT_FILE.extracted" /etc/pki/trust/anchors/
              sudo c_rehash

              # Or, if you need it in a specific location (like /opt/opsware/openssl/cert.pem)
              # sudo cat "$CERT_FILE.extracted" >> /opt/opsware/openssl/cert.pem
              echo "$(date +%Y-%m-%d_%H:%M:%S) Certificate installed. c_rehash executed"

          else
              echo "$(date +%Y-%m-%d_%H:%M:%S) Failed to extract certificate."
          fi
          rm "$CERT_FILE" "$CERT_FILE.extracted" # Clean up temporary files

        else
          echo "$(date +%Y-%m-%d_%H:%M:%S) Failed to download the SSL certificate from: $SUSE_MANAGER_SERVER"
        fi
    else
      echo "$(date +%Y-%m-%d_%H:%M:%S) Variable SUSE_MANAGER_SERVER not defined. Configure it before running the script."
      fi
    else
      echo "$(date +%Y-%m-%d_%H:%M:%S) Connectivity test failed on ports 80 and 443. Skipping SSL certificate download."
    fi
  else
    echo "$(date +%Y-%m-%d_%H:%M:%S) Variable SUSE_MANAGER_SERVER not defined. Skipping SSL certificate download."
  fi
fi

##########################################################################################
## FINALIZATION
##########################################################################################
echo "#######################################################################################"
echo "$(date +%Y-%m-%d_%H:%M:%S) --- Finalization ---"
echo "#######################################################################################"
# Compressing logs and backup files
if [[ "$use_option_nT" == "false" ]]; then
  echo "$(date +%Y-%m-%d_%H:%M:%S) Compressing logs and backup files"
  tar -czvf "susemanager_cleanup_${timestamp}.tgz" "$log_file" "$backup_dir"  2>&1
  echo "#######################################################################################"
  echo "$(date +%Y-%m-%d_%H:%M:%S) --- End ---"
  echo "#######################################################################################"
  echo "$(date +%Y-%m-%d_%H:%M:%S) Cleaning completed. If possible restart the system"
fi