## Vars
TEMPL_ID=9000

### Download latest cloud image
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# Adjust image to local settings
virt-customize -a jammy-server-cloudimg-amd64.img --install qemu-guest-agent
virt-customize -a jammy-server-cloudimg-amd64.img --run-command 'fstrim -av'

# Setup the template in proxmox
qm create $TEMPL_ID --name "ubuntu-2204-cloudinit-template-2" --memory 1024 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk $TEMPL_ID jammy-server-cloudimg-amd64.img local-lvm
qm set $TEMPL_ID --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-$TEMPL_ID-disk-0,discard=on
qm set $TEMPL_ID --boot c --bootdisk scsi0
qm set $TEMPL_ID --ide2 local-lvm:cloudinit
qm set $TEMPL_ID --ciuser torivar
qm set $TEMPL_ID --sshkeys /root/ssh_torivar_id_rsa.pub
qm set $TEMPL_ID --serial0 socket --vga serial0
qm set $TEMPL_ID --nameserver '192.168.1.1 9.9.9.9'
qm set $TEMPL_ID --agent 1
qm set $TEMPL_ID --cpu host
sleep 2
qm template $TEMPL_ID