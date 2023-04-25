584fe668-abeb-4ee0-a0b4-7b8d73c01d7d

vda:66899547-eb2b-4e77-976d-dfdb970ae22d
vdb:27e01f2a-f477-402a-bcb9-71d7de6e74ad


net-id:acd31833-54c7-4f71-8219-04574ebc84b9
flavor-id:110
vloume-id:3d51727d-3855-47cc-8055-e87e93cff5ac
image-id:caccaec2-7eaa-473f-a896-f72d2e2f9b9a 
mysql+pymysql://nova:gWLyXyM4QqMxKohAACpmbdoNq87kVRqrCC0FxDqP


qemu-img create -f qcow2 /var/chengjun/win10.qcow2 40G

virt-install \
  --network bridge=virbr0,model=virtio \
  --name win10 \
  --ram=2048 \
  --vcpus=1 \
  --os-type=windows --os-variant=win10 \
  --disk path=/var/chengjun/win10.qcow2,format=qcow2,bus=virtio,cache=none,size=40 \
  --graphics vnc,listen=0.0.0.0,port=5920 --noautoconsole \
  --cdrom=/var/chengjun/Windows.iso


  virtio-win-0.1.229.iso