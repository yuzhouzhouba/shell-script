/usr/bin/qemu-system-x86_64 -m 1024 -smp 2 -M pc -name kvmgt -hda $1 #-hdb media.img 
 -enable-kvm -net nic -net tap,script=/etc/qemu-ifup -vgt -vga vgt -machine kernel_irqchip=on -vgt_high_gm_sz 256 -vgt_fence_sz 4 -vgt_low_gm_sz 128  -cpu host -net nic,model=e1000,macaddr=00:DE:EF:12:34:5D
