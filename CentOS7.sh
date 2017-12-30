#!/bin/bash
# Made by Steven Sullivan
# Copyright Steven Sullivan Ltd
# Version: 1.5 for VestaCP 0.9.8-18
# PLEASE ONLY USE THIS FOR CENTOS 7.X

if [ "x$(id -u)" != 'x0' ]; then
    echo 'Error: this script can only be executed by root'
    exit 1
fi

function StartTheProcess()
{
	read -r -p "Do you want to upgrade PHP 5 to PHP 7? [y/N] " vPhp7
	read -r -p "Do you want to harden sysctl.conf? (This will increase security, but decrease network performance. Recommended for multi-user production servers i.e. web hosting companies) [y/N] " vSysctl
	read -r -p "Do you want to install Softaculous? [y/N] " vSoftaculous
	
	vSoftaculousFull='no';
	
	if [ $vSoftaculous == "y" ] || [ $vSoftaculous == "Y" ]; then
		vSoftaculousFull='yes'
	fi
	
	read -r -p "What is your hostname? " vHostname

	yum clean all
	yum -y install bind-utils
	IPAddress=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/')
	#IPAddress=$(hostname -i)
	DigResult=$(dig @8.8.8.8 +short $vHostname)

	if [ "$IPAddress" != "$DigResult" ]; then
	    echo 'Error: Hostname does not match IP address yet, please wait otherwise LetsEncrypt will not work.'
	    exit 1
	fi

	echo " "
	echo " "

	read -r -p "What e-mail address would you like to receive Monit and VestaCP alerts to? " vEmail
	read -r -p "Please type a password to use with VestaCP and Monit: " vPassword
	read -r -p "Monit needs an SMTP server to use to send email alerts properly. What's your SMTP Hostname? " vSMTPHostname
	read -r -p "What port does the SMTP Hostname listen on (usually 25 or 587)? " vSMTPPort
	read -r -p "What's your SMTP Username (usually a full email address)? " vSMTPEmail
	read -r -p "What's your SMTP Password? " vSMTPPassword

	# ---------------------------------

		# Installing VestaCP

		curl -O http://vestacp.com/pub/vst-install.sh
		bash vst-install.sh --nginx yes --phpfpm yes --apache no --vsftpd yes --proftpd no --exim yes --dovecot yes --spamassassin yes --clamav no --named yes --iptables no --fail2ban no --mysql yes --postgresql no --remi yes --softaculous $vSoftaculousFull --quota no --hostname $vHostname --email $vEmail --password $vPassword
		export VESTA=/usr/local/vesta/
		source /etc/profile
		/usr/local/vesta/bin/v-change-web-domain-ip admin $vHostname $IPAddress y
		/usr/local/vesta/bin/v-change-dns-domain-ip admin $vHostname $IPAddress

	# ---------------------------------

		# Set the hostname and stop it from being edited

		hostname $vHostname
		echo $vHostname > /etc/hostname
		chattr +i /etc/hostname

	# ---------------------------------

		# Make the server use local DNS and stop it from being edited

		echo 'nameserver 127.0.0.1' | cat - /etc/resolv.conf > temp && mv temp /etc/resolv.conf
		chattr +i /etc/resolv.conf
		curl https://raw.githubusercontent.com/SS88UK/VestaCP-Server-Installer/master/CentOS7/named.conf > /etc/named.conf
		/sbin/service named restart


	# ---------------------------------

		# Harden sysctl.conf
		
		if [ $vSysctl == "y" ] || [ $vSysctl == "Y" ]; then

			a="`netstat -i | cut -d' ' -f1 | grep eth0`";
			b="`netstat -i | cut -d' ' -f1 | grep venet0:0`";
			if [ "$a" == "eth0" ]; then
				curl https://raw.githubusercontent.com/SS88UK/VestaCP-Server-Installer/master/CentOS7/sysctl.conf-eth0 > /etc/sysctl.conf
			elif [ "$b" == "venet0:0" ]; then
				curl https://raw.githubusercontent.com/SS88UK/VestaCP-Server-Installer/master/CentOS7/sysctl.conf-venet0 > /etc/sysctl.conf
			fi
			sysctl -p

		fi

	# ---------------------------------

		# Set SpamAssassin Rules + Extras

		curl https://raw.githubusercontent.com/SS88UK/VestaCP-Server-Installer/master/CentOS7/dnsbl.conf > /etc/exim/dnsbl.conf
		curl https://raw.githubusercontent.com/SS88UK/VestaCP-Server-Installer/master/CentOS7/custom_SA-rules.cf > /etc/mail/spamassassin/custom_SA-rules.cf
		sed -i 's/rfc1413_query_timeout = 5s/rfc1413_query_timeout = 0s/' /etc/exim/exim.conf
		curl https://raw.githubusercontent.com/SS88UK/VestaCP-Server-Installer/master/CentOS7/90-quota.conf > /etc/dovecot/conf.d/90-quota.conf
		sed -i 's/mail_plugins = .*/mail_plugins = $mail_plugins autocreate quota imap_quota/' /etc/dovecot/conf.d/20-imap.conf
		echo "mail_max_userip_connections = 50" >> /etc/dovecot/conf.d/10-mail.conf
		echo "mail_fsync = never" >> /etc/dovecot/conf.d/10-mail.conf

	# ---------------------------------

		# Let's fix LetsEncrypt and secure our own server!

		yum -y install vim-common
		#sed -i 's/agreement=.*/agreement="https:\/\/letsencrypt.org\/documents\/LE-SA-v1.1.1-August-1-2016.pdf"/' /usr/local/vesta/bin/v-add-letsencrypt-user
		/usr/local/vesta/bin/v-add-letsencrypt-domain admin $vHostname

		if [ -f /home/admin/conf/web/ssl.$vHostname.pem ]; then
		
			rm -f /usr/local/vesta/ssl/certificate.crt
			ln -s /home/admin/conf/web/ssl.$vHostname.pem /usr/local/vesta/ssl/certificate.crt
			chown -h root:mail /usr/local/vesta/ssl/certificate.crt

		fi

		if [ -f /home/admin/conf/web/ssl.$vHostname.key ]; then
		
			rm -f /usr/local/vesta/ssl/certificate.key
			ln -s /home/admin/conf/web/ssl.$vHostname.key /usr/local/vesta/ssl/certificate.key
			chown -h root:mail /usr/local/vesta/ssl/certificate.key

		fi

	# ---------------------------------

		# Let's fix NGINX up! This will take a very long time.

		if [ ! -f /etc/nginx/dhparams.pem ]; then
		
			openssl dhparam -dsaparam -out /etc/nginx/dhparams.pem 4096

		fi

		curl https://raw.githubusercontent.com/SS88UK/VestaCP-Server-Installer/master/CentOS7/nginx.conf > /etc/nginx/nginx.conf

	# ---------------------------------

		# Let's fix PHP-FPM

		curl https://raw.githubusercontent.com/SS88UK/VestaCP-Server-Installer/master/CentOS7/default.tpl > /usr/local/vesta/data/templates/web/php-fpm/default.tpl
		curl https://raw.githubusercontent.com/SS88UK/VestaCP-Server-Installer/master/CentOS7/socket.tpl > /usr/local/vesta/data/templates/web/php-fpm/socket.tpl
		/usr/local/vesta/bin/v-rebuild-web-domains admin
		
	# ---------------------------------

		# Make it HTTP2 and SPDY
		
		sed -i 's/\%web_ssl_port\%/\%web_ssl_port\% ssl http2/' /usr/local/vesta/data/templates/web/nginx/php-fpm/*.stpl
		sed -i 's/\%web_port\%/\%web_port\% spdy/' /usr/local/vesta/data/templates/web/nginx/php-fpm/*.tpl

	# ---------------------------------

		# Let's install Monit & Configure it

		yum -y install monit
		curl https://raw.githubusercontent.com/SS88UK/VestaCP-Server-Installer/master/CentOS7/monitrc > /etc/monitrc
		sed -i "s/vPassword/$vPassword/" /etc/monitrc
		sed -i "s/vEmail/$vEmail/" /etc/monitrc
		sed -i "s/IPAddress/$IPAddress/" /etc/monitrc
		sed -i "s/vSMTPEmail/$vSMTPEmail/" /etc/monitrc
		sed -i "s/vSMTPPassword/$vSMTPPassword/" /etc/monitrc
		sed -i "s/vSMTPHostname/$vSMTPHostname/" /etc/monitrc
		sed -i "s/vSMTPPort/$vSMTPPort/" /etc/monitrc
		chkconfig monit on

	# ---------------------------------

		# Let's install CSF

		yum -y install perl-libwww-perl perl-LWP-Protocol-https
		curl https://vestacp.ss88.uk/Install_CSF_on_VestaCP/Install.sh > ./InstallCSF.sh
		chmod 777 ./InstallCSF.sh
		sudo ./InstallCSF.sh
		curl https://raw.githubusercontent.com/SS88UK/VestaCP-Server-Installer/master/CentOS7/csf.conf > /etc/csf/csf.conf
		sed -i "s/vEmail/$vEmail/" /etc/csf/csf.conf
		curl https://raw.githubusercontent.com/SS88UK/CSF-Custom-Regex-for-VestaCP/master/regex.custom.pm > /etc/csf/regex.custom.pm

	# ---------------------------------

		# Install PHP 7

		if [ $vPhp7 == "y" ] || [ $vPhp7 == "Y" ]; then

			service php-fpm stop
			yum -y --enablerepo=remi install php70-php php70-php-pear php70-php-bcmath php70-php-pecl-jsond-devel php70-php-mysqlnd php70-php-gd php70-php-common php70-php-fpm php70-php-intl php70-php-cli php70-php php70-php-xml php70-php-opcache php70-php-pecl-apcu php70-php-pecl-jsond php70-php-pdo php70-php-gmp php70-php-process php70-php-pecl-imagick php70-php-devel php70-php-mbstring
			rm -f /usr/bin/php
			ln -s /usr/bin/php70 /usr/bin/php
			sed -i 's/include=.*/include=\/etc\/php-fpm.d\/\*\.conf/' /etc/opt/remi/php70/php-fpm.conf
			sed -i 's/;pid/pid/' /etc/opt/remi/php70/php-fpm.conf
			service php70-php-fpm restart
			rm -f /usr/lib/systemd/system/php-fpm.service
			ln -s /usr/lib/systemd/system/php70-php-fpm.service /usr/lib/systemd/system/php-fpm.service
			systemctl daemon-reload
			yum -y install yum-utils
			yum-config-manager --disable remi-php56 remi-php55 remi-test
			sed -i "s/\/var\/run\/php-fpm\/php-fpm.pid/\/var\/opt\/remi\/php70\/run\/php-fpm\/php-fpm.pid/" /etc/monitrc

		fi


		echo "Done!";
		echo " ";
		echo "You can access VestaCP here: https://$vHostname:8083/";
		echo "Username: admin";
		echo "Username: $vPassword";
		echo " ";
		echo " ";
		echo "You can access Monit here (always best to use IP address: http://$IPAddress:2812/";
		echo "Username: admin";
		echo "Username: $vPassword";
		echo " ";
		echo "Have fun! Visit https://blog.ss88.uk/ for more great tutorials!";
		echo " ";
		echo "PLEASE REBOOT THE SERVER ONCE YOU HAVE COPIED THE DETAILS ABOVE. REBOOT COMMAND:    shutdown -r now";
}





echo "IMPORTANT! Make sure you have VestaCP install and are running CentOS 7.x";
read -r -p "Do you want to continue? [y/N] " response
case $response in
    [yY][eE][sS]|[yY]) 
        StartTheProcess
        ;;
    *)
        echo "OK. Bye bye.";
        ;;
esac



