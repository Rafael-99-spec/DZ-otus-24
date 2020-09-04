# -*- mode: ruby -*-
# vim: set ft=ruby :

MACHINES = {
  :server => {
        :box_name => "centos/7",
        :ip_addr => '192.168.111.10',
	:disks => {
		            :sata1 => {
			                  :dfile => './sata1.vdi',
			                  :size => 2048,
			                  :port => 1
	             	},
		            :sata2 => {
                        :dfile => './sata2.vdi',
                        :size => 2048, # Megabytes
			                  :port => 2
		            },
	}
		
  },
  :client => {
        :box_name => "centos/7",
        :ip_addr => '192.168.111.11',
	:disks => {
		            :sata3 => {
			                  :dfile => './sata3.vdi',
			                  :size => 250,
			                  :port => 2
	             	},
  }

  }
} 
Vagrant.configure("2") do |config|

  MACHINES.each do |boxname, boxconfig|

    config.vm.define boxname do |box|

          box.vm.box = boxconfig[:box_name]
          box.vm.host_name = boxname.to_s

          #box.vm.network "forwarded_port", guest: 3260, host: 3260+offset

          box.vm.network "private_network", ip: boxconfig[:ip_addr]

          box.vm.provider :virtualbox do |vb|
            	  vb.customize ["modifyvm", :id, "--memory", "1024"]
                  needsController = false
		              boxconfig[:disks].each do |dname, dconf|
			            unless File.exist?(dconf[:dfile])
				          vb.customize ['createhd', '--filename', dconf[:dfile], '--variant', 'Fixed', '--size', dconf[:size]]
                                needsController =  true
          end

		    end
        if needsController == true
                     vb.customize ["storagectl", :id, "--name", "SATA", "--add", "sata" ]
                     boxconfig[:disks].each do |dname, dconf|
                         vb.customize ['storageattach', :id,  '--storagectl', 'SATA', '--port', dconf[:port], '--device', 0, '--type', 'hdd', '--medium', dconf[:dfile]]
                     end
                  end
      end
 	      config.vm.define "server", primary: true do |s|
            s.vm.hostname = 'server'
            #s.vm.network "private_network", ip: "192.168.111.10"
            s.vm.provision "shell", inline: <<-SHELL
            yum install -y epel-release && yum install -y borgbackup wget nano             
            sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
            sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config
            echo "toor" | passwd root --stdin
            systemctl restart sshd
            timedatectl set-timezone Europe/Kaliningrad
            SHELL
          end
    end

        config.vm.define "client" do |c|
            c.vm.hostname = 'client'
            #c.vm.network "private_network", ip: "192.168.111.11"
            c.vm.provision "shell", inline: <<-SHELL
            yum install -y epel-release wget nano && yum install -y borgbackup
            echo "toor" | passwd root --stdin
            timedatectl set-timezone Europe/Kaliningrad
            SHELL
        end             
  end                                                 
end
