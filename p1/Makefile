# Variables
SERVER_NAME = zihirriS
WORKER_NAME = zihirriSW

# Default target
all: up

# 🛠️ Fix KVM lock and boot the machines
up:
	@echo "🔒 Releasing KVM locks to allow VirtualBox to boot..."
	-@sudo modprobe -r kvm_intel 2>/dev/null || true
	-@sudo modprobe -r kvm_amd 2>/dev/null || true
	-@sudo modprobe -r kvm 2>/dev/null || true
	@echo "🚀 Starting Vagrant cluster..."
	vagrant up

# 🛑 Gracefully shut down the machines
down:
	@echo "🛑 Halting Vagrant machines..."
	vagrant halt

# 🗑️ Destroy the machines completely (Clean up)
clean:
	@echo "🗑️ Destroying all Vagrant machines to free up RAM..."
	vagrant destroy -f
	@echo "🧹 Removing ghost machines from VirtualBox (if any)..."
	-@VBoxManage unregistervm $(SERVER_NAME) --delete 2>/dev/null || true
	-@VBoxManage unregistervm $(WORKER_NAME) --delete 2>/dev/null || true

# 🔄 Nuke everything and rebuild from scratch
rebuild: clean up

# 💻 Shortcuts to log into the machines
ssh-server:
	vagrant ssh $(SERVER_NAME)

ssh-worker:
	vagrant ssh $(WORKER_NAME)

# Show cluster status
status:
	vagrant status
