#**Raspberry PI 3 configuration**

Various configurations and settings, for using a Raspberry PI 3.
All/most of the information can be found on the internet, but I could not locate any source that would provide it all in one place.

##**Home Gateway**

This allows using the RBPI3 as replacement for the typical AP that is popular as home appliance.
The PI has only one built in network interface, however it sports 4 USB ports. One of them can be fitted with a USB-to-Ethernet adapter. Unfortunately the USB ports available are only of type 2, which will be a bottleneck for certain high speed home connections. However it doesn't present a problem for slower ones.
Should this become a problem, then it's advisable to replace the PI3 with a better HW, but most of the configuration will still work. The only part that might need adjustment is the configuration of hostapd for the WIFI driver.

###**Disabling unnecessary services**
The basic image has several services that are useless for a Gateway setup.
 - **lightdm:** the device works in headless, remote mode, it is intended to be controlled over ssh, so we might as well turn off graphic mode entirely.
 - **avahi-daemon:** I do not have any need for this, so off it goes, but of course ymmv.
 - **triggerhappy:** again, only networking is needed.
 - **autologin@tty1.service:** no need for serial login to a remote device.

````
systemctl stop lightdm
systemctl disable lightdm
systemctl stop avahi-daemon
systemctl disable avahi-daemon
systemctl stop triggerhappy
systemctl disable triggerhappy
systemctl stop autologin@tty1.service
systemctl disable autologin@tty1.service
````

###**Basic description of services to configure and enable**

 - **dhcp client:** the main issue with the client is that it must not try to use the wlan interface; the modification to the configuration file is to make the dhcp client ignore the wifi interface.
 - **hostapd:** is responsible of exposing the wifi interface as AP. Part of this configuration is HW-specific and therefore will require adjustments in case one wants to use a different WiFi chip.
 - **interfaces file:** configures the bridge: while both the local network interface and the WAN-facing ethernet interface are configured as usual, the intranet ethernet port (from the USB adapter) is bridged with the on-board WiFi interface.
 - **dns masquerade:** used to provide IP configuration to clients on the LAN (both wired and wireless).
 - **iptables:** provides the natting for the WLAN and firewalls the PI from outside connections. The only port left open is for ssh. The most relevant feature of these rules is that they do not rely on any explicit IP listing, thus they do not require reloading upon change of WAN IP. The file used (rc.local) is probably not the best choice, but it will do, as a start.
 - **ddclient:** updates the information used by DynDNS to resolve the public name.
 - **sshd:** after creating a basic user with no special rights/permissions, make it the only one allowed to perform ssh access.
````
/etc/ssh/sshd_config
Add:
AllowUsers gw
````
###**Fixing logging**

The logging will try to happen over the xconsole, but we are in headless mode, so prevent it by commenting out the following lines in **/etc/rsyslog.conf**:

````
#daemon.*;mail.*;\
#       news.err;\
#       *.=debug;*.=info;\
#       *.=notice;*.=warn       |/dev/xconsole
````

##**Acknowledgments**

These are the resources I used to put together the configuration.

 1. HOWTO: Create Wired/Wireless Router with dnsmasq
 2. USING YOUR NEW RASPBERRY PI 3 AS A WIFI ACCESS POINT WITH HOSTAPD
 3. Setup Wireless Access Point (WAP) with Hostapd
 4. Turn any computer into a wireless access point with Hostapd
 5. Systemd Timers
 6. External antenna modifications for the Raspberry Pi 3
 7. Disabling log to xconsole

[1] https://ubuntuforums.org/showthread.php?t=716192

[2] https://frillip.com/using-your-raspberry-pi-3-as-a-wifi-access-point-with-hostapd/

[3] https://www.cyberciti.biz/faq/debian-ubuntu-linux-setting-wireless-access-point/

[4] https://seravo.fi/2014/create-wireless-access-point-hostapd

[5] https://wiki.archlinux.org/index.php/Systemd/Timers

[6] https://dorkbotpdx.org/blog/wramsdell/external_antenna_modifications_for_the_raspberry_pi_3

[7] https://www.raspberrypi.org/forums/viewtopic.php?f=63&t=134971#p898539
