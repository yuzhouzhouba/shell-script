#this is some btrfs cmd

#mount 
mount /dev/sda7 /mnt

#show
btrfs subvolume list '/dir'
btrfs subvolume show '/subvolume'

#new
btrfs subvolume create 'vol_name'
btrfs subvolume snapshot 'old_vol' 'new_vol'

#delete
btrfs subvolume delete


#tips
只能创建一个新的子卷，或者给已经子卷做一份快照
