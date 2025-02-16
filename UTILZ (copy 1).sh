




#----------------------------------------------------
#-------------------UTILZ



rm -f /var/lib/pacman/db.lck

sudo pacman -S fakeroot







#---------------------- Block 5: Quick Network Reset (run as rc)
tee ~/reset_network.sh <<'EOF'
#!/bin/bash
echo "Flushing connection tracking..."
sudo sysctl -w net.netfilter.nf_conntrack_max=0
sudo sysctl -w net.netfilter.nf_conntrack_max=2000000

echo "Resetting network interfaces..."
for interface in $(ip -o link show | awk -F': ' '{print $2}'); do
    if [[ $interface != "lo" ]]; then
        sudo ip link set $interface down
        sudo ip link set $interface up
    fi
done

echo "Flushing routing..."
sudo ip route flush cache

echo "Restarting network service..."
sudo systemctl restart systemd-networkd

echo "Done! Check your connection now."
EOF
chmod +x ~/reset_network.sh
    sudo ip link set wlo1 down
        sudo ip link set wlo1 up
        sudo ip route flush cache
        sudo systemctl restart systemd-networkd
        
        
        
        
        #------------------- EMERGENCY MEMORY RECLAIM -------------------
sync
echo 3 > /proc/sys/vm/drop_caches
echo 1 > /proc/sys/vm/compact_memory
sysctl -w vm.min_free_kbytes=1000000





Got it! You can use ix.io for a simple and hassle-free way to upload your file using curl. Here’s how you can do it:
Using ix.io with curl

    Create the list of installed packages:

    bash

pacman -Q > installed_packages.txt

Upload the file to ix.io:

bash

    curl -F 'f:1=<-' ix.io < installed_packages.txt

    This will output a URL where your file is hosted.

Example Steps

    Create the list of installed packages:

    bash

pacman -Q > installed_packages.txt

Upload the file to ix.io:

bash

    curl -F 'f:1=<-' ix.io < installed_packages.txt

    Copy the URL and share it here.

Example Output

Here’s an example of what the output might look like when uploading the file:

bash

[root@sysrescue ~]# pacman -Q > installed_packages.txt
[root@sysrescue ~]# curl -F 'f:1=<-' ix.io < installed_packages.txt
https://ix.io/1AbC

Copy the URL (https://ix.io/1AbC) and share it here.
Sharing the URL

Once you have the URL, you can share it here, and I can access the list of installed packages.

For example:

https://ix.io/1AbC

Feel free to follow these steps to upload your file to ix.io.








        
