# Variables
SERVER_NAME = zihirriS

# Default target
all: up

# 🛠️ Fix KVM lock and boot the machine
up:
	@echo "🔒 Releasing KVM locks to allow VirtualBox to boot..."
	-@sudo modprobe -r kvm_intel 2>/dev/null || true
	-@sudo modprobe -r kvm_amd 2>/dev/null || true
	-@sudo modprobe -r kvm 2>/dev/null || true
	@echo "🚀 Starting Vagrant machine for Part 2..."
	vagrant up
	@echo "⏳ Waiting a few seconds for K3s to fully initialize..."
	sleep 15
	@echo "✅ Machine is up! Run 'make deploy' to apply your YAML files."

# 📦 Automatically apply the YAML files from outside the VM
deploy:
	@echo "📦 Deploying apps and Ingress to Kubernetes..."
	vagrant ssh $(SERVER_NAME) -c "kubectl apply -f /vagrant/confs/"
	@echo "👀 Watch the pods spin up by running: make watch"

# 🎯 Run the Defense Tests automatically
test:
	@echo "🧪 Testing App 1 Routing..."
	curl -H "Host: app1.com" http://192.168.56.110
	@echo "\n🧪 Testing App 2 Routing (Load Balanced)..."
	curl -H "Host: app2.com" http://192.168.56.110
	@echo "\n🧪 Testing App 3 Routing (Default Fallback)..."
	curl -H "Host: random-garbage.com" http://192.168.56.110
	@echo "\n✅ Testing complete!"

# 🛑 Gracefully shut down the machine
down:
	@echo "🛑 Halting Vagrant machine..."
	vagrant halt

# 🗑️ Destroy the machine completely (Clean up)
clean:
	@echo "🗑️ Destroying Part 2 machine to free up RAM..."
	vagrant destroy -f
	@echo "🧹 Removing ghost machines from VirtualBox (if any)..."
	-@VBoxManage unregistervm $(SERVER_NAME) --delete 2>/dev/null || true

# 💻 Shortcuts
ssh:
	vagrant ssh $(SERVER_NAME)

watch:
	vagrant ssh $(SERVER_NAME) -c "kubectl get pods -w"

status:
	vagrant status
