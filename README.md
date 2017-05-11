### Currently porting the code over. Once this line is removed from the Readme all the code will be on GitHub.

# VestaCP-Server-Installer
Install VestaCP with mandatory security changes, etc on CentOS 7

THIS SCRIPT SHOULD BE USED ON A **NEW SERVER**. THIS SCRIPT INSTALLS VESTACP.

#I DO NOT ACCEPT ANY RESPONSIBILITY, SHOULD THIS SCRIPT DAMAGE YOUR SERVER#

## What This VestaCP Server Installer Does:

- Installs VestaCP with: NGINX & PHP-FPM, MariaDB, Named, Remi repository, vsftpd, no firewall (CSF will be installed), Exim, Dovecot, and SpamAssassin.
- Makes the new LetsEncrypt in-built script work properly + creates an SSL certificate for the hostname.
- Installs CSF as a Firewall with common settings.
- Sets the hostname properly (so Exim uses the full hostname), and then prevents the system from editing the file (because of reboots).
- Makes the server use it’s own DNS server to perform lookups. This helps SpamAssassin to reduce more spam. It also prevents the server from editing the file.
- Hardens the /etc/sysctl.conf file for security.
- Enables Dovecot quotas and configures Dovecot performance.
- Installs SpamAssassin rules to help prevent further spam.
- Updates the file /etc/exim/dnsbl.conf to further reduce spam.
- Updates Exim to make sure there is no delay accepting email.
- Fixes NGINX and secures it even further so you receive a A (A+ requires you enable HSTS) at Quality SSL Labs.
- Fixes PHP-FPM to use less memory and crash less often.
- Installs and configures Monit to monitor your server.
- Asks you if you want to install PHP 7. WordPress supports PHP 7.
- Makes websites use HTTP2 instead of HTTP1.1

## Run The Following Commands To Install The VestaCP Server Installer:

```
wget https://vestacp.ss88.uk/VestaCP_Installer/CentOS7.sh -O ./CentOS7.sh
chmod 777 ./CentOS7.sh
sudo ./CentOS7.sh
```

Next hold tight and watch it set-up the server. It may take 15 minutes just securing the server as part of the script generates DH parameters to secure NGINX (this could take up to 1 hour on 1 core DigitalOcean VPS’s).

## Once installed, issue a server reboot with the following command:

`shutdown -r now`
