NUM_WORKERS = 2
NUMBER_CPU_CTRL = 2
NUMBER_CPU_WORKER = 4
MEMORY_SIZE_CTRL = 4096
MEMORY_SIZE_WORKER = 2816

IP_CTRL = "192.168.56.100"
SUBNET = "192.168.56"


Vagrant.configure("2") do |config|

  config.vm.boot_timeout = 600
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.box_version = "202510.26.0"

  config.vm.synced_folder "./shared", "/mnt/shared", create: true
  config.vm.define "ctrl" do |ctrl_config|
    ctrl_config.vm.hostname = "ctrl"
    ctrl_config.vm.network "private_network", ip: IP_CTRL
    ctrl_config.vm.provider "virtualbox" do |vb|
      vb.cpus = NUMBER_CPU_CTRL
      vb.memory = MEMORY_SIZE_CTRL
      vb.gui = false
    end
  end

  (1..NUM_WORKERS).each do |i|
    worker_name = "node-#{i}"
    config.vm.define worker_name do |worker_config|
      worker_config.vm.hostname = worker_name
      ip_octet = 100 + i
      worker_config.vm.network "private_network", ip: "#{SUBNET}.#{ip_octet}"
      worker_config.vm.provider "virtualbox" do |vb|
        vb.memory = MEMORY_SIZE_WORKER
        vb.cpus = NUMBER_CPU_WORKER
        vb.gui = false
      end
    end
  end

  # This file stored in .vagrant folder, but I guess we need to generate it manually according to the rubric
  config.trigger.before [:provision, :up, :reload] do |t|
    t.name = "Generate inventory.cfg"
    t.ruby do |env, machine|
      if machine.name.to_s == "ctrl"
        File.open("provisioning/inventory.cfg", "w") do |f|
          f.puts "[masters]"
          f.puts "ctrl ansible_host=#{IP_CTRL} ansible_user=vagrant"
          f.puts ""
          f.puts "[workers]"
          (1..NUM_WORKERS).each do |i|
             f.puts "node-#{i} ansible_host=#{SUBNET}.#{100 + i} ansible_user=vagrant"
          end
          f.puts ""
          f.puts "[cluster:children]"
          f.puts "masters"
          f.puts "workers"
        end
      end
    end
  end

  # Ansible hits all workers instantly (placed at the end)
  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "provisioning/playbook.yml"
    ansible.limit = "all"
    ansible.raw_arguments = ["--forks=10"]
    ansible.extra_vars = {
      worker_count: NUM_WORKERS,
      ctrl_ip: IP_CTRL,
      subnet_prefix: SUBNET
    }

    ansible.groups = {
      "masters" => ["ctrl"],
      "workers" => (1..NUM_WORKERS).map { |i| "node-#{i}" },
      "cluster:children" => ["masters", "workers"]
    }
  end

end  
